local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Zellij: sidekick.cli.Session
---@field zellij_pane_id? string
---@field zellij_pid? number
---@field zellij string
local M = {}
M.__index = M
M.priority = 50
M.external = false

local MIN_VERSION = "0.44.0" -- `list-panes`, returned pane ids and `--pane-id`

---@param pane_id string
local function skid(pane_id)
  return ("zellij %s"):format(pane_id)
end

-- editors match tools by their arguments, e.g. `nvim ~/.claude/settings.json`
---@param proc sidekick.cli.Proc
local function is_editor(proc)
  local exe = vim.fs.basename(proc.cmd:match("^%S+") or "")
  return exe == "nvim" or exe == "vim"
end

--- Whether zellij supports splits and tabs
function M.supported()
  if M._supported == nil then
    local lines = Util.exec({ "zellij", "--version" }, { notify = false })
    local version = lines and lines[1] and lines[1]:match("(%d+%.%d+%.%d+)")
    M._supported = version ~= nil and vim.version.ge(version, MIN_VERSION)
  end
  return M._supported
end

function M:init()
  if self.started then
    self.external = self.zellij_pane_id ~= nil
  else
    self.external = vim.env.ZELLIJ ~= nil and Config.cli.mux.create ~= "terminal" and M.supported()
  end
  self.priority = self.external and 10 or 50
end

M.tpl = [[
layout {
    pane command="{cmd}" {
      borderless true
      focus true
      name "{name}"
      close_on_exit true
      {args}
   }
}
session_serialization false
]]

---@return sidekick.cli.terminal.Cmd?
function M:terminal()
  local layout = M.tpl
  layout = layout:gsub("{cmd}", self.tool.cmd[1])
  layout = layout:gsub("{name}", self.tool.name)
  if #self.tool.cmd == 1 then
    layout = layout:gsub("{args}", "")
  else
    local args = vim.list_slice(self.tool.cmd, 2)
    layout = layout:gsub("{args}", "args " .. table.concat(
      vim.tbl_map(function(a)
        return ("%q"):format(a)
      end, args),
      " "
    )) --[[@as string]]
  end

  local session = self.sid

  local layout_file = Config.state("zellij-layout-" .. session .. ".kdl")
  vim.fn.writefile(vim.split(layout, "\n"), layout_file)
  Util.set_state(session, { tool = self.tool.name, cwd = self.cwd })

  return {
    cmd = { "zellij", "--layout", layout_file, "attach", "--create", session },
    env = {
      ZELLIJ = false,
      ZELLIJ_SESSION_NAME = false,
      ZELLIJ_PANE_ID = false,
    },
  }
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  if not self.external then
    if vim.env.ZELLIJ and Config.cli.mux.create ~= "terminal" then
      Util.warn({
        ("`opts.cli.mux.create = %q` requires zellij >= %s."):format(Config.cli.mux.create, MIN_VERSION),
        ("Falling back to `%q`."):format("terminal"),
      })
    end
    return self:terminal()
  elseif Config.cli.mux.create == "window" then
    local cmd = { "zellij", "action", "new-tab", "--name", self.tool.name, "--cwd", self.cwd }
    self:add_cmd(cmd)
    self:spawn(cmd)
  elseif Config.cli.mux.create == "split" then
    local cmd = { "zellij", "action", "new-pane", "--name", self.tool.name, "--cwd", self.cwd }
    -- zellij has no size option for new panes
    vim.list_extend(cmd, { "--direction", Config.cli.mux.split.vertical and "right" or "down" })
    self:add_cmd(cmd)
    self:spawn(cmd)
  end
end

--- Execute the given zellij command and update the session info,
--- based on the pane it created.
---@param cmd string[]
function M:spawn(cmd)
  local lines = Util.exec(cmd, { notify = true })
  local id = lines and lines[1]
  if not id then
    return
  end
  -- `new-pane` returns the pane id, `new-tab` the tab id
  for _, pane in ipairs(M.panes()) do
    if pane.id == id or (pane.tab_id == tonumber(id) and pane.cmd) then
      self.id = pane.skid
      self.zellij_pane_id = pane.id
      self.mux_session = vim.env.ZELLIJ_SESSION_NAME
      self.started = true
      return
    end
  end
end

