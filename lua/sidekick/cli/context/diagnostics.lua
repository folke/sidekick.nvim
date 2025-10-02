local Loc = require("sidekick.cli.context.location")

local M = {}

---@param ctx? sidekick.context.ctx
---@param opts? vim.diagnostic.GetOpts|{all?:boolean}
function M.get(ctx, opts)
  opts = opts or {}
  local diags = vim.diagnostic.get(opts.all ~= true and (ctx and ctx.buf) or nil, opts)
  if #diags == 0 then
    return
  end
  table.sort(diags, function(a, b)
    if a.lnum == b.lnum then
      return a.col < b.col
    end
    return a.lnum < b.lnum
  end)

  local ret = {} ---@type sidekick.Text[]

  for _, d in ipairs(diags) do
    local severity = d.severity and vim.diagnostic.severity[d.severity] or "UNKNOWN"
    local lnum = (d.lnum or 0) + 1
    local col = d.col or 0
    local end_lnum = (d.end_lnum or d.lnum or 0) + 1
    local end_col = d.end_col or d.col or 0

    local vt = {} ---@type sidekick.Text
    vt[#vt + 1] = {
      "[" .. severity .. "]",
      "DiagnosticVirtualText" .. severity:sub(1, 1):upper() .. severity:sub(2):lower(),
    }
    vt[#vt + 1] = { " " }

    local msg_text = (d.message or "")
    local msg = require("sidekick.treesitter").get_virtual_lines(msg_text, { ft = "markdown_inline" })
    for i, t in ipairs(msg) do
      if i > 1 then
        ret[#ret + 1] = vt
        vt = {}
      end
      vim.list_extend(vt, t)
    end

    local loc = Loc.get({
      row = lnum,
      col = col,
      cwd = ctx and ctx.cwd or vim.fs.normalize(vim.fn.getcwd()),
      buf = d.bufnr,
      range = {
        from = { lnum, col },
        to = { end_lnum, end_col },
        kind = "char",
      },
    })
    if loc[1] then
      vt[#vt + 1] = { " " }
      vim.list_extend(vt, loc[1])
    end

    ret[#ret + 1] = vt
  end

  return ret
end

return M
