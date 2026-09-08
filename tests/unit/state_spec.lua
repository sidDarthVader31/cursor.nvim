local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq

test("state rpc ids", function()
  local state = require("cursor.state")
  state.reset()
  assert_eq(state.next_rpc_id(), 1)
  assert_eq(state.next_rpc_id(), 2)
end)

test("state error tracking", function()
  local state = require("cursor.state")
  state.reset()
  state.set_error("boom")
  assert_eq(state.get().last_error, "boom")
  state.clear_error()
  assert_eq(state.get().last_error, nil)
end)
