local acp = require("cursor.acp")
local chats_index = require("cursor.chats_index")
local project = require("cursor.project")
local schedule = require("cursor.schedule")
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
  schedule.defer(function()
    local root = project.root()
    local chats = chats_index.list_for_root(root)
    callback(chats)
  end)
end

return M
