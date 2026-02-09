local Config = require("sidekick.config")
local TS = require("sidekick.treesitter")
local Text = require("sidekick.text")
local Util = require("sidekick.util")

local M = {}

local INLINE_MAX_LINES = 3
local INLINE_MAX_INSERT_RATIO = 0.5

---@type vim.text.diff.Opts
local DIFF_OPTS = {
  algorithm = "patience",
  ctxlen = 0,
  indent_heuristic = true,
  interhunkctxlen = 0,
  linematch = 10,
  result_type = "indices",
}

---@type vim.text.diff.Opts
local DIFF_INLINE_OPTS = {
  algorithm = "minimal",
  ctxlen = 0,
  indent_heuristic = false,
  interhunkctxlen = 4,
  linematch = 0,
  result_type = "indices",
}

---@alias sidekick.DiffText {text: string, lines: string[], virt_lines: sidekick.Text[]}

---@class sidekick.Diff
---@field range {from: sidekick.Pos, to: sidekick.Pos}
---@field hunks sidekick.diff.Hunk[]
---@field from sidekick.DiffText
---@field to sidekick.DiffText

---@class sidekick.diff.Hunk
---@field pos sidekick.Pos
---@field cover integer the number of lines covered in the "from" text
---@field kind "add" | "delete" | "change"
---@field inline? boolean
---@field extmarks sidekick.Extmark[]

