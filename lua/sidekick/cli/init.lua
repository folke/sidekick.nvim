local Config = require("sidekick.config")
local Session = require("sidekick.cli.session")
local Terminal = require("sidekick.cli.terminal")
local Util = require("sidekick.util")

local M = {}

---@alias sidekick.Prompt string | sidekick.Context | fun(ctx?: sidekick.context.ctx): (sidekick.Context|string)

---@class sidekick.cli.Tool.spec
---@field cmd string[] Command to run the CLI tool
---@field env? table<string, string> Environment variables to set when running the command
---@field close_on_exit? boolean default is true. Close the terminal when the command exits
---@field url? string Web URL to open when the tool is not installed
---@field keys? table<string, sidekick.cli.Keymap|false>

---@class sidekick.cli.Tool: sidekick.cli.Tool.spec
---@field name string
---@field installed? boolean
---@field running? boolean
---@field mux? boolean
---@field session? sidekick.cli.Session

---@class sidekick.cli.Filter
---@field name? string
---@field session? string
---@field installed? boolean
---@field running? boolean
---@field cwd? boolean

---@class sidekick.cli.With
---@field filter? sidekick.cli.Filter
---@field create? boolean
---@field all? boolean

---@class sidekick.cli.Show
---@field name? string
---@field focus? boolean
---@field filter? sidekick.cli.Filter
---@field on_show? fun(terminal: sidekick.cli.Terminal)

---@class sidekick.cli.Hide
---@field name? string
---@field all? boolean

---@class sidekick.cli.Select: sidekick.cli.With
---@field on_select? fun(t:sidekick.cli.Tool)
---@field auto? boolean Automatically select if only one tool matches the filter

---@class sidekick.cli.Send: sidekick.cli.Show,sidekick.Context
---@field submit? boolean

--- Keymap options similar to `vim.keymap.set` and `lazy.nvim` mappings
---@class sidekick.cli.Keymap: vim.keymap.set.Opts
---@field [1] string keymap
---@field [2] string|sidekick.cli.Action
---@field mode? string|string[]

