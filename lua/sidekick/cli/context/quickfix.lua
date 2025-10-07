local Loc = require("sidekick.cli.context.location")
local TS = require("sidekick.treesitter")

local M = {}

local TYPE_HL = {
  E = "DiagnosticVirtualTextError",
  W = "DiagnosticVirtualTextWarn",
  I = "DiagnosticVirtualTextInfo",
  N = "DiagnosticVirtualTextInfo",
  H = "DiagnosticVirtualTextHint",
}

---@param cwd string
---@param item vim.quickfix.entry
---@return sidekick.Text?
local function format_location(cwd, item)
  local bufnr = item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) and item.bufnr or nil
  local name = item.filename
  if (not name or name == "") and bufnr then
    name = vim.api.nvim_buf_get_name(bufnr)
  end

  if name and name ~= "" then
    name = vim.fs.normalize(name)
  end

  if (not bufnr or vim.api.nvim_buf_get_name(bufnr) == "") and (not name or name == "") then
    return nil
  end

  local loc_ctx = {
    buf = bufnr,
    name = name,
    cwd = cwd,
  }

  local lnum = item.lnum or 0
  local col = item.col or 0

  if lnum > 0 then
    loc_ctx.row = lnum
    loc_ctx.col = col > 0 and col or nil
    loc_ctx.range = {
      from = { lnum, math.max(0, col - 1) },
      to = {
        (item.end_lnum and item.end_lnum > 0) and item.end_lnum or lnum,
        (item.end_col and item.end_col > 0) and (item.end_col - 1) or math.max(0, col - 1),
      },
      kind = "char",
    }
  end

  local loc = Loc.get(loc_ctx, { kind = loc_ctx.range and "position" or "file" })
  return loc and loc[1] or nil
end

---@param ctx sidekick.context.ctx?
---@return sidekick.Text[]|nil
function M.get(ctx)
  local info = vim.fn.getqflist({ items = 0, title = 0 }) --[[@as {items:vim.quickfix.entry[], title:string}]]
  local items = info.items or {}
  if vim.tbl_isempty(items) then
    return
  end

  local cwd = ctx and ctx.cwd or vim.fs.normalize(vim.fn.getcwd())

  local ret = {} ---@type sidekick.Text[]
  local title = info.title or ""
  if title:match("^:%S") then
    title = ""
  end

  if title ~= "" then
    ret[#ret + 1] = { { ("Quickfix: %s"):format(title), "Title" } }
  end

  for _, item in ipairs(items) do
    local location = format_location(cwd, item)
    local vt = location and vim.deepcopy(location) or { { "@", "Bold" }, { "[No Name]", "SnacksPickerDir" } }
    table.insert(vt, 1, { "- ", "@markup.list.markdown" })

    local qtype = item.type and item.type ~= "" and item.type:upper() or nil
    if qtype then
      vt[#vt + 1] = { " " }
      vt[#vt + 1] = { ("[%s]"):format(qtype), TYPE_HL[qtype] or "DiagnosticVirtualTextInfo" }
    end

    local message = item.text or ""
    message = message:gsub("%s+$", "")

    local msg_lines = message ~= "" and TS.get_virtual_lines(message, { ft = "markdown_inline" }) or {}
    ---@type sidekick.Text[]?
    local followups

    if msg_lines and #msg_lines > 0 then
      vt[#vt + 1] = { " " }
      vim.list_extend(vt, msg_lines[1])
      followups = {}
      for i = 2, #msg_lines do
        local extra = { { "  " } }
        vim.list_extend(extra, msg_lines[i])
        followups[#followups + 1] = extra
      end
    elseif message ~= "" then
      vt[#vt + 1] = { " " .. message }
    end

    ret[#ret + 1] = vt
    if followups then
      vim.list_extend(ret, followups)
    end
  end

  return ret
end

return M
