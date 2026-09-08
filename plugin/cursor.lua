if vim.g.loaded_cursor then
  return
end
vim.g.loaded_cursor = true

require("cursor").setup()
