local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_not_nil = helper.assert_not_nil

test("state update_config_options uses id field", function()
  local state = require("cursor.state")
  state.reset()
  state.update_config_options({
    {
      id = "model",
      category = "model",
      currentValue = "model-2",
      options = {
        { value = "model-1", name = "Model 1" },
        { value = "model-2", name = "Model 2" },
      },
    },
    {
      id = "thought_level",
      category = "thought_level",
      currentValue = "high",
    },
    {
      id = "mode",
      category = "mode",
      currentValue = "code",
    },
  })
  assert_eq(state.get().current_model, "model-2")
  assert_eq(state.get().current_effort, "high")
  assert_eq(state.get().current_mode, "code")
  assert_not_nil(state.get_config_option("model"))
end)

test("state get_config_option resolves id or configId", function()
  local state = require("cursor.state")
  state.reset()
  state.update_config_options({
    { configId = "legacy", category = "model", currentValue = "x" },
  })
  assert_not_nil(state.get_config_option("legacy"))
end)
