local M = {}

--- Run fn on the main loop. Required before any UI/buffer/win API from fast events
--- (vim.system stdout/stderr, some keymap callbacks, etc.).
function M.ui(fn)
  if vim.in_fast_event() then
    vim.schedule(fn)
  else
    fn()
  end
end

--- Always defer to the next main-loop tick (e.g. ACP process callbacks).
function M.defer(fn)
  vim.schedule(fn)
end

return M
