local layout = require("cursor.ui.layout")
local state = require("cursor.state")

local M = {}

function M.render()
  local buf = layout.chat_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  for _, msg in ipairs(state.get().messages) do
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
    end
  end

  local streaming = state.get().assistant_buffer
  if streaming and streaming ~= "" then
    table.insert(lines, "Agent")
    for line in streaming:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    table.insert(lines, "")
  end

  if #lines == 0 then
    table.insert(lines, "Cursor Agent ready. Type a message below.")
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  if layout.chat_win and vim.api.nvim_win_is_valid(layout.chat_win) then
    local last = #lines
    if last > 0 then
      vim.api.nvim_win_set_cursor(layout.chat_win, { last, 0 })
    end
  end
end

return M
