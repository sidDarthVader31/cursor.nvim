local permissions = require("cursor.permissions")

local M = {}

M.win = nil
M.buf = nil

local function option_key(option, index)
  local id = (option.id or option.optionId or option.name or ""):lower()
  if id:find("session", 1, true) or id:find("always", 1, true) then
    return "s"
  end
  if id:find("reject", 1, true) or id:find("deny", 1, true) then
    return "d"
  end
  if id:find("allow", 1, true) then
    return "a"
  end
  local defaults = { "a", "s", "d", "q" }
  return defaults[index] or id:sub(1, 1)
end

local function build_option_lines(params)
  local options = params.options or (params.toolCall and params.toolCall.options) or {}
  local lines = {}
  local bindings = {}

  if #options > 0 then
    for i, opt in ipairs(options) do
      local id = opt.id or opt.optionId or opt.name
      local label = opt.name or opt.title or id or "?"
      local key = option_key(opt, i)
      table.insert(lines, string.format("  [%s] %s", key, label))
      bindings[key] = { id = id, label = label }
    end
    return lines, bindings
  end

  lines = {
    "  [a] allow once",
    "  [s] allow for session",
    "  [d] deny",
    "  [q] cancel",
  }
  bindings = {
    a = { kind = "allow", label = "Allowed once" },
    s = { kind = "session", label = "Allowed for session" },
    d = { kind = "reject", label = "Denied" },
    q = { kind = "reject", label = "Cancelled" },
  }
  return lines, bindings
end

function M.show(params, request_id)
  M.close()

  local lines = vim.split(permissions.format_request(params), "\n")
  table.insert(lines, "")
  local option_lines, bindings = build_option_lines(params)
  for _, line in ipairs(option_lines) do
    table.insert(lines, line)
  end

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  vim.api.nvim_buf_set_option(M.buf, "readonly", true)
  vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")

  local width = 60
  local height = #lines + 2
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Cursor permission ",
    title_pos = "center",
  })

  vim.cmd("stopinsert")

  local function respond(binding)
    local label = binding.label or "Permission choice"
    if binding.id then
      permissions.respond(request_id, binding.id)
    else
      permissions.respond(request_id, permissions.default_option_id(params, binding.kind))
    end
    vim.notify("[cursor] " .. label, vim.log.levels.INFO)
    M.close()
  end

  local map_opts = { buffer = M.buf, nowait = true, silent = true }
  for key, binding in pairs(bindings) do
    vim.keymap.set({ "n", "i", "v" }, key, function()
      respond(binding)
    end, map_opts)
  end
  vim.keymap.set({ "n", "i", "v" }, "<Esc>", function()
    respond({ kind = "reject", label = "Cancelled" })
  end, map_opts)
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

return M
