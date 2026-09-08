local config = require("cursor.config")

local M = {}

local function should_log(level)
  local levels = { trace = 0, debug = 1, info = 2, warn = 3, error = 4 }
  return (levels[level] or 3) >= config.get_log_level()
end

function M.trace(msg)
  if should_log("trace") then
    vim.notify("[cursor] " .. msg, vim.log.levels.DEBUG)
  end
end

function M.debug(msg)
  if should_log("debug") then
    vim.notify("[cursor] " .. msg, vim.log.levels.DEBUG)
  end
end

function M.info(msg)
  if should_log("info") then
    vim.notify("[cursor] " .. msg, vim.log.levels.INFO)
  end
end

function M.warn(msg)
  if should_log("warn") then
    vim.notify("[cursor] " .. msg, vim.log.levels.WARN)
  end
end

function M.error(msg)
  if should_log("error") then
    vim.notify("[cursor] " .. msg, vim.log.levels.ERROR)
  end
end

return M
