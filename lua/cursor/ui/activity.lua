local layout = require("cursor.ui.layout")
local state = require("cursor.state")

local M = {}

function M.render()
  local buf = layout.chat_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  -- Tool activity is rendered inline in chat for MVP
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local tool_lines = {}
  for _, tc in pairs(state.get().tool_calls) do
    local icon = "◌"
    if tc.status == "completed" then
      icon = "✓"
    elseif tc.status == "failed" then
      icon = "✗"
    end
    table.insert(tool_lines, string.format("%s %s", icon, tc.title or "tool"))
  end
  if #tool_lines > 0 then
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    local base = #lines
    for i, line in ipairs(tool_lines) do
      vim.api.nvim_buf_set_lines(buf, base + i - 1, base + i - 1, false, { line })
    end
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end
end

return M
