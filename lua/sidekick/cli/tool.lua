local Config = require("sidekick.config")

---@class sidekick.cli.Tool: sidekick.cli.Config
---@field config sidekick.cli.Config
---@field name string
local M = {}
M.__index = M

---@type table<string,sidekick.cli.Config>
local base = setmetatable({}, {
  __index = function(t, key)
    local f = vim.api.nvim_get_runtime_file("sk/cli/" .. key .. ".lua", false)[1]
    if f then
      local ok, ret = pcall(dofile, f)
      if ok and type(ret) == "table" then
        rawset(t, key, ret)
      end
    end
    return rawget(t, key)
  end,
})

---@param name string
function M.get(name)
  local config =
    vim.tbl_deep_extend("force", vim.deepcopy(base[name] or {}), vim.deepcopy(Config.cli.tools[name] or {}))
  local self = setmetatable(vim.deepcopy(config), M) --[[@as sidekick.cli.Tool]]
  self.config = config
  self.is_proc = nil
  self.name = name
  return self
end

---@param proc sidekick.cli.Proc
function M:is_proc(proc)
  local is_proc = self.config.is_proc
  if type(is_proc) == "string" then
    local re = vim.regex(is_proc)
    is_proc = function(_, p)
      return re:match_str(p.cmd) ~= nil
    end
    self.config.is_proc = is_proc
  end
  return type(is_proc) == "function" and is_proc(self, proc) or false
end

---@param opts? sidekick.cli.Config
function M:clone(opts)
  local clone = vim.tbl_deep_extend("force", vim.deepcopy(self), opts or {})
  return setmetatable(clone, M) --[[@as sidekick.cli.Tool]]
end

return M
