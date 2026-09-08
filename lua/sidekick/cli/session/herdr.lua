local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Herdr: sidekick.cli.Session
---@field external? boolean running in an existing Herdr session instead of an embedded terminal
---@field herdr_pane_id? string Herdr pane id used for pane commands
---@field herdr_terminal_id? string Herdr terminal id used for terminal attach and stable session identity
---@field herdr_current? boolean Use the inherited Herdr socket/session environment instead of --session
local M = {}
M.__index = M

local DEFAULT_SESSION = "default"

---@class sidekick.herdr.Pane
---@field skid string unique id for the pane
---@field id string Herdr pane id
---@field terminal_id? string Herdr terminal id
---@field workspace_id? string Herdr workspace id
---@field tab_id? string Herdr tab id
---@field cwd? string pane cwd
---@field agent? string detected/reported agent label
---@field mux_session? string Herdr session name
---@field herdr_current? boolean use inherited Herdr socket/session environment

--- Convert a Sidekick session id into a Herdr-safe session name.
---@param name string
---@return string
function M.session_name(name)
  name = name:gsub("[^%w._-]", "-")
  if #name > 64 then
    name = name:sub(1, 64)
  end
  return name
end

--- Build a Herdr CLI command, optionally targeting a named session.
---@param session? string
---@param args string[]
---@param current? boolean
---@return string[]
function M.cmd(session, args, current)
  local ret = { "herdr" }
  if session and not current then
    vim.list_extend(ret, { "--session", session })
  end
  vim.list_extend(ret, args)
  return ret
end

--- Execute a Herdr CLI command and decode its JSON response.
---@param cmd string[]
---@param opts? {notify?:boolean}
---@return table?
function M.json(cmd, opts)
  local lines = Util.exec(cmd, opts)

  if not lines then
    return nil
  end

  -- Some successful commands, including `pane run`, do not return a payload.
  if #lines == 0 then
    return {}
  end

  local ok, ret = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(ret) ~= "table" then
    if not opts or opts.notify ~= false then
      Util.error(("Failed to parse Herdr response: `%s`"):format(table.concat(cmd, " ")))
    end
    return nil
  end

  return ret
end

--- Build a Herdr command for this session.
---@param args string[]
---@return string[]
function M:herdr(args)
  return M.cmd(self.mux_session, args, self.herdr_current)
end

--- Check whether the Herdr server for a session is running.
---@param session? string
---@return boolean
function M.server_running(session)
  local ret = M.json(M.cmd(session, { "status", "server", "--json" }), { notify = false })
  return ret and ret.running == true or false
end

--- Start the Herdr server for a session if needed.
---@param session? string
---@return boolean
function M.ensure_server(session)
  if M.server_running(session) then
    return true
  end
  local cmd = M.cmd(session, { "server" })
  local job = vim.fn.jobstart(cmd, { detach = true })
  if job <= 0 then
    Util.error(("Failed to start Herdr server: `%s`"):format(table.concat(cmd, " ")))
    return false
  end
  if vim.wait(3000, function()
    return M.server_running(session)
  end, 50) then
    return true
  end
  Util.error(("Timed out waiting for Herdr server: `%s`"):format(table.concat(cmd, " ")))
  return false
end

--- Convert argv into a shell-escaped command string for `pane run`.
---@param cmd string[]
---@return string
function M.shell_cmd(cmd)
  return table.concat(
    vim.tbl_map(function(arg)
      return vim.fn.shellescape(arg)
    end, cmd),
    " "
  )
end

--- Build a command that replaces the pane shell with the tool process.
---@param cmd string[]
---@return string
function M.exec_cmd(cmd)
  return "exec " .. M.shell_cmd(cmd)
end

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if not self.external and self.herdr_terminal_id then
    return { cmd = self:herdr({ "terminal", "attach", self.herdr_terminal_id }) }
  end
end

function M:init()
  if self.started then
    self.external = M.session_name(self.sid) ~= self.mux_session
  else
    self.external = vim.env.HERDR_ENV == "1" and Config.cli.mux.create ~= "terminal"
    self.herdr_current = self.external
    self.mux_session = self.external and (vim.env.HERDR_SESSION or DEFAULT_SESSION) or M.session_name(self.sid)
  end
  self.priority = self.external and 10 or 50
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  local pane
  if not self.external then
    if not M.ensure_server(self.mux_session) then
      return
    end
    pane = self:create_workspace_pane()
  elseif Config.cli.mux.create == "window" then
    pane = self:create_tab_pane()
  elseif Config.cli.mux.create == "split" then
    pane = self:create_split_pane(Config.cli.mux.split.vertical and "right" or "down")
  end

  if not pane or not self:launch_pane(pane) then
    return
  end

  if not self.external then
    return { cmd = self:herdr({ "terminal", "attach", self.herdr_terminal_id }) }
  elseif Config.cli.mux.create == "window" then
    Util.info(("Started **%s** in a new Herdr tab"):format(self.tool.name))
  elseif Config.cli.mux.create == "split" then
    Util.info(("Started **%s** in a new Herdr split"):format(self.tool.name))
  end
