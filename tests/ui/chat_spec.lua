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

test("chat render shows status bar with session context", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  state.get().session_id = "sess-1"
  state.set_session_title("Fix login bug")
  state.update_config_options({
    {
      id = "model",
      category = "model",
      currentValue = "model-1",
      options = { { value = "model-1", name = "Composer" } },
    },
    {
      id = "thought_level",
      category = "thought_level",
      currentValue = "medium",
      options = { { value = "medium", name = "Medium" } },
    },
    {
      id = "mode",
      category = "mode",
      currentValue = "agent",
      options = { { value = "agent", name = "Agent" } },
    },
  })
  state.add_message({ role = "user", content = "hello" })
  chat.render()

  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  assert_true(text:find("Fix login bug") ~= nil)
  assert_true(text:find("Composer") ~= nil)
  assert_true(text:find("Agent") ~= nil)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render applies heading highlights", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(layout.chat_buf, "filetype", "markdown")
  state.add_message({ role = "user", content = "hello" })
  state.add_message({ role = "assistant", content = "hi there" })
  chat.render()

  local marks = vim.api.nvim_buf_get_extmarks(layout.chat_buf, chat.ns, 0, -1, {})
  assert_true(#marks >= 2)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render preserves blank lines in markdown content", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(layout.chat_buf, "filetype", "markdown")

  local content = "# heading\n\n```lua\nprint('hi')\n```\n\n**bold**"
  state.add_message({ role = "assistant", content = content })
  chat.render()

  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  assert_true(text:find("# heading", 1, true) ~= nil)
  assert_true(text:find("```lua", 1, true) ~= nil)
  assert_true(text:find("**bold**", 1, true) ~= nil)

  -- blank line between heading and code fence should be preserved
  local found_blank = false
  for _, line in ipairs(lines) do
    if line == "" then
      found_blank = true
      break
    end
  end
  assert_true(found_blank)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render applies markdown extmarks for inline code", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(layout.chat_buf, "filetype", "markdown")
  state.add_message({ role = "assistant", content = "Use `foo.lua` here" })
  chat.render()

  local marks = vim.api.nvim_buf_get_extmarks(layout.chat_buf, chat.ns, 0, -1, { details = true })
  local found_code = false
  for _, mark in ipairs(marks) do
    local opts = mark[4]
    if opts and opts.hl_group == "CursorMdCode" then
      found_code = true
      break
    end
  end
  assert_true(found_code)

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
