local config = require("cursor.config")
local markdown = require("cursor.ui.markdown")
local plans = require("cursor.plans")
local schedule = require("cursor.schedule")
local state = require("cursor.state")

local M = {}

M.win = nil
M.buf = nil
M.ns = vim.api.nvim_create_namespace("cursor-plan")

local function split_lines(text)
  if not text or text == "" then
    return {}
  end
  return vim.split(text, "\n", { plain = true })
end

local function todo_icon(status)
  if status == "completed" then
    return "✓"
  elseif status == "cancelled" then
    return "✗"
  elseif status == "in_progress" then
    return "◌"
  end
  return "○"
end

local function build_body(plan)
  local lines = {}
  if plan.overview and plan.overview ~= "" then
    table.insert(lines, plan.overview)
    table.insert(lines, "")
  end
  for _, line in ipairs(split_lines(plan.plan or "")) do
    table.insert(lines, line)
  end
  if plan.phases and #plan.phases > 0 then
    table.insert(lines, "")
    table.insert(lines, "Phases")
    for _, phase in ipairs(plan.phases) do
      table.insert(lines, "")
      table.insert(lines, phase.name or "Phase")
      for _, todo in ipairs(phase.todos or {}) do
        table.insert(lines, string.format("  %s %s", todo_icon(todo.status), todo.content or ""))
      end
    end
  elseif plan.todos and #plan.todos > 0 then
    table.insert(lines, "")
    table.insert(lines, "Todos")
    for _, todo in ipairs(plan.todos) do
      table.insert(lines, string.format("  %s %s", todo_icon(todo.status), todo.content or ""))
    end
  end
  if #lines == 0 then
    table.insert(lines, "(empty plan)")
  end
  return lines
end

local function footer_lines(readonly)
  if readonly then
    return { "", "  q close  Esc close" }
  end
  return { "", "  [b] Build  [r] Reject  [q] Cancel  Esc close" }
end

function M.show(plan, request_id, opts)
  opts = opts or {}
  M.close()

  local readonly = opts.readonly or plan.status ~= "pending"
  local lines = build_body(plan)
  for _, line in ipairs(footer_lines(readonly)) do
    table.insert(lines, line)
  end

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  vim.api.nvim_buf_set_option(M.buf, "readonly", true)
  vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")
  pcall(vim.treesitter.start, M.buf, "markdown")
  markdown.apply(M.buf, M.ns, {})

  local cfg = config.get().picker or {}
  local width = math.min(cfg.width or 80, vim.o.columns - 4)
  local height = math.min(math.max(#lines + 2, 12), vim.o.lines - 4)

  local title = string.format(" %s ", plan.name or "Plan")
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = config.get().border or "rounded",
    title = title,
    title_pos = "center",
  })

  vim.cmd("stopinsert")

  local map_opts = { buffer = M.buf, nowait = true, silent = true }

  vim.keymap.set({ "n", "i" }, "q", function()
    M.close()
  end, map_opts)
  vim.keymap.set("n", "<Esc>", function()
    if readonly then
      M.close()
    else
      plans.cancel(plan, request_id)
    end
  end, map_opts)

  if not readonly then
    vim.keymap.set({ "n", "i" }, "b", function()
      plans.build(plan, request_id)
    end, map_opts)
    vim.keymap.set({ "n", "i" }, "r", function()
      plans.reject(plan, request_id)
    end, map_opts)
  end
end

function M.open_picker()
  local all = state.get().plans or {}
  if #all == 0 then
    vim.notify("[cursor] No plans in this session", vim.log.levels.WARN)
    return
  end

  M.close()
  local items = {}
  for i = #all, 1, -1 do
    local p = all[i]
    table.insert(items, {
      plan = p,
      line = string.format("%s  (%s)", p.name or "Plan", p.status or "?"),
    })
  end

  local cursor = 1
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")

  local function render()
    local lines = { "Plans", "" }
    for i, item in ipairs(items) do
      local prefix = i == cursor and "❯ " or "  "
      table.insert(lines, prefix .. item.line)
    end
    table.insert(lines, "")
    table.insert(lines, " <CR> open   q close")
    vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  end

  local cfg = config.get().picker or {}
  local width = cfg.width or 70
  local height = math.min(cfg.height or 18, #items + 6)
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = config.get().border,
    title = " Cursor plans ",
    title_pos = "center",
  })

  render()
  local opts = { buffer = M.buf, nowait = true, silent = true }
  vim.keymap.set("n", "j", function()
    cursor = math.min(#items, cursor + 1)
    render()
  end, opts)
  vim.keymap.set("n", "k", function()
    cursor = math.max(1, cursor - 1)
    render()
  end, opts)
  vim.keymap.set("n", "<CR>", function()
    local item = items[cursor]
    if not item then
      return
    end
    M.close()
    schedule.ui(function()
      M.show(item.plan, item.plan.request_id, { readonly = item.plan.status ~= "pending" })
    end)
  end, opts)
  vim.keymap.set("n", "q", function()
    M.close()
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, opts)
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

return M
