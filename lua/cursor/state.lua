local M = {}

M.states = {
  stopped = "stopped",
  starting = "starting",
  ready = "ready",
  prompting = "prompting",
  stopping = "stopping",
  error = "error",
}

local function option_id(opt)
  return opt.id or opt.configId
end

local initial = {
  status = M.states.stopped,
  process = nil,
  session_id = nil,
  session_title = nil,
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
  last_error = nil,
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
    elseif opt.category == "thought_level" or option_id(opt) == "thought_level" then
      M._state.current_effort = opt.currentValue
    elseif opt.category == "mode" then
      M._state.current_mode = opt.currentValue
    end
  end
end

function M.set_error(msg)
  M._state.last_error = msg
end

function M.clear_error()
  M._state.last_error = nil
end

function M.get_config_option(config_id)
  for _, opt in ipairs(M._state.config_options) do
    if option_id(opt) == config_id then
      return opt
    end
  end
  return nil
end

function M.option_id(opt)
  return option_id(opt)
end

local function humanize(value)
  if not value or value == "" then
    return "?"
  end
  local base = value:match("^([^%[]+)") or value
  return base:sub(1, 1):upper() .. base:sub(2)
end

function M.set_session_title(title)
  M._state.session_title = title
end

function M.display_value(category)
  for _, opt in ipairs(M._state.config_options) do
    if opt.category == category or option_id(opt) == category then
      local current = opt.currentValue
      if opt.options and current then
        for _, o in ipairs(opt.options) do
          if o.value == current then
            return o.name or humanize(current)
          end
        end
      end
      if current then
        return humanize(current)
      end
    end
  end
  if category == "model" and M._state.current_model then
    return humanize(M._state.current_model)
  end
  if category == "thought_level" and M._state.current_effort then
    return humanize(M._state.current_effort)
  end
  if category == "mode" and M._state.current_mode then
    return humanize(M._state.current_mode)
  end
  return "?"
end

return M
