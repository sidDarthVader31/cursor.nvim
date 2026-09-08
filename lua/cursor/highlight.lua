local M = {}

M._done = false

function M.setup()
  if M._done then
    return
  end
  if vim.in_fast_event() then
    vim.schedule(M.setup)
    return
  end
  vim.api.nvim_set_hl(0, "CursorTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "CursorUser", { link = "DiagnosticInfo", bold = true, default = true })
  vim.api.nvim_set_hl(0, "CursorAgent", { link = "Special", bold = true, default = true })
  vim.api.nvim_set_hl(0, "CursorTool", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "CursorPickerCurrent", { link = "CursorLine", default = true })
  vim.api.nvim_set_hl(0, "CursorPickerTab", { link = "TabLineSel", default = true })
  vim.api.nvim_set_hl(0, "CursorPickerFilter", { link = "Question", default = true })
  M._done = true
end

return M
