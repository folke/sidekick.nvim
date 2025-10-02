local M = {}

---@param msg string
---@param level? vim.log.levels
function M.notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Sidekick" })
  end)
end

---@param msg string
function M.info(msg)
  M.notify(msg, vim.log.levels.INFO)
end

---@param msg string
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

---@param msg string
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

---@param msg string
function M.debug(msg)
  if require("sidekick.config").debug then
    M.warn(msg)
  end
end

---@generic T
---@param fn T
---@param ms? number
---@return T
function M.debounce(fn, ms)
  local timer = assert(vim.uv.new_timer())
  return function()
    timer:start(ms or 20, 0, vim.schedule_wrap(fn))
  end
end

--- @param buffer integer Buffer id, or 0 for current buffer
--- @param ns_id integer Namespace id from `nvim_create_namespace()`
--- @param row integer Line where to place the mark, 0-based. `api-indexing`
--- @param col integer Column where to place the mark, 0-based. `api-indexing`
--- @param opts vim.api.keyset.set_extmark Optional parameters.
function M.set_extmark(buffer, ns_id, row, col, opts)
  -- opts.strict = false
  local ok, ret = pcall(vim.api.nvim_buf_set_extmark, buffer, ns_id, row, col, opts or {})
  if not ok then
    local e = vim.deepcopy(opts) --[[@as sidekick.Extmark]]
    e.row, e.col = row, col
    M.error("Failed to set extmark: " .. ret .. "\n```lua\n" .. vim.inspect(e) .. "\n```")
    return nil
  end
  return ret
end

--- Exit visual mode if in visual mode, and return the type of visual mode exited.
function M.exit_visual_mode()
  local kind, mode = M.visual_mode()
  if not mode then
    return
  end
  vim.cmd("normal! " .. mode)
  return kind, mode
end

--- Exit visual mode if in visual mode, and return the type of visual mode exited.
---@return sidekick.VisualMode?, string?
function M.visual_mode()
  ---@alias sidekick.VisualMode "char"|"line"|"block"
  local mode = vim.fn.mode()
  if not (mode:match("^[vV]$") or mode == "\22") then
    return
  end
  return (mode == "V" and "line" or mode == "v" and "char" or "block"), mode
end

---@param str string
function M.width(str)
  str = str:gsub("\t", string.rep(" ", vim.o.tabstop))
  return vim.api.nvim_strwidth(str)
end

--- UTF-8 aware word splitting. See |keyword|
---@param str string
function M.split_words(str)
  if str == "" then
    return {}
  end

  local ret = {} ---@type string[]
  local word = {} ---@type string[]
  local starts = vim.str_utf_pos(str)

  local function flush()
    if #word > 0 then
      ret[#ret + 1] = table.concat(word)
      word = {}
    end
  end

  for idx, start in ipairs(starts) do
    local stop = (starts[idx + 1] or (#str + 1)) - 1
    local ch = str:sub(start, stop)
    if vim.fn.charclass(ch) == 2 then -- iskeyword
      word[#word + 1] = ch
    else
      flush()
      ret[#ret + 1] = ch
    end
  end

  flush()
  return ret
end

--- UTF-8 aware character splitting
---@param str string
function M.split_chars(str)
  if str == "" then
    return {}
  end

  local ret = {} ---@type string[]
  local starts = vim.str_utf_pos(str)
  for i = 1, #starts - 1 do
    table.insert(ret, str:sub(starts[i], starts[i + 1] - 1))
  end
  table.insert(ret, str:sub(starts[#starts], #str))
  return ret
end

function M.deprecate(deprecated, replacement)
  M.warn(("`%s` is deprecated.\nPlease use `%s` instead."):format(deprecated, replacement))
end

return M
