local permissions = require("cursor.permissions")

local M = {}

M.win = nil
M.buf = nil

function M.show(params, request_id)
  M.close()

  local lines = vim.split(permissions.format_request(params), "\n")
  table.insert(lines, "")
  table.insert(lines, "  [a] allow once    [s] allow for session")
  table.insert(lines, "  [d] deny          [q] cancel")

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")

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

  local function respond(kind)
    permissions.respond(request_id, permissions.default_option_id(params, kind))
    M.close()
  end

  vim.keymap.set("n", "a", function()
    respond("allow")
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "s", function()
    respond("session")
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "d", function()
    respond("reject")
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "q", function()
    respond("reject")
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    respond("reject")
  end, { buffer = M.buf, nowait = true })
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

return M
