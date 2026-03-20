---@module 'snacks'

local Config = require("sidekick.config")
local Context = require("sidekick.cli.context")

local M = {}

---@param opts sidekick.cli.PromptOpts
function M.select(opts)
  assert(type(opts) == "table", "opts must be a table")
  local prompts = vim.tbl_keys(Config.cli.prompts) ---@type string[]
  table.sort(prompts)
  local context = Context.get(opts.cwd)

  ---@param msg string
  local function tpl(msg)
    msg = msg:gsub("\n", "{nl}")
    local parts = require("sidekick.text").split(msg, "%b{}")
    ---@param part string
    return vim.tbl_map(function(part)
      if part == "{nl}" then
        return { "\\n", "@string.escape" }
      elseif part:match("^%b{}$") then
        return { part, "Special" }
      end
      return { part }
    end, parts)
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  for _, name in ipairs(prompts) do
    local prompt = Config.cli.prompts[name] or {}
    prompt = type(prompt) == "string" and { msg = prompt } or prompt
    prompt = type(prompt) == "function" and { msg = "[function]" } or prompt

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
        rendered = rendered,
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
    kind = "sidekick_prompt",
    ---@param item sidekick.select_prompt.Item
    format_item = function(item)
      return ("[%s] %s"):format(item.name, string.rep(" ", 18 - #item.name) .. item.prompt.msg)
    end,
    snacks = {
      format = function(item)
        local ret = {} ---@type snacks.picker.Highlight[]
        ret[#ret + 1] = { item.name, "Title" }
        ret[#ret + 1] = { string.rep(" ", 18 - #item.name) }
        vim.list_extend(ret, tpl(item.prompt.msg))
        return ret
      end,
      preview = "preview",
      layout = {
        preset = "vscode",
        hidden = {},
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
    if not choice then
      return opts.cb()
    end
    return opts.cb(choice.preview.text, choice.rendered)
  end)
end

return M
