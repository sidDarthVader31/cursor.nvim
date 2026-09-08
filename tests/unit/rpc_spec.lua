local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

test("rpc request encoding", function()
  local rpc = require("cursor.rpc")
  local state = require("cursor.state")
  state.reset()
  local data, id = rpc.request("initialize", { protocolVersion = 1 }, function() end)
  assert_eq(id, 1)
  assert_true(data:find("initialize") ~= nil)
end)

test("rpc response handling", function()
  local rpc = require("cursor.rpc")
  local state = require("cursor.state")
  state.reset()
  local called = false
  rpc.request("test", {}, function(result)
    called = true
    assert_eq(result.status, "ok")
  end)
  rpc.handle_line(vim.json.encode({ jsonrpc = "2.0", id = 1, result = { status = "ok" } }))
  assert_true(called)
end)

test("rpc async request returns nil response", function()
  local rpc = require("cursor.rpc")
  local state = require("cursor.state")
  state.reset()
  rpc.on_request("test/async", function()
    return nil
  end)
  local response = rpc.handle_line(vim.json.encode({
    jsonrpc = "2.0",
    id = 99,
    method = "test/async",
    params = {},
  }))
  assert_eq(response, nil)
end)

test("rpc response with null result dispatches callback", function()
  local rpc = require("cursor.rpc")
  local state = require("cursor.state")
  state.reset()
  local called = false
  rpc.request("test/null", {}, function(result, err)
    called = true
    assert_eq(result, vim.NIL)
    assert_eq(err, nil)
  end)
  rpc.handle_line(vim.json.encode({ jsonrpc = "2.0", id = 1, result = vim.NIL }))
  assert_true(called)
end)
