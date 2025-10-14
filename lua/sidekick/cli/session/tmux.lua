local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Tmux: sidekick.cli.Session
---@field tmux_pane_id string
---@field tmux_pid number
local M = {}
M.__index = M

local PANE_FORMAT =
  "#{session_id}:#{pane_id}:#{pane_pid}:#{session_name}:#{?pane_current_path,#{pane_current_path},#{pane_start_path}}"

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if self.sid == self.mux_session then
    return { cmd = { M.binary(), "attach-session", "-t", self.sid } }
  end
end

function M:init()
  if self.started then
    self.external = self.sid ~= self.mux_session
  else
    self.external = vim.env.TMUX and Config.cli.mux.create ~= "terminal"
    self.mux_session = self.sid
  end
  self.priority = self.external and 10 or 50
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  if not self.external then
    local cmd = { M.binary(), "new", "-A", "-s", self.id }
    vim.list_extend(cmd, { "-c", self.cwd })
    self:add_cmd(cmd)
    vim.list_extend(cmd, { ";", "set-option", "status", "off" })
    vim.list_extend(cmd, { ";", "set-option", "detach-on-destroy", "on" })
    return { cmd = cmd }
  elseif Config.cli.mux.create == "window" then
    local cmd = { M.binary(), "new-window", "-dP", "-c", self.cwd, "-F", PANE_FORMAT }
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new tmux window"):format(self.tool.name))
  elseif Config.cli.mux.create == "split" then
    local cmd = { M.binary(), "split-window", "-dP", "-c", self.cwd, "-F", PANE_FORMAT }
    cmd[#cmd + 1] = Config.cli.mux.split.vertical and "-h" or "-v"
    local size = Config.cli.mux.split.size
    vim.list_extend(cmd, { "-l", tostring(size <= 1 and ((size * 100) .. "%") or size) })
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new tmux split"):format(self.tool.name))
  end
end

--- Execute the given tmux command and update the session info,
--- based on the first pane returned.
---@param cmd string[]
function M:spawn(cmd)
  local pane = M.panes({ cmd = cmd, notify = true })[1]
  if pane then
    self.id = pane.skid
    self.tmux_pane_id = pane.id
    self.mux_session = pane.session_name
    self.tmux_pid = pane.pid
    self.started = true
  end
end

function M:is_running()
  return self.tmux_pid and vim.api.nvim_get_proc(self.tmux_pid) ~= nil
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

---@param opts? { cmd?:string[], notify?:boolean }
function M.panes(opts)
  opts = opts or {}
  -- List all panes in current session with their command and cwd
  local cmd = opts.cmd or { M.binary(), "list-panes", "-a", "-F", PANE_FORMAT }
  local lines = Util.exec(cmd, { notify = opts.notify == true })
  local panes = {} ---@type sidekick.tmux.Pane[]
  for _, line in ipairs(lines or {}) do
    local session_id, id, pid, session_name, cwd = line:match("^(%$%d+):(%%%d+):(%d+):(.-):(.*)$")
    if id and pid and session_name and cwd then
      pid = assert(tonumber(pid), "invalid tmux pane_pid: " .. pid) --[[@as number]]
      ---@class sidekick.tmux.Pane
      panes[#panes + 1] = {
        skid = ("tmux %s"):format(pid), -- unique id for the pane
        pid = pid, -- process id of the pane
        id = id, -- tmux pane id
        session_name = session_name,
        session_id = session_id,
        cwd = cwd,
      }
    end
  end
  return panes
end

function M.clients()
  local lines = Util.exec({ M.binary(), "list-clients", "-F", "#{session_id}:#{client_pid}" }, { notify = false })
  local ret = {} ---@type table<string, integer>[]
  for _, line in ipairs(lines or {}) do
    local session_id, pid = line:match("^(%$%d+):(%d+)$")
    if session_id and pid then
      pid = assert(tonumber(pid), "invalid tmux client_pid: " .. pid) --[[@as number]]
      ret[session_id] = ret[session_id] or {}
      table.insert(ret[session_id], pid)
    end
  end
  return ret
end

function M.sessions()
  local panes = M.panes()
  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()

  local clients = M.clients()

  local Procs = require("sidekick.cli.procs")
  local procs = Procs.new()
  for _, pane in ipairs(panes) do
    procs:walk(pane.pid, function(proc)
      for _, tool in pairs(tools) do
        if tool:is_proc(proc) then
          local pids = Procs.pids(pane.pid)
          vim.list_extend(pids, clients[pane.session_id] or {})
          ret[#ret + 1] = {
            id = pane.skid,
            cwd = proc.cwd or pane.cwd,
            tool = tool,
            tmux_pane_id = pane.id,
            tmux_pid = pane.pid,
            mux_session = pane.session_name,
            pids = pids,
          }
          return true
        end
      end
    end)
  end

  return ret
end

function M:pane_id()
  if self.tmux_pane_id then
    return self.tmux_pane_id
  end
  if not self.external then
    self:spawn({
      M.binary(),
      "list-panes",
      "-s",
      "-F",
      PANE_FORMAT,
      "-t",
      self.mux_session,
    })
  end
  return self.tmux_pane_id
end

---Send text to a tmux pane
function M:send(text)
  local function send()
    local buffer = "sidekick-" .. self.tmux_pane_id
    Util.exec({ M.binary(), "load-buffer", "-b", buffer, "-" }, { stdin = text })
    Util.exec({
      M.binary(),
      "paste-buffer",
      "-b",
      buffer,
      "-d",
      "-r",
      "-t",
      self.tmux_pane_id,
    })
  end

  if self.tool.mux_focus then
    -- Send focus-in event first (some TUI apps like qwen ignore input when unfocused)
    Util.exec({
      M.binary(),
      "send-keys",
      "-t",
      self.tmux_pane_id,
      "Escape",
      "[",
      "I",
    })
    vim.defer_fn(send, 50) -- slight delay to ensure focus event is processed first
  else
    send()
  end
end

---Send text to a tmux pane
function M:submit()
  Util.exec({ M.binary(), "send-keys", "-t", self.tmux_pane_id, "Enter" })
end

function M:dump()
  local pane_id = self:pane_id()
  if not pane_id then
    return
  end
  local _, ret = Util.exec({
    M.binary(),
    "capture-pane",
    "-p",
    "-t",
    pane_id,
    "-S",
    "-",
    "-E",
    "-",
    "-e",
  })
  return ret
end

function M.binary()
  return Config.cli.mux.binary or "tmux"
end

return M
