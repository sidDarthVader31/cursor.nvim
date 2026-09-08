local M = {}

M.states = {
  stopped = "stopped",
  starting = "starting",
  ready = "ready",
  prompting = "prompting",
  stopping = "stopping",
  error = "error",
}

local initial = {
  status = M.states.stopped,
  process = nil,
  session_id = nil,
  project_root = nil,
  rpc_next_id = 1,
  pending_requests = {},
  tool_calls = {},
  messages = {},
  config_options = {},
  current_model = nil,
  current_effort = nil,
  current_mode = nil,
  auth_email = nil,
  stderr_lines = {},
  assistant_buffer = "",
  active_assistant_id = nil,
  prompting = false,
  session_allow = {},
}

M._state = vim.deepcopy(initial)

function M.get()
  return M._state
end

function M.reset()
  M._state = vim.deepcopy(initial)
end

function M.set_status(status)
  M._state.status = status
end

function M.next_rpc_id()
  local id = M._state.rpc_next_id
  M._state.rpc_next_id = id + 1
  return id
end

function M.add_message(msg)
  table.insert(M._state.messages, msg)
end

function M.clear_messages()
  M._state.messages = {}
end

function M.update_config_options(options)
  M._state.config_options = options or {}
  for _, opt in ipairs(M._state.config_options) do
    if opt.category == "model" then
      M._state.current_model = opt.currentValue
    elseif opt.category == "thought_level" or opt.configId == "thought_level" then
      M._state.current_effort = opt.currentValue
    elseif opt.category == "mode" then
      M._state.current_mode = opt.currentValue
    end
  end
end

function M.get_config_option(config_id)
  for _, opt in ipairs(M._state.config_options) do
    if opt.configId == config_id then
      return opt
    end
  end
  return nil
end

return M