end

--- Update this session from a Herdr pane/agent response.
---@param pane table
function M:update_pane(pane)
  self.herdr_pane_id = pane.pane_id or pane.id
  self.herdr_terminal_id = pane.terminal_id
  self.mux_session = self.mux_session or pane.session or DEFAULT_SESSION
  self.id = self.herdr_terminal_id and ("herdr %s"):format(self.herdr_terminal_id) or self.id
  self.cwd = pane.foreground_cwd or pane.cwd or self.cwd
  self.started = true
end

--- Create the root pane for a dedicated Herdr workspace.
---@return table?
function M:create_workspace_pane()
  local cmd = self:herdr({ "workspace", "create", "--cwd", self.cwd, "--label", self.sid, "--no-focus" })
  self:add_env(cmd)
  local ret = M.json(cmd, { notify = true })
  return ret and ret.result and ret.result.root_pane
end

--- Create the root pane of a new Herdr tab.
---@return table?
function M:create_tab_pane()
  local cmd = self:herdr({ "tab", "create" })
  if vim.env.HERDR_WORKSPACE_ID then
    vim.list_extend(cmd, { "--workspace", vim.env.HERDR_WORKSPACE_ID })
  end
  vim.list_extend(cmd, { "--cwd", self.cwd, "--label", self.sid, "--no-focus" })
  self:add_env(cmd)
  local ret = M.json(cmd, { notify = true })
  return ret and ret.result and ret.result.root_pane
end

--- Create a split of the pane containing Neovim.
---@param direction "right"|"down"
---@return table?
function M:create_split_pane(direction)
  local cmd = self:herdr({
    "pane",
    "split",
    "--current",
    "--direction",
    direction,
    "--cwd",
    self.cwd,
    "--no-focus",
  })
  local size = Config.cli.mux.split.size
  if size > 0 and size <= 1 then
    vim.list_extend(cmd, { "--ratio", tostring(1 - size) })
  end
  self:add_env(cmd)
  local ret = M.json(cmd, { notify = true })
  return ret and ret.result and ret.result.pane
end

--- Replace a newly-created pane's shell with the configured tool process.
---@param pane table
---@return boolean
function M:launch_pane(pane)
  local pane_id = pane.pane_id or pane.id
  if not pane_id then
    Util.error("Herdr did not return a pane id")
    return false
  end

  local ret = M.json(self:herdr({ "pane", "run", pane_id, M.exec_cmd(self.tool.cmd) }), { notify = true })
  if not ret then
    -- The pane belongs to this launch attempt, so do not leave its idle shell behind.
    M.json(self:herdr({ "pane", "close", pane_id }), { notify = false })
    return false
  end

  self:update_pane(pane)
  return true
end

function M:is_running()
  return self:pane() ~= nil
end

--- Add environment variables to a Herdr command.
---@param ret string[]
function M:add_env(ret)
  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      -- Herdr's CLI supports setting env vars for new panes/agents, but not unsetting them.
    else
      vim.list_extend(ret, { "--env", ("%s=%s"):format(key, tostring(value)) })
    end
  end
end

--- List all panes in the Herdr session with their command and cwd.
---@param opts? {session?:string,current?:boolean,notify?:boolean}
function M.panes(opts)
  opts = opts or {}
  local ret = M.json(M.cmd(opts.session, { "pane", "list" }, opts.current), { notify = opts.notify == true })
  local panes = {} ---@type sidekick.herdr.Pane[]
  for _, pane in ipairs(ret and ret.result and ret.result.panes or {}) do
    panes[#panes + 1] = {
      skid = ("herdr %s"):format(pane.terminal_id or pane.pane_id), -- unique id for the pane
      id = pane.pane_id, -- Herdr pane id
      terminal_id = pane.terminal_id, -- Herdr terminal id
      workspace_id = pane.workspace_id,
      tab_id = pane.tab_id,
      cwd = pane.foreground_cwd or pane.cwd,
      agent = pane.agent or (pane.agent_session and pane.agent_session.agent),
      mux_session = opts.session or (opts.current and (vim.env.HERDR_SESSION or DEFAULT_SESSION) or nil),
      herdr_current = opts.current,
    }
  end
  return panes
end

