local Config = require("sidekick.config")
local Context = require("sidekick.cli.context")

local M = {}

---@class sidekick.cli.Prompt
---@field cb fun(msg?:string)

---@param opts sidekick.cli.Prompt
function M.select(opts)
  assert(type(opts) == "table", "opts must be a table")
  local prompts = vim.tbl_keys(Config.cli.prompts) ---@type string[]
  table.sort(prompts)
  local context = Context.get()
  local test = Context.get()
  test.get = function(_, name)
    if name == "nl" then
      return { { { "\\n", "@string.escape" } } }
    end
    return { { { ("{%s}"):format(name), "Special" } } }
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  for _, name in ipairs(prompts) do
    local prompt = Config.cli.prompts[name] or {}
    prompt = type(prompt) == "string" and { msg = prompt } or prompt
    ---@cast prompt sidekick.Prompt
    prompt.msg = prompt.msg or ""
    local text, rendered = context:render({ prompt = name })
    if rendered and #rendered > 0 then
      local extmarks = {} ---@type snacks.picker.Extmark[]
      for l, line in ipairs(rendered) do
        local col = 0
        for _, hl in ipairs(line) do
          if hl[1] then
            if hl[2] then
              extmarks[#extmarks + 1] = {
                row = l,
                col = col,
                end_col = col + #hl[1],
                hl_group = hl[2],
              }
            end
            col = col + #hl[1]
          end
        end
      end
      ---@class sidekick.select_prompt.Item: snacks.picker.finder.Item
      items[#items + 1] = {
        text = name,
        data = text,
        name = name,
        prompt = prompt,
        preview = {
          text = text,
          extmarks = extmarks,
        },
      }
    end
  end

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    prompt = "Select a prompt",
    ---@param item sidekick.select_prompt.Item
    format_item = function(item, is_snacks)
      if is_snacks then
        local ret = {} ---@type snacks.picker.Highlight[]
        ret[#ret + 1] = { item.name, "Title" }
        ret[#ret + 1] = { string.rep(" ", 18 - #item.name) }
        local _, prompt = test:render({ msg = item.prompt.msg:gsub("\n", "{nl}"), this = false })
        vim.list_extend(ret, prompt and prompt[1] or {})
        return ret
      end
      return ("[%s] %s"):format(item.name, string.rep(" ", 18 - #item.name) .. item.prompt.msg)
    end,
    picker = {
      preview = "preview",
      layout = {
        preset = "vscode",
        min_height = 0.6,
        preview = true,
      },
      win = {
        input = {
          keys = {
            ["<c-y>"] = { "yank", mode = { "n", "i" } },
            ["y"] = { "yank" },
          },
        },
      },
    },
  }

  ---@param choice? sidekick.select_prompt.Item
  vim.ui.select(items, select_opts, function(choice)
    return opts.cb(choice and choice.preview.text or nil)
  end)
end

return M
