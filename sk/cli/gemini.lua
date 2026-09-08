---@param cwd string
---@param limit number
---@return sidekick.cli.session.Info[]
local function discover_sessions(cwd, limit)
  -- Calculate project hash from CWD (SHA256)
  local project_hash = vim.fn.sha256(cwd)
  local chats_dir = vim.fs.normalize("~/.gemini/tmp/" .. project_hash .. "/chats")

  local stat = vim.uv.fs_stat(chats_dir)
  if not stat or stat.type ~= "directory" then
    return {}
  end

  -- Collect session files from the current project
  local file_info = {}
  local handle = vim.uv.fs_scandir(chats_dir)
  if handle then
    while true do
      local name, file_type = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if file_type == "file" and name:match("^session%-.*%.json$") then
        local file_path = chats_dir .. "/" .. name
        local file_stat = vim.uv.fs_stat(file_path)
        if file_stat then
          table.insert(file_info, {
            path = file_path,
            mtime = file_stat.mtime.sec,
          })
        end
      end
    end
  end

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
      local session_stat = vim.uv.fs_fstat(fd)
      if not session_stat then
        vim.uv.fs_close(fd)
        return nil
      end
      local data = vim.uv.fs_read(fd, session_stat.size, 0)
      vim.uv.fs_close(fd)

      if data then
        local ok, session = pcall(vim.json.decode, data)
        if ok and session and session.sessionId and session.messages then
          -- Find first user message for title
          local title = session.sessionId:sub(1, 8) .. "..." -- Fallback to short ID
          for _, msg in ipairs(session.messages) do
            if msg.type == "user" and msg.content then
              title = msg.content:gsub("\n.*", "") -- Use first line only
              if #title > 80 then
                title = title:sub(1, 77) .. "..."
              end
              break
            end
          end

          return {
            id = session.sessionId,
            title = title,
            updated = info.mtime, -- Use file mtime for consistency
            cli_name = "gemini",
            cwd = cwd,
          }
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
  cmd = { "gemini" },
  is_proc = "\\<gemini\\>",
  url = "https://github.com/google-gemini/gemini-cli",
  format = function(text)
    require("sidekick.text").transform(text, function(str)
      return str:gsub("([^%w/_%.%-])", "\\%1")
    end, "SidekickLocFile")
  end,
  resume = { "--resume" },
  discover_sessions = discover_sessions,
}
