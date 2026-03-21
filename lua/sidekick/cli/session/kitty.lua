--- Kitty terminal multiplexer backend for sidekick.nvim
---
local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Kitty: sidekick.cli.Session
local M = {}
M.__index = M
M.priority = 50
M.external = true

--- Send text to the kitty window
---@param text string
function M:send(text)
  if not self.mux_session then
    return
  end

  local function send()
    -- Use stdin to send text (avoids escaping issues)
    Util.exec({ "kitty", "@", "send-text", "--match", ("id:%s"):format(self.mux_session), "--stdin" }, { stdin = text })
  end

  if self.tool.mux_focus then
    -- Send focus-in event first (some TUI apps ignore input when unfocused)
    -- Focus-in sequence: ESC [ I
    Util.exec({ "kitty", "@", "send-key", "--match", ("id:%s"):format(self.mux_session), "escape", "[", "I" })
    vim.defer_fn(send, 50) -- slight delay to ensure focus event is processed first
  else
    send()
  end
end

function M:init()
  if not M.is_available() then
    local is_linux = vim.loop.os_uname().sysname == "Linux"
    local socket_example = is_linux and "unix:@mykitty" or "unix:/tmp/mykitty"
    Util.warn({
      "Kitty remote control is not enabled.",
      "Add to kitty.conf:",
      "  allow_remote_control yes",
      ("  listen_on %s"):format(socket_example),
    })
  end
end

--- Submit (send Enter key) to the kitty window
function M:submit()
  if not self.mux_session then
    return
  end
  Util.exec({ "kitty", "@", "send-key", "--match", ("id:%s"):format(self.mux_session), "enter" })
end

--- Focus the kitty window
function M:focus()
  if not self.mux_session then
    return self
  end
  Util.exec({
    "kitty",
    "@",
    "focus-window",
    "--match",
    ("id:%s"):format(self.mux_session),
  }, { notify = false })
  return self
end

--- Start a new kitty window/tab for the session
---@return sidekick.cli.terminal.Cmd?
function M:start()
  -- Kitty backend always creates external sessions (in kitty windows/splits)
  if Config.cli.mux.create == "terminal" then
    -- Create a new terminal instance in an OS window
    local cmd = { "kitty", "@", "launch", "--type=os-window", "--cwd", self.cwd }
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new kitty OS window"):format(self.tool.name))
  elseif Config.cli.mux.create == "window" then
    -- Create a new tab in the current OS window
    local cmd = { "kitty", "@", "launch", "--type=tab", "--cwd", self.cwd }
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new kitty tab"):format(self.tool.name))
  elseif Config.cli.mux.create == "split" then
    -- Create a split in the current tab
    local location = Config.cli.mux.split.vertical and "vsplit" or "hsplit"
    local cmd = { "kitty", "@", "launch", "--type=window", "--location", location, "--cwd", self.cwd }
    -- Add bias if size is specified (convert 0-1 to 0-100 percentage)
    if Config.cli.mux.split.size and Config.cli.mux.split.size > 0 and Config.cli.mux.split.size < 1 then
      local bias = math.floor(Config.cli.mux.split.size * 100)
      vim.list_extend(cmd, { "--bias", tostring(bias) })
    end
    self:add_cmd(cmd)
    self:spawn(cmd)
    Util.info(("Started **%s** in a new kitty split"):format(self.tool.name))
  end
end

--- Check if the kitty window is still running
---@return boolean
function M:is_running()
  if not self.mux_session then
    return false
  end
  -- Check if the window still exists by querying kitty
  local output = Util.exec({
    "kitty",
    "@",
    "ls",
    "--match",
    ("id:%s"):format(self.mux_session),
  }, { notify = false })
  return output ~= nil and #output > 0
end

--- List all active kitty sessions
--- Discovers tool sessions by parsing kitty's JSON window tree
---@return sidekick.cli.session.State[]
function M.sessions()
  if not M.is_available() then
    return {}
  end

  local function get_kitty_tree()
    local output = Util.exec({ "kitty", "@", "ls" }, { notify = false })
    if not output then
      return nil
    end

    local ok, kitty_info_json = pcall(vim.json.decode, table.concat(output, "\n"))
    if not ok or not kitty_info_json then
      return nil
    end

    return kitty_info_json
  end

  local kitty_info_json = get_kitty_tree()
  if not kitty_info_json then
    return {}
  end

  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()
  local Procs = require("sidekick.cli.procs")

  -- Walk through the kitty window tree structure
  -- Structure: os_windows[] → tabs[] → windows[] → foreground_processes[]
  for _, os_window in ipairs(kitty_info_json or {}) do
    for _, tab in ipairs(os_window.tabs or {}) do
      for _, window in ipairs(tab.windows or {}) do
        -- Iterate kitty's pre-identified foreground processes
        for _, fg_proc in ipairs(window.foreground_processes or {}) do
          -- Build a process object that matches what tool:is_proc expects
          local proc = {
            pid = fg_proc.pid,
            cmd = table.concat(fg_proc.cmdline or {}, " "),
            cwd = fg_proc.cwd,
          }

          -- Try to match against configured tools
          for _, tool in pairs(tools) do
            if tool:is_proc(proc) then
              -- Found a matching tool! Create session state
              ret[#ret + 1] = {
                id = ("kitty %s"):format(window.id),
                cwd = fg_proc.cwd or window.cwd,
                tool = tool,
                mux_session = tostring(window.id), -- Window ID stored as string
                pids = Procs.pids(window.pid), -- Get full process tree for deduplication
              }
              -- Move to next window (don't check other tools for this window)
              goto next_window
            end
          end
        end
        ::next_window::
      end
    end
  end

  return ret
end

--- Check if kitty remote control is available and properly configured
--- @return boolean
function M.is_available()
  -- KITTY_LISTEN_ON must be set and non-empty for remote control to work
  if not vim.env.KITTY_LISTEN_ON or vim.env.KITTY_LISTEN_ON == "" then
    return false
  end
  return true
end

--- Add environment variables and tool command to kitty launch command
---@param ret string[] The command array to extend
function M:add_cmd(ret)
  -- Add environment variables
  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      -- Unset environment variable (just name removes it)
      vim.list_extend(ret, { "--env", key })
    else
      vim.list_extend(ret, { "--env", ("%s=%s"):format(key, tostring(value)) })
    end
  end
  -- Add the tool command
  vim.list_extend(ret, self.tool.cmd)
end

--- Execute the given kitty launch command and update session info
--- Captures the window ID returned by kitty @ launch
---@param cmd string[]
function M:spawn(cmd)
  local output = Util.exec(cmd, { notify = true })
  if not output or #output == 0 then
    return
  end

  -- kitty @ launch prints the window ID
  local window_id = tonumber(output[1])
  if not window_id then
    return
  end

  -- Set session info based on the window ID
  self.id = ("kitty %d"):format(window_id)
  self.mux_session = tostring(window_id)
  self.started = true
end

--- Dump the screen contents (scrollback + screen)
---@return string|nil
function M:dump()
  if not self.mux_session then
    return
  end
  local output = Util.exec({
    "kitty",
    "@",
    "get-text",
    "--match",
    ("id:%s"):format(self.mux_session),
    "--extent",
    "all",
    "--ansi",
  }, { notify = false })
  if output then
    return table.concat(output, "\n")
  end
end

return M
