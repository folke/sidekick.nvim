---@class sidekick.cli.session.Opencode: sidekick.cli.Session
---@field port number
---@field base_url string
local M = {}
M.__index = M

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

  for _, proc in pairs(Procs:find("opencode")) do
    local port = ports[proc.pid]
    if port then
      ret[#ret + 1] = {
        id = "opencode-" .. proc.pid,
        tool = "opencode",
        cwd = proc.cwd,
        port = port,
        base_url = ("http://localhost:%d"):format(port),
      }
    end
  end
  return ret
end

function M:attach() end

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

require("sidekick.cli.session").register("opencode", M)

---@type sidekick.cli.Config
return {
  cmd = { "opencode" },
  env = {
    OPENCODE_THEME = "system",
  },
  is_proc = "\\<opencode\\>",
  url = "https://github.com/sst/opencode",
}
