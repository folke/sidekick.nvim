local M = {}

---@class sidekick.context.ctx
---@field buf integer
---@field win integer

---@class sidekick.context.location.Opts
local location_defaults = {
  row = true,
  col = true,
  range = true,
}

---@class sidekick.context.diagnostics.Opts: vim.diagnostic.GetOpts
local diagnostics_defaults = {
  all = false,
}

---@class sidekick.context.Opts
---@field buf? number
---@field diagnostics? sidekick.context.diagnostics.Opts|boolean
---@field location? sidekick.context.location.Opts|boolean
local context_defaults = {
  diagnostics = nil,
  location = {},
}

---@param opts sidekick.context.Opts
function M.get(opts)
  opts = vim.tbl_extend("force", {}, context_defaults, opts or {})
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].sidekick_cli then
    local info = vim.fn.getbufinfo({ buflisted = true, bufloaded = true })
    ---@param b vim.fn.getbufinfo.ret.item
    info = vim.tbl_filter(function(b)
      return not vim.b[b.bufnr].sidekick_cli
    end, info)
    -- sort all by lastused of the win buffer
    table.sort(info, function(a, b)
      if (a.hidden == 0) ~= (b.hidden == 0) then
        return a.hidden == 0
      end
      return a.lastused < b.lastused
    end)
    if not info[1] then
      return {}
    end
    buf = info[1].bufnr
  end
  local ret = {} ---@type string[]
  if opts.location then
    ret[#ret + 1] = M.get_location(buf, opts.location == true and {} or opts.location)
  end
  if opts.diagnostics then
    ret[#ret + 1] = M.get_diagnostics(buf, opts.diagnostics == true and {} or opts.diagnostics)
  end
  return ret
end

local CTRL_V = vim.keycode("<C-V>")

local function resolve_name(opts)
  local buf = opts.buf
  local name = opts.name
  name = name or buf and vim.api.nvim_buf_get_name(buf)

  if not name or name == "" then
    return "[No Name]"
  end
  local cwd = vim.uv.cwd()
  if cwd then
    local ok, rel = pcall(vim.fs.relpath, cwd, name)
    if ok and rel and rel ~= "" and rel ~= "." then
      return rel
    end
  end
  return name
end

---@class sidekick.context.Location
---@field buf? integer
---@field name? string
---@field row? integer (1-based)
---@field col? integer (0-based)
---@field range? {from: sidekick.Pos, to: sidekick.Pos, kind: "line"|"char"} (1,0)-based

---@param opts? sidekick.context.Location
function M.format_location(opts)
  opts = opts or {}
  assert(opts.buf or opts.name, "Either buf or name must be provided")

  local fname = resolve_name(opts)
  local loc = ""
  if opts.range then
    local from, to = opts.range.from, opts.range.to
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end

    if opts.range.kind == "line" and from[1] == to[1] then
      loc = ("%d"):format(from[1])
    elseif opts.range.kind == "line" then
      loc = ("%d-%d"):format(from[1], to[1])
    elseif opts.range.kind == "char" and from[1] == to[1] then
      loc = ("%d:%d-%d"):format(from[1], from[2] + 1, to[2] + 1)
    elseif opts.range.kind == "char" then
      loc = ("%d:%d-%d:%d"):format(from[1], from[2] + 1, to[1], to[2] + 1)
    end
  elseif opts.row and opts.col then
    loc = ("%d:%d"):format(opts.row, opts.col + 1)
  elseif opts.row then
    loc = ("%d"):format(opts.row)
  end
  if loc == "" then
    return ("@%s"):format(fname)
  end
  return ("@%s:%s"):format(fname, loc)
end

---@param buf? integer
---@param opts? sidekick.context.location.Opts
function M.get_location(buf, opts)
  opts = vim.tbl_extend("force", {}, location_defaults, opts or {})
  buf = buf or vim.api.nvim_get_current_buf()
  ---@type sidekick.context.Location
  local ctx = {
    buf = buf,
    row = opts.row and vim.fn.line(".") or nil,
    col = opts.row and opts.col and vim.fn.col(".") - 1 or nil,
  }

  local mode = opts.range and vim.fn.mode() or ""
  if mode:match("^[vV]$") or mode == CTRL_V then
    vim.cmd("normal! " .. mode)

    local from = vim.api.nvim_buf_get_mark(buf, "<")
    local to = vim.api.nvim_buf_get_mark(buf, ">")
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end
    ctx.range = { from = { from[1], from[2] }, to = { to[1], to[2] }, kind = mode == "V" and "line" or "char" }
    vim.fn.feedkeys("gv", "nx") -- restore visual selection
  end
  return M.format_location(ctx), ctx
end

---@param buf? integer
---@param opts? sidekick.context.diagnostics.Opts
function M.get_diagnostics(buf, opts)
  opts = vim.tbl_extend("force", {}, diagnostics_defaults, opts or {})

  buf = buf or vim.api.nvim_get_current_buf()
  local diags = vim.diagnostic.get(opts.all == false and buf or nil, opts)
  if #diags == 0 then
    return
  end
  table.sort(diags, function(a, b)
    if a.lnum == b.lnum then
      return a.col < b.col
    end
    return a.lnum < b.lnum
  end)
  local ret = {} ---@type string[]
  for _, d in ipairs(diags) do
    local severity = d.severity and vim.diagnostic.severity[d.severity] or "UNKNOWN"
    local lnum = (d.lnum or 0) + 1
    local col = d.col or 0
    local end_lnum = (d.end_lnum or d.lnum or 0) + 1
    local end_col = d.end_col or d.col or 0

    ret[#ret + 1] = ("[%s] %s %s"):format(
      severity,
      d.message:gsub("\n", " "),
      M.format_location({
        buf = d.bufnr,
        range = {
          from = { lnum, col },
          to = { end_lnum, end_col },
          kind = "char",
        },
      })
    )
  end
  return table.concat(ret, "\n"), diags
end

return M
