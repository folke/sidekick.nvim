local Util = require("sidekick.util")

---@class sidekick.cli.Select: sidekick.cli.With
---@field cb fun(state?:sidekick.cli.State)
---@field auto? boolean Automatically select if only one tool matches the filter

local M = {}

---@param opts sidekick.cli.Select
function M.select(opts)
  assert(type(opts) == "table", "opts must be a table")
  local tools = require("sidekick.cli.state").get(opts.filter)

  ---@param state? sidekick.cli.State
  local on_select = function(state)
    if state and not state.installed then
      M.on_missing(state.tool)
      state = nil
    end
    opts.cb(state)
  end

  if #tools == 0 then
    Util.warn("No tools match the given filter")
    return
  elseif #tools == 1 and opts.auto then
    on_select(tools[1])
    return
  end

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    prompt = "Select CLI tool:",
    picker = { format = M.format },
    kind = "snacks",
    ---@param tool sidekick.cli.State
    format_item = function(tool, is_snacks)
      local parts = M.format(tool)
      return is_snacks and parts or table.concat(vim.tbl_map(function(p)
        return p[1]
      end, parts))
    end,
  }

  vim.ui.select(tools, select_opts, on_select)
end

---@param tool sidekick.cli.Tool
function M.on_missing(tool)
  Util.error(("Tool `%s` is not installed"):format(tool.name))
  if tool.url then
    local ok, err = vim.ui.open(tool.url)
    if ok then
      Util.info(("Opening %s in your browser..."):format(tool.url))
    else
      Util.error(("Failed to open %s: %s"):format(tool.url, err))
    end
  end
end

---@param state sidekick.cli.State|snacks.picker.Item
---@param picker? snacks.Picker
function M.format(state, picker)
  local sw = vim.api.nvim_strwidth
  local ret = {} ---@type snacks.picker.Highlight[]

  local status = state.terminal and "terminal"
    or state.attached and "attached"
    or state.started and "started"
    or state.installed and "installed"
    or "missing"

  ---@type table<string, sidekick.Chunk>
  local icons = {
    terminal = { "󰆍 ", "SidekickCliTerminal" },
    attached = { " ", "SidekickCliAttached" },
    started = { " ", "SidekickCliStarted" },
    installed = { " ", "SidekickCliInstalled" },
    missing = { " ", "SidekickCliMissing" },
  }

  if picker then
    local count = picker:count()
    local idx = tostring(state.idx)
    idx = (" "):rep(#tostring(count) - #idx) .. idx
    ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }
    ret[#ret + 1] = { " " }
  end
  ret[#ret + 1] = icons[status]
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { state.tool.name }
  local len = sw(state.tool.name) + 2
  if state.session then
    local b = state.session.mux_backend or state.session.backend
    local backend = ("[%s]"):format(b)
    if state.session.mux_session and state.session.mux_session ~= state.session.sid then
      backend = ("[%s:%s]"):format(b, state.session.mux_session)
    end
    ret[#ret + 1] = { string.rep(" ", 12 - len) }
    ret[#ret + 1] = { backend, "Special" }
    len = 12 + sw(backend)
    ret[#ret + 1] = { string.rep(" ", 22 - len) }
    if picker then
      local item = setmetatable({}, state) --[[@as snacks.picker.Item]]
      item.file = state.session.cwd
      item.dir = true
      vim.list_extend(ret, require("snacks").picker.format.filename(item, picker))
    else
      ret[#ret + 1] = { vim.fn.fnamemodify(state.session.cwd, ":p:~"), "Directory" }
    end
  end
  return ret
end

return M
