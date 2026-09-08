local M = {}

function M.current_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    name = nil
  end
  return {
    buf = buf,
    file = name,
  }
end

function M.cursor_position(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local row, col = vim.api.nvim_win_get_cursor(0)
  return {
    line = row,
    column = col + 1,
  }
end

function M.visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil
  end
  local start = vim.fn.getpos("v<")
  local finish = vim.fn.getpos("v>")
  local lines = vim.api.nvim_buf_get_lines(0, start[2] - 1, finish[2], false)
  if #lines == 0 then
    return nil
  end
  if #lines == 1 then
    lines[1] = lines[1]:sub(start[3], finish[3])
  else
    lines[1] = lines[1]:sub(start[3])
    lines[#lines] = lines[#lines]:sub(1, finish[3])
  end
  return {
    start_line = start[2],
    end_line = finish[2],
    text = table.concat(lines, "\n"),
  }
end

function M.build_prompt(user_text, opts)
  opts = opts or {}
  local parts = {}
  if user_text and user_text ~= "" then
    table.insert(parts, "User request:\n" .. user_text)
  end

  local ctx = {}
  if opts.file then
    ctx.file = opts.file
  end
  if opts.cwd then
    ctx.cwd = opts.cwd
  end
  if opts.cursor then
    ctx.cursor = opts.cursor
  end
  if opts.selection and opts.selection.text and opts.selection.text ~= "" then
    ctx.selection = opts.selection
  end

  if vim.tbl_count(ctx) > 0 then
    table.insert(parts, "\nCurrent editor context:")
    if ctx.cwd then
      table.insert(parts, "Project: " .. ctx.cwd)
    end
    if ctx.file then
      table.insert(parts, "File: " .. ctx.file)
    end
    if ctx.cursor then
      table.insert(
        parts,
        string.format("Cursor: line %d, column %d", ctx.cursor.line, ctx.cursor.column)
      )
    end
    if ctx.selection then
      table.insert(parts, "\nSelected text:\n" .. ctx.selection.text)
    end
  end

  return table.concat(parts, "\n")
end

function M.from_editor(user_text)
  local project = require("cursor.project")
  local buf = M.current_buffer()
  local cwd = project.root(buf.file or 0)
  return M.build_prompt(user_text, {
    file = buf.file,
    cwd = cwd,
    cursor = M.cursor_position(buf.buf),
    selection = M.visual_selection(),
  })
end

return M
