---@param dir string
---@param pattern string
---@param results table
local function find_files_recursive(dir, pattern, results)
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local path = dir .. "/" .. name
    if type == "directory" then
      find_files_recursive(path, pattern, results)
    elseif type == "file" and name:match(pattern) then
      local stat = vim.uv.fs_stat(path)
      if stat then
        table.insert(results, {
          path = path,
          mtime = stat.mtime.sec,
        })
      end
    end
  end
end

---@param cwd string
---@param limit number
---@return sidekick.cli.session.Info[]
local function discover_sessions(cwd, limit)
  local session_dir = vim.fs.normalize("~/.codex/sessions")

  local stat = vim.uv.fs_stat(session_dir)
  if not stat or stat.type ~= "directory" then
    return {}
  end

  -- Find all rollout-*.jsonl files recursively and get mtime for each
  local file_info = {}
  find_files_recursive(session_dir, "^rollout%-.*%.jsonl$", file_info)

  -- Sort by mtime (descending)
  table.sort(file_info, function(a, b)
    return a.mtime > b.mtime
  end)

  -- Read only up to limit files
  return vim
    .iter(file_info)
    :take(limit)
    :map(function(info)
      local fd = vim.uv.fs_open(info.path, "r", 438)
      if not fd then
        return nil
      end
      local first_line_stat = vim.uv.fs_fstat(fd)
      if not first_line_stat then
        vim.uv.fs_close(fd)
        return nil
      end
      -- Read up to 1KB for the first line
      local data = vim.uv.fs_read(fd, math.min(first_line_stat.size, 1024), 0)
      vim.uv.fs_close(fd)

      if data then
        local first_line = data:match("^([^\n]*)")
        if first_line then
          local ok, meta = pcall(vim.json.decode, first_line)
          if ok and meta and meta.type == "session_meta" and meta.payload then
            local payload = meta.payload
            -- Only include sessions for the current cwd
            if payload.cwd == cwd and payload.id then
              return {
                id = payload.id,
                title = payload.id:sub(1, 8) .. "...", -- Use short ID as title
                updated = info.mtime, -- Use file mtime (timestamp is ISO 8601 string)
                cli_name = "codex",
                cwd = cwd,
              }
            end
          end
        end
      end
    end)
    :filter(function(session)
      return session ~= nil
    end)
    :totable()
end

---@type sidekick.cli.Config
return {
  cmd = { "codex", "--enable", "web_search_request" },
  is_proc = "\\<codex\\>",
  url = "https://github.com/openai/codex",
  resume = { "resume" },
  continue = { "resume", "--last" },
  discover_sessions = discover_sessions,
}
