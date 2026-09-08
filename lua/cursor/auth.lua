local config = require("cursor.config")
local log = require("cursor.log")

local M = {}

function M.status(callback)
  local cmd = { config.get().agent_command, "status", "--format", "json" }
  vim.system(cmd, {}, function(obj)
    if obj.code ~= 0 then
      callback({ authenticated = false, raw = obj.stderr })
      return
    end
    local ok, data = pcall(vim.json.decode, obj.stdout)
    if ok and data then
      callback(data)
    else
      callback({ authenticated = obj.stdout and obj.stdout ~= "", raw = obj.stdout })
    end
  end)
end

function M.login(opts)
  opts = opts or {}
  local cmd = { config.get().agent_command, "login" }
  local env = vim.deepcopy(vim.env)
  if opts.no_browser then
    env.NO_OPEN_BROWSER = "1"
  end
  return vim.system(cmd, { env = env }, opts.on_exit)
end

function M.logout(callback)
  local cmd = { config.get().agent_command, "logout" }
  vim.system(cmd, {}, function(obj)
    if callback then
      callback(obj.code == 0)
    end
  end)
end

function M.about(callback)
  local cmd = { config.get().agent_command, "about", "--format", "json" }
  vim.system(cmd, {}, function(obj)
    if callback then
      callback(obj.stdout, obj.stderr, obj.code)
    end
  end)
end

function M.is_api_key_set()
  return vim.env.CURSOR_API_KEY ~= nil and vim.env.CURSOR_API_KEY ~= ""
end

return M
