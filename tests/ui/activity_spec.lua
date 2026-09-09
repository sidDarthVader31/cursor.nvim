local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("chat render shows activity footer while prompting", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  helper.reset_plugin()
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  state.get().session_id = "sess-1"
  state.get().prompting = true
  state.get().tool_calls = {
    t1 = { id = "t1", title = "Run tests", status = "in_progress", started_at = vim.loop.now() },
  }
  state.get().activity_todos = {
    { id = "1", content = "Setup", status = "completed" },
    { id = "2", content = "Verify", status = "pending" },
  }

  chat.render()
  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  assert_true(text:find("Working", 1, true) ~= nil)
  assert_true(text:find("Run tests", 1, true) ~= nil)
  assert_true(text:find("Todos 1/2", 1, true) ~= nil)
  assert_true(text:find("Enter / Ctrl+c / x to stop", 1, true) ~= nil)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render shows plan card", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  local plans = require("cursor.plans")
  helper.reset_plugin()
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  state.get().session_id = "sess-plan-card"

  local entry = plans.normalize_entry({
    toolCallId = "call-card",
    name = "Auth refactor",
    overview = "Improve login",
    plan = "Steps",
  }, "pending")
  plans.add_entry(entry)
  state.add_message({
    role = "plan",
    plan_id = entry.id,
    name = entry.name,
    overview = entry.overview,
  })

  chat.render()
  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  assert_true(text:find("Plan · Auth refactor") ~= nil)
  assert_true(text:find("P to view") ~= nil)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)

test("chat render shows stopped after cancel", function()
  local state = require("cursor.state")
  local layout = require("cursor.ui.layout")
  local chat = require("cursor.ui.chat")
  helper.reset_plugin()
  state.reset()
  layout.chat_buf = vim.api.nvim_create_buf(false, true)
  state.get().session_id = "sess-stop"
  state.get().run_cancelled = true

  chat.render()
  local lines = vim.api.nvim_buf_get_lines(layout.chat_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  assert_true(text:find("Stopped") ~= nil)

  vim.api.nvim_buf_delete(layout.chat_buf, { force = true })
  layout.chat_buf = nil
end)
