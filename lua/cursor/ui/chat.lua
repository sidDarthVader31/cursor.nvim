local layout = require("cursor.ui.layout")
local markdown = require("cursor.ui.markdown")
local plans = require("cursor.plans")
local spinner = require("cursor.ui.spinner")
local state = require("cursor.state")
local status = require("cursor.ui.status")

local M = {}

M.ns = vim.api.nvim_create_namespace("cursor-chat")

local function tool_icon(tool_status)
  if tool_status == "completed" then
    return "✓"
  elseif tool_status == "failed" then
    return "✗"
  end
  return "◌"
end

local function split_lines(content)
  if not content or content == "" then
    return {}
  end
  return vim.split(content, "\n", { plain = true })
end

local function elapsed_seconds(started_at)
  if not started_at then
    return nil
  end
  return math.floor((vim.loop.now() - started_at) / 1000)
end

local function apply_highlights(buf, marks, excluded)
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for _, entry in ipairs(marks) do
    local opts = {
      end_row = entry.line,
      hl_group = entry.hl,
      strict = false,
    }
    if entry.col then
      opts.end_col = entry.end_col
    elseif entry.end_col then
      opts.end_col = entry.end_col
    end
    vim.api.nvim_buf_set_extmark(buf, M.ns, entry.line, entry.col or 0, opts)
  end
  markdown.apply(buf, M.ns, excluded)
end

local function active_tool_title(st)
  for _, tc in pairs(st.tool_calls or {}) do
    if tc.status == "in_progress" or tc.status == "pending" then
      return tc.title or "tool"
    end
  end
  return nil
end

local function exclude_line(excluded, idx)
  excluded[idx] = true
end

