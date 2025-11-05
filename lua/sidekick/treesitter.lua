local M = {}

M._scratch_buf = nil ---@type number?

---@param source string
function M.scratch_buf(source)
  if not (M._scratch_buf and vim.api.nvim_buf_is_valid(M._scratch_buf)) then
    M._scratch_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M._scratch_buf, "sidekick://highlight")
  end
  vim.bo[M._scratch_buf].fixeol = false
  vim.bo[M._scratch_buf].eol = false
  vim.api.nvim_buf_set_lines(M._scratch_buf, 0, -1, false, vim.split(source, "\n", { plain = true }))
  return M._scratch_buf
end

---@param source string|number
---@param opts? {ft:string, start_row?: integer, end_row?: integer, bg?: string}
---@return sidekick.Text[]
function M.get_virtual_lines(source, opts)
  opts = opts or {}

  local lines = type(source) == "number"
      and vim.api.nvim_buf_get_lines(source, opts.start_row or 0, opts.end_row or -1, false)
    or vim.split(source --[[@as string]], "\n")

  local extmarks = M.get_extmarks(source, opts)
  if not extmarks then
    return vim.tbl_map(function(line)
      return { { line } }
    end, lines)
  end

  local index = {} ---@type table<number, table<number, string>>
  for _, e in ipairs(extmarks) do
    e.row = e.row - (opts.start_row and opts.start_row or 0)
    if e.hl_group and e.end_col then
      index[e.row] = index[e.row] or {}
      for i = e.col + 1, e.end_col do
        index[e.row][i] = e.hl_group
      end
    end
  end

  local ret = {} ---@type sidekick.Text[]
  for i = 1, #lines do
    local line = lines[i]
    local from = 0
    local hl_group = nil ---@type string?

    ---@param to number
    local function add(to)
      if to >= from then
        ret[i] = ret[i] or {}
        local text = line:sub(from, to)
        local hl = opts.bg and { hl_group or "Normal", opts.bg } or hl_group
        if #text > 0 then
          table.insert(ret[i], { text, hl })
        end
      end
      from = to + 1
      hl_group = nil
    end

    for col = 1, #line do
      local hl = index[i] and index[i][col]
      if hl ~= hl_group then
        add(col - 1)
        hl_group = hl
      end
    end
    add(#line)
  end
  return ret
end

--- Highlight leading/trailing whitespace and EOL in virtual lines
---@param virtual_lines sidekick.Text[]
---@param opts? {leading?:string, trailing?:string, block?:string, width?:number}
function M.highlight_block(virtual_lines, opts)
  if #virtual_lines == 0 then
    return virtual_lines
  end
  opts = opts or {}
  local indent = -1
  local len = 0
  local ts = vim.o.tabstop
  local lengths = {} ---@type table<number, number>

  ---@param str string
  local function sw(str)
    return vim.api.nvim_strwidth(str)
  end

  for l, vt in ipairs(virtual_lines) do
    local line_len = 0
    for c, chunk in ipairs(vt) do
      -- normalize tabs
      chunk[1] = chunk[1]:gsub("\t", string.rep(" ", ts))
      line_len = line_len + sw(chunk[1])
      if c == 1 then
        local ws = chunk[1]:match("^%s*") ---@type string?
        if ws then
          indent = indent == -1 and #ws or math.min(indent, #ws)
        end
      end
    end
    lengths[l] = line_len
    len = math.max(len, line_len)
  end
  len = opts.width or len

  for l, vt in ipairs(virtual_lines) do
    local line_len = lengths[l]
    if opts.block and line_len < len then
      table.insert(vt, { string.rep(" ", len - line_len), opts.block })
    end
    if opts.trailing then
      table.insert(vt, { string.rep(" ", vim.o.columns), opts.trailing })
    end
    if opts.leading and indent > 0 then
      local chunk = vt[1]
      chunk[1] = chunk[1]:sub(indent + 1)
      if #chunk[1] == 0 then
        vt[1] = { string.rep(" ", indent), opts.leading }
      else
        table.insert(vt, 1, { string.rep(" ", indent), opts.leading })
      end
    end
  end
  return virtual_lines
end

---@param source string|number
---@param opts? {ft:string, start_row?: integer, end_row?: integer}
function M.get_extmarks(source, opts)
  opts = opts or {}
  assert(type(source) == "number" or opts.ft, "Either buf or ft should be specified")

  local buf = type(source) == "number" and source or M.scratch_buf(source --[[@as string]])

  local lang = vim.treesitter.language.get_lang(opts.ft or vim.bo[buf].filetype)

  local parser ---@type vim.treesitter.LanguageTree?
  if lang then
    lang = lang:lower()
    local ok = false
    ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    parser = ok and parser or nil
  end

  if not parser then
    return
  end

  local ret = {} ---@type sidekick.Extmark[]
  local skips = { spell = true, nospell = true, conceal = true }

  parser:parse(true)
  parser:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local query = vim.treesitter.query.get(tree:lang(), "highlights")
    -- Some injected languages may not have highlight queries.
    if not query then
      return
    end

    for capture, node, metadata in query:iter_captures(tstree:root(), source, opts.start_row, opts.end_row) do
      ---@type string
      local name = query.captures[capture]
      if not skips[name] then
        local range = { node:range() } ---@type number[]
        local multi = range[1] ~= range[3]
        local text = multi
            and vim.split(vim.treesitter.get_node_text(node, source, metadata[capture]), "\n", { plain = true })
          or {}
        for row = range[1] + 1, range[3] + 1 do
          local first, last = row == range[1] + 1, row == range[3] + 1
          local end_col = last and range[4] or #(text[row - range[1]] or "")
          end_col = multi and first and end_col + range[2] or end_col
          ret[#ret + 1] = {
            row = row,
            col = first and range[2] or 0,
            end_col = end_col,
            priority = (tonumber(metadata.priority or metadata[capture] and metadata[capture].priority) or 100),
            conceal = metadata.conceal or metadata[capture] and metadata[capture].conceal,
            hl_group = "@" .. name .. "." .. lang,
          }
        end
      end
    end
  end)

  return ret
end

return M
