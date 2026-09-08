local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("chat render with tools", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  state.add_message({ role = "user", content = "hi" })
  state.get().tool_calls["t1"] = { id = "t1", title = "Read foo.lua", status = "completed" }
  require("cursor.ui.chat").render()
  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  assert_true(#lines > 0)
  local text = table.concat(lines, "\n")
  assert_true(text:find("Read foo.lua") ~= nil)
  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render applies heading highlights", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  state.add_message({ role = "user", content = "hello" })
  state.add_message({ role = "assistant", content = "hi there" })
  chat.render()

  local marks = vim.api.nvim_buf_get_extmarks(layout.chat_buf, chat.ns, 0, -1, {})
  assert_true(#marks >= 2)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render does not crash on empty buffer", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(layout.chat_buf, "modifiable", false)
  require("cursor.ui.chat").render()
  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  assert_true(#lines >= 1)
  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)
