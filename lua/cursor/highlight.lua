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
  vim.api.nvim_set_hl(0, "CursorPickerMuted", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CursorMdHeading", { link = "@markup.heading", default = true })
  vim.api.nvim_set_hl(0, "CursorMdBold", { link = "@markup.bold", default = true })
  vim.api.nvim_set_hl(0, "CursorMdItalic", { link = "@markup.italic", default = true })
  vim.api.nvim_set_hl(0, "CursorMdCode", { link = "markdownCode", default = true })
  vim.api.nvim_set_hl(0, "CursorMdFence", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CursorMdList", { link = "@markup.list", default = true })
  vim.api.nvim_set_hl(0, "CursorMdQuote", { link = "@markup.quote", default = true })
  vim.api.nvim_set_hl(0, "CursorPlan", { link = "DiagnosticInfo", bold = true, default = true })
  vim.api.nvim_set_hl(0, "CursorMdHr", { link = "Comment", default = true })
  M._done = true
end

return M
