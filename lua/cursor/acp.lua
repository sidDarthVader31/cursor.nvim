local config = require("cursor.config")
local log = require("cursor.log")
local project = require("cursor.project")
local rpc = require("cursor.rpc")
local state = require("cursor.state")
local transport = require("cursor.transport")

local M = {}

local terminals = {}

local function send_rpc(data)
  if type(data) == "string" then
    transport.send(data)
  end
end

local function send_request(method, params, callback)
  local data = rpc.request(method, params, callback)
  send_rpc(data)
end

function M.setup_handlers()
  rpc.on_notification("session/update", function(params)
    M.handle_session_update(params)
  end)

  rpc.on_request("session/request_permission", function(params, id)
    local permissions = require("cursor.permissions")
    return permissions.handle(params, id)
  end)

  rpc.on_request("fs/read_text_file", function(params, id)
    local result, err = M.read_text_file(params)
    if err then
      return rpc.error_response(id, -32000, err)
    end
    return rpc.response(id, result)
  end)

  rpc.on_request("fs/write_text_file", function(params, id)
    local result, err = M.write_text_file(params)
    if err then
      return rpc.error_response(id, -32000, err)
    end
    return rpc.response(id, result)
  end)

  rpc.on_request("terminal/create", function(params, id)
    local result, err = M.terminal_create(params)
    if err then
      return rpc.error_response(id, -32000, err)
    end
    return rpc.response(id, result)
  end)

  rpc.on_request("terminal/output", function(params)
    return M.terminal_output(params)
  end)

  rpc.on_request("terminal/wait_for_exit", function(params)
    return M.terminal_wait_for_exit(params)
  end)

  rpc.on_request("terminal/kill", function(params)
    return M.terminal_kill(params)
  end)

  rpc.on_request("terminal/release", function(params)
    return M.terminal_release(params)
  end)

  -- Cursor extension methods (stub to avoid deadlocks)
  rpc.on_request("cursor/ask_question", function(params)
    log.info("cursor/ask_question received; auto-skipping")
    return { outcome = { outcome = "skipped", reason = "cursor.nvim stub" } }
  end)

  rpc.on_request("cursor/create_plan", function(params, id)
    return require("cursor.plans").handle_create_plan(params, id)
  end)

  rpc.on_notification("cursor/update_todos", function(params)
    require("cursor.plans").merge_todos(params.todos or {}, params.merge)
  end)

  rpc.on_notification("cursor/task", function(params)
    require("cursor.plans").set_task(params.description or params.prompt or "Running subagent")
  end)

  rpc.on_notification("cursor/generate_image", function(params)
    log.debug("cursor/generate_image")
  end)
end

function M.handle_session_update(params)
  local update = params.update or params
  if not update then
    return
  end

  local kind = update.sessionUpdate or update.type
  if kind == "agent_message_chunk" then
    local text = update.content and (update.content.text or update.content) or ""
    if type(text) == "string" and text ~= "" then
      local st = state.get()
      st.assistant_buffer = (st.assistant_buffer or "") .. text
      local ui = require("cursor.ui")
      ui.schedule_refresh()
    end
  elseif kind == "agent_thought_chunk" then
    -- optional: show in debug
  elseif kind == "tool_call" then
    local id = update.toolCallId or update.id
    state.get().tool_calls[id] = {
      id = id,
      title = update.title or update.kind or "tool",
      status = update.status or "pending",
      kind = update.kind,
      started_at = vim.loop.now(),
      completed_at = nil,
    }
    require("cursor.ui").schedule_refresh()
  elseif kind == "tool_call_update" then
    local id = update.toolCallId or update.id
    local tc = state.get().tool_calls[id]
    if tc then
      tc.status = update.status or tc.status
      tc.title = update.title or tc.title
      if tc.status == "completed" or tc.status == "failed" then
        tc.completed_at = vim.loop.now()
      end
    end
    require("cursor.ui").schedule_refresh()
  elseif kind == "config_option_update" then
    if update.configOptions then
      state.update_config_options(update.configOptions)
      require("cursor.ui").schedule_refresh()
    end
  elseif kind == "plan" then
    require("cursor.plans").ingest_session_plan(update)
    require("cursor.ui").schedule_refresh()
  elseif kind == "session_info_update" then
    if update.title and update.title ~= "" then
      local session_id = params.sessionId or state.get().session_id
      state.set_session_title(update.title)
      if session_id then
        require("cursor.chats_index").sync_title(session_id, update.title, {
          cwd = state.get().project_root,
        })
      end
      require("cursor.ui").schedule_refresh()
    end
  else
    log.debug("Unknown session update: " .. tostring(kind))
  end
