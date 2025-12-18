local M = {}

---@class sidekick.cli.SelectSession
---@field cb fun(session?: sidekick.cli.session.Info)
---@field auto? boolean Auto-select if only one session
---@field cwd? string Filter sessions by cwd

---@param opts sidekick.cli.SelectSession
function M.select(opts)
  opts = opts or {}
  local Util = require("sidekick.util")
  local Sessions = require("sidekick.cli.sessions")

  -- Discover all sessions
  local sessions = Sessions.discover_all_sessions({ cwd = opts.cwd })

  if #sessions == 0 then
    Util.warn("No CLI sessions found")
    if opts.cb then
      return opts.cb()
    end
    return
  end

  if #sessions == 1 and opts.auto then
    if opts.cb then
      return opts.cb(sessions[1])
    end
    return
  end

  if not opts.cb then
    Util.error("No callback provided for session selection")
    return
  end

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    prompt = "Select CLI session:",
    kind = "sidekick_cli_session",
    format_item = function(session)
      return string.format("[%s] %s", session.cli_name, session.title)
    end,
    snacks = {
      format = M.format,
      layout = {
        preset = "select",
      },
    },
  }

  vim.ui.select(sessions, select_opts, opts.cb)
end

---@param session sidekick.cli.session.Info
---@param picker? snacks.Picker
function M.format(session, picker)
  local ret = {} ---@type snacks.picker.Highlight[]

  if picker then
    local count = picker:count()
    local idx = tostring(session.idx)
    idx = (" "):rep(#tostring(count) - #idx) .. idx
    ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }
    ret[#ret + 1] = { " " }
  end

  -- Format: [CLI] Title
  ret[#ret + 1] = { "[", "Comment" }
  ret[#ret + 1] = { session.cli_name, "Title" }
  ret[#ret + 1] = { "] ", "Comment" }
  ret[#ret + 1] = { session.title }

  return ret
end

return M
