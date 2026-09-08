local layout = require("cursor.ui.layout")
local state = require("cursor.state")

local M = {}

M.ns = vim.api.nvim_create_namespace("cursor-chat")

local function tool_icon(status)
  if status == "completed" then
    return "✓"
  elseif status == "failed" then
    return "✗"
  end
  return "◌"
end

local function apply_highlights(buf, heading_lines)
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for _, entry in ipairs(heading_lines) do
    vim.api.nvim_buf_set_extmark(buf, M.ns, entry.line, 0, {
      end_row = entry.line,
      end_col = #entry.text,
      hl_group = entry.hl,
      strict = false,
    })
  end
end

function M.render()
  local buf = layout.chat_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  local heading_lines = {}
  local st = state.get()

  local function add_heading(text, hl)
    table.insert(lines, text)
    table.insert(heading_lines, { line = #lines - 1, text = text, hl = hl })
  end

  for _, msg in ipairs(st.messages) do
    if msg.role == "user" then
      add_heading("You", "CursorUser")
      for line in (msg.content or ""):gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      table.insert(lines, "")
    elseif msg.role == "assistant" then
      add_heading("Agent", "CursorAgent")
      for line in (msg.content or ""):gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      table.insert(lines, "")
    elseif msg.role == "tool" then
      table.insert(lines, string.format("%s %s", tool_icon(msg.status), msg.title or "tool"))
    end
  end

  if st.assistant_buffer and st.assistant_buffer ~= "" then
    add_heading("Agent", "CursorAgent")
    for line in st.assistant_buffer:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    table.insert(lines, "")
  end

  for _, tc in pairs(st.tool_calls) do
    local already = false
    for _, msg in ipairs(st.messages) do
      if msg.role == "tool" and msg.tool_id == tc.id then
        already = true
        break
      end
    end
    if not already then
      table.insert(lines, string.format("%s %s", tool_icon(tc.status), tc.title or "tool"))
    end
  end

  if st.last_error and st.last_error ~= "" then
    table.insert(lines, "")
    table.insert(lines, "Error: " .. st.last_error)
  end

  if #lines == 0 then
    table.insert(lines, "Cursor Agent ready. Type a message below.")
    table.insert(lines, "Enter to send · Shift+Enter for newline")
  end

  local ok, err = pcall(function()
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    apply_highlights(buf, heading_lines)
  end)

  if not ok then
    vim.notify("[cursor] render failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  if layout.chat_win and vim.api.nvim_win_is_valid(layout.chat_win) then
    local last = #lines
    if last > 0 then
      pcall(vim.api.nvim_win_set_cursor, layout.chat_win, { last, 0 })
    end
  end
end

return M
