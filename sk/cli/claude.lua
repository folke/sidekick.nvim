---@param cwd string
---@return string
local function cwd_to_project(cwd)
  -- Convert /home/user/ghq/github.com/owner/repo -> -home-user-ghq-github-com-owner-repo
  -- Claude replaces all non-alphanumeric characters (except -) with -
  -- Example: test-path_with.symbols+chars@123[test](foo)~bar,baz%qux{}
  --       -> -test-path-with-symbols-chars-123-test--foo--bar-baz-qux--
  return "-" .. cwd:gsub("^/", ""):gsub("[^%w%-]", "-")
end

---@param cwd string
---@param limit number
---@return sidekick.cli.session.Info[]
local function discover_sessions(cwd, limit)
  local sessions = {}
  local project = cwd_to_project(cwd)
  local session_dir = vim.fn.expand("~/.claude/projects/" .. project)

  if vim.fn.isdirectory(session_dir) == 0 then
    return {}
  end

  -- Find all .jsonl files (exclude agent-* files) and sort by mtime
  local pattern = session_dir .. "/*.jsonl"
  local files = vim.fn.glob(pattern, false, true)

  -- Filter out agent files and get mtime for each
  local file_info = {}
  for _, file in ipairs(files) do
    local filename = vim.fn.fnamemodify(file, ":t")
    if not filename:match("^agent%-") then
      local stat = vim.loop.fs_stat(file)
      if stat then
        table.insert(file_info, {
          path = file,
          filename = filename,
          mtime = stat.mtime.sec,
        })
      end
    end
  end

  -- Sort by mtime (descending)
  table.sort(file_info, function(a, b)
    return a.mtime > b.mtime
  end)

  -- Read only up to limit files
  for i = 1, math.min(#file_info, limit) do
    local info = file_info[i]
    -- Read first line only
    local lines = vim.fn.readfile(info.path, "", 1)
    if #lines > 0 then
      local ok, meta = pcall(vim.fn.json_decode, lines[1])
      if ok and meta and meta.type == "summary" then
        -- Extract session ID from filename (UUID)
        local session_id = info.filename:match("^(.+)%.jsonl$")
        if session_id then
          table.insert(sessions, {
            id = session_id,
            title = meta.summary,
            updated = info.mtime,
            cli_name = "claude",
            cwd = cwd,
          })
        end
      end
    end
  end

  return sessions
end

---@type sidekick.cli.Config
return {
  cmd = { "claude" },
  is_proc = "\\<claude\\>",
  url = "https://github.com/anthropics/claude-code",
  resume = { "--resume" },
  continue = { "--continue" },
  discover_sessions = discover_sessions,
  format = function(text)
    local Text = require("sidekick.text")

    Text.transform(text, function(str)
      return str:find("[^%w/_%.%-]") and ('"' .. str .. '"') or str
    end, "SidekickLocFile")

    local ret = Text.to_string(text)

    -- transform line ranges to a format that Claude understands
    ret = ret:gsub("@([^@]-) :L(%d+)%-L(%d+)", "@%1#L%2-%3")

    return ret
  end,
}
