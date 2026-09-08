local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

test("state display_value returns option name", function()
  local state = require("cursor.state")
  state.reset()
  state.update_config_options({
    {
      id = "model",
      category = "model",
      currentValue = "model-1",
      options = {
        { value = "model-1", name = "Model 1" },
        { value = "model-2", name = "Model 2" },
      },
    },
    {
      id = "thought_level",
      category = "thought_level",
      currentValue = "high",
      options = {
        { value = "low", name = "Low" },
        { value = "high", name = "High" },
      },
    },
    {
      id = "mode",
      category = "mode",
      currentValue = "ask",
      options = {
        { value = "ask", name = "Ask" },
        { value = "code", name = "Code" },
      },
    },
  })
  assert_eq(state.display_value("model"), "Model 1")
  assert_eq(state.display_value("thought_level"), "High")
  assert_eq(state.display_value("mode"), "Ask")
end)

test("state set_session_title stores title", function()
  local state = require("cursor.state")
  state.reset()
  state.set_session_title("Fix login bug")
  assert_eq(state.get().session_title, "Fix login bug")
end)

test("status text includes session title and config labels", function()
  local state = require("cursor.state")
  local status = require("cursor.ui.status")
  state.reset()
  state.get().session_id = "sess-1"
  state.set_session_title("My chat")
  state.update_config_options({
    {
      id = "model",
      category = "model",
      currentValue = "model-1",
      options = { { value = "model-1", name = "Composer" } },
    },
    {
      id = "thought_level",
      category = "thought_level",
      currentValue = "medium",
      options = { { value = "medium", name = "Medium" } },
    },
    {
      id = "mode",
      category = "mode",
      currentValue = "agent",
      options = { { value = "agent", name = "Agent" } },
    },
  })
  local text = status.text()
  assert_true(text:find("My chat") ~= nil)
  assert_true(text:find("Composer") ~= nil)
  assert_true(text:find("Medium") ~= nil)
  assert_true(text:find("Agent") ~= nil)
end)
