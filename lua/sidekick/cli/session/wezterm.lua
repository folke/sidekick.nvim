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

--- Start a new WezTerm split pane session
---@return sidekick.cli.terminal.Cmd?
function M:start()
  if not vim.env.WEZTERM_PANE then
    Util.error("Cannot start WezTerm session: not running inside WezTerm")
    return
  end

  -- Build command: wezterm cli split-pane --cwd <cwd> -- <tool.cmd>
  local cmd = { "wezterm", "cli", "split-pane", "--cwd", self.cwd, "--" }
  vim.list_extend(cmd, self.tool.cmd)

  -- Execute and capture pane_id
  local output = Util.exec(cmd, { notify = true })
  if not output or #output == 0 then
    Util.error("Failed to create WezTerm split pane")
    return
  end

  -- Parse pane_id (wezterm cli split-pane returns just the pane ID number)
  self.wezterm_pane_id = tonumber(output[1])
  if not self.wezterm_pane_id then
    Util.error(("Failed to parse pane ID from WezTerm output: %s"):format(output[1]))
    return
  end

  self.started = true
  Util.info(("Started **%s** in WezTerm pane %d"):format(self.tool.name, self.wezterm_pane_id))
end

--- Send text to WezTerm pane
---@param text string
function M:send(text)
  if not self.wezterm_pane_id then
    Util.error("Cannot send text: no pane ID available")
    return
  end

  Util.exec({
    "wezterm",
    "cli",
    "send-text",
    "--pane-id",
    tostring(self.wezterm_pane_id),
    "--no-paste",
    text,
  }, { notify = false })
end

--- Submit current input (send newline)
function M:submit()
  if not self.wezterm_pane_id then
    Util.error("Cannot submit: no pane ID available")
    return
  end

  Util.exec({
    "wezterm",
    "cli",
    "send-text",
    "--pane-id",
    tostring(self.wezterm_pane_id),
    "--no-paste",
    "\n",
  }, { notify = false })
end

--- Check if the WezTerm pane still exists
---@return boolean
function M:is_running()
  if not self.wezterm_pane_id then
    return false
  end

  -- List all panes and check if our pane_id exists
  local output = Util.exec({ "wezterm", "cli", "list", "--format", "json" }, { notify = false })
  if not output then
    return false
  end

  local ok, panes = pcall(vim.json.decode, table.concat(output, "\n"))
  if not ok or type(panes) ~= "table" then
    return false
  end

  for _, pane in ipairs(panes) do
    if pane.pane_id == self.wezterm_pane_id then
      return true
    end
  end

  return false
end

return M
