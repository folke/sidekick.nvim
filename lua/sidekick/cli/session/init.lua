local Config = require("sidekick.config")
local Util = require("sidekick.util")

local M = {}

M.backends = {} ---@type table<string,sidekick.cli.Session>
M.did_setup = false
M.attached = {} ---@type table<string,boolean>

---@class sidekick.cli.session.State
---@field id string unique id of the running tool (typically pid of tool)
---@field cwd string
---@field tool sidekick.cli.Tool|string
---@field backend? string
---@field started? boolean
---@field attached? boolean
---@field mux_session? string
---@field mux_backend? string

---@alias sidekick.cli.session.Opts sidekick.cli.session.State|{cwd?:string,id?:string}

---@class sidekick.cli.Session: sidekick.cli.session.State
---@field sid string unique id based on tool and cwd
---@field tool sidekick.cli.Tool
---@field backend string
local B = {}
B.__index = B

---@param text string
function B:send(text)
  error("Backend:send() not implemented")
end

function B:init() end

function B:submit()
  error("Backend:submit() not implemented")
end

---@return sidekick.cli.terminal.Cmd?
function B:attach()
  error("Backend:attach() not implemented")
end

---@return sidekick.cli.session.State[]
function B.sessions()
  error("Backend:sessions() not implemented")
end

---@param state sidekick.cli.session.Opts
function M.new(state)
  local tool = state.tool
  tool = type(tool) == "string" and Config.get_tool(tool) or tool --[[@as sidekick.cli.Tool]]

  local backend = state.backend or (Config.cli.mux.enabled and Config.cli.mux.backend or "terminal")
  local super = assert(M.backends[backend], "unknown backend: " .. backend)
  local meta = getmetatable(state)
  local self = setmetatable(state, super) --[[@as sidekick.cli.Session]]
  self.tool = tool
  self.cwd = M.cwd(state)
  -- self.cmd = state.cmd or { cmd = tool.cmd, env = tool.env }
  self.backend = backend
  self.sid = M.sid({ tool = tool.name, cwd = self.cwd })
  self.id = self.id or self.sid
  self.attached = self.attached or M.attached[self.id] or false
  if meta ~= super and self.init then
    self:init()
  end
  return self
end

---@param opts? {cwd?:string}
function M.cwd(opts)
  return vim.fs.normalize(vim.fn.fnamemodify(opts and opts.cwd or vim.fn.getcwd(0), ":p"))
end

---@param opts {tool:string, cwd?:string}
function M.sid(opts)
  local tool = assert(opts and opts.tool, "missing tool")
  local cwd = M.cwd(opts)
  return ("%s %s"):format(tool, vim.fn.sha256(cwd):sub(1, 16 - #tool))
end

---@param name string
---@param backend sidekick.cli.Session
function M.register(name, backend)
  setmetatable(backend, B)
  backend.backend = name
  M.backends[name] = backend
end

function M.setup()
  if M.did_setup then
    return
  end
  M.did_setup = true
  local session_backends = { tmux = "sidekick.cli.session.tmux", zellij = "sidekick.cli.session.zellij" }
  for name, mod in pairs(session_backends) do
    if vim.fn.executable(name) == 1 then
      M.register(name, require(mod))
    end
  end
  M.register("terminal", require("sidekick.cli.terminal"))
end

function M.sessions()
  M.setup()
  require("sidekick.cli.procs"):update()
  local ret = {} ---@type sidekick.cli.Session[]
  local ids = {} ---@type table<string,boolean>
  for name, backend in pairs(M.backends) do
    for _, s in pairs(backend:sessions()) do
      s.backend = name
      s.started = true
      ret[#ret + 1] = M.new(s)
      ids[s.id] = true
    end
  end
  for id in pairs(M.attached) do
    if not ids[id] then
      M.attached[id] = nil
    end
  end
  return ret
end

---@param session sidekick.cli.Session
function M.attach(session)
  if M.attached[session.id] then
    return session
  end
  local cmd = session:attach()
  M.attached[session.id] = true
  session.attached = true
  if cmd then
    return M.new({
      tool = session.tool:clone({ cmd = cmd.cmd, env = cmd.env }),
      cwd = session.cwd,
      id = session.sid,
      backend = "terminal",
      mux_backend = session.backend,
      mux_session = session.mux_session,
      attached = true,
    })
  end
  return session
end

return M
