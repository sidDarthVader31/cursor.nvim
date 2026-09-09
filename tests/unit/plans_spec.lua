local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true
local assert_not_nil = helper.assert_not_nil

test("plans normalize and store entries", function()
  local state = require("cursor.state")
  local plans = require("cursor.plans")
  state.reset()
  state.get().session_id = "sess-plans-1"

  local entry = plans.normalize_entry({
    toolCallId = "call-1",
    name = "Refactor auth",
    overview = "Tighten login flow",
    plan = "1. Inspect\n2. Fix",
    todos = { { id = "t1", content = "Inspect", status = "pending" } },
  }, "pending")

  plans.add_entry(entry)
  assert_eq(#state.get().plans, 1)
  assert_eq(state.get().plans[1].name, "Refactor auth")
end)

test("plans ingest session plan adds compact message", function()
  local state = require("cursor.state")
  local plans = require("cursor.plans")
  state.reset()
  state.get().session_id = "sess-plans-2"

  plans.ingest_session_plan({
    plan = "# My plan\nDo things",
    name = "My plan",
    overview = "Overview text",
  })

  assert_eq(#state.get().plans, 1)
  assert_eq(state.get().messages[1].role, "plan")
  assert_eq(state.get().messages[1].name, "My plan")
end)

test("plans merge todos updates activity", function()
  local state = require("cursor.state")
  local plans = require("cursor.plans")
  state.reset()

  plans.merge_todos({
    { id = "1", content = "Step 1", status = "completed" },
    { id = "2", content = "Step 2", status = "in_progress" },
  }, false)

  assert_eq(#state.get().activity_todos, 2)
  plans.merge_todos({
    { id = "2", content = "Step 2", status = "completed" },
    { id = "3", content = "Step 3", status = "pending" },
  }, true)
  assert_eq(#state.get().activity_todos, 3)
end)

test("plans build waits for prompting then sends implement prompt", function()
  local state = require("cursor.state")
  local plans = require("cursor.plans")
  local acp = require("cursor.acp")
  helper.reset_plugin()
  state.reset()
  state.get().session_id = "sess-build"
  state.get().current_mode = "plan"
  state.update_config_options({
    {
      id = "mode",
      category = "mode",
      currentValue = "plan",
      options = {
        { value = "plan", name = "Plan" },
        { value = "agent", name = "Agent" },
      },
    },
  })

  local responded = false
  local mode_switched = false
  local prompted = false

  local orig_send = require("cursor.transport").send
  require("cursor.transport").send = function(data)
    if type(data) == "string" and data:find("accepted") then
      responded = true
    end
    return orig_send(data)
  end

  acp.set_config_option = function(_, value, _, cb)
    if value == "agent" then
      mode_switched = true
    end
    if cb then
      cb({}, nil)
    end
  end

  acp.session_prompt = function(text, cb)
    if text == "Implement the approved plan." then
      prompted = true
    end
    if cb then
      cb({}, nil)
    end
  end

  local plan = plans.normalize_entry({
    toolCallId = "call-build",
    name = "Build me",
    plan = "Do work",
  }, "pending")
  plan.request_id = 99

  plans.build(plan, 99)

  assert_true(responded)
  vim.wait(300, function()
    return mode_switched and prompted
  end, 20)
  assert_true(mode_switched)
  assert_true(prompted)
end)

test("status text shows working while prompting", function()
  local state = require("cursor.state")
  local status = require("cursor.ui.status")
  state.reset()
  state.get().session_id = "sess-1"
  state.get().prompting = true
  state.get().tool_calls = {
    t1 = { id = "t1", title = "Read file", status = "in_progress" },
  }

  local text = status.text()
  assert_true(text:find("Working") ~= nil)
  assert_true(text:find("Read file") ~= nil)
end)
