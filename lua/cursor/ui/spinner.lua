local M = {}

M.frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
M.index = 1
M.timer = nil

function M.current()
  return M.frames[M.index] or "◌"
end

function M.start(on_tick)
  M.stop()
  M.timer = vim.loop.new_timer()
  M.timer:start(0, 120, vim.schedule_wrap(function()
    M.index = (M.index % #M.frames) + 1
    if on_tick then
      on_tick()
    end
  end))
end

function M.stop()
  if M.timer then
    M.timer:stop()
    M.timer:close()
    M.timer = nil
  end
  M.index = 1
end

return M
