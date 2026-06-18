local Config = require("sidekick.config")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.Picker
local P = {}

---@param source string
---@param cb fun(items:sidekick.context.Loc[])
---@param opts? table
function P.open(source, cb, opts) end

---@param cb fun(items:sidekick.context.Loc[])
---@return fun()
function P.action(cb) end

---@param picker? string
function M.get(picker)
  local pickers = picker and { picker } or { Config.cli.picker, "snacks", "telescope", "fzf-lua", "mini.pick" }
  for _, name in ipairs(pickers) do
    ---@type boolean, sidekick.Picker
    local ok, mod = pcall(require, "sidekick.cli.picker." .. name)
    if not ok then
      return Util.error("Invalid picker: " .. name)
    end
    if pcall(require, name) then
      return mod
    end
  end
  Util.error("No valid picker found")
end

---@param opts? sidekick.context.loc.Opts|sidekick.cli.Send
function M._send_cb(opts)
  opts = opts or {}
  ---@param items sidekick.context.Loc[]
  return function(items)
    local Loc = require("sidekick.cli.context.location")
    local ret = { { " " } } ---@type sidekick.Text
    for _, item in ipairs(items) do
      local file = Loc.get(item, { kind = opts.kind or "file" })[1]
      if file then
        vim.list_extend(ret, file)
        ret[#ret + 1] = { " " }
      end
    end
    vim.schedule(function()
      opts = vim.tbl_deep_extend("force", vim.deepcopy(opts or {}), { text = { ret } })
      ---@cast opts sidekick.cli.Send
      require("sidekick.cli").send(opts)
    end)
  end
end

---@param source string
---@param opts? sidekick.context.loc.Opts|sidekick.cli.Send
---@param popts? table
function M.open(source, opts, popts)
  local picker = M.get()
  return picker and picker.open(source, M._send_cb(opts), popts)
end

return M
