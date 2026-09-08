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

test("acp session_info_update syncs title overlay", function()
  local state = require("cursor.state")
  local acp = require("cursor.acp")
  local chats_index = require("cursor.chats_index")

  state.reset()
  chats_index.clear_overrides()
  state.get().session_id = "sess-auto-title"
  state.get().project_root = "/tmp/cursor-nvim-test-project"

  acp.handle_session_update({
    sessionId = "sess-auto-title",
    update = {
      sessionUpdate = "session_info_update",
      title = "Auto generated title",
    },
  })

  assert_eq(state.get().session_title, "Auto generated title")
  assert_eq(chats_index.get_remembered_title("sess-auto-title"), "Auto generated title")

  chats_index.clear_overrides()
end)