end

function M.read_text_file(params)
  local path = params.path or params.uri
  if not path then
    return nil, "missing path"
  end
  local root = state.get().project_root
  if not project.within_root(path, root) then
    return nil, "path outside project root"
  end
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "failed to read file"
  end
  return { content = table.concat(content, "\n") }
end

function M.write_text_file(params)
  local path = params.path or params.uri
  local content = params.content or ""
  if not path then
    return nil, "missing path"
  end
  local root = state.get().project_root
  if not project.within_root(path, root) then
    return nil, "path outside project root"
  end
  local lines = vim.split(content, "\n", { plain = true })
  vim.fn.writefile(lines, path)
  return { success = true }
end

function M.terminal_create(params)
  local id = params.terminalId or params.id or tostring(vim.loop.hrtime())
  local cmd = params.command or params.cmd
  if type(cmd) == "string" then
    cmd = vim.split(cmd, "%s+", { trimempty = true })
  end
  if type(cmd) ~= "table" or #cmd == 0 then
    return nil, "missing command"
  end

  local term = {
    id = id,
    output = "",
    exit_code = nil,
    done = false,
  }

  local proc = vim.system(cmd, {
    cwd = state.get().project_root,
    stdout = function(_, data)
      if data then
        term.output = term.output .. data
      end
    end,
    stderr = function(_, data)
      if data then
        term.output = term.output .. data
      end
    end,
  }, function(code)
    term.exit_code = code or 0
    term.done = true
  end)

  term.process = proc
  terminals[id] = term
  return { terminalId = id }
end

function M.terminal_output(params)
  local id = params.terminalId or params.id
  local term = terminals[id]
  if not term then
    return { output = "" }
  end
  return { output = term.output }
end

function M.terminal_wait_for_exit(params)
  local id = params.terminalId or params.id
  local term = terminals[id]
  if not term then
    return { exitCode = 1 }
  end
  if not term.done then
    return { exitCode = nil, running = true }
  end
  return { exitCode = term.exit_code or 0 }
end

function M.terminal_kill(params)
  local id = params.terminalId or params.id
  local term = terminals[id]
  if term and term.process then
    term.process:kill(15)
  end
  return { success = true }
end

function M.terminal_release(params)
  local id = params.terminalId or params.id
  terminals[id] = nil
  return { success = true }
end

function M.initialize(callback)
  send_request("initialize", {
    protocolVersion = 1,
    clientCapabilities = {
      fs = { readTextFile = true, writeTextFile = true },
      terminal = true,
      session = {
        configOptions = { boolean = {} },
      },
    },
    clientInfo = { name = "cursor.nvim", version = "0.1.0" },
  }, function(result, err)
    if err then
      callback(nil, err)
      return
    end
    callback(result)
  end)
end

function M.authenticate(callback)
  send_request("authenticate", { methodId = "cursor_login" }, function(result, err)
    if err then
      callback(nil, err)
      return
    end
    callback(result)
  end)
end

function M.session_new(callback)
  local cwd = state.get().project_root
  send_request("session/new", { cwd = cwd, mcpServers = {} }, function(result, err)
    if err then
      callback(nil, err)
      return
    end
    if result and result.sessionId then
      state.get().session_id = result.sessionId
      require("cursor.plans").load_for_session(result.sessionId)
    end
    if result and result.configOptions then
      state.update_config_options(result.configOptions)
    end
    callback(result)
  end)
end

function M.session_load(session_id, callback)
  send_request("session/load", { sessionId = session_id }, function(result, err)
    if err then
      callback(nil, err)
      return
    end
    if result and result.sessionId then
      state.get().session_id = result.sessionId
      require("cursor.plans").load_for_session(result.sessionId)
    end
    if result and result.configOptions then
      state.update_config_options(result.configOptions)
    end
    callback(result)
  end)
end

