local acp = require("cursor.acp")
local rpc = require("cursor.rpc")
local schedule = require("cursor.schedule")
local state = require("cursor.state")
local transport = require("cursor.transport")

local M = {}

local IMPLEMENT_PROMPT = "Implement the approved plan."

local function storage_dir()
  return vim.fn.stdpath("data") .. "/cursor.nvim/plans"
end

local function storage_path(session_id)
  if not session_id then
    return nil
  end
  return storage_dir() .. "/" .. session_id .. ".json"
end

local function now_ms()
  return vim.loop.now()
end

function M.normalize_entry(params, status)
  local id = params.toolCallId or params.id or ("plan-" .. tostring(now_ms()))
  return {
    id = id,
    tool_call_id = params.toolCallId,
    name = params.name or "Plan",
    overview = params.overview or "",
    plan = params.plan or params.text or "",
    todos = params.todos or {},
    phases = params.phases,
    is_project = params.isProject,
    status = status or "pending",
    created_at = now_ms(),
    request_id = nil,
  }
end

function M.persist()
  local st = state.get()
  local session_id = st.session_id
  if not session_id then
    return
  end
  local path = storage_path(session_id)
  if not path then
    return
  end
  local ok = pcall(function()
    vim.fn.mkdir(storage_dir(), "p")
    local payload = vim.json.encode({
      session_id = session_id,
      plans = st.plans or {},
    })
    vim.fn.writefile(vim.split(payload, "\n", { plain = true }), path)
  end)
  if not ok then
    -- ignore persistence errors (e.g. sandboxed test env)
  end
end

function M.load_for_session(session_id)
  if not session_id then
    return
  end
  local path = storage_path(session_id)
  if not path or vim.fn.filereadable(path) ~= 1 then
    return
  end
  local raw = table.concat(vim.fn.readfile(path), "\n")
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" or type(data.plans) ~= "table" then
    return
  end
  state.get().plans = data.plans
end

function M.add_entry(entry)
  local st = state.get()
  st.plans = st.plans or {}
  for i, existing in ipairs(st.plans) do
    if existing.id == entry.id or (entry.tool_call_id and existing.tool_call_id == entry.tool_call_id) then
      st.plans[i] = vim.tbl_extend("force", existing, entry)
      M.persist()
      return st.plans[i]
    end
  end
  table.insert(st.plans, entry)
  M.persist()
  return entry
end

function M.ingest_session_plan(update)
  local text = update.plan or update.text or ""
  if text == "" then
    return
  end
  local entry = M.normalize_entry({
    toolCallId = update.toolCallId or ("session-plan-" .. tostring(now_ms())),
    name = update.name or "Plan",
    overview = update.overview or "",
    plan = text,
    todos = update.todos or {},
    phases = update.phases,
  }, "pending")
  M.add_entry(entry)
  state.add_message({
    role = "plan",
    plan_id = entry.id,
    name = entry.name,
    overview = entry.overview,
  })
end

function M.handle_create_plan(params, request_id)
  local entry = M.normalize_entry(params, "pending")
  entry.request_id = request_id
  M.add_entry(entry)
  state.get().pending_plan = entry
  state.add_message({
    role = "plan",
    plan_id = entry.id,
    name = entry.name,
    overview = entry.overview,
  })

  schedule.ui(function()
    require("cursor.ui").open()
    require("cursor.ui.plan").show(entry, request_id)
    require("cursor.ui").schedule_refresh()
  end)

  return nil
end

function M.respond(request_id, outcome, reason)
  local result = { outcome = { outcome = outcome } }
  if reason and outcome == "rejected" then
    result.outcome.reason = reason
  end
  transport.send(rpc.response(request_id, result))
end

function M.set_status(plan_id, status)
  local st = state.get()
  for _, p in ipairs(st.plans or {}) do
    if p.id == plan_id then
      p.status = status
      break
    end
  end
  if st.pending_plan and st.pending_plan.id == plan_id then
    st.pending_plan.status = status
    if status ~= "pending" then
      st.pending_plan = nil
    end
  end
  M.persist()
end

function M.find(plan_id)
  for _, p in ipairs(state.get().plans or {}) do
    if p.id == plan_id then
      return p
    end
  end
  return nil
end

