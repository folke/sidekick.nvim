---@type sidekick.Picker
local M = {}

local typeMapFn = {
  -- MiniPick.builtin.files() deals with list of file paths
  ["string"] = function(value)
    return { name = value }
  end,
  -- MiniPick.builtin.buffers() deals with list of tables that include buffer number and file name
  ["table"] = function(value)
    return {
      name = value.text,
      bufnr = value.bufnr,
    }
  end,
}

---@param source string
---@param cb fun(items:sidekick.context.Loc[])
---@param opts? table
function M.open(source, cb, opts)
  local choose_marked_fn = M.action(cb)
  require("mini.pick").builtin[source]({}, {
    source = {
      choose = function(item)
        choose_marked_fn({ item })
      end,
      choose_marked = choose_marked_fn,
    },
  })
end

---@param cb fun(items:sidekick.context.Loc[])
---@return fun(items:any[])
function M.action(cb)
  return function(items)
    cb(vim.tbl_map(function(value)
      return typeMapFn[type(value)](value)
    end, items))
  end
end

return M
