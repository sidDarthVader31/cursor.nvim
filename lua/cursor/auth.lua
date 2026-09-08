local config = require("cursor.config")
local env_util = require("cursor.env")
local transport = require("cursor.transport")

local M = {}

local function agent_argv(...)
  local agent = transport.find_agent()
  if not agent then
    return nil
  end
  return vim.list_extend({ agent }, { ... })
end

function M.status(callback)
  local cmd = agent_argv("status", "--format", "json")
  if not cmd then
    callback({ authenticated = false, raw = "agent not found" })
    return
  end
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

--- Programmatic login (headless). Prefer require("cursor.ui.login").start() for UI.
function M.login(opts)
  opts = opts or {}
  local cmd = agent_argv("login")
  if not cmd then
    if opts.on_exit then
      opts.on_exit({ code = 1, stdout = "", stderr = "agent not found" })
    end
    return nil
  end
  local env = env_util.current(opts.no_browser and { NO_OPEN_BROWSER = "1" } or nil)
  return vim.system(cmd, { env = env }, opts.on_exit)
end

function M.logout(callback)
  local cmd = agent_argv("logout")
  if not cmd then
    if callback then
      callback(false)
    end
    return
  end
  vim.system(cmd, {}, function(obj)
    if callback then
      callback(obj.code == 0)
    end
  end)
end

function M.about(callback)
  local cmd = agent_argv("about", "--format", "json")
  if not cmd then
    if callback then
      callback("", "agent not found", 1)
    end
    return
  end
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
