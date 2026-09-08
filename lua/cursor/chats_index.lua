local config = require("cursor.config")

local M = {}

local function normalize_path(path)
  if not path or path == "" then
    return ""
  end
  local abs = vim.fn.fnamemodify(path, ":p")
  if abs:sub(-1) == "/" then
    abs = abs:sub(1, -2)
  end
  return abs
end

function M.normalize_path(path)
  return normalize_path(path)
end

function M.workspace_hash(root)
  root = normalize_path(root)
  if root == "" then
    return nil
  end
  local out = vim.fn.system({ "openssl", "dgst", "-md5", "-hex" }, root)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(out):match("(%x+)$")
end

function M.storage_dirs()
  local cfg = config.get()
  if cfg.chats_storage_dirs and #cfg.chats_storage_dirs > 0 then
    return cfg.chats_storage_dirs
  end
  local home = vim.env.HOME or vim.fn.expand("~")
  return {
    home .. "/.cursor/chats",
    home .. "/.config/cursor/chats",
  }
end

function M.read_meta(meta_path)
  if vim.fn.filereadable(meta_path) ~= 1 then
    return nil
  end
  local raw = table.concat(vim.fn.readfile(meta_path), "\n")
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil
  end
  return data
end

local function chat_from_meta(session_id, meta)
  if not meta then
    return nil
  end
  if meta.hasConversation == false then
    return nil
  end
  local title = meta.title
  if not title or title == "" then
    title = session_id:sub(1, 8)
  end
  return {
    id = session_id,
    title = title,
    cwd = meta.cwd,
    updatedAtMs = meta.updatedAtMs or meta.createdAtMs or 0,
    createdAtMs = meta.createdAtMs or 0,
  }
end

local function scan_workspace_dir(base, hash, root, chats, seen)
  local workspace_dir = vim.fn.join({ base, hash }, "/")
  if vim.fn.isdirectory(workspace_dir) ~= 1 then
    return
  end
  local entries = vim.fn.readdir(workspace_dir)
  for _, entry in ipairs(entries) do
    if entry ~= "." and entry ~= ".." then
      local meta_path = vim.fn.join({ workspace_dir, entry, "meta.json" }, "/")
      local meta = M.read_meta(meta_path)
      local chat = chat_from_meta(entry, meta)
      if chat and not seen[chat.id] then
        if root == nil or normalize_path(meta.cwd) == normalize_path(root) then
          seen[chat.id] = true
          table.insert(chats, chat)
        end
      end
    end
  end
end

local function scan_all_workspaces(base, root, chats, seen)
  if vim.fn.isdirectory(base) ~= 1 then
    return
  end
  local hashes = vim.fn.readdir(base)
  for _, hash in ipairs(hashes) do
    if hash ~= "." and hash ~= ".." then
      scan_workspace_dir(base, hash, root, chats, seen)
    end
  end
end

function M.sort_chats(chats)
  table.sort(chats, function(a, b)
    return (a.updatedAtMs or 0) > (b.updatedAtMs or 0)
  end)
  return chats
end

function M.list_for_root(root)
  root = normalize_path(root)
  local chats = {}
  local seen = {}
  local hash = M.workspace_hash(root)

  for _, base in ipairs(M.storage_dirs()) do
    if hash then
      scan_workspace_dir(base, hash, root, chats, seen)
    end
    scan_all_workspaces(base, root, chats, seen)
  end

  return M.sort_chats(chats)
end

function M.title_for_session(session_id, root)
  if not session_id then
    return nil
  end
  root = normalize_path(root)
  for _, base in ipairs(M.storage_dirs()) do
    if vim.fn.isdirectory(base) == 1 then
      local hashes = vim.fn.readdir(base)
      for _, hash in ipairs(hashes) do
        if hash ~= "." and hash ~= ".." then
          local meta_path = vim.fn.join({ base, hash, session_id, "meta.json" }, "/")
          local meta = M.read_meta(meta_path)
          if meta and meta.title and meta.title ~= "" then
            if root == "" or normalize_path(meta.cwd) == root then
              return meta.title
            end
          end
        end
      end
    end
  end
  return nil
end

function M.find_meta_path(session_id)
  if not session_id then
    return nil
  end
  for _, base in ipairs(M.storage_dirs()) do
    if vim.fn.isdirectory(base) == 1 then
      local hashes = vim.fn.readdir(base)
      for _, hash in ipairs(hashes) do
        if hash ~= "." and hash ~= ".." then
          local meta_path = vim.fn.join({ base, hash, session_id, "meta.json" }, "/")
          if vim.fn.filereadable(meta_path) == 1 then
            return meta_path
          end
        end
      end
    end
  end
  return nil
end

function M.set_title(session_id, title)
  if not session_id or not title or title == "" then
    return false, "missing session id or title"
  end
  local meta_path = M.find_meta_path(session_id)
  if not meta_path then
    return false, "meta.json not found for session"
  end
  local meta = M.read_meta(meta_path)
  if not meta then
    return false, "failed to read meta.json"
  end
  meta.title = title
  meta.updatedAtMs = vim.loop.now()
  local encoded = vim.json.encode(meta)
  local ok, err = pcall(vim.fn.writefile, vim.split(encoded, "\n", { plain = true }), meta_path)
  if not ok then
    return false, tostring(err)
  end
  return true
end

function M.format_relative_time(updated_at_ms)
  if not updated_at_ms or updated_at_ms == 0 then
    return ""
  end
  local now_ms = vim.loop.now()
  local delta = math.max(0, math.floor((now_ms - updated_at_ms) / 1000))
  if delta < 60 then
    return "just now"
  elseif delta < 3600 then
    return string.format("%dm ago", math.floor(delta / 60))
  elseif delta < 86400 then
    return string.format("%dh ago", math.floor(delta / 3600))
  else
    return string.format("%dd ago", math.floor(delta / 86400))
  end
end

function M.format_chat_line(chat)
  local title = chat.title or chat.id
  local rel = M.format_relative_time(chat.updatedAtMs)
  if rel ~= "" then
    return string.format("%s · %s", title, rel)
  end
  return title
end

return M
