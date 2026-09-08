local acp = require("cursor.acp")
local config = require("cursor.config")
local state = require("cursor.state")

local M = {}

M.win = nil
M.buf = nil
M.tab = "model"
M.filter = ""
M.cursor = 1
M.items = {}
M.on_select = nil

local TABS = {
  model = { key = "m", label = "Model", category = "model" },
  effort = { key = "e", label = "Effort", category = "thought_level" },
  mode = { key = "o", label = "Mode", category = "mode" },
}

local FALLBACK = {
  effort = {
    { value = "medium", name = "medium", description = "default · cheaper" },
    { value = "high", name = "high", description = "more reasoning · more tokens" },
  },
  mode = {
    { value = "agent", name = "agent", description = "edit + terminal (asks permission)" },
    { value = "plan", name = "plan", description = "design first, read-mostly" },
    { value = "ask", name = "ask", description = "Q&A, no edits" },
  },
}

local function get_option_for_tab(tab)
  local info = TABS[tab]
  if not info then
    return nil
  end
  for _, opt in ipairs(state.get().config_options) do
    if opt.category == info.category or opt.configId == info.category then
      return opt
    end
  end
  if tab == "effort" then
    return { configId = "thought_level", options = FALLBACK.effort, currentValue = "medium" }
  end
  if tab == "mode" then
    return { configId = "mode", options = FALLBACK.mode, currentValue = "agent" }
  end
  return nil
end

