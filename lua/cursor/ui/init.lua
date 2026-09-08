local config = require("cursor.config")
local state = require("cursor.state")

local M = {}

M._refresh_timer = nil

function M.schedule_refresh()
  if M._refresh_timer then
    return
  end
  local flush_ms = config.get().ui_flush_ms or 30
  M._refresh_timer = vim.defer_fn(function()
    M._refresh_timer = nil
    M.refresh()
  end, flush_ms)
end

function M.refresh()
  local layout = require("cursor.ui.layout")
  if layout.is_open() then
    require("cursor.ui.chat").render()
    require("cursor.ui.activity").render()
    layout.update_title()
  end
end

function M.open()
  require("cursor.ui.layout").open()
  M.refresh()
end

function M.close()
  require("cursor.ui.layout").close()
end

function M.toggle()
  local layout = require("cursor.ui.layout")
  if layout.is_open() then
    layout.close()
  else
    M.open()
  end
end

function M.focus()
  local layout = require("cursor.ui.layout")
  if not layout.is_open() then
    M.open()
  end
  layout.focus_input()
end

function M.focus_chat()
  local layout = require("cursor.ui.layout")
  if not layout.is_open() then
    M.open()
  end
  layout.focus_chat()
end

function M.focus_code()
  require("cursor.ui.layout").focus_code()
end

function M.ensure_started(callback)
  local transport = require("cursor.transport")
  if transport.is_running() and state.get().session_id then
    if callback then
      callback(true)
    end
    return
  end
  local acp = require("cursor.acp")
  acp.start({}, function(ok, err)
    if not ok then
      vim.notify("[cursor] " .. (err or "Failed to start agent"), vim.log.levels.ERROR)
      if callback then
        callback(false, err)
      end
      return
    end
    if callback then
      callback(true)
    end
  end)
end

return M
