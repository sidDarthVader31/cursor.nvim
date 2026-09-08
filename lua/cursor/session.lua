local acp = require("cursor.acp")
local chats_index = require("cursor.chats_index")
local log = require("cursor.log")
local project = require("cursor.project")
local schedule = require("cursor.schedule")
local state = require("cursor.state")

local M = {}

local function sync_session_title(session_id, title)
  if not session_id or not title or title == "" then
    return
  end
  chats_index.sync_title(session_id, title, { cwd = project.root() })
end

function M.new(callback)
  state.set_session_title("New chat")
  acp.session_new(function(result, err)
    if not err and result and result.title and result.sessionId then
      state.set_session_title(result.title)
      sync_session_title(result.sessionId, result.title)
    elseif not err and result and result.sessionId then
      sync_session_title(result.sessionId, "New chat")
    end
    if callback then
      callback(result, err)
    end
  end)
end

function M.resume(session_id, title, callback)
  if title then
    state.set_session_title(title)
    sync_session_title(session_id, title)
  else
    local looked_up = chats_index.title_for_session(session_id, project.root())
    state.set_session_title(looked_up or session_id:sub(1, 8))
  end
  acp.session_load(session_id, function(result, err)
    if not err and result and result.title then
      state.set_session_title(result.title)
      sync_session_title(session_id, result.title)
    end
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

function M.rename(title, session_id, callback)
  session_id = session_id or state.get().session_id
  if not session_id then
    local err = "No active session"
    if callback then
      callback(false, err)
    end
    return false, err
  end
  if not title or title == "" then
    local err = "Title cannot be empty"
    if callback then
      callback(false, err)
    end
    return false, err
  end

  chats_index.sync_title(session_id, title, { cwd = project.root() })

  if session_id == state.get().session_id then
    state.set_session_title(title)
    require("cursor.ui").schedule_refresh()
  end

  acp.session_set_title(session_id, title, function(_, acp_err)
    if acp_err then
      log.debug("session/setTitle not supported or failed: " .. vim.inspect(acp_err))
    end
    if callback then
      callback(true)
    end
  end)

  return true
end

function M.prompt_rename(session_id)
  session_id = session_id or state.get().session_id
  if not session_id then
    vim.notify("[cursor] No active session to rename", vim.log.levels.WARN)
    return
  end
  local default = state.get().session_title or ""
  vim.ui.input({
    prompt = "Rename chat: ",
    default = default,
  }, function(input)
    if not input or input == "" then
      return
    end
    M.rename(input, session_id, function(ok, err)
      if not ok then
        vim.notify("[cursor] Rename failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
      else
        vim.notify("[cursor] Chat renamed to: " .. input, vim.log.levels.INFO)
      end
    end)
  end)
end

return M
