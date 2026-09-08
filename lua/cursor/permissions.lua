local config = require("cursor.config")
local log = require("cursor.log")
local rpc = require("cursor.rpc")
local state = require("cursor.state")
local transport = require("cursor.transport")

local M = {}

local pending = {}

function M.handle(params, request_id)
  local cfg = config.get().permissions
  local default = cfg.default or "ask"

  if default == "deny" then
    transport.send(rpc.response(request_id, {
      outcome = { outcome = "selected", optionId = "reject-once" },
    }))
    return nil
  end

  table.insert(pending, { params = params, id = request_id })

  vim.schedule(function()
    require("cursor.ui.permission").show(params, request_id)
  end)

  return nil
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
