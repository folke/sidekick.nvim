---@class sidekick.cli.session.Opencode: sidekick.cli.Session
---@field port number
---@field pid number
---@field base_url string
local M = {}
M.__index = M
M.priority = 20
M.external = true

local function get_mux_session(pid)
  local Util = require("sidekick.util")
  local env = require("sidekick.cli.procs").env(pid)
  if not env then
    return nil
  end

  local tmux_pane = env["TMUX_PANE"]
  if not tmux_pane then
    return nil
  end

  local lines = Util.exec({
    "tmux", "display-message", "-p", "-t", tmux_pane,
    "#{session_name}:#{window_index}.#{pane_index}"
  }, { notify = false })
  
  if lines and lines[1] then
    -- Strip any trailing newlines or whitespace
    return lines[1]:gsub("%s+$", "")
  end

  return nil
end

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
        mux_session = get_mux_session(pid) or tostring(pid),
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

---@type sidekick.cli.Config
return {
  cmd = { "opencode" },
  env = {
    -- HACK: https://github.com/sst/opencode/issues/445
    OPENCODE_THEME = "system",
  },
  keys = {
    prompt = { "<a-p>", "prompt" },
  },
  is_proc = "\\<opencode\\>",
  url = "https://github.com/sst/opencode",
  continue = { "--continue" },
  native_scroll = true,
}
