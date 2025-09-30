local Config = require("sidekick.config")
local Session = require("sidekick.cli.session")
local Util = require("sidekick.util")

---@class sidekick.cli.mux.Opts
---@field cwd? string

---@class sidekick.cli.Muxer
---@field tool sidekick.cli.Tool
---@field session sidekick.cli.Session
---@field backend "tmux"|"zellij"
---@field cwd string
local M = {}
M.__index = M

---@param tool sidekick.cli.Tool
---@param session sidekick.cli.Session
function M.new(tool, session)
  local super = M.get()
  if not super then
    return
  end
  ---@type sidekick.cli.Muxer
  local self = setmetatable({}, { __index = super })
  self.tool = tool
  session.mux = self.backend
  self.session = session
  return self
end

---@return sidekick.cli.Tool.spec?
function M:cmd()
  error("Muxer:cmd() not implemented")
end

---@return string[]?
function M:_sessions()
  error("Muxer:cmd() not implemented")
end

---@return table<string,sidekick.cli.Session>
function M.sessions()
  local mux = M.get()
  if not mux then
    return {}
  end
  local sessions = mux:_sessions() or {}
  local ret = {} ---@type table<string,sidekick.cli.Session>
  for _, id in ipairs(sessions) do
    local s = Session.get(id)
    if s then
      s.mux = mux.backend
      ret[id] = s
    end
  end
  return ret
end

function M.get()
  if not Config.cli.mux.enabled then
    return
  end
  ---@type boolean, sidekick.cli.Muxer
  local ok, ret = pcall(require, "sidekick.cli.mux." .. Config.cli.mux.backend)
  if not ok then
    Util.error("Invalid **mux** backend `" .. Config.cli.mux.backend .. "`")
    return
  end
  return ret
end

return M
