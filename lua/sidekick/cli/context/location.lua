local M = {}

---@param ctx sidekick.context.ctx|{name?: string}
---@param opts? {kind?: "file"|"line"|"position"}
---@return sidekick.Text[]
function M.get(ctx, opts)
  opts = opts or {}
  opts.kind = opts.kind or "position"
  assert(ctx.buf or ctx.name, "Either buf or name must be provided")

  local name = ctx.name or vim.api.nvim_buf_get_name(ctx.buf)
  if not name or name == "" then
    name = "[No Name]"
  else
    local ok, rel = pcall(vim.fs.relpath, ctx.cwd, name)
    if ok and rel and rel ~= "" and rel ~= "." then
      name = rel
    end
  end

  local from = ctx.range and ctx.range.from or { ctx.row, ctx.col }
  local to = ctx.range and ctx.range.to or nil

  -- normalize order
  if from and to then
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end
  end

  local ret = {} ---@type sidekick.Text

  ---@param ... string|number
  local function add(...)
    for _, v in ipairs({ ... }) do
      if type(v) == "number" then
        ret[#ret + 1] = { tostring(v), "SidekickLocNum" }
      elseif v == "L" then
        ret[#ret + 1] = { v, "SidekickLocRow" }
      elseif v == "C" then
        ret[#ret + 1] = { v, "SidekickLocCol" }
      else
        ret[#ret + 1] = { v, "SidekickLocDelim" }
      end
    end
  end

  add(" ")
  add("@")
  ret[#ret + 1] = { name, "SidekickLocFile" }

  if opts.kind == "line" or (ctx.range and ctx.range.kind == "line") then
    add(" ")
    add(":", "L", from[1])
    if to and from[1] ~= to[1] then
      add("-", "L", to[1])
    end
  elseif opts.kind == "position" then
    add(" ")
    if to and from[1] == to[1] and from[2] ~= to[2] then
      add(":", "L", from[1], ":", "C", from[2] + 1, "-", "C", to[2] + 1)
    elseif to and from[2] ~= to[2] then
      add(":", "L", from[1], ":", "C", from[2] + 1, "-", "L", to[1], ":", "C", to[2] + 1)
    else
      add(":", "L", from[1], ":", "C", from[2] + 1)
    end
  end
  add(" ")

  return { ret }
end

---@param buf integer
function M.is_file(buf)
  return vim.bo[buf].buflisted
    and vim.tbl_contains({ "", "help" }, vim.bo[buf].buftype)
    and vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) == 1
end

return M
