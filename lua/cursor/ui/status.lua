local spinner = require("cursor.ui.spinner")
local state = require("cursor.state")

local M = {}

local function active_tool_title(st)
  for _, tc in pairs(st.tool_calls or {}) do
    if tc.status == "in_progress" or tc.status == "pending" then
      return tc.title or "tool"
    end
  end
  return nil
end

function M.text(opts)
  opts = opts or {}
  local st = state.get()
  if not st.session_id then
    return opts.window and " Cursor " or ""
  end

  local parts = {}
  if st.prompting then
    local spin = spinner.current()
    local working = spin .. " Working"
    local tool = active_tool_title(st)
    if tool then
      working = working .. " · " .. tool
    end
    table.insert(parts, working)
  elseif st.session_title and st.session_title ~= "" then
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
