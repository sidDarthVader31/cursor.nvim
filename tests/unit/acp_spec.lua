local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq

test("acp session update streaming", function()
  local state = require("cursor.state")
  local acp = require("cursor.acp")
  state.reset()
  acp.handle_session_update({
    update = {
      sessionUpdate = "agent_message_chunk",
      content = { text = "hello" },
    },
  })
  assert_eq(state.get().assistant_buffer, "hello")
  acp.handle_session_update({
    update = {
      sessionUpdate = "agent_message_chunk",
      content = { text = " world" },
    },
  })
  assert_eq(state.get().assistant_buffer, "hello world")
end)
