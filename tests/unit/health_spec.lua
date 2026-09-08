local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("health report", function()
  local lines = require("cursor").health()
  assert_true(#lines > 0)
end)
