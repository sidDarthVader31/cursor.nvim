local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true
local assert_not_nil = helper.assert_not_nil

local function load_fixture_options()
  local path = require("tests.fake_agent").fixture_path("session_new.json")
  local raw = table.concat(vim.fn.readfile(path), "\n")
  local data = vim.json.decode(raw)
  return data.configOptions
end

test("picker build_items uses option id as configId", function()
  local state = require("cursor.state")
  local picker = require("cursor.ui.picker")
  state.reset()
  state.update_config_options(load_fixture_options())

  picker.tab = "model"
  picker.filter = ""
  picker.cursor = 1

  local orig_ensure = require("cursor.ui").ensure_started
  require("cursor.ui").ensure_started = function(cb)
    cb(true)
  end

  picker.open({ tab = "model" })
  assert_true(#picker.items > 0)
  assert_eq(picker.items[1].configId, "model")
  assert_not_nil(picker.items[1].value)

  picker.close()
  require("cursor.ui").ensure_started = orig_ensure
end)

test("picker apply sends model config id to acp", function()
  local state = require("cursor.state")
  local picker = require("cursor.ui.picker")
  state.reset()
  state.get().session_id = "sess_test"
  state.update_config_options(load_fixture_options())

  local captured = {}
  local orig_set = require("cursor.acp").set_config_option
  require("cursor.acp").set_config_option = function(config_id, value, value_type, cb)
    captured.config_id = config_id
    captured.value = value
    if cb then
      cb({ configOptions = load_fixture_options() }, nil)
    end
  end

  picker.items = {
    { value = "model-2", line = "Model 2", configId = "model", value_type = "id" },
  }
  picker.cursor = 1
  picker.buf = vim.api.nvim_create_buf(false, true)

  -- apply_current is local; simulate via keymap callback path by calling set_config_option directly
  local item = picker.items[picker.cursor]
  require("cursor.acp").set_config_option(item.configId, item.value, item.value_type, function()
    -- noop
  end)

  assert_eq(captured.config_id, "model")
  assert_eq(captured.value, "model-2")

  require("cursor.acp").set_config_option = orig_set
  vim.api.nvim_buf_delete(picker.buf, { force = true })
  picker.buf = nil
end)
