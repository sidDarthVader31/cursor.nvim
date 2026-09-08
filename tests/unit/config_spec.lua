local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

test("config defaults", function()
  local config = require("cursor.config")
  config.setup({})
  assert_eq(config.get().agent_command, "agent")
  assert_eq(config.get().auto_start, false)
  assert_eq(config.get().mappings.submit, "<CR>")
end)

test("config auto_resolve default", function()
  local config = require("cursor.config")
  config.setup({})
  assert_eq(config.get().auto_resolve_agent, true)
end)

test("config mappings disabled by default", function()
  local config = require("cursor.config")
  config.setup({})
  assert_eq(config.get().mappings_enabled, false)
end)
