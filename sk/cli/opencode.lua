---@class sidekick.cli.session.Opencode: sidekick.cli.Session
---@field port number
---@field pid number
---@field base_url string
local M = {}
M.__index = M
M.priority = 20
M.external = true

function M.sessions()
  local Procs = require("sidekick.cli.procs")
  local Util = require("sidekick.util")

  -- Get listening port for this PID
  -- Get all listening ports with PIDs in one call
  local lines = Util.exec({ "lsof", "-w", "-iTCP", "-sTCP:LISTEN", "-P", "-n", "-Fn", "-Fp" }, { notify = false }) or {}

  -- Parse lsof output to build pid -> port mapping
  local ports = {} ---@type table<number, number>
  local current_pid ---@type number?

  for _, line in ipairs(lines) do
    local pid = line:match("^p(%d+)$")
    if pid then
      current_pid = tonumber(pid)
    else
      local port = line:match("^n.*:(%d+)$")
      if port and current_pid then
        ports[current_pid] = tonumber(port)
      end
    end
  end

  -- Find opencode processes and match with ports
  local ret = {} ---@type sidekick.cli.session.State[]

  for pid, port in pairs(ports) do
    local proc = vim.api.nvim_get_proc(pid)
    if proc and proc.name == "opencode" then
      ret[#ret + 1] = {
        id = "opencode-" .. pid,
        pid = pid,
        tool = "opencode",
        cwd = Procs.cwd(pid) or "",
        port = port,
        pids = Procs.pids(pid),
        mux_session = tostring(pid),
        base_url = ("http://localhost:%d"):format(port),
      }
    end
  end
  return ret
end

function M:attach() end

function M:is_running()
  return self.pid and vim.api.nvim_get_proc(self.pid) ~= nil
end

function M:send(text)
  require("sidekick.util").curl(self.base_url .. "/tui/append-prompt", {
    method = "POST",
    data = { text = text },
  })
end

function M:submit()
  require("sidekick.util").curl(self.base_url .. "/tui/submit-prompt", {
    method = "POST",
    data = {},
  })
end

-- only register on Unix-like systems with lsof available
if vim.fn.has("win32") == 0 and vim.fn.executable("lsof") == 1 then
  require("sidekick.cli.session").register("opencode", M)
end

---@param cwd string
---@param limit number
---@return sidekick.cli.session.Info[]
local function discover_sessions(cwd, limit)
  local storage_base = vim.fn.expand("~/.local/share/opencode/storage")

  if vim.fn.isdirectory(storage_base) == 0 then
    return {}
  end

  -- Find project ID for the current cwd (git-managed projects)
  local project_files = vim.fn.glob(storage_base .. "/project/*.json", false, true)
  local project_id = vim.iter(project_files)
    :map(function(file)
      local content = vim.fn.readfile(file)
      if #content > 0 then
        local ok, project = pcall(vim.fn.json_decode, table.concat(content, "\n"))
        if ok and project and project.id and project.worktree and project.worktree == cwd then
          return project.id
        end
      end
    end)
    :find(function(id)
      return id ~= nil
    end)

  -- Use global as fallback if no git project found
  project_id = project_id or "global"

  -- Collect session files from the project
  local session_dir = storage_base .. "/session/" .. project_id
  if vim.fn.isdirectory(session_dir) == 0 then
    return {}
  end

  local pattern = session_dir .. "/ses_*.json"
  local files = vim.fn.glob(pattern, false, true)

  local file_info = vim.iter(files)
    :map(function(file)
      local stat = vim.loop.fs_stat(file)
      if not stat then
        return nil
      end

      -- For global project, check directory field to match cwd
      if project_id == "global" then
        local content = vim.fn.readfile(file)
        if #content > 0 then
          local ok, meta = pcall(vim.fn.json_decode, table.concat(content, "\n"))
          if ok and meta and meta.directory == cwd then
            return {
              path = file,
              filename = vim.fn.fnamemodify(file, ":t"),
              mtime = stat.mtime.sec,
            }
          end
        end
      else
        -- For git projects, include all sessions
        return {
          path = file,
          filename = vim.fn.fnamemodify(file, ":t"),
          mtime = stat.mtime.sec,
        }
      end
    end)
    :filter(function(info)
      return info ~= nil
    end)
    :totable()

  -- Sort by mtime (descending)
  table.sort(file_info, function(a, b)
    return a.mtime > b.mtime
  end)

  -- Read session files (already filtered by cwd)
  return vim.iter(file_info)
    :take(limit)
    :map(function(info)
      local content = vim.fn.readfile(info.path)
      if #content > 0 then
        local ok, meta = pcall(vim.fn.json_decode, table.concat(content, "\n"))
        if ok and meta and meta.id and meta.title then
          return {
            id = meta.id,
            title = meta.title,
            updated = info.mtime, -- Use file mtime for consistency
            cli_name = "opencode",
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
  cmd = { "opencode" },
  env = {
    OPENCODE_THEME = "system",
  },
  is_proc = "\\<opencode\\>",
  url = "https://github.com/sst/opencode",
  resume = { "-s" },
  continue = { "--continue" },
  discover_sessions = discover_sessions,
  native_scroll = true,
}