function M.latest()
  local plans = state.get().plans or {}
  if #plans == 0 then
    return nil
  end
  return plans[#plans]
end

function M.reject(plan, request_id)
  request_id = request_id or plan.request_id
  if request_id then
    M.respond(request_id, "rejected")
  end
  M.set_status(plan.id, "rejected")
  require("cursor.ui.plan").close()
  require("cursor.ui").schedule_refresh()
end

function M.cancel(plan, request_id)
  request_id = request_id or plan.request_id
  if request_id then
    M.respond(request_id, "cancelled")
  end
  M.set_status(plan.id, "cancelled")
  require("cursor.ui.plan").close()
  require("cursor.ui").schedule_refresh()
end

local function executable_mode_value()
  local opt = state.get_config_option("mode")
  if not opt or not opt.options then
    return "agent"
  end
  local preferred = { "agent", "code", "default" }
  for _, want in ipairs(preferred) do
    for _, o in ipairs(opt.options) do
      local v = (o.value or ""):lower()
      local n = (o.name or ""):lower()
      if v == want or n == want then
        return o.value
      end
    end
  end
  for _, o in ipairs(opt.options) do
    local v = (o.value or ""):lower()
    if v ~= "plan" and v ~= "ask" then
      return o.value
    end
  end
  return opt.currentValue
end

local function needs_mode_switch()
  local mode = (state.get().current_mode or ""):lower()
  return mode == "plan" or mode == "ask"
end

local function wait_until_ready(callback)
  if not state.get().prompting then
    callback()
    return
  end
  vim.defer_fn(function()
    wait_until_ready(callback)
  end, 50)
end

local function send_implement_prompt(callback)
  state.add_message({ role = "user", content = IMPLEMENT_PROMPT })
  require("cursor.ui").schedule_refresh()
  acp.session_prompt(IMPLEMENT_PROMPT, callback)
end

function M.build(plan, request_id)
  request_id = request_id or plan.request_id
  if plan.status == "pending" and request_id then
    M.respond(request_id, "accepted")
    M.set_status(plan.id, "accepted")
  elseif plan.status ~= "accepted" then
    M.set_status(plan.id, "accepted")
  end
  require("cursor.ui.plan").close()
  require("cursor.ui").schedule_refresh()

  wait_until_ready(function()
    local function after_mode()
      send_implement_prompt(function(_, err)
        if err then
          vim.notify(
            "[cursor] " .. (err.message or vim.inspect(err) or "implement prompt failed"),
            vim.log.levels.ERROR
          )
        end
      end)
    end

    if needs_mode_switch() then
      local mode_opt = state.get_config_option("mode")
      local config_id = mode_opt and state.option_id(mode_opt) or "mode"
      local value = executable_mode_value()
      acp.set_config_option(config_id, value, "id", function(_, err)
        if err then
          vim.notify(
            "[cursor] mode switch failed: " .. (err.message or vim.inspect(err)),
            vim.log.levels.ERROR
          )
        end
        after_mode()
      end)
    else
      after_mode()
    end
  end)
end

function M.merge_todos(todos, merge)
  local st = state.get()
  if not todos or #todos == 0 then
    return
  end
  st.activity_todos = st.activity_todos or {}
  if not merge then
    st.activity_todos = todos
  else
    local by_id = {}
    for _, t in ipairs(st.activity_todos) do
      by_id[t.id] = t
    end
    for _, t in ipairs(todos) do
      by_id[t.id] = t
    end
    local merged = {}
    for _, t in ipairs(st.activity_todos) do
      if by_id[t.id] then
        table.insert(merged, by_id[t.id])
        by_id[t.id] = nil
      end
    end
    for _, t in ipairs(todos) do
      if by_id[t.id] then
        table.insert(merged, by_id[t.id])
      end
    end
    st.activity_todos = merged
  end
  if st.pending_plan then
    st.pending_plan.todos = st.activity_todos
    M.persist()
  end
  require("cursor.ui").schedule_refresh()
end

function M.set_task(description)
  state.get().activity_task = description
  require("cursor.ui").schedule_refresh()
end

function M.open_latest_or_picker()
  local plans = state.get().plans or {}
  if #plans == 0 then
    vim.notify("[cursor] No plans in this session", vim.log.levels.WARN)
    return
  end
  if #plans == 1 then
    require("cursor.ui.plan").show(plans[1], plans[1].request_id, { readonly = plans[1].status ~= "pending" })
    return
  end
  require("cursor.ui.plan").open_picker()
end

function M.build_latest()
  local plan = state.get().pending_plan or M.latest()
  if not plan then
    vim.notify("[cursor] No plan to build", vim.log.levels.WARN)
    return
  end
  if plan.status == "rejected" or plan.status == "cancelled" then
    vim.notify("[cursor] Plan is " .. plan.status, vim.log.levels.WARN)
    return
  end
  M.build(plan, plan.request_id)
end

return M
