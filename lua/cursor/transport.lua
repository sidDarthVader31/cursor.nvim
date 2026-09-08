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

function M.start(opts)
  opts = opts or {}
  if transport.running then
    return true
  end

  local cfg = config.get()
  local cmd = { cfg.agent_command, unpack(cfg.agent_args) }
  local cwd = opts.cwd or state.get().project_root or vim.loop.cwd()

  state.set_status(state.states.starting)

  local proc = vim.system(cmd, {
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

  if not proc then
    state.set_status(state.states.error)
    log.error("Failed to start agent process")
    return false
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

function M.find_agent()
  local cfg = config.get()
  local path = vim.fn.exepath(cfg.agent_command)
  if path and path ~= "" then
    return path
  end
  return nil
end

return M