--- Calculate the result covering full lines
---@param edit sidekick.NesEdit
function M.parse_edit(edit)
  local lines = vim.api.nvim_buf_get_lines(edit.buf, edit.from[1], edit.to[1] + 1, false)
  if #lines == 0 then
    lines = { "" }
  end
  local first, last = lines[1] or "", lines[#lines] or ""
  return table.concat(lines, "\n"), first:sub(1, edit.from[2]) .. edit.text .. last:sub(edit.to[2] + 1)
end

---@param a string[]
---@param b string[]
---@param opts vim.text.diff.Opts
function M._diff(a, b, opts)
  local txt_a = table.concat(a, "\n")
  local txt_b = table.concat(b, "\n")
  if txt_a ~= "" then
    txt_a = txt_a .. "\n"
  end
  if txt_b ~= "" then
    txt_b = txt_b .. "\n"
  end
  ---@diagnostic disable-next-line: deprecated
  return (vim.text.diff or vim.diff)(txt_a, txt_b, opts) --[[@as (integer[][])]]
end

---@param edit sidekick.NesEdit
function M.diff(edit)
  local from_text, to_text = M.parse_edit(edit)
  local to_lines = vim.split(to_text, "\n", { plain = true })
  local from_lines = vim.split(from_text, "\n", { plain = true })

  ---@type sidekick.Diff
  local ret = {
    hunks = {},
    range = { from = edit.from, to = edit.to },
    from = {
      text = from_text,
      lines = from_lines,
      virt_lines = TS.get_virtual_lines(from_text, {
        ft = vim.bo[edit.buf].filetype,
      }),
    },
    to = {
      text = to_text,
      lines = to_lines,
      virt_lines = TS.get_virtual_lines(to_text, {
        ft = vim.bo[edit.buf].filetype,
        bg = "SidekickDiffAdd",
      }),
    },
  }

  M.diff_lines(ret)
  return ret
end

---@param diff sidekick.Diff
function M.diff_lines(diff)
  local hunks = M._diff(diff.from.lines, diff.to.lines, DIFF_OPTS)
  local dels = {} ---@type table<integer, {hunk: sidekick.diff.Hunk}>
  local adds = {} ---@type table<integer, {hunk: sidekick.diff.Hunk, virt_lines: sidekick.Text[]}>

  local width = 0
  for _, hunk in ipairs(hunks) do
    local ai, ac, bi, bc = unpack(hunk)

    local inline_hunks = {} ---@type sidekick.diff.Hunk[]
    if Config.nes.diff.inline and ac == bc and ac >= 1 and ac <= INLINE_MAX_LINES then
      for i = 0, ac - 1 do
        local line_hunks = M.diff_inline(diff, ai + i, bi + i)
        if not line_hunks then
          inline_hunks = {}
          break
        end
        vim.list_extend(inline_hunks, line_hunks)
      end
    end

    if #inline_hunks > 0 then
      vim.list_extend(diff.hunks, inline_hunks)
    else
      local row = math.max(diff.range.from[1] + ai - 1, 0)
      ---@type sidekick.diff.Hunk
      local h = {
        kind = ac > 0 and bc > 0 and "change" or ac > 0 and "delete" or "add",
        pos = { row, 0 },
        cover = ac,
        extmarks = {},
      }
      table.insert(diff.hunks, h)
      if ac > 0 then
        for l = 0, ac - 1 do
          dels[row + l] = { hunk = h }
          width = math.max(width, Util.width(diff.from.lines[ai + l] or ""))
        end
      end
      if bc > 0 then
        local virt_lines = vim.list_slice(diff.to.virt_lines, bi, bi + bc - 1)
        width = math.max(width, Text.lines_width(virt_lines))
        adds[row + (ac > 0 and ac - 1 or 0)] = { hunk = h, virt_lines = virt_lines }
      end
    end
  end

  for row, info in pairs(dels) do
    table.insert(info.hunk.extmarks, {
      row = row,
      col = 0,
      virt_text_win_col = width + 1,
      virt_text = { { string.rep(" ", vim.o.columns), "SidekickDiffContext" } },
      line_hl_group = "SidekickDiffDelete",
    })
  end

  for row, info in pairs(adds) do
    table.insert(info.hunk.extmarks, {
      row = row,
      col = 0,
      hl_eol = true,
      virt_lines = TS.highlight_block(info.virt_lines, {
        leading = "SidekickDiffContext",
        trailing = "SidekickDiffContext",
        block = "SidekickDiffAdd",
        width = width + 1,
      }),
    })
  end
end

---@param line_idx integer
---@param vl_all sidekick.Text[]
function M._index(line_idx, vl_all)
  local toks = {} ---@type string[]
  local vt = {} ---@type sidekick.Text
  local index = {} ---@type table<integer, {col: integer, end_col: integer}>
  index[0] = { col = 0, end_col = 0 } -- needed for insertions before the first token
  for _, t in ipairs(vl_all[line_idx] or {}) do
    local parts = Config.nes.diff.inline == "words" and Util.split_words(t[1]) or Util.split_chars(t[1])
    for _, p in ipairs(parts) do
      local idx = #toks + 1
      toks[idx] = p
      vt[idx] = { p, t[2] }
      index[idx] = { col = index[idx - 1].end_col, end_col = index[idx - 1].end_col + #p }
    end
  end
  -- needed for insertions after the last token
  index[#toks + 1] = { col = index[#index].end_col, end_col = index[#index].end_col }
  setmetatable(index, {
    __index = function()
      return index[#index]
    end,
  })
  return toks, index, vt
end

---@param diff sidekick.Diff
---@param from_idx integer
---@param to_idx integer
---@return sidekick.diff.Hunk[]?
function M.diff_inline(diff, from_idx, to_idx)
  local a_toks, a_index = M._index(from_idx, diff.from.virt_lines)
  local b_toks, b_index, b_vl = M._index(to_idx, diff.to.virt_lines)

  local hunks = M._diff(a_toks, b_toks, DIFF_INLINE_OPTS)
  if #hunks == 0 then
    return {}
  end

  local ret = {} ---@type sidekick.diff.Hunk[]
  local row = diff.range.from[1] + from_idx - 1
  local delete_len, insert_len = 0, 0

  for _, token_hunk in ipairs(hunks) do
    local ai, ac, bi, bc = unpack(token_hunk)
    local a_from = a_index[ai]
    ---@type sidekick.diff.Hunk
    local h = {
      kind = ac > 0 and bc > 0 and "change" or ac > 0 and "delete" or "add",
      pos = { row, a_from.col },
      cover = 1,
      inline = true,
      extmarks = {},
    }

    if ac > 0 then
      local a_to = a_index[ai + ac - 1]
      delete_len = delete_len + a_to.end_col - a_from.col
      table.insert(h.extmarks, {
        row = row,
        col = a_from.col,
        end_col = a_to.end_col,
        hl_group = "SidekickDiffDelete",
      })
    end

    if bc > 0 then
      insert_len = insert_len + b_index[bi + bc - 1].end_col - b_index[bi].col
      local col = ac > 0 and a_index[ai + ac - 1].end_col or a_from.end_col
      table.insert(h.extmarks, {
        row = row,
        col = col,
        virt_text_pos = "inline",
        virt_text = vim.list_slice(b_vl, bi, bi + bc - 1),
      })
    end
    table.insert(ret, h)
  end

  local new_len = #(diff.to.lines[to_idx] or "")
  local insert_ratio = insert_len / new_len
  return insert_ratio < INLINE_MAX_INSERT_RATIO and ret or nil
end

return M
