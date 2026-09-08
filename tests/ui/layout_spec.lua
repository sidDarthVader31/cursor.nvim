local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("chat opens without agent", function()
  local layout = require("cursor.ui.layout")
  layout.close()
  require("cursor.ui").open()
  assert_true(layout.is_open())
  layout.close()
end)
