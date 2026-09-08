local M = {}

local markers = {
  ".git",
  "package.json",
  "go.mod",
  "Cargo.toml",
  "pyproject.toml",
  "Makefile",
}

function M.root(start_path)
  start_path = start_path or vim.loop.cwd()
  if type(start_path) == "number" then
    start_path = vim.api.nvim_buf_get_name(start_path)
  end
  if start_path == "" then
    start_path = vim.loop.cwd()
  end
  start_path = vim.fn.fnamemodify(start_path, ":p")

  local function is_dir(path)
    return vim.fn.isdirectory(path) == 1
  end

  local current = start_path
  if vim.fn.isdirectory(current) == 0 then
    current = vim.fn.fnamemodify(current, ":h")
  end

  while current and current ~= "/" and current ~= "" do
    for _, marker in ipairs(markers) do
      if is_dir(vim.fn.join({ current, marker }, "/")) then
        return current
      end
    end
    local parent = vim.fn.fnamemodify(current, ":h")
    if parent == current then
      break
    end
    current = parent
  end

  return vim.loop.cwd()
end

function M.within_root(path, root)
  if not path or not root then
    return false
  end
  local abs = vim.fn.fnamemodify(path, ":p")
  local abs_root = vim.fn.fnamemodify(root, ":p")
  if abs:sub(1, #abs_root) ~= abs_root then
    return false
  end
  if #abs > #abs_root and abs:sub(#abs_root + 1, #abs_root + 1) ~= "/" then
    return false
  end
  return true
end

return M