local function add_activity_footer(lines, marks, excluded, st)
  if not st.prompting and not st.run_cancelled then
    return
  end

  table.insert(lines, "")
  local sep_idx = #lines
  table.insert(lines, string.rep("─", 24))
  exclude_line(excluded, sep_idx)
  table.insert(marks, { line = sep_idx, hl = "Comment" })

  if st.run_cancelled and not st.prompting then
    local stop_idx = #lines
    table.insert(lines, "Stopped")
    exclude_line(excluded, stop_idx)
    table.insert(marks, { line = stop_idx, hl = "CursorTool" })
    return
  end

  local spin = spinner.current()
  local tool_title = active_tool_title(st)
  local working = spin .. " Working"
  if tool_title then
    working = working .. " · " .. tool_title
  end
  local work_idx = #lines
  table.insert(lines, working)
  exclude_line(excluded, work_idx)
  table.insert(marks, { line = work_idx, hl = "CursorTool" })

  local hint_idx = #lines
  table.insert(lines, "Enter / Ctrl+c / x to stop")
  exclude_line(excluded, hint_idx)
  table.insert(marks, { line = hint_idx, hl = "Comment" })

  local has_tools = false
  for _, tc in pairs(st.tool_calls or {}) do
    has_tools = true
    local secs = elapsed_seconds(tc.started_at)
    local suffix = ""
    if tc.status == "in_progress" or tc.status == "pending" then
      if secs then
        suffix = string.format(" (%ds)", secs)
      end
    end
    local line_idx = #lines
    table.insert(lines, string.format("%s %s%s", tool_icon(tc.status), tc.title or "tool", suffix))
    exclude_line(excluded, line_idx)
  end

  if st.activity_task then
    local task_idx = #lines
    table.insert(lines, "◌ " .. st.activity_task)
    exclude_line(excluded, task_idx)
  end

  if st.activity_todos and #st.activity_todos > 0 then
    local done = 0
    for _, todo in ipairs(st.activity_todos) do
      if todo.status == "completed" then
        done = done + 1
      end
    end
    local todo_idx = #lines
    table.insert(lines, string.format("Todos %d/%d", done, #st.activity_todos))
    exclude_line(excluded, todo_idx)
  elseif not has_tools and not st.assistant_buffer and not st.activity_task then
    local think_idx = #lines
    table.insert(lines, "Thinking…")
    exclude_line(excluded, think_idx)
    table.insert(marks, { line = think_idx, hl = "Comment" })
  end
end

function M.render()
  local buf = layout.chat_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  local marks = {}
  local excluded = {}
  local st = state.get()
  local show_status = st.session_id ~= nil

  if show_status then
    local status_text = status.text()
    table.insert(lines, status_text)
    exclude_line(excluded, 0)
    table.insert(marks, { line = 0, hl = "CursorTitle" })
    local sep_width = layout.chat_win and vim.api.nvim_win_is_valid(layout.chat_win)
      and vim.api.nvim_win_get_width(layout.chat_win)
      or status.separator_width()
    table.insert(lines, string.rep("─", math.max(20, sep_width - 2)))
    exclude_line(excluded, 1)
    table.insert(marks, { line = 1, hl = "Comment" })
  end

  local function add_heading(text, hl)
    local line_idx = #lines
    table.insert(lines, text)
    exclude_line(excluded, line_idx)
    table.insert(marks, { line = line_idx, end_col = #text, hl = hl })
  end

  local function add_content(content)
    for _, line in ipairs(split_lines(content)) do
      table.insert(lines, line)
    end
  end

  for _, msg in ipairs(st.messages) do
    if msg.role == "user" then
      add_heading("You", "CursorUser")
      add_content(msg.content)
      table.insert(lines, "")
    elseif msg.role == "assistant" then
      add_heading("Agent", "CursorAgent")
      add_content(msg.content)
      table.insert(lines, "")
    elseif msg.role == "plan" then
      local plan = plans.find(msg.plan_id)
      local name = msg.name or (plan and plan.name) or "Plan"
      local overview = msg.overview or (plan and plan.overview) or ""
      local line_idx = #lines
      local card = "Plan · " .. name
      if overview ~= "" then
        card = card .. " — " .. overview
      end
      card = card .. "  (P to view)"
      table.insert(lines, card)
      exclude_line(excluded, line_idx)
      table.insert(marks, { line = line_idx, hl = "CursorPlan" })
      table.insert(lines, "")
    elseif msg.role == "tool" then
      local line_idx = #lines
      table.insert(lines, string.format("%s %s", tool_icon(msg.status), msg.title or "tool"))
      exclude_line(excluded, line_idx)
    end
  end

  if st.assistant_buffer and st.assistant_buffer ~= "" then
    add_heading("Agent", "CursorAgent")
    add_content(st.assistant_buffer)
    table.insert(lines, "")
  end

  if st.prompting then
    for _, tc in pairs(st.tool_calls) do
      local already = false
      for _, msg in ipairs(st.messages) do
        if msg.role == "tool" and msg.tool_id == tc.id then
          already = true
          break
        end
      end
      if not already and tc.status ~= "in_progress" and tc.status ~= "pending" then
        local line_idx = #lines
        table.insert(lines, string.format("%s %s", tool_icon(tc.status), tc.title or "tool"))
        exclude_line(excluded, line_idx)
      end
    end
  else
    for _, tc in pairs(st.tool_calls) do
      local already = false
      for _, msg in ipairs(st.messages) do
        if msg.role == "tool" and msg.tool_id == tc.id then
          already = true
          break
        end
      end
      if not already then
        local line_idx = #lines
        table.insert(lines, string.format("%s %s", tool_icon(tc.status), tc.title or "tool"))
        exclude_line(excluded, line_idx)
      end
    end
  end

  add_activity_footer(lines, marks, excluded, st)

  if st.last_error and st.last_error ~= "" then
    table.insert(lines, "")
    local err_idx = #lines
    table.insert(lines, "Error: " .. st.last_error)
    exclude_line(excluded, err_idx)
  end

  local has_content = #st.messages > 0
    or (st.assistant_buffer and st.assistant_buffer ~= "")
    or st.prompting
    or st.run_cancelled
    or (st.last_error and st.last_error ~= "")

  if not has_content and not show_status then
    local welcome_idx = #lines
    table.insert(lines, "Cursor Agent ready. Type a message below.")
    exclude_line(excluded, welcome_idx)
    local hint_idx = #lines
    table.insert(lines, "Enter to send · Shift+Enter for newline · P plans")
    exclude_line(excluded, hint_idx)
  end

  local ok, err = pcall(function()
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    apply_highlights(buf, marks, excluded)
  end)

  if not ok then
    vim.notify("[cursor] render failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  layout.update_title()
  layout.update_input_title()

  if layout.chat_win and vim.api.nvim_win_is_valid(layout.chat_win) then
    local last = #lines
    if last > 0 then
      pcall(vim.api.nvim_win_set_cursor, layout.chat_win, { last, 0 })
    end
  end
end

return M
