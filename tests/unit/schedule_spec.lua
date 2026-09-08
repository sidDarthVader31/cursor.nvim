local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("schedule ui defers in fast event", function()
  local schedule = require("cursor.schedule")
  local ran = false
  schedule.ui(function()
    ran = true
  end)
  -- outside fast event runs immediately
  assert_true(ran)
end)
