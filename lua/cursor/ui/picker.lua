local acp = require("cursor.acp")
local config = require("cursor.config")
local schedule = require("cursor.schedule")
local state = require("cursor.state")

local M = {}

M.win = nil
M.buf = nil
M.tab = "model"
M.filter = ""
M.cursor = 1
M.items = {}

local TABS = {
  model = { key = "m", label = "Model", category = "model" },
  effort = { key = "e", label = "Effort", category = "thought_level" },
  mode = { key = "o", label = "Mode", category = "mode" },
}

local function get_option_for_tab(tab)
  local info = TABS[tab]
  if not info then
    return nil
  end
  for _, opt in ipairs(state.get().config_options) do
    if opt.category == info.category then
      return opt
    end
    if state.option_id(opt) == info.category then
      return opt
    end
  end
  return nil
end

function M.build_items()
  local opt = get_option_for_tab(M.tab)
  M.items = {}
  if not opt or not opt.options then
    return
  end
  local config_id = state.option_id(opt)
  for _, o in ipairs(opt.options) do
    local name = o.name or o.value or "?"
    local desc = o.description or ""
    local line = name
    if desc ~= "" then
      line = line .. "     " .. desc
    end
    if o.value == opt.currentValue then
      line = line .. "     (current)"
    end
    if M.filter == "" or name:lower():find(M.filter:lower(), 1, true) then
      table.insert(M.items, {
        value = o.value,
        line = line,
        configId = config_id,
        value_type = opt.type == "boolean" and "boolean" or "id",
      })
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
    st.current_effort or "?",
    st.current_mode or "?"
  )
end

function M.render()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  M.build_items()
  local lines = {}
  table.insert(lines, tab_header())
  table.insert(lines, "")
  if M.tab == "model" and M.filter ~= "" then
    table.insert(lines, "/ " .. M.filter)
    table.insert(lines, "")
  end
  if #M.items == 0 then
    table.insert(lines, "  (no options — open chat first or run :CursorRestart)")
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
  if not item or not item.configId then
    vim.notify("[cursor] No config option selected", vim.log.levels.WARN)
    return
  end
  acp.set_config_option(item.configId, item.value, item.value_type or "id", function(_, err)
    if err then
      local msg = err.message or vim.inspect(err)
      if msg:lower():find("internal error") then
        msg = msg .. " — try :CursorRestart or set model at agent startup"
      end
      vim.notify("[cursor] " .. msg, vim.log.levels.ERROR)
    else
      require("cursor.ui.layout").update_title()
      schedule.ui(function()
        M.render()
      end)
    end
  end)
end

local function setup_keymaps()
  local opts = { buffer = M.buf, nowait = true }

  vim.keymap.set("n", "j", function()
    M.cursor = math.min(#M.items, M.cursor + 1)
    M.render()
  end, opts)
  vim.keymap.set("n", "k", function()
    M.cursor = math.max(1, M.cursor - 1)
    M.render()
  end, opts)
  vim.keymap.set("n", "<CR>", apply_current, opts)

  vim.keymap.set("n", "m", function()
    M.tab = "model"
    M.filter = ""
    M.cursor = 1
    M.render()
  end, opts)
  vim.keymap.set("n", "e", function()
    M.tab = "effort"
    M.filter = ""
    M.cursor = 1
    M.render()
  end, opts)
  vim.keymap.set("n", "o", function()
    M.tab = "mode"
    M.filter = ""
    M.cursor = 1
    M.render()
  end, opts)

  vim.keymap.set("n", "/", function()
    vim.ui.input({ prompt = "Filter: " }, function(input)
      M.filter = input or ""
      M.cursor = 1
      schedule.ui(function()
        M.render()
      end)
    end)
  end, opts)

  vim.keymap.set({ "n", "i" }, "q", function()
    M.close()
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, opts)
end

local function open_picker_window(opts)
  opts = opts or {}
  M.tab = opts.tab or "model"
  M.filter = ""
  M.cursor = 1

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
  M.render()

  if opts.apply_name then
    for i, item in ipairs(M.items) do
      if item.value == opts.apply_name or item.line:find(opts.apply_name, 1, true) then
        M.cursor = i
        apply_current()
        break
      end
    end
  end
end

function M.open(opts)
  opts = opts or {}
  require("cursor.ui").ensure_started(function(ok, err)
    if not ok then
      vim.notify("[cursor] " .. (err or "Agent not available"), vim.log.levels.ERROR)
      return
    end
    schedule.ui(function()
      open_picker_window(opts)
    end)
  end)
end

local function refresh_chats()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  local out = { "Cursor chats", "" }
  for i, item in ipairs(M.items) do
    table.insert(out, (i == M.cursor and "❯ " or "  ") .. item.line)
  end
  table.insert(out, "")
  table.insert(out, " <CR> resume  n new  q close")
  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, out)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

local function open_chats_window(chats)
  local chats_index = require("cursor.chats_index")
  M.items = {}
  for _, c in ipairs(chats) do
    table.insert(M.items, {
      value = c.id,
      line = chats_index.format_chat_line(c),
      configId = "session",
    })
  end
  table.insert(M.items, 1, { value = "new", line = "(new session)", configId = "session" })
  if #chats == 0 then
    table.insert(M.items, { value = "empty", line = "(no chats for this project)", configId = "session" })
  end

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")
  M.cursor = 1

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

  refresh_chats()

  local session = require("cursor.session")
  local opts = { buffer = M.buf, nowait = true }

  vim.keymap.set("n", "j", function()
    M.cursor = math.min(#M.items, M.cursor + 1)
    refresh_chats()
  end, opts)
  vim.keymap.set("n", "k", function()
    M.cursor = math.max(1, M.cursor - 1)
    refresh_chats()
  end, opts)

  local function after_session_action(ok, err, open_chat)
    if not ok and err then
      local msg = type(err) == "table" and (err.message or vim.inspect(err)) or tostring(err)
      vim.notify("[cursor] " .. msg, vim.log.levels.ERROR)
      return
    end
    M.close()
    if open_chat then
      require("cursor.ui").open()
    end
  end

  vim.keymap.set("n", "<CR>", function()
    local item = M.items[M.cursor]
    if not item or item.value == "empty" then
      return
    end
    require("cursor.ui").ensure_started(function(started, start_err)
      if not started then
        vim.notify("[cursor] " .. (start_err or "Agent not available"), vim.log.levels.ERROR)
        return
      end
      if item.value == "new" then
        session.new(function(_, err)
          after_session_action(err == nil, err, true)
        end)
      else
        session.resume(item.value, function(_, err)
          after_session_action(err == nil, err, true)
        end)
      end
    end)
  end, opts)

  vim.keymap.set("n", "n", function()
    require("cursor.ui").ensure_started(function(started, start_err)
      if not started then
        vim.notify("[cursor] " .. (start_err or "Agent not available"), vim.log.levels.ERROR)
        return
      end
      session.new(function(_, err)
        after_session_action(err == nil, err, true)
      end)
    end)
  end, opts)

  vim.keymap.set("n", "q", function()
    M.close()
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, opts)
end

function M.open_chats()
  local session = require("cursor.session")
  session.list_chats(function(chats)
    schedule.ui(function()
      open_chats_window(chats)
    end)
  end)
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

return M
