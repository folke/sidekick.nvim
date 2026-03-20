local M = {}

--- Humanize a Unix timestamp to a relative time string
---@param timestamp number Unix timestamp in seconds
---@return string
local function humanize_time(timestamp)
  local now = os.time()
  local diff = now - timestamp

  if diff < 0 then
    return "in the future" -- unreachable
  elseif diff < 60 then
    return "just now"
  elseif diff < 60 * 60 then -- 1 hour
    local minutes = math.floor(diff / 60)
    return minutes == 1 and "1 minute ago" or string.format("%d minutes ago", minutes)
  elseif diff < 60 * 60 * 24 then -- 1 day
    local hours = math.floor(diff / (60 * 60))
    return hours == 1 and "1 hour ago" or string.format("%d hours ago", hours)
  elseif diff < 60 * 60 * 24 * 7 then -- 1 week
    local days = math.floor(diff / (60 * 60 * 24))
    return days == 1 and "1 day ago" or string.format("%d days ago", days)
  elseif diff < 60 * 60 * 24 * 30 then -- ~1 month
    local weeks = math.floor(diff / (60 * 60 * 24 * 7))
    return weeks == 1 and "1 week ago" or string.format("%d weeks ago", weeks)
  elseif diff < 60 * 60 * 24 * 365 then -- 1 year
    local months = math.floor(diff / (60 * 60 * 24 * 30))
    return months == 1 and "1 month ago" or string.format("%d months ago", months)
  else
    local years = math.floor(diff / (60 * 60 * 24 * 365))
    return years == 1 and "1 year ago" or string.format("%d years ago", years)
  end
end

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

  -- Calculate max CLI name width and max time string width for column alignment
  local max_cli_width = vim
    .iter(sessions)
    :map(function(s)
      return #s.cli_name
    end)
    :fold(0, math.max)

  local max_time_width = vim
    .iter(sessions)
    :map(function(s)
      return #humanize_time(s.updated)
    end)
    :fold(0, math.max)

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    prompt = "Select CLI session:",
    kind = "sidekick_cli_session",
    format_item = function(session)
      local cli_padded = session.cli_name .. (" "):rep(max_cli_width - #session.cli_name)
      local time_str = humanize_time(session.updated)
      local time_padded = time_str .. (" "):rep(max_time_width - #time_str)
      return string.format("%s %s %s", cli_padded, time_padded, session.title)
    end,
    snacks = {
      format = function(session, picker)
        return M.format(session, picker, max_cli_width, max_time_width)
      end,
      layout = {
        preset = "select",
      },
    },
  }

  vim.ui.select(sessions, select_opts, opts.cb)
end

---@param session snacks.picker.Item
---@param picker? snacks.Picker
---@param max_cli_width? number Maximum CLI name width for padding
---@param max_time_width? number Maximum time string width for padding
function M.format(session, picker, max_cli_width, max_time_width)
  local ret = {} ---@type snacks.picker.Highlight[]

  if picker then
    local count = picker:count()
    local idx = tostring(session.idx)
    idx = (" "):rep(#tostring(count) - #idx) .. idx
    ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }
    ret[#ret + 1] = { " " }
  end

  -- Default to current widths if not provided
  local time_str = humanize_time(session.updated)
  max_cli_width = max_cli_width or #session.cli_name
  max_time_width = max_time_width or #time_str

  -- Format: CLI (padded) | Humanized time (padded) | Title
  local cli_padded = session.cli_name .. (" "):rep(max_cli_width - #session.cli_name)
  local time_padded = time_str .. (" "):rep(max_time_width - #time_str)

  ret[#ret + 1] = { cli_padded, "Title" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { time_padded, "Comment" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { session.title }

  return ret
end

return M
