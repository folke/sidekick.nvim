local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Tmux: sidekick.cli.Muxer
local M = {}
M.backend = "tmux"
setmetatable(M, require("sidekick.cli.mux"))

---@return sidekick.cli.Tool.spec?
function M:cmd()
  if vim.fn.executable("tmux") ~= 1 then
    Util.error("tmux executable not found on $PATH")
    return
  end

  local cmd = { "tmux", "new", "-A", "-s", self.session.id }
  vim.list_extend(cmd, self.tool.cmd)
  vim.list_extend(cmd, { ";", "set-option", "status", "off" })
  vim.list_extend(cmd, { ";", "set-option", "detach-on-destroy", "on" })
  return { cmd = cmd }
end

function M._sessions()
  return Util.exec({ "tmux", "list-sessions", "-F", "#{session_name}" })
end

return M
