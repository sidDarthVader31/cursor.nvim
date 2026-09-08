local layout = require("cursor.ui.layout")
local state = require("cursor.state")

local M = {}

local function tool_icon(status)
  if status == "completed" then
    return "✓"
  elseif status == "failed" then
    return "✗"
  end
  return "◌"
end

function M.render()
  local buf = layout.chat_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  local st = state.get()

  for _, msg in ipairs(st.messages) do
    if msg.role == "user" then
      table.insert(lines, "You")
      for line in (msg.content or ""):gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      table.insert(lines, "")
    elseif msg.role == "assistant" then
      table.insert(lines, "Agent")
      for line in (msg.content or ""):gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      table.insert(lines, "")
    elseif msg.role == "tool" then
      table.insert(lines, string.format("%s %s", tool_icon(msg.status), msg.title or "tool"))
    end
  end

  if st.assistant_buffer and st.assistant_buffer ~= "" then
    table.insert(lines, "Agent")
    for line in st.assistant_buffer:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    table.insert(lines, "")
  end

  -- Live tool activity (not yet in messages)
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
