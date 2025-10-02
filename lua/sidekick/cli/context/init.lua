local Config = require("sidekick.config")
local Diag = require("sidekick.cli.context.diagnostics")
local Loc = require("sidekick.cli.context.location")
local Text = require("sidekick.text")
local Util = require("sidekick.util")

local M = {}

---@type table<string, sidekick.context.Fn>
M.context = {
  position = function(ctx)
    return Loc.is_file(ctx.buf) and Loc.get(ctx, { kind = "position" })
  end,
  file = function(ctx)
    return Loc.is_file(ctx.buf) and Loc.get(ctx, { kind = "file" })
  end,
  line = function(ctx)
    return Loc.is_file(ctx.buf) and Loc.get(ctx, { kind = "line" })
  end,
  this = function()
    -- this is not actually used.
    -- `{this}` is special, see the C:render function for more details
  end,
  buffers = function(ctx)
    local ret = {} ---@type sidekick.Text[]
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if Loc.is_file(buf) then
        local file = Loc.get({ buf = buf, cwd = ctx.cwd }, { kind = "file" })[1]
        if file then
          table.insert(file, 1, { "- ", "@markup.list.markdown" })
          ret[#ret + 1] = file
        end
      end
    end
    return ret
  end,
  diagnostics = function(ctx)
    return Diag.get(ctx)
  end,
  diagnostics_all = function(ctx)
    return Diag.get(ctx, { all = true })
  end,
  selection = function(ctx)
    return require("sidekick.cli.context.selection").get(ctx)
  end,
}

---@class sidekick.context.ctx
---@field win integer
---@field buf integer
---@field cwd string
---@field row integer (1-based)
---@field col integer (1-based)
---@field range? sidekick.context.Range

---@alias sidekick.context.Fn.ret string|string[]|sidekick.Text|sidekick.Text[]|false
---@alias sidekick.context.Fn fun(ctx: sidekick.context.ctx): sidekick.context.Fn.ret?

---@class sidekick.context.Range
---@field from sidekick.Pos (1,0)-based
---@field to sidekick.Pos (1,0)-based
---@field kind "line"|"char"|"block"

---@class sidekick.Context
---@field ctx sidekick.context.ctx
---@field context table<string, sidekick.Text[]|false>
local C = {}
C.__index = C

function C.new()
  local self = setmetatable({}, C)
  self.ctx = M.ctx()
  self.context = {}
  return self
end

---@param name string
function C:get(name)
  if self.context[name] == nil then
    local fn = M.fn(name)
    if not fn then
      Util.error(("Invalid context `{%s}`"):format(name))
    end
    local ret = fn and fn(self.ctx) or false
    ret = ret and Text.to_text(ret) or false
    ret = type(ret) == "table" and not vim.tbl_isempty(ret) and ret or false
    self.context[name] = ret
  end
  return self.context[name]
end

---@param msg string
function C:render_line(msg)
  local ret = { {} } ---@type sidekick.Text[]
  local pos = 1
  ---@param t sidekick.Text
  ---@param nl? boolean
  local function add(t, nl)
    if #ret == 0 or nl then
      ret[#ret + 1] = {}
    end
    vim.list_extend(ret[#ret], t)
  end
  while pos <= #msg do
    local from, to, key = msg:find("(%b{})", pos)
    if from and to and key then
      ret[#ret] = ret[#ret] or {}
      if from > pos then
        add({ { msg:sub(pos, from - 1) } })
      end
      local value = self:get(key:sub(2, -2))
      if not value then
        return -- fail if any replacement failed
      end
      for i, vt in ipairs(value or {}) do
        add(vt, i > 1)
      end
      pos = to + 1
    else
      break
    end
  end
  if pos <= #msg then
    add({ { msg:sub(pos) } })
  end
  return ret
end

---@param opts string|sidekick.cli.Message|{this?: boolean}
function C:render(opts)
  opts = type(opts) == "string" and { msg = opts } or opts --[[@as sidekick.cli.Message|{this?:boolean}]]
  opts.msg = opts.msg or ""

  local lines = opts.msg == "" and {} or vim.split(opts.msg, "\n", { plain = true })

  if opts.prompt then
    ---@type sidekick.Prompt|string|fun(ctx:sidekick.context.ctx):(string?)|nil
    local prompt = Config.cli.prompts[opts.prompt]
    if not prompt then
      Util.error(("`%s` is not a valid prompt name"):format(opts.prompt))
      return
    end
    if type(prompt) == "function" then
      prompt = prompt(self.ctx)
    end
    ---@cast prompt sidekick.Prompt|string
    vim.list_extend(lines, vim.split(type(prompt) == "string" and prompt or prompt.msg or "", "\n", { plain = true }))
  end

  local ret = {} ---@type sidekick.Text[]

  if opts.this ~= false then
    -- {this} is special:
    -- * when ctx is an actual file, then {position} is used
    -- * otherwise it's replaced with `this` and a `{selection}` is appended
    -- * when in that case the user is not in visual mode, the message will be discarded
    local this, did_this, c = Loc.is_file(self.ctx.buf) and "{position}" or "this", false, 0
    for l in ipairs(lines) do
      lines[l], c = lines[l]:gsub("{this}", this)
      if c > 0 and this == "this" and not did_this then
        vim.list_extend(lines, { "", "{selection}" }) -- append selection
        did_this = true
      end
    end
  end

  for _, line in ipairs(lines) do
    local vt = self:render_line(line)
    if not vt then
      return
    end
    vim.list_extend(ret, vt)
  end

  return table.concat(Text.lines(ret), "\n"), ret
end

---@param name string
---@return sidekick.context.Fn?
function M.fn(name)
  return Config.cli.context[name] or M.context[name] or nil
end

function M.ctx()
  ---@param w integer
  local wins = vim.tbl_filter(function(w)
    local buf = vim.api.nvim_win_get_buf(w)
    return vim.bo[buf].filetype ~= "sidekick_terminal"
  end, vim.api.nvim_list_wins())
  table.sort(wins, function(a, b)
    return (vim.w[a].sidekick_visit or 0) > (vim.w[b].sidekick_visit or 0)
  end)
  local win = wins[1] or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  ---@type sidekick.context.ctx
  return {
    win = win,
    buf = buf,
    cwd = vim.fs.normalize(vim.fn.getcwd(win)),
    row = cursor[1],
    col = cursor[2] + 1,
    range = M.selection(buf),
  }
end

---@param buf? integer
---@return sidekick.context.Range?
function M.selection(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local kind = Util.exit_visual_mode()
  if not kind then
    return
  end
  local from = vim.api.nvim_buf_get_mark(buf, "<")
  local to = vim.api.nvim_buf_get_mark(buf, ">")
  if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
    from, to = to, from
  end

  ---@type sidekick.context.Range
  local ret = {
    from = { from[1], from[2] },
    to = { to[1], to[2] },
    kind = kind,
  }
  vim.fn.feedkeys("gv", "nx") -- restore visual selection
  return ret
end

M.get = C.new

return M
