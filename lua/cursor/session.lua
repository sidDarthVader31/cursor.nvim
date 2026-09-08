local acp = require("cursor.acp")
local state = require("cursor.state")

local M = {}

function M.new(callback)
  acp.session_new(function(result, err)
    if callback then
      callback(result, err)
    end
  end)
end

function M.resume(session_id, callback)
  acp.session_load(session_id, function(result, err)
    if callback then
      callback(result, err)
    end
  end)
end

function M.current_id()
  return state.get().session_id
end

function M.list_chats(callback)
  local config = require("cursor.config")
  local cmd = { config.get().agent_command, "ls" }
  vim.system(cmd, {}, function(obj)
    if obj.code ~= 0 then
      callback({})
      return
    end
    local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
    local chats = {}
    for _, line in ipairs(lines) do
      table.insert(chats, { id = line, title = line })
    end
    callback(chats)
  end)
end

return M
