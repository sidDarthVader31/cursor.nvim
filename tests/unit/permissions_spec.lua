local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true
local assert_match = helper.assert_match

test("permissions default_option_id resolves session allow", function()
  local permissions = require("cursor.permissions")
  local id = permissions.default_option_id({
    options = {
      { id = "allow-once", name = "Allow once" },
      { id = "allow-session", name = "Allow for session" },
      { id = "reject-once", name = "Deny" },
    },
  }, "session")
  assert_eq(id, "allow-session")
end)

test("permissions default_option_id prefers agent options for allow", function()
  local permissions = require("cursor.permissions")
  local id = permissions.default_option_id({
    options = {
      { id = "allow-once", name = "Allow once" },
      { id = "allow-session", name = "Allow for session" },
      { id = "reject-once", name = "Deny" },
    },
  }, "allow")
  assert_match("allow", id)
end)
