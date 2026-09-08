local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true
local assert_false = helper.assert_false

test("usage validate prompt", function()
  local usage = require("cursor.usage")
  local ok = usage.validate_prompt("")
  assert_false(ok)
  local ok2 = usage.validate_prompt("hello")
  assert_true(ok2)
end)
