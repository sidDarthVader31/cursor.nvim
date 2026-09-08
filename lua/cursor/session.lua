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

--- Parse one line from `agent ls` output into { id, title }.
function M.parse_ls_line(line)
  line = vim.trim(line or "")
  if line == "" then
    return nil
  end
  local id, title = line:match("^(%S+)%s+(.+)$")
  if id and title then
    return { id = id, title = vim.trim(title) }
  end
  if line:match("^sess_") then
    return { id = line, title = line }
  end
  return nil
end

function M.parse_ls_output(lines)
  local chats = {}
  for _, line in ipairs(lines or {}) do
    local parsed = M.parse_ls_line(line)
    if parsed then
      table.insert(chats, parsed)
    end
  end
  return chats
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
    callback(M.parse_ls_output(lines))
  end)
end

return M
