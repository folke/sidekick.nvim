local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.WezTerm: sidekick.cli.Session
---@field wezterm_pane_id number
local M = {}
M.__index = M
M.priority = 70  -- Higher than tmux/zellij for backwards compatibility
M.external = false  -- Only works from inside WezTerm

--- Initialize WezTerm session, verify we're running inside WezTerm
function M:init()
  if not vim.env.WEZTERM_PANE then
    Util.warn("WezTerm backend requires running inside WezTerm")
    return
  end

  if vim.fn.executable("wezterm") ~= 1 then
    Util.warn("wezterm executable not found in PATH")
    return
  end
end

return M
