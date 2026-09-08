local helper = require("tests.helper")
local fake = require("tests.fake_agent")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

test("acp.start against fake agent only initializes once", function()
  helper.reset_plugin()
  fake.clear_log()

  local config = require("cursor.config")
  config.setup({
    agent_path = fake.script_path(),
    agent_args = { "acp" },
    auto_resolve_agent = false,
  })

  local acp = require("cursor.acp")
  local transport = require("cursor.transport")
  local state = require("cursor.state")
  state.reset()

  local env = fake.env()
  local orig_system = vim.system
  vim.system = function(cmd, opts, on_exit)
    opts = opts or {}
    opts.env = vim.tbl_extend("force", vim.env, env)
    return orig_system(cmd, opts, on_exit)
  end

  local done = false
  local ok1 = false
  acp.start({}, function(ok)
    ok1 = ok
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_true(ok1)
  assert_eq(state.get().session_id, "sess_test_001")
  assert_eq(fake.init_count(), 1)

  done = false
  local ok2 = false
  acp.start({}, function(ok)
    ok2 = ok
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_true(ok2)
  assert_eq(fake.init_count(), 1)

  transport.stop()
  vim.system = orig_system
end)

test("set_config_option with model id succeeds on fake agent", function()
  helper.reset_plugin()
  fake.clear_log()

  local config = require("cursor.config")
  config.setup({
    agent_path = fake.script_path(),
    agent_args = { "acp" },
    auto_resolve_agent = false,
  })

  local acp = require("cursor.acp")
  local transport = require("cursor.transport")
  local state = require("cursor.state")
  state.reset()

  local env = fake.env()
  local orig_system = vim.system
  vim.system = function(cmd, opts, on_exit)
    opts = opts or {}
    opts.env = vim.tbl_extend("force", vim.env, env)
    return orig_system(cmd, opts, on_exit)
  end

  local started = false
  acp.start({}, function(ok)
    started = ok
  end)
  vim.wait(3000, function()
    return started and state.get().session_id ~= nil
  end)

  assert_true(state.get().session_id ~= nil)

  local done = false
  local err_msg = nil
  acp.set_config_option("model", "model-2", "id", function(_, err)
    err_msg = err and (err.message or vim.inspect(err)) or nil
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_eq(err_msg, nil)

  transport.stop()
  vim.system = orig_system
end)
