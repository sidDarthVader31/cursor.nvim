local function run()
  local passed = 0
  local failed = 0

  local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
      passed = passed + 1
      print("PASS: " .. name)
    else
      failed = failed + 1
      print("FAIL: " .. name .. " — " .. tostring(err))
    end
  end

  local function assert_eq(a, b)
    if a ~= b then
      error(string.format("expected %s, got %s", vim.inspect(b), vim.inspect(a)))
    end
  end

  local function assert_true(v)
    if not v then
      error("expected true")
    end
  end

  local function assert_false(v)
    if v then
      error("expected false")
    end
  end

  test("config defaults", function()
    local config = require("cursor.config")
    config.setup({})
    assert_eq(config.get().agent_command, "agent")
    assert_eq(config.get().auto_start, false)
    assert_eq(config.get().mappings.submit, "<CR>")
  end)

  test("state rpc ids", function()
    local state = require("cursor.state")
    state.reset()
    assert_eq(state.next_rpc_id(), 1)
    assert_eq(state.next_rpc_id(), 2)
  end)

  test("state error tracking", function()
    local state = require("cursor.state")
    state.reset()
    state.set_error("boom")
    assert_eq(state.get().last_error, "boom")
    state.clear_error()
    assert_eq(state.get().last_error, nil)
  end)

  test("rpc request encoding", function()
    local rpc = require("cursor.rpc")
    local state = require("cursor.state")
    state.reset()
    local data, id = rpc.request("initialize", { protocolVersion = 1 }, function() end)
    assert_eq(id, 1)
    assert_true(data:find("initialize") ~= nil)
  end)

  test("rpc response handling", function()
    local rpc = require("cursor.rpc")
    local state = require("cursor.state")
    state.reset()
    local called = false
    rpc.request("test", {}, function(result)
      called = true
      assert_eq(result.status, "ok")
    end)
    rpc.handle_line(vim.json.encode({ jsonrpc = "2.0", id = 1, result = { status = "ok" } }))
    assert_true(called)
  end)

  test("rpc async request returns nil response", function()
    local rpc = require("cursor.rpc")
    state = require("cursor.state")
    state.reset()
    rpc.on_request("test/async", function()
      return nil
    end)
    local response = rpc.handle_line(vim.json.encode({
      jsonrpc = "2.0",
      id = 99,
      method = "test/async",
      params = {},
    }))
    assert_eq(response, nil)
  end)

  test("context lean prompt", function()
    local context = require("cursor.context")
    local prompt = context.build_prompt("explain", {
      file = "/repo/foo.go",
      cwd = "/repo",
      cursor = { line = 10, column = 5 },
    })
    assert_true(prompt:find("explain") ~= nil)
    assert_true(prompt:find("foo.go") ~= nil)
  end)

  test("project within root", function()
    local project = require("cursor.project")
    assert_true(project.within_root("/repo/src/foo.go", "/repo"))
    assert_false(project.within_root("/other/foo.go", "/repo"))
  end)

  test("usage validate prompt", function()
    local usage = require("cursor.usage")
    local ok = usage.validate_prompt("")
    assert_false(ok)
    local ok2 = usage.validate_prompt("hello")
    assert_true(ok2)
  end)

  test("health report", function()
    local lines = require("cursor").health()
    assert_true(#lines > 0)
  end)

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

  test("acp session update streaming", function()
    local state = require("cursor.state")
    local acp = require("cursor.acp")
    state.reset()
    acp.handle_session_update({
      update = {
        sessionUpdate = "agent_message_chunk",
        content = { text = "hello" },
      },
    })
    assert_eq(state.get().assistant_buffer, "hello")
    acp.handle_session_update({
      update = {
        sessionUpdate = "agent_message_chunk",
        content = { text = " world" },
      },
    })
    assert_eq(state.get().assistant_buffer, "hello world")
  end)

  test("schedule ui defers in fast event", function()
    local schedule = require("cursor.schedule")
    local ran = false
    schedule.ui(function()
      ran = true
    end)
    -- outside fast event runs immediately
    assert_true(ran)
  end)

  test("transport start without agent returns error", function()
    local transport = require("cursor.transport")
    transport.stop()
    local orig_find = transport.find_agent
    transport.find_agent = function()
      return nil
    end
    local ok, err = transport.start()
    transport.find_agent = orig_find
    transport.stop()
    assert_false(ok)
    assert_true(err and err:find("agent") ~= nil)
  end)

  test("chat opens without agent", function()
    local layout = require("cursor.ui.layout")
    layout.close()
    require("cursor.ui").open()
    assert_true(layout.is_open())
    layout.close()
  end)

  test("config auto_resolve default", function()
    local config = require("cursor.config")
    config.setup({})
    assert_eq(config.get().auto_resolve_agent, true)
  end)

  print(string.format("\n%d passed, %d failed", passed, failed))
  if failed > 0 then
    os.exit(1)
  end
end

run()
