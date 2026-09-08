local state = require("cursor.state")
local log = require("cursor.log")

local M = {}

M.handlers = {}
M.request_handlers = {}

function M.on_notification(method, fn)
  M.handlers[method] = fn
end

function M.on_request(method, fn)
  M.request_handlers[method] = fn
end

function M.request(method, params, callback)
  local id = state.next_rpc_id()
  state.get().pending_requests[id] = callback
  local msg = vim.json.encode({
    jsonrpc = "2.0",
    id = id,
    method = method,
    params = params or vim.empty_dict(),
  })
  return msg .. "\n", id
end

function M.notify(method, params)
  local msg = vim.json.encode({
    jsonrpc = "2.0",
    method = method,
    params = params or vim.empty_dict(),
  })
  return msg .. "\n"
end

function M.response(id, result)
  local msg = vim.json.encode({
    jsonrpc = "2.0",
    id = id,
    result = result or vim.empty_dict(),
  })
  return msg .. "\n"
end

function M.error_response(id, code, message, data)
  local msg = vim.json.encode({
    jsonrpc = "2.0",
    id = id,
    error = {
      code = code,
      message = message,
      data = data,
    },
  })
  return msg .. "\n"
end

function M.handle_line(line)
  local ok, decoded = pcall(vim.json.decode, line)
  if not ok or type(decoded) ~= "table" then
    log.warn("Failed to decode JSON-RPC message")
    return nil
  end

  local st = state.get()

  if decoded.id and decoded.result ~= nil then
    local cb = st.pending_requests[decoded.id]
    if cb then
      st.pending_requests[decoded.id] = nil
      cb(decoded.result, nil)
    end
    return nil
  end

  if decoded.id and decoded.error then
    local cb = st.pending_requests[decoded.id]
    if cb then
      st.pending_requests[decoded.id] = nil
      cb(nil, decoded.error)
    end
    return nil
  end

  if decoded.method and decoded.id then
    local handler = M.request_handlers[decoded.method]
    if handler then
      local result = handler(decoded.params or {}, decoded.id)
      return M.response(decoded.id, result)
    end
    log.debug("Unhandled request: " .. decoded.method)
    return M.error_response(decoded.id, -32601, "Method not found: " .. decoded.method)
  end

  if decoded.method then
    local handler = M.handlers[decoded.method]
    if handler then
      handler(decoded.params or {})
    else
      log.debug("Unhandled notification: " .. decoded.method)
    end
    return nil
  end

  return nil
end

return M
