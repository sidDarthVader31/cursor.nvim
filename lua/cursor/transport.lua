local config = require("cursor.config")
local log = require("cursor.log")
local state = require("cursor.state")

local M = {}

local transport = {
  process = nil,
  running = false,
  on_message = nil,
  on_exit = nil,
  buffer = "",
}

local AGENT_NOT_FOUND = "Cursor CLI `agent` not found. Install from https://cursor.com/docs/cli/overview "
  .. "or set agent_path in require('cursor').setup({ agent_path = '...' }). "
  .. "GUI Neovim may not inherit your shell PATH — use the full path to agent."

function M.is_running()
  return transport.running
end

function M.set_message_handler(fn)
  transport.on_message = fn
end

function M.set_exit_handler(fn)
  transport.on_exit = fn
end

local function flush_buffer()
  local buf = transport.buffer
  local start = 1
  while true do
    local nl = buf:find("\n", start, true)
    if not nl then
      transport.buffer = buf:sub(start)
      return
    end
    local line = buf:sub(start, nl - 1)
    if line ~= "" and transport.on_message then
      transport.on_message(line)
    end
    start = nl + 1
  end
end

function M.find_agent()
  local cfg = config.get()

  if cfg.agent_path and cfg.agent_path ~= "" then
    local expanded = vim.fn.expand(cfg.agent_path)
    if vim.fn.executable(expanded) == 1 then
      return expanded
    end
  end

  local path = vim.fn.exepath(cfg.agent_command)
  if path and path ~= "" and vim.fn.executable(path) == 1 then
    return path
  end

  local home = vim.env.HOME or vim.fn.expand("~")
  local candidates = {
    home .. "/.local/bin/agent",
    home .. "/.cursor/bin/agent",
    "/opt/homebrew/bin/agent",
    "/usr/local/bin/agent",
  }
  for _, candidate in ipairs(candidates) do
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end

  return M.find_agent_via_shell()
end

--- Last resort: ask the user's login shell (GUI Neovim often has a minimal PATH).
function M.find_agent_via_shell()
  local cfg = config.get()
  if cfg.auto_resolve_agent == false then
    return nil
  end
  local name = cfg.agent_command or "agent"
  local ok, out = pcall(vim.fn.system, {
    "sh",
    "-lc",
    string.format("command -v %s 2>/dev/null", name),
  })
  if not ok or not out or out == "" then
    return nil
  end
  local path = vim.fn.trim(vim.split(out, "\n", { plain = true })[1] or "")
  if path ~= "" and vim.fn.executable(path) == 1 then
    return path
  end
  return nil
end

--- Resolve and optionally cache agent path into config (called from setup).
function M.resolve_agent()
  return M.find_agent()
end

function M.start(opts)
  opts = opts or {}
  if transport.running and transport.process then
    return true
  end
  transport.running = false
  transport.process = nil

  local agent = M.find_agent()
  if not agent then
    state.set_status(state.states.error)
    log.error(AGENT_NOT_FOUND)
    return false, AGENT_NOT_FOUND
  end

  local cfg = config.get()
  local cmd = { agent, unpack(cfg.agent_args) }
  local cwd = opts.cwd or state.get().project_root or vim.loop.cwd()

  state.set_status(state.states.starting)

  local ok, proc = pcall(vim.system, cmd, {
    cwd = cwd,
    stdin = true,
    stdout = function(err, data)
      if err then
        log.error("stdout error: " .. tostring(err))
        return
      end
      if data then
        transport.buffer = transport.buffer .. data
        flush_buffer()
      end
    end,
    stderr = function(err, data)
      if data then
        local st = state.get()
        for line in data:gmatch("[^\r\n]+") do
          table.insert(st.stderr_lines, line)
          log.debug("stderr: " .. line)
        end
      end
      if err then
        log.error("stderr error: " .. tostring(err))
      end
    end,
  }, function(code, signal)
    transport.running = false
    transport.process = nil
    state.set_status(state.states.stopped)
    if transport.on_exit then
      transport.on_exit(code, signal)
    end
  end)

  if not ok then
    state.set_status(state.states.error)
    local msg = "Failed to start agent: " .. tostring(proc)
    log.error(msg)
    return false, msg
  end

  if not proc then
    state.set_status(state.states.error)
    log.error("Failed to start agent process")
    return false, "Failed to start agent process"
  end

  transport.process = proc
  transport.running = true
  transport.buffer = ""
  return true
end

function M.send(data)
  if not transport.process or not transport.running then
    return false
  end
  transport.process:write(data)
  return true
end

function M.stop()
  if not transport.process then
    transport.running = false
    return
  end
  state.set_status(state.states.stopping)
  transport.process:kill(15)
  transport.process = nil
  transport.running = false
end

return M
