local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Tmux: sidekick.cli.Session
---@field tmux_pane_id string
local M = {}
M.__index = M

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if self.started then
    if self.sid == self.mux_session then
      return { cmd = { "tmux", "attach-session", "-t", self.sid } }
    end
    return -- nothing to do
  end

  if Config.cli.mux.create == "terminal" or vim.env.TMUX == nil then
    local cmd = { "tmux", "new", "-A", "-s", self.id }
    vim.list_extend(cmd, { "-c", self.cwd })
    self:add_cmd(cmd)
    vim.list_extend(cmd, { ";", "set-option", "status", "off" })
    vim.list_extend(cmd, { ";", "set-option", "detach-on-destroy", "on" })
    return { cmd = cmd }
  elseif Config.cli.mux.create == "window" then
    local cmd = { "tmux", "new-window", "-dP", "-c", self.cwd, "-F", "#{pane_pid}" }
    self:add_cmd(cmd)
    local lines = Util.exec(cmd)
    if lines and lines[1] then
      self.id = "tmux " .. lines[1]
    end
  elseif Config.cli.mux.create == "split" then
    local cmd = { "tmux", "split-window", "-dP", "-c", self.cwd, "-F", "#{pane_pid}" }
    cmd[#cmd + 1] = Config.cli.mux.split.vertical and "-h" or "-v"
    local size = Config.cli.mux.split.size
    vim.list_extend(cmd, { "-l", tostring(size <= 1 and ((size * 100) .. "%") or size) })
    self:add_cmd(cmd)
    local lines = Util.exec(cmd)
    if lines and lines[1] then
      self.id = "tmux " .. lines[1]
    end
  end
end

---@param ret string[]
function M:add_cmd(ret)
  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      vim.list_extend(ret, { "-u", key }) -- unset
    else
      vim.list_extend(ret, { "-e", ("%s=%s"):format(key, tostring(value)) })
    end
  end
  vim.list_extend(ret, self.tool.cmd)
end

function M.panes()
  -- List all panes in current session with their command and cwd
  ---@type string[]?
  local lines = Util.exec({
    "tmux",
    "list-panes",
    "-a",
    "-F",
    "#{pane_id}:#{pane_pid}:#{session_name}:#{?pane_current_path,#{pane_current_path},#{pane_start_path}}",
  }, { notify = false })

  local panes = {} ---@type sidekick.tmux.Pane[]
  for _, line in ipairs(lines or {}) do
    local id, pid, session_name, cwd = line:match("^(%%%d+):(%d+):(.-):(.*)$")
    if id and pid and session_name and cwd then
      local p = assert(tonumber(pid), "invalid tmux pane_pid: " .. pid)
      ---@class sidekick.tmux.Pane
      panes[#panes + 1] = {
        id = id,
        pid = p,
        session_name = session_name,
        cwd = cwd,
      }
    end
  end
  return panes
end

function M.sessions()
  local panes = M.panes()
  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()

  local procs = require("sidekick.cli.procs")
  for _, pane in ipairs(panes) do
    procs:walk(pane.pid, function(proc)
      for _, tool in pairs(tools) do
        if tool:is_proc(proc) then
          ret[#ret + 1] = {
            id = ("tmux %s"):format(pane.pid),
            cwd = proc.cwd or pane.cwd,
            tool = tool,
            tmux_pane_id = pane.id,
            mux_session = pane.session_name,
          }
          return true
        end
      end
    end)
  end

  return ret
end

---Send text to a tmux pane
function M:send(text)
  Util.exec({ "tmux", "set-buffer", "-b", "sidekick", text })
  Util.exec({ "tmux", "paste-buffer", "-b", "sidekick", "-d", "-t", self.tmux_pane_id })
end

---Send text to a tmux pane
function M:submit()
  Util.exec({ "tmux", "send-keys", "-t", self.tmux_pane_id, "Enter" })
end

return M