local function build_items()
  local opt = get_option_for_tab(M.tab)
  M.items = {}
  if not opt then
    return
  end
  local options = opt.options or {}
  for _, o in ipairs(options) do
    local name = o.name or o.value
    local desc = o.description or ""
    local line = name
    if desc ~= "" then
      line = line .. "     " .. desc
    end
    if o.value == opt.currentValue then
      line = line .. "     (current)"
    end
    if M.filter == "" or name:lower():find(M.filter:lower(), 1, true) then
      table.insert(M.items, { value = o.value, line = line, configId = opt.configId })
    end
  end
  if M.cursor > #M.items then
    M.cursor = math.max(1, #M.items)
  end
end

local function tab_header()
  local parts = {}
  for key, info in pairs(TABS) do
    local label = info.label
    if M.tab == key then
      label = "[" .. info.key .. "] " .. label
    else
      label = " " .. info.key .. " " .. label
    end
    table.insert(parts, label)
  end
  return table.concat(parts, "   ")
end

local function status_line()
  local st = state.get()
  return string.format(
    " current: %s · %s · %s ",
    st.current_model or "?",
    st.current_effort or "medium",
    st.current_mode or "agent"
  )
end

local function render()
  build_items()
  local lines = {}
  table.insert(lines, tab_header())
  table.insert(lines, "")
  if M.tab == "model" and M.filter ~= "" then
    table.insert(lines, "/ " .. M.filter)
    table.insert(lines, "")
  end
  if #M.items == 0 then
    table.insert(lines, "  (no matches)")
  else
    for i, item in ipairs(M.items) do
      local prefix = i == M.cursor and "❯ " or "  "
      table.insert(lines, prefix .. item.line)
    end
  end
  table.insert(lines, "")
  table.insert(lines, string.format(" %d/%d%s", M.cursor, #M.items, status_line()))
  table.insert(lines, " <CR> apply  / filter  j/k  m/e/o tabs  q close")

  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

local function apply_current()
  local item = M.items[M.cursor]
  if not item then
    return
  end
  acp.set_config_option(item.configId, item.value, "id", function(_, err)
    if err then
      vim.notify("[cursor] " .. (err.message or "failed to set option"), vim.log.levels.ERROR)
    else
      require("cursor.ui.layout").update_title()
      render()
    end
  end)
end

local function setup_keymaps()
  local opts = { buffer = M.buf, nowait = true }

  vim.keymap.set("n", "j", function()
    M.cursor = math.min(#M.items, M.cursor + 1)
    render()
  end, opts)
  vim.keymap.set("n", "k", function()
    M.cursor = math.max(1, M.cursor - 1)
    render()
  end, opts)
  vim.keymap.set("n", "<CR>", apply_current, opts)

  vim.keymap.set("n", "m", function()
    M.tab = "model"
    M.filter = ""
    M.cursor = 1
    render()
  end, opts)
  vim.keymap.set("n", "e", function()
    M.tab = "effort"
    M.filter = ""
    M.cursor = 1
    render()
  end, opts)
  vim.keymap.set("n", "o", function()
    M.tab = "mode"
    M.filter = ""
    M.cursor = 1
    render()
  end, opts)

  vim.keymap.set("n", "/", function()
    vim.ui.input({ prompt = "Filter: " }, function(input)
      M.filter = input or ""
      M.cursor = 1
      render()
    end)
  end, opts)

  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
  end, opts)

  vim.keymap.set({ "n", "i" }, "q", function()
    M.close()
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, opts)
end

function M.open(opts)
  opts = opts or {}
  M.tab = opts.tab or "model"
  M.filter = ""
  M.cursor = 1

  require("cursor.ui").ensure_started(function(ok)
    if not ok then
      return
    end

    M.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")

    local cfg = config.get().picker
    local width = cfg.width or 70
    local height = cfg.height or 18

    M.win = vim.api.nvim_open_win(M.buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = "minimal",
      border = config.get().border,
      title = " Cursor ",
      title_pos = "center",
    })

    setup_keymaps()
    render()

    if opts.apply_name then
      for i, item in ipairs(M.items) do
        if item.value == opts.apply_name or item.line:find(opts.apply_name, 1, true) then
          M.cursor = i
          apply_current()
          break
        end
      end
    end
  end)
end

function M.open_chats()
  local session = require("cursor.session")
  session.list_chats(function(chats)
    M.tab = "chats"
    M.items = {}
    for _, c in ipairs(chats) do
      table.insert(M.items, {
        value = c.id,
        line = c.title or c.id,
        configId = "session",
      })
    end
    table.insert(M.items, 1, { value = "new", line = "(new session)", configId = "session" })

    M.buf = vim.api.nvim_create_buf(false, true)
    M.cursor = 1
    local lines = { "Cursor chats", "" }
    for i, item in ipairs(M.items) do
      table.insert(lines, (i == 1 and "❯ " or "  ") .. item.line)
    end
    table.insert(lines, "")
    table.insert(lines, " <CR> resume  n new  q close")

    local cfg = config.get().picker
    M.win = vim.api.nvim_open_win(M.buf, true, {
      relative = "editor",
      width = cfg.width or 70,
      height = cfg.height or 18,
      col = math.floor((vim.o.columns - (cfg.width or 70)) / 2),
      row = math.floor((vim.o.lines - (cfg.height or 18)) / 2),
      style = "minimal",
      border = config.get().border,
      title = " Cursor chats ",
    })

    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)

    vim.keymap.set("n", "j", function()
      M.cursor = math.min(#M.items, M.cursor + 1)
      M.open_chats_refresh()
    end, { buffer = M.buf })
    vim.keymap.set("n", "k", function()
      M.cursor = math.max(1, M.cursor - 1)
      M.open_chats_refresh()
    end, { buffer = M.buf })
    vim.keymap.set("n", "<CR>", function()
      local item = M.items[M.cursor]
      if not item then
        return
      end
      if item.value == "new" then
        session.new(function()
          M.close()
          require("cursor.ui").open()
        end)
      else
        session.resume(item.value, function()
          M.close()
          require("cursor.ui").open()
        end)
      end
    end, { buffer = M.buf })
    vim.keymap.set("n", "n", function()
      session.new(function()
        M.close()
      end)
    end, { buffer = M.buf })
    vim.keymap.set("n", "q", function()
      M.close()
    end, { buffer = M.buf })
  end)
end

function M.open_chats_refresh()
  -- simplified re-render for chat list cursor
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

return M
