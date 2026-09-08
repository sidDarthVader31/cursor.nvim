local state = require("cursor.state")

local M = {}

function M.text(opts)
  opts = opts or {}
  local st = state.get()
  if not st.session_id then
    return opts.window and " Cursor " or ""
  end

  local parts = {}
  if st.session_title and st.session_title ~= "" then
    table.insert(parts, st.session_title)
  end
  table.insert(parts, state.display_value("model"))
  table.insert(parts, state.display_value("thought_level"))
  table.insert(parts, state.display_value("mode"))

  local text = table.concat(parts, "  ·  ")
  if opts.window then
    return " Cursor  " .. text .. " "
  end
  return text
end

function M.separator_width()
  if vim.api.nvim_get_current_win() then
    return vim.api.nvim_win_get_width(0)
  end
  return 50
end

return M