function M.session_prompt(text, callback)
  local session_id = state.get().session_id
  if not session_id then
    state.set_error("No active session — run :CursorRestart")
    require("cursor.ui").schedule_refresh()
    if callback then
      callback(nil, { message = "No active session" })
    end
    return
  end

  state.clear_error()
  local st = state.get()
  st.prompting = true
  st.assistant_buffer = ""
  st.tool_calls = {}
  st.activity_todos = {}
  st.activity_task = nil
  st.run_cancelled = false
  st.prompt_started_at = vim.loop.now()
  state.set_status(state.states.prompting)
  require("cursor.ui.spinner").start(function()
    require("cursor.ui").schedule_refresh()
  end)

  send_request("session/prompt", {
    sessionId = session_id,
    prompt = { { type = "text", text = text } },
  }, function(result, err)
    local st = state.get()
    st.prompting = false
    st.prompt_started_at = nil
    require("cursor.ui.spinner").stop()
    state.set_status(state.states.ready)
    if err then
      local msg = err.message or vim.inspect(err)
      state.set_error(msg)
      vim.notify("[cursor] prompt failed: " .. msg, vim.log.levels.ERROR)
    end
    if state.get().assistant_buffer and state.get().assistant_buffer ~= "" then
      state.add_message({ role = "assistant", content = state.get().assistant_buffer })
      state.get().assistant_buffer = ""
    end
    require("cursor.ui").schedule_refresh()
    if callback then
      callback(result, err)
    end
  end)
end

function M.session_cancel(callback)
  local session_id = state.get().session_id
  if not session_id then
    if callback then
      callback(nil)
    end
    return
  end
  send_request("session/cancel", { sessionId = session_id }, function(result, err)
    local st = state.get()
    st.prompting = false
    st.prompt_started_at = nil
    st.run_cancelled = true
    require("cursor.ui.spinner").stop()
    state.set_status(state.states.ready)
    require("cursor.ui").schedule_refresh()
    if callback then
      callback(result, err)
    end
  end)
end

function M.session_set_title(session_id, title, callback)
  if not session_id or not title or title == "" then
    if callback then
      callback(nil, { message = "missing session id or title" })
    end
    return
  end
  send_request("session/setTitle", { sessionId = session_id, title = title }, function(result, err)
    if callback then
      callback(result, err)
    end
  end)
end

function M.set_config_option(config_id, value, value_type, callback)
  local session_id = state.get().session_id
  if not session_id then
    local msg = "No active session — run :CursorRestart"
    vim.notify("[cursor] " .. msg, vim.log.levels.ERROR)
    if callback then
      callback(nil, { message = msg })
    end
    return
  end
  send_request("session/set_config_option", {
    sessionId = session_id,
    configId = config_id,
    type = value_type or "id",
    value = value,
  }, function(result, err)
    if err then
      local msg = err.message or vim.inspect(err)
      state.set_error(msg)
      vim.notify("[cursor] config failed: " .. msg, vim.log.levels.ERROR)
    else
      state.clear_error()
    end
    if result and result.configOptions then
      state.update_config_options(result.configOptions)
    end
    require("cursor.ui").schedule_refresh()
    if callback then
      callback(result, err)
    end
  end)
end

local function finish_start(callback, ok, err)
  if callback then
    callback(ok, err)
  end
end

local function run_session_new(callback)
  M.session_new(function(_, session_err)
    if session_err then
      M.stop()
      local msg = session_err.message or "session/new failed"
      finish_start(callback, false, msg)
      return
    end
    state.set_status(state.states.ready)
    finish_start(callback, true)
  end)
end

local function run_initialize_chain(callback)
  M.initialize(function(_, init_err)
    if init_err then
      M.stop()
      local msg = init_err.message or "initialize failed"
      finish_start(callback, false, msg)
      return
    end
    M.authenticate(function(_, auth_err)
      if auth_err then
        M.stop()
        local msg = auth_err.message or "authentication failed — run :CursorLogin"
        finish_start(callback, false, msg)
        return
      end
      run_session_new(callback)
    end)
  end)
end

function M.start(opts, callback)
  opts = opts or {}
  M.setup_handlers()

  local st = state.get()
  st.project_root = opts.cwd or config.get().project_root or project.root()

  if transport.is_running() and st.session_id then
    finish_start(callback, true)
    return true
  end

  transport.set_message_handler(function(line)
    require("cursor.schedule").defer(function()
      local response = rpc.handle_line(line)
      if response then
        transport.send(response)
      end
    end)
  end)

  transport.set_exit_handler(function(code)
    require("cursor.schedule").defer(function()
      log.warn("Agent process exited with code " .. tostring(code))
      state.set_status(state.states.stopped)
    end)
  end)

  if transport.is_running() then
    run_session_new(callback)
    return true
  end

  local ok_start, start_err = transport.start({ cwd = st.project_root })
  if not ok_start then
    finish_start(callback, false, start_err or "Failed to start transport")
    return false, start_err or "Failed to start transport"
  end

  run_initialize_chain(callback)
  return true
end

function M.stop()
  transport.stop()
  state.set_status(state.states.stopped)
end

function M.restart(opts, callback)
  M.stop()
  state.reset()
  return M.start(opts, callback)
end

return M
