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

  local ret = {} ---@type sidekick.Text
  if opts.kind == "position" and ctx.range then
    local from, to = ctx.range.from, ctx.range.to
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end
    if ctx.range.kind == "line" and from[1] == to[1] then
      ret[#ret + 1] = { ("%d"):format(from[1]), "SnacksPickerRow" }
    elseif ctx.range.kind == "line" then
      ret[#ret + 1] = { ("%d-%d"):format(from[1], to[1]), "SnacksPickerRow" }
    elseif from[1] == to[1] then -- block/char on same line
      ret[#ret + 1] = { ("%d"):format(from[1]), "SnacksPickerRow" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { ("%d-%d"):format(from[2] + 1, to[2] + 1), "SnacksPickerCol" }
    else -- block/char on different lines
      ret[#ret + 1] = { ("%d"):format(from[1]), "SnacksPickerRow" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { ("%d-%d:%d"):format(from[2] + 1, to[1], to[2] + 1), "SnacksPickerCol" }
    end
  elseif opts.kind == "position" and ctx.row and ctx.col then
    ret[#ret + 1] = { ("%d"):format(ctx.row), "SnacksPickerRow" }
    ret[#ret + 1] = { ":", "SnacksPickerDelim" }
    ret[#ret + 1] = { ("%d"):format(ctx.col), "SnacksPickerCol" }
  elseif (opts.kind == "position" or opts.kind == "line") and ctx.row then
    ret[#ret + 1] = { ("%d"):format(ctx.row), "SnacksPickerRow" }
  end

  if #ret > 0 then
    table.insert(ret, 1, { ":", "SnacksPickerDelim" })
  end
  table.insert(ret, 1, { name, "SnacksPickerDir" })
  table.insert(ret, 1, { "@", "Bold" })
  return { ret }
end

---@param buf integer
function M.is_file(buf)
  return vim.bo[buf].buflisted
    and vim.tbl_contains({ "", "help" }, vim.bo[buf].buftype)
    and vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) == 1
end

return M
