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

  rpc.on_request("fs/read_text_file", function(params)
    return M.read_text_file(params)
  end)

  rpc.on_request("fs/write_text_file", function(params)
    return M.write_text_file(params)
  end)

  rpc.on_request("terminal/create", function(params)
    return M.terminal_create(params)
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

  rpc.on_request("cursor/create_plan", function(params)
    log.info("cursor/create_plan received; auto-accepting")
    return { outcome = { outcome = "accepted" } }
  end)

  rpc.on_notification("cursor/update_todos", function(params)
    log.debug("cursor/update_todos")
  end)

  rpc.on_notification("cursor/task", function(params)
    log.debug("cursor/task")
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
    }
    require("cursor.ui").schedule_refresh()
  elseif kind == "tool_call_update" then
    local id = update.toolCallId or update.id
    local tc = state.get().tool_calls[id]
    if tc then
      tc.status = update.status or tc.status
      tc.title = update.title or tc.title
    end
    require("cursor.ui").schedule_refresh()
  elseif kind == "config_option_update" then
    if update.configOptions then
      state.update_config_options(update.configOptions)
      require("cursor.ui").schedule_refresh()
    end
  elseif kind == "plan" then
    state.add_message({ role = "assistant", content = update.plan or update.text or "" })
    require("cursor.ui").schedule_refresh()
  else
    log.debug("Unknown session update: " .. tostring(kind))
  end
end

function M.read_text_file(params)
  local path = params.path or params.uri
  if not path then
    return { error = "missing path" }
  end
  local root = state.get().project_root
  if not project.within_root(path, root) then
    return { error = "path outside project root" }
  end
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then
    return { error = "failed to read file" }
  end
  return { content = table.concat(content, "\n") }
end

function M.write_text_file(params)
  local path = params.path or params.uri
  local content = params.content or ""
  if not path then
    return { error = "missing path" }
  end
  local root = state.get().project_root
  if not project.within_root(path, root) then
    return { error = "path outside project root" }
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
    return { error = "missing command" }
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
  -- async wait: poll briefly (non-blocking for MVP)
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
    callback(nil, { message = "No active session" })
    return
  end

  state.clear_error()
  state.get().prompting = true
  state.get().assistant_buffer = ""
  state.get().tool_calls = {}
  state.set_status(state.states.prompting)

  send_request("session/prompt", {
    sessionId = session_id,
    prompt = { { type = "text", text = text } },
  }, function(result, err)
    state.get().prompting = false
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
    callback(result, err)
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
    state.get().prompting = false
    state.set_status(state.states.ready)
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

function M.start(opts, callback)
  opts = opts or {}
  M.setup_handlers()

  local st = state.get()
  st.project_root = opts.cwd or config.get().project_root or project.root()

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

  if not transport.start({ cwd = st.project_root }) then
    if callback then
      callback(false, "Failed to start transport")
    end
    return false, "Failed to start transport"
  end

  M.initialize(function(_, init_err)
    if init_err then
      M.stop()
      local msg = init_err.message or "initialize failed"
      if callback then
        callback(false, msg)
      end
      return
    end
    M.authenticate(function(_, auth_err)
      if auth_err then
        M.stop()
        local msg = auth_err.message or "authentication failed — run :CursorLogin"
        if callback then
          callback(false, msg)
        end
        return
      end
      M.session_new(function(_, session_err)
        if session_err then
          M.stop()
          local msg = session_err.message or "session/new failed"
          if callback then
            callback(false, msg)
          end
          return
        end
        state.set_status(state.states.ready)
        if callback then
          callback(true)
        end
      end)
    end)
  end)

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
