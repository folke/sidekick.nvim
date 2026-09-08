local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.WezTerm: sidekick.cli.Session
---@field wezterm_pane_id integer
---@field wezterm_pid integer
local M = {}
M.__index = M

function M:init()
  if self.started then
    self.external = true
  else
    self.external = vim.env.WEZTERM_PANE ~= nil and Config.cli.mux.create ~= "terminal"
    if not self.external then
      self.mux_session = self.sid
    end
  end
  self.priority = self.external and 10 or 50
end

---Parse a WezTerm file URI ("file://hostname/path") into an absolute path.
---@param uri string?
---@return string?
function M.cwd_from_uri(uri)
  if not uri then
    return nil
  end
  local path = uri:match("^file://[^/]*(/.*)$")
  return path and vim.fs.normalize(path) or uri
end

---Return the workspace name for the current WezTerm pane (via WEZTERM_PANE).
---@return string?
function M.current_workspace()
  local pane_id = vim.env.WEZTERM_PANE
  if not pane_id then
    return nil
  end
  local _, output = Util.exec({ "wezterm", "cli", "list", "--format", "json" }, { notify = false })
  if not output then
    return nil
  end
  local ok, panes = pcall(vim.json.decode, output)
  if not ok or type(panes) ~= "table" then
    return nil
  end
  local id = tonumber(pane_id)
  for _, pane in ipairs(panes) do
    if pane.pane_id == id then
      return pane.workspace
    end
  end
  return nil
end

---Find the root (shell) PID for a TTY by looking for the process whose
---parent is not itself on that TTY.
---@param tty string full path like "/dev/ttys001"
---@return integer?
function M.root_pid(tty)
  local tty_short = tty:match("[^/]+$")
  if not tty_short then
    return nil
  end
  local lines = Util.exec({ "ps", "-t", tty_short, "-o", "pid=,ppid=" }, { notify = false })
  if not lines or #lines == 0 then
    return nil
  end
  local pids = {} ---@type table<integer, integer> pid -> ppid
  for _, line in ipairs(lines) do
    local pid, ppid = line:match("^%s*(%d+)%s+(%d+)")
    if pid then
      pids[tonumber(pid)] = tonumber(ppid)
    end
  end
  for pid, ppid in pairs(pids) do
    if not pids[ppid] then
      return pid
    end
  end
  return (next(pids))
end

---Append env vars (via `env KEY=VAL`) and the tool command to cmd.
---WezTerm CLI has no -e flag, so we prepend `env` when needed.
---Entries with value==false are skipped (no unset support in wezterm CLI).
---@param cmd string[]
function M:add_cmd(cmd)
  local has_env = false
  for key, value in pairs(self.tool.env or {}) do
    if value ~= false then
      if not has_env then
        cmd[#cmd + 1] = "env"
        has_env = true
      end
      cmd[#cmd + 1] = ("%s=%s"):format(key, tostring(value))
    end
  end
  vim.list_extend(cmd, self.tool.cmd)
end

---Run a wezterm CLI command and update session state with the returned pane ID.
---@param cmd string[]
function M:spawn(cmd)
  local lines = Util.exec(cmd, { notify = true })
  if not lines or #lines == 0 then
    return
  end
  local pane_id = tonumber(lines[1]:match("^(%d+)"))
  if pane_id then
    self.id = "wezterm: " .. pane_id
    self.wezterm_pane_id = pane_id
    self.mux_session = tostring(pane_id)
    self.started = true
  end
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  if not self.external then
    return { cmd = self.tool.cmd, env = self.tool.env }
  elseif Config.cli.mux.create == "window" then
    local cmd = { "wezterm", "cli", "spawn", "--new-window", "--cwd", self.cwd }
    local workspace = M.current_workspace()
    if workspace then
      vim.list_extend(cmd, { "--workspace", workspace })
    end
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new WezTerm window"):format(self.tool.name))
  elseif Config.cli.mux.create == "tab" then
    local cmd = { "wezterm", "cli", "spawn", "--cwd", self.cwd }
    local pane_id = vim.env.WEZTERM_PANE
    if pane_id then
      vim.list_extend(cmd, { "--pane-id", pane_id })
    end
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new WezTerm tab"):format(self.tool.name))
  elseif Config.cli.mux.create == "split" then
    local cmd = { "wezterm", "cli", "split-pane", "--cwd", self.cwd }
    cmd[#cmd + 1] = Config.cli.mux.split.vertical and "--right" or "--bottom"
    local size = Config.cli.mux.split.size
    vim.list_extend(cmd, { "--percent", tostring(math.floor(size <= 1 and size * 100 or size)) })
    cmd[#cmd + 1] = "--"
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new WezTerm split"):format(self.tool.name))
  end
end

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if not self.external then
    return { cmd = self.tool.cmd, env = self.tool.env }
  end
  if self.wezterm_pane_id then
    Util.exec(
      { "wezterm", "cli", "activate-pane", "--pane-id", tostring(self.wezterm_pane_id) },
      { notify = false }
    )
  end
end

function M:send(text)
  Util.exec({
    "wezterm", "cli", "send-text",
    "--pane-id", tostring(self.wezterm_pane_id),
    "--no-paste",
  }, { stdin = text, notify = false })
end

function M:submit()
  Util.exec({
    "wezterm", "cli", "send-text",
    "--pane-id", tostring(self.wezterm_pane_id),
    "--no-paste",
    "\r",
  }, { notify = false })
end

function M:is_running()
  if self.wezterm_pid then
    return vim.api.nvim_get_proc(self.wezterm_pid) ~= nil
  end
  return self.wezterm_pane_id ~= nil
end

function M.sessions()
  local _, output = Util.exec({ "wezterm", "cli", "list", "--format", "json" }, { notify = false })
  if not output then
    return {}
  end
  local ok, panes = pcall(vim.json.decode, output)
  if not ok or type(panes) ~= "table" then
    return {}
  end

  local tools = Config.tools()
  local Procs = require("sidekick.cli.procs")
  local procs = Procs.new()
  local ret = {} ---@type sidekick.cli.session.State[]

  for _, pane in ipairs(panes) do
    if pane.tty_name then
      local pid = M.root_pid(pane.tty_name)
      if pid then
        procs:walk(pid, function(proc)
          for _, tool in pairs(tools) do
            if tool:is_proc(proc) then
              ret[#ret + 1] = {
                id = "wezterm: " .. pane.pane_id,
                cwd = proc.cwd or M.cwd_from_uri(pane.cwd),
                tool = tool,
                wezterm_pane_id = pane.pane_id,
                wezterm_pid = pid,
                mux_session = tostring(pane.pane_id),
                pids = Procs.pids(pid),
              }
              return true
            end
          end
        end)
      end
    end
  end

  return ret
end

function M:dump()
  if not self.wezterm_pane_id then
    return nil
  end
  local _, ret = Util.exec({
    "wezterm", "cli", "get-text",
    "--pane-id", tostring(self.wezterm_pane_id),
    "--start-line", tostring(-Config.cli.mux.dump),
    "--escapes",
  }, { notify = false })
  return ret
end

return M