--- Get process info for a Herdr pane.
---@param opts? {session?:string,current?:boolean}
---@param pane_id string
---@return table?
function M.process_info(opts, pane_id)
  opts = opts or {}
  local ret =
    M.json(M.cmd(opts.session, { "pane", "process-info", "--pane", pane_id }, opts.current), { notify = false })
  return ret and ret.result and ret.result.process_info
end

--- List all Herdr sessions and whether they are the current session.
---@return {session?:string,current?:boolean}[]
function M.sources()
  local ret = {} ---@type {session?:string,current?:boolean}[]
  local seen = {} ---@type table<string,boolean>

  local function add(source)
    local key = source.session or (source.current and (vim.env.HERDR_SESSION or DEFAULT_SESSION) or DEFAULT_SESSION)
    if not seen[key] then
      seen[key] = true
      ret[#ret + 1] = source
    end
  end

  if vim.env.HERDR_ENV == "1" or vim.env.HERDR_SOCKET_PATH then
    add({ current = true, session = vim.env.HERDR_SESSION or DEFAULT_SESSION })
  end

  local sessions = M.json({ "herdr", "session", "list", "--json" }, { notify = false })
  for _, session in ipairs(sessions and sessions.sessions or {}) do
    if session.running then
      add({ session = session.name or DEFAULT_SESSION })
    end
  end
  return ret
end

--- List all Sidekick sessions that are running in Herdr panes.
function M.sessions()
  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()

  for _, source in ipairs(M.sources()) do
    for _, pane in ipairs(M.panes(source)) do
      local info = M.process_info(source, pane.id)
      local pids = {} ---@type integer[]
      local pid_seen = {} ---@type table<integer,boolean>
      local function add_pid(pid)
        if pid and not pid_seen[pid] then
          pids[#pids + 1] = pid
          pid_seen[pid] = true
        end
      end

      add_pid(info and info.shell_pid)
      local matched = false
      for _, proc in ipairs(info and info.foreground_processes or {}) do
        add_pid(proc.pid)
        local cmd = proc.cmdline or (proc.argv and table.concat(proc.argv, " ")) or proc.argv0 or proc.name or ""
        ---@type sidekick.cli.Proc
        local p = {
          pid = proc.pid,
          ppid = info and info.shell_pid or 0,
          cmd = cmd,
          cwd = proc.cwd or pane.cwd,
        }
        for _, tool in pairs(tools) do
          if tool:is_proc(p) then
            ret[#ret + 1] = {
              id = pane.skid,
              cwd = p.cwd or pane.cwd or vim.fn.getcwd(0),
              tool = tool,
              herdr_pane_id = pane.id,
              herdr_terminal_id = pane.terminal_id,
              herdr_current = pane.herdr_current,
              mux_session = pane.mux_session,
              pids = pids,
            }
            matched = true
            break
          end
        end
        if matched then
          break
        end
      end
    end
  end

  return ret
end

--- Get the Herdr pane for this session, if it exists.
---@return sidekick.herdr.Pane?
function M:pane()
  for _, pane in ipairs(M.panes({ session = self.mux_session, current = self.herdr_current })) do
    if
      (self.herdr_terminal_id and pane.terminal_id == self.herdr_terminal_id)
      or (not self.herdr_terminal_id and self.herdr_pane_id and pane.id == self.herdr_pane_id)
    then
      self.herdr_pane_id = pane.id
      self.herdr_terminal_id = pane.terminal_id or self.herdr_terminal_id
      return pane
    end
  end
end

---@return string?
function M:pane_id()
  local pane = self:pane()
  return pane and pane.id
end

---Send text to a Herdr pane
function M:send(text)
  local pane_id = self:pane_id()
  if not pane_id then
    return
  end

  local function send()
    Util.exec(self:herdr({ "pane", "send-text", pane_id, text }))
  end

  if self.tool.mux_focus then
    -- Send focus-in event first (some TUI apps like qwen ignore input when unfocused)
    Util.exec(self:herdr({ "pane", "send-keys", pane_id, "Escape", "[", "I" }))
    vim.defer_fn(send, 50) -- slight delay to ensure focus event is processed first
  else
    send()
  end
end

---Send text to a Herdr pane
function M:submit()
  local pane_id = self:pane_id()
  if pane_id then
    Util.exec(self:herdr({ "pane", "send-keys", pane_id, "Enter" }))
  end
end

function M:dump()
  local pane_id = self:pane_id()
  if not pane_id then
    return
  end
  local _, ret = Util.exec(self:herdr({
    "pane",
    "read",
    pane_id,
    "--source",
    "recent",
    "--lines",
    tostring(Config.cli.mux.dump),
    "--ansi",
  }))
  return ret
end

return M
