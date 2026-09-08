local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("float layout does not open duplicate windows", function()
  local config = require("cursor.config")
  local layout = require("cursor.ui.layout")
  config.setup({ layout = "float" })
  layout.close()

  layout.open()
  local first_chat = layout.chat_win
  layout.open()
  assert_true(layout.chat_win == first_chat)
  layout.close()
  config.setup({ layout = "split" })
end)
