local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.WezTerm: sidekick.cli.Session
---@field wezterm_pane_id number
local M = {}
M.__index = M
M.priority = 70  -- Higher than tmux/zellij for backwards compatibility
M.external = false  -- Only works from inside WezTerm

return M
