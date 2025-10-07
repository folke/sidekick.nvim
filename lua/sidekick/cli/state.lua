local Config = require("sidekick.config")
local Session = require("sidekick.cli.session")
local Terminal = require("sidekick.cli.terminal")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.cli.State
---@field tool sidekick.cli.Tool
---@field session? sidekick.cli.Session
---@field installed? boolean
---@field started? boolean
---@field attached? boolean
---@field terminal? sidekick.cli.Terminal

---@class sidekick.cli.Filter
---@field attached? boolean
---@field cwd? boolean
---@field installed? boolean
---@field name? string
---@field session? string
---@field started? boolean
---@field terminal? boolean

---@class sidekick.cli.With
---@field filter? sidekick.cli.Filter
---@field show? boolean
---@field focus? boolean
---@field create? boolean
---@field all? boolean
---@field state? sidekick.cli.State

---@param t sidekick.cli.State
---@param filter? sidekick.cli.Filter
function M.is(t, filter)
  filter = filter or {}
  return (filter.attached == nil or filter.attached == t.attached)
    and (filter.cwd == nil or (t.session and t.session.cwd == Session.cwd()))
    and (filter.installed == nil or filter.installed == t.installed)
    and (filter.name == nil or filter.name == t.tool.name)
    and (filter.session == nil or (t.session and t.session.id == filter.session))
    and (filter.started == nil or filter.started == t.started)
    and (filter.terminal == nil or filter.terminal == (t.terminal ~= nil))
end

---@param session sidekick.cli.Session
function M.get_state(session)
  return {
    tool = session.tool,
    session = session,
    installed = true, -- it's running, so it must be installed
    started = session.started,
    attached = session.attached,
    terminal = session.backend == "terminal" and Terminal.get(session.id) or nil,
  }
end

---@param filter? sidekick.cli.Filter
---@return sidekick.cli.State[]
function M.get(filter)
  local all = {} ---@type sidekick.cli.State[]
  local sids = {} ---@type table<string, boolean>
  local sessions = Session.sessions()
  local terminals = {} ---@type table<string, boolean>

  for _, s in pairs(sessions) do
    if s.backend == "terminal" then
      terminals[s.id] = true
    end
  end

  for _, s in pairs(sessions) do
    local skip = false
    if s.backend ~= "terminal" and s.mux_session == s.sid and terminals[s.sid] then
      -- ignore non-terminal sessions that have a terminal session with the same mux_session
      -- this avoids showing both a tmux/zellij session and the terminal session attached to it
      skip = true
    end
    if not skip then
      sids[s.sid] = true
      all[#all + 1] = M.get_state(s)
    end
  end

  for name, tool in pairs(Config.tools()) do
    local sid = Session.sid({ tool = name })
    if not sids[sid] then
      all[#all + 1] = {
        tool = tool,
        installed = vim.fn.executable(tool.cmd[1]) == 1,
      }
    end
  end

  local cwd = Session.cwd()

  ---@type sidekick.cli.State[]
  ---@param t sidekick.cli.State
  local ret = vim.tbl_filter(function(t)
    return M.is(t, filter)
  end, all)
  table.sort(ret, function(a, b)
    if a.installed ~= b.installed then
      return a.installed
    end
    -- sessions in cwd, or tools without a session
    local a_cwd = (not a.session or a.session.cwd == cwd or false)
    local b_cwd = (not b.session or b.session.cwd == cwd or false)
    if a_cwd ~= b_cwd then
      return a_cwd
    end
    if a.started ~= b.started then
      return a.started
    end
    if a.attached ~= b.attached then
      return a.attached
    end
    if (a.terminal ~= nil) ~= (b.terminal ~= nil) then
      return a.terminal ~= nil
    end
    return a.tool.name < b.tool.name
  end)
  return ret
end

---@param cb fun(state: sidekick.cli.State)
---@param ... sidekick.cli.With
function M.with(cb, ...)
  local todo = { {} } ---@type sidekick.cli.With[]
  for i = 1, select("#", ...) do
    local o = select(i, ...)
    if type(o) == "table" then
      todo[#todo + 1] = o
    end
  end
  local opts = vim.tbl_deep_extend("force", unpack(todo)) ---@type sidekick.cli.With
  cb = vim.schedule_wrap(cb)
  local filter = vim.deepcopy(opts.filter or {})
  filter.attached = true
  local tools = opts.state and { opts.state } or M.get(filter)
  tools = opts.all and tools or { tools[1] } -- FIXME: should be last used
  if #tools == 0 and opts.create then
    require("sidekick.cli.ui.select").select({
      auto = true,
      filter = opts.filter,
      cb = function(state)
        if not state then
          return
        end
        cb(M.attach(state, { show = opts.show, focus = opts.focus }))
      end,
    })
  else
    vim.tbl_map(cb, tools)
  end
end

---@param state sidekick.cli.State
---@param opts? {show?:boolean, focus?:boolean}
function M.attach(state, opts)
  opts = opts or {}
  local tool = state.tool
  if vim.fn.executable(tool.cmd[1]) == 0 then
    Util.error(("`%s` is not installed"):format(tool.cmd[1]))
    return
  end
  local session = state.session or Session.new({ tool = tool.name })
  session = Session.attach(session)
  state = M.get_state(session)
  local terminal = state.terminal
  if terminal then
    if opts.show then
      terminal:show()
      if opts.focus ~= false and terminal:is_running() then
        terminal:focus()
      end
      state = M.get_state(session)
    end
  else
    Util.info("Attached to `" .. state.tool.name .. "`")
  end
  return state
end

return M