---@param opts? sidekick.cli.Select
function M.select(opts)
  opts = opts or {}
  local tools = M.get_tools(opts.filter)

  ---@param tool? sidekick.cli.Tool
  local on_select = function(tool)
    if tool then
      if not tool.installed then
        if tool.url then
          local ok, err = vim.ui.open(tool.url)
          if ok then
            Util.info(("Opening %s in your browser..."):format(tool.url))
          else
            Util.error(("Failed to open %s: %s"):format(tool.url, err))
          end
        else
          Util.error(("Tool `%s` is not installed"):format(tool.name))
        end
        return
      end
      if opts.on_select then
        return opts.on_select(tool)
      end
      M.show({
        filter = { name = tool.name, session = tool.session and tool.session.id or nil },
        focus = opts.focus,
      })
    end
  end

  if #tools == 0 then
    Util.warn("No tools match the given filter")
    return
  elseif #tools == 1 and opts.auto then
    on_select(tools[1])
    return
  end

  ---@param tool sidekick.cli.Tool|snacks.picker.Item
  ---@param picker? snacks.Picker
  local format = function(tool, picker)
    local sw = vim.api.nvim_strwidth
    local ret = {} ---@type snacks.picker.Highlight[]
    if picker then
      local count = picker:count()
      local idx = tostring(tool.idx)
      idx = (" "):rep(#tostring(count) - #idx) .. idx
      ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }
      ret[#ret + 1] = { " " }
    end
    ret[#ret + 1] = { tool.installed and "✅" or "❌" }
    ret[#ret + 1] = { " " }
    ret[#ret + 1] = { tool.name }
    local len = sw(tool.name) + 2
    if tool.mux then
      local backend = ("[%s]"):format(Config.cli.mux.backend)
      ret[#ret + 1] = { string.rep(" ", 12 - len) }
      ret[#ret + 1] = { backend, "Special" }
      len = 12 + sw(backend)
    elseif tool.running then
      ret[#ret + 1] = { string.rep(" ", 12 - len) }
      ret[#ret + 1] = { "[running]", "Special" }
      len = 12 + sw("[running]")
    end
    if tool.session then
      ret[#ret + 1] = { string.rep(" ", 22 - len) }
      if picker then
        local item = vim.deepcopy(tool) --[[@as snacks.picker.Item]]
        item.file = tool.session.cwd
        item.dir = true
        vim.list_extend(ret, require("snacks").picker.format.filename(item, picker))
      else
        ret[#ret + 1] = { vim.fn.fnamemodify(tool.session.cwd, ":p:~"), "Directory" }
      end
    end
    return ret
  end

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    prompt = "Select CLI tool:",
    picker = {
      format = format,
    },
    kind = "snacks",
    ---@param tool sidekick.cli.Tool
    format_item = function(tool, is_snacks)
      local parts = format(tool)
      return is_snacks and parts or table.concat(vim.tbl_map(function(p)
        return p[1]
      end, parts))
    end,
  }

  vim.ui.select(tools, select_opts, on_select)
end

---@param t sidekick.cli.Terminal|sidekick.cli.Tool
---@param filter? sidekick.cli.Filter
function M.is(t, filter)
  filter = filter or {}
  t = getmetatable(t) == Terminal and t.tool or t
  ---@cast t sidekick.cli.Tool
  local terminal = t.session and Terminal.get(t.session.id)
  return (filter.name == nil or filter.name == t.name)
    and (filter.installed == nil or filter.installed == t.installed)
    and (filter.session == nil or (t.session and t.session.id == filter.session))
    and (filter.running == nil or filter.running == (terminal and terminal:is_running()))
    and (filter.cwd == nil or (t.session and t.session.cwd == Session.cwd()))
end

---@param filter? sidekick.cli.Filter
---@return sidekick.cli.Tool[]
function M.get_tools(filter)
  local Mux = require("sidekick.cli.mux")
  local all = {} ---@type sidekick.cli.Tool[]

  local sessions = Mux.sessions()
  for id, session in pairs(Terminal.sessions()) do
    sessions[id] = session
  end

  for _, session in pairs(sessions) do
    local t = vim.deepcopy(Config.cli.tools[session.tool]) --[[@as sidekick.cli.Tool?]]
    if t then
      t.name = session.tool
      t.session = session
      t.installed = true
      t.running = session.mux == nil
      t.mux = session.mux ~= nil
      all[#all + 1] = t
    end
  end

  for name, tool in pairs(vim.deepcopy(Config.cli.tools)) do
    ---@cast tool sidekick.cli.Tool
    tool.name = name
    local id = Session.new(tool).id
    if not sessions[id] then
      tool.installed = vim.fn.executable(tool.cmd[1]) == 1
      tool.running = false
      tool.mux = false
      all[#all + 1] = tool
    end
  end

  local cwd = Session.cwd()

  ---@type sidekick.cli.Tool[]
  ---@param t sidekick.cli.Tool
  local ret = vim.tbl_filter(function(t)
    return M.is(t, filter)
  end, all)
  table.sort(ret, function(a, b)
    if a.installed ~= b.installed then
      return a.installed
    end
    if a.running ~= b.running then
      return a.running
    end
    -- sessions in cwd, or tools without a session
    local a_cwd = (not a.session or a.session.cwd == cwd or false)
    local b_cwd = (not b.session or b.session.cwd == cwd or false)
    if a_cwd ~= b_cwd then
      return a_cwd
    end
    if a.mux ~= b.mux then
      return a.mux
    end
    return a.name < b.name
  end)
  return ret
end

---@param filter? sidekick.cli.Filter
function M.get_terminals(filter)
  ---@param t sidekick.cli.Terminal
  local ret = vim.tbl_filter(function(t)
    return M.is(t, filter)
  end, Terminal.terminals) --[[@as sidekick.cli.Terminal[] ]]
  table.sort(ret, function(a, b)
    return a.atime > b.atime
  end)
  return ret
end

---@param cb fun(terminal: sidekick.cli.Terminal)
---@param opts? sidekick.cli.With
function M.with(cb, opts)
  opts = opts or {}
  cb = vim.schedule_wrap(cb)
  local terminals = M.get_terminals(opts.filter)
  terminals = opts.all and terminals or { terminals[1] }
  if #terminals == 0 and opts.create then
    M.select({
      auto = true,
      filter = opts.filter,
      on_select = function(tool)
        if vim.fn.executable(tool.cmd[1]) == 0 then
          Util.error(("`%s` is not installed"):format(tool.cmd[1]))
          return
        end
        cb(Terminal.new(tool))
      end,
    })
  else
    vim.tbl_map(cb, terminals)
  end
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.show(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  local filter = opts.filter or {}
  filter.name = opts.name or filter.name or nil
  M.with(function(t)
    t:show()
    if t:is_open() then
      if opts.focus ~= false then
        t:focus()
      end
      if opts.on_show then
        vim.schedule(function()
          opts.on_show(t)
        end)
      end
    end
  end, { filter = filter, create = true })
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.toggle(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:toggle()
    if t:is_open() and opts.focus ~= false then
      t:focus()
    end
  end, { filter = { name = opts.name }, create = true })
end

--- Toggle focus of the terminal window if it is already open
---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.focus(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    if t:is_focused() then
      t:blur()
    else
      t:focus()
    end
  end, { filter = { name = opts.name }, create = true })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.hide(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:hide()
  end, { filter = { name = opts.name, running = true }, all = opts.all })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.close(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:close()
  end, { filter = { name = opts.name, running = true }, all = opts.all })
end

---@param opts? sidekick.Context|string
function M.render(opts)
  opts = opts or {}
  opts = type(opts) == "string" and { msg = opts } or opts
  ---@cast opts sidekick.Context

  local Context = require("sidekick.cli.context")
  return Context.get(opts)
end

---@param opts? sidekick.cli.Send
---@overload fun(msg:string)
function M.send(opts)
  opts = opts or {}

  local prompt = M.render(opts)
  if prompt:find("^%s*$") then
    Util.warn("Nothing to send.")
    return
  end

  opts.on_show = function(terminal)
    Util.exit_visual_mode()
    vim.schedule(function()
      terminal:send(prompt)
      if opts.submit then
        terminal:submit()
      end
    end)
  end

  M.show(opts)
end

---@param cb? fun(prompt?: string)
function M.prompt(cb)
  local prompts = vim.tbl_keys(Config.cli.prompts) ---@type string[]
  table.sort(prompts)

  local items = {} ---@type snacks.picker.finder.Item[]
  for _, name in ipairs(prompts) do
    local text, rendered = M.render({ prompt = name })
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
        value = name,
        prompt = name,
        preview = {
          text = text,
          extmarks = extmarks,
        },
      }
    end
  end

  ---@type snacks.picker.ui_select.Opts
  local opts = {
    prompt = "Select a prompt",
    ---@param item sidekick.select_prompt.Item
    format_item = function(item, is_snacks)
      if is_snacks then
        return { { item.text, "Special" } }
      end
      return ("[%s] %s"):format(item.text, item.prompt)
    end,
    picker = {
      preview = "preview",
      layout = {
        preset = "vscode",
        preview = true,
      },
    },
  }

  ---@param choice? sidekick.select_prompt.Item
  vim.ui.select(items, opts, function(choice)
    if cb then
      return cb(choice and choice.prompt or nil)
    end
    if choice then
      M.send({ msg = choice.preview.text, context = false })
    end
  end)
end

---@deprecated use `require("sidekick.cli").prompt()`
function M.select_prompt(...)
  Util.deprecate('require("sidekick.cli").select_prompt()', 'require("sidekick.cli").prompt()')
  return M.prompt(...)
end

---@deprecated use `require("sidekick.cli").select()`
function M.select_tool(...)
  Util.deprecate('require("sidekick.cli").select_tool()', 'require("sidekick.cli").select()')
  return M.select(...)
end

---@deprecated use `require("sidekick.cli").send()`
function M.ask(...)
  Util.deprecate('require("sidekick.cli").ask()', 'require("sidekick.cli").send()')
  return M.send(...)
end

return M