---@param ret string[]
function M:add_cmd(ret)
  vim.list_extend(ret, { "--close-on-exit", "--no-focus", "--" })
  -- panes inherit the environment of the zellij server
  local unset, set = {}, {} ---@type string[], string[]
  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      vim.list_extend(unset, { "-u", key })
    else
      set[#set + 1] = ("%s=%s"):format(key, tostring(value))
    end
  end
  if #unset > 0 or #set > 0 then
    ret[#ret + 1] = "env"
    vim.list_extend(ret, unset)
    vim.list_extend(ret, set)
  end
  vim.list_extend(ret, self.tool.cmd)
end

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if not self.external then
    return self:terminal()
  end
end

--- Terminal panes of the current zellij session
function M.panes()
  local _, out = Util.exec({ "zellij", "action", "list-panes", "--json", "--all" }, { notify = false })
  local ok, list = pcall(vim.json.decode, out or "", { luanil = { object = true, array = true } })
  local panes = {} ---@type sidekick.zellij.Pane[]
  for _, p in ipairs(ok and type(list) == "table" and list or {}) do
    if not p.is_plugin then
      local id = "terminal_" .. p.id
      ---@class sidekick.zellij.Pane
      panes[#panes + 1] = {
        id = id, -- zellij pane id
        skid = skid(id), -- unique id for the pane
        tab_id = p.tab_id,
        exited = p.exited,
        cmd = p.terminal_command, -- only set for command panes
      }
    end
  end
  return panes
end

function M:pane()
  for _, pane in ipairs(M.panes()) do
    if pane.id == self.zellij_pane_id then
      return pane
    end
  end
end

function M:is_running()
  -- a discovered tool can exit while its shell keeps the pane open
  if self.zellij_pid then
    return vim.api.nvim_get_proc(self.zellij_pid) ~= nil
  end
  local pane = self:pane()
  return pane ~= nil and not pane.exited
end

function M:focus()
  -- switches to the tab of the pane if needed; fails when the pane is already focused
  Util.exec({ "zellij", "action", "focus-pane-id", self.zellij_pane_id }, { notify = false })
end

---@param text string
function M:send(text)
  local pane_id = self.zellij_pane_id
  local function send()
    Util.exec({ "zellij", "action", "write-chars", "--pane-id", pane_id, "--", text })
  end

  if self.tool.mux_focus then
    -- Send focus-in event first (some TUI apps like qwen ignore input when unfocused)
    Util.exec({ "zellij", "action", "write", "--pane-id", pane_id, "27", "91", "73" }) -- ESC [ I
    vim.defer_fn(send, 50) -- slight delay to ensure focus event is processed first
  else
    send()
  end
end

function M:submit()
  Util.exec({ "zellij", "action", "send-keys", "--pane-id", self.zellij_pane_id, "Enter" })
end

--- Tools running in panes of the current zellij session,
--- matched to their pane by the inherited `ZELLIJ_PANE_ID`
---@return sidekick.cli.session.State[]
function M.external_sessions()
  local session_name = vim.env.ZELLIJ_SESSION_NAME
  if not session_name or not M.supported() then
    return {}
  end

  local Procs = require("sidekick.cli.procs")
  local procs = Procs.new()
  local tools = Config.tools()

  ---@param proc sidekick.cli.Proc
  local function get_tool(proc)
    for _, tool in pairs(tools) do
      if tool:is_proc(proc) then
        return tool
      end
    end
  end

  -- skip helper processes of tools and tools in Neovim terminals
  ---@param proc sidekick.cli.Proc
  local function is_nested(proc)
    local parent = procs:parent(proc.pid)
    while parent and not parent.cmd:find("zellij.*%-%-server") do
      if is_editor(parent) or get_tool(parent) then
        return true
      end
      parent = procs:parent(parent.pid)
    end
    return false
  end

  local ret = {} ---@type sidekick.cli.session.State[]
  local seen = {} ---@type table<string, boolean>
  for _, proc in ipairs(procs:list()) do
    local tool = not is_editor(proc) and get_tool(proc)
    if tool and not is_nested(proc) then
      local env = proc.env or {}
      local pane_id = env.ZELLIJ_PANE_ID and ("terminal_" .. env.ZELLIJ_PANE_ID)
      if pane_id and env.ZELLIJ_SESSION_NAME == session_name and not seen[pane_id] then
        seen[pane_id] = true
        ret[#ret + 1] = {
          id = skid(pane_id),
          cwd = proc.cwd or nil,
          tool = tool,
          zellij_pane_id = pane_id,
          zellij_pid = proc.pid,
          mux_session = session_name,
          pids = Procs.pids(proc.pid),
        }
      end
    end
  end
  return ret
end

function M.sessions()
  local sessions = Util.exec({ "zellij", "list-sessions", "-ns" }, { notify = false }) or {}
  local ret = {} ---@type sidekick.cli.session.State[]
  local Terminal = require("sidekick.cli.terminal")

  -- Find the terminal instance attached to this zellij session.
  -- We need this to get the PIDs for deduplication, since zellij's
  -- API doesn't provide process information.
  local function find_pids(sid)
    local pids = {} ---@type integer[]
    for _, t in pairs(Terminal.terminals) do
      if t.mux_backend == "zellij" and t.mux_session == sid then
        vim.list_extend(pids, t.pids or {})
      end
    end
    return pids
  end

  for _, s in ipairs(sessions) do
    local state = Util.get_state(s)
    if state then
      ret[#ret + 1] = {
        id = "zellij: " .. s,
        cwd = state.cwd,
        tool = state.tool,
        mux_session = s,
        pids = find_pids(s),
      }
    end
  end

  vim.list_extend(ret, M.external_sessions())
  return ret
end

-- function M:dump()
--   do
--     -- sigh, another broken zellij feature
--     -- dump-screen doesn't include ansi escape sequences
--     -- just the raw text
--     return
--   end
--   local tmp = Config.state("zellij-dump.txt")
--   local ok = Util.exec({ "zellij", "-s", self.mux_session, "action", "dump-screen", "-f", tmp }, {
--     notify = true,
--   })
--   if not ok then
--     return
--   end
--   local f = io.open(tmp, "r")
--   if not f then
--     return
--   end
--   vim.fn.delete(tmp)
--   local content = f:read("*a")
--   f:close()
--   return content
-- end

return M
