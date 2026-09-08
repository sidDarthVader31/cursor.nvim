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
  end)

  test("state rpc ids", function()
    local state = require("cursor.state")
    state.reset()
    assert_eq(state.next_rpc_id(), 1)
    assert_eq(state.next_rpc_id(), 2)
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

  print(string.format("\n%d passed, %d failed", passed, failed))
  if failed > 0 then
    os.exit(1)
  end
end

run()
