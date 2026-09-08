local config = require("cursor.config")
local schedule = require("cursor.schedule")
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
  schedule.ui(function()
    local layout = require("cursor.ui.layout")
    if layout.is_open() then
      require("cursor.ui.chat").render()
      layout.update_title()
    end
  end)
end

function M.open()
  schedule.ui(function()
    require("cursor.ui.layout").open()
    M.refresh()
  end)
end

function M.close()
  schedule.ui(function()
    require("cursor.ui.layout").close()
  end)
end

function M.toggle()
  schedule.ui(function()
    local layout = require("cursor.ui.layout")
    if layout.is_open() then
      layout.close()
    else
      require("cursor.ui.layout").open()
      M.refresh()
    end
  end)
end

function M.focus()
  schedule.ui(function()
    local layout = require("cursor.ui.layout")
    if not layout.is_open() then
      layout.open()
      M.refresh()
    end
    layout.focus_input()
  end)
end

function M.focus_chat()
  schedule.ui(function()
    local layout = require("cursor.ui.layout")
    if not layout.is_open() then
      layout.open()
      M.refresh()
    end
    layout.focus_chat()
  end)
end

function M.focus_code()
  schedule.ui(function()
    require("cursor.ui.layout").focus_code()
  end)
end

function M.ensure_started(callback)
  local transport = require("cursor.transport")
  if transport.is_running() and state.get().session_id then
    if callback then
      schedule.defer(function()
        callback(true)
      end)
    end
    return
  end

  if not transport.find_agent() then
    local msg = "Cursor CLI `agent` not found — set agent_path in setup() or fix PATH"
    if callback then
      schedule.defer(function()
        callback(false, msg)
      end)
    end
    return
  end
  local acp = require("cursor.acp")
  acp.start({}, function(ok, err)
    schedule.defer(function()
      if not ok then
        local msg = err or "Failed to start agent"
        vim.notify("[cursor] " .. msg, vim.log.levels.ERROR)
        if callback then
          callback(false, msg)
        end
        return
      end
      if callback then
        callback(true)
      end
    end)
  end)
end

return M
