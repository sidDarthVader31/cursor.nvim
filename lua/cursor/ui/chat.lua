local layout = require("cursor.ui.layout")
local markdown = require("cursor.ui.markdown")
local state = require("cursor.state")
local status = require("cursor.ui.status")

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

local function split_lines(content)
  if not content or content == "" then
    return {}
  end
  return vim.split(content, "\n", { plain = true })
end

local function apply_highlights(buf, marks, excluded)
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for _, entry in ipairs(marks) do
    local opts = {
      end_row = entry.line,
      hl_group = entry.hl,
      strict = false,
    }
    if entry.col then
      opts.end_col = entry.end_col
    elseif entry.end_col then
      opts.end_col = entry.end_col
    end
    vim.api.nvim_buf_set_extmark(buf, M.ns, entry.line, entry.col or 0, opts)
  end
  markdown.apply(buf, M.ns, excluded)
end

function M.render()
  local buf = layout.chat_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  local marks = {}
  local excluded = {}
  local st = state.get()
  local show_status = st.session_id ~= nil

  local function exclude_line(idx)
    excluded[idx] = true
  end

  if show_status then
    local status_text = status.text()
    table.insert(lines, status_text)
    exclude_line(0)
    table.insert(marks, { line = 0, hl = "CursorTitle" })
    local sep_width = layout.chat_win and vim.api.nvim_win_is_valid(layout.chat_win)
      and vim.api.nvim_win_get_width(layout.chat_win)
      or status.separator_width()
    table.insert(lines, string.rep("─", math.max(20, sep_width - 2)))
    exclude_line(1)
    table.insert(marks, { line = 1, hl = "Comment" })
  end

  local function add_heading(text, hl)
    local line_idx = #lines
    table.insert(lines, text)
    exclude_line(line_idx)
    table.insert(marks, { line = line_idx, end_col = #text, hl = hl })
  end

  local function add_content(content)
    for _, line in ipairs(split_lines(content)) do
      table.insert(lines, line)
    end
  end

  for _, msg in ipairs(st.messages) do
    if msg.role == "user" then
      add_heading("You", "CursorUser")
      add_content(msg.content)
      table.insert(lines, "")
    elseif msg.role == "assistant" then
      add_heading("Agent", "CursorAgent")
      add_content(msg.content)
      table.insert(lines, "")
    elseif msg.role == "tool" then
      local line_idx = #lines
      table.insert(lines, string.format("%s %s", tool_icon(msg.status), msg.title or "tool"))
      exclude_line(line_idx)
    end
  end

  if st.assistant_buffer and st.assistant_buffer ~= "" then
    add_heading("Agent", "CursorAgent")
    add_content(st.assistant_buffer)
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
      local line_idx = #lines
      table.insert(lines, string.format("%s %s", tool_icon(tc.status), tc.title or "tool"))
      exclude_line(line_idx)
    end
  end

  if st.last_error and st.last_error ~= "" then
    table.insert(lines, "")
    local err_idx = #lines
    table.insert(lines, "Error: " .. st.last_error)
    exclude_line(err_idx)
  end

  local has_content = #st.messages > 0
    or (st.assistant_buffer and st.assistant_buffer ~= "")
    or (st.last_error and st.last_error ~= "")

  if not has_content and not show_status then
    local welcome_idx = #lines
    table.insert(lines, "Cursor Agent ready. Type a message below.")
    exclude_line(welcome_idx)
    local hint_idx = #lines
    table.insert(lines, "Enter to send · Shift+Enter for newline")
    exclude_line(hint_idx)
  end

  local ok, err = pcall(function()
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    apply_highlights(buf, marks, excluded)
  end)

  if not ok then
    vim.notify("[cursor] render failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  layout.update_title()

  if layout.chat_win and vim.api.nvim_win_is_valid(layout.chat_win) then
    local last = #lines
    if last > 0 then
      pcall(vim.api.nvim_win_set_cursor, layout.chat_win, { last, 0 })
    end
  end
end

return M
