local config = require("cursor.config")
local rpc = require("cursor.rpc")
local schedule = require("cursor.schedule")
local transport = require("cursor.transport")

local M = {}

local pending = {}

local function option_id(option)
  return option.id or option.optionId or option.name
end

function M.handle(params, request_id)
  local cfg = config.get().permissions
  local default = cfg.default or "ask"

  if default == "deny" then
    schedule.ui(function()
      M.respond(request_id, M.default_option_id(params, "reject"))
    end)
    return nil
  end

  table.insert(pending, { params = params, id = request_id })

  schedule.ui(function()
    require("cursor.ui.permission").show(params, request_id)
  end)

  return nil
end

function M.default_option_id(params, kind)
  local options = params.options or (params.toolCall and params.toolCall.options) or {}

  if kind == "session" then
    for _, opt in ipairs(options) do
      local id = option_id(opt)
      if id and (id:find("session", 1, true) or id:find("always", 1, true)) then
        return id
      end
    end
    return "allow-always"
  end

  for _, opt in ipairs(options) do
    local id = option_id(opt)
    if id and id:find(kind, 1, true) then
      return id
    end
  end

  if kind == "reject" then
    return "reject-once"
  end
  if kind == "allow" then
    return "allow-once"
  end
  return kind .. "-once"
end

function M.respond(request_id, option_id)
  transport.send(rpc.response(request_id, {
    outcome = { outcome = "selected", optionId = option_id },
  }))
end

function M.format_request(params)
  local lines = { "Cursor wants to:" }
  if params.toolCall and params.toolCall.title then
    table.insert(lines, params.toolCall.title)
  elseif params.title then
    table.insert(lines, params.title)
  end
  if params.message then
    table.insert(lines, params.message)
  end
  return table.concat(lines, "\n")
end

return M
