local Util = require("sidekick.util")

local M = {}

---@alias sidekick.command.Args table<string, any>
---@alias sidekick.command.Fn fun(args: sidekick.command.Args)
---@alias sidekick.command.Cmd sidekick.command.Fn | table<string, sidekick.command.Cmd>

---@type sidekick.command.Cmd
M.commands = {
  nes = {
    apply = function()
      require("sidekick.nes").apply()
    end,
    enable = function()
      require("sidekick.nes").enable(true)
    end,
    disable = function()
      require("sidekick.nes").enable(false)
    end,
    toggle = function()
      require("sidekick.nes").toggle()
    end,
    update = function()
      require("sidekick.nes").update()
    end,
    clear = function()
      require("sidekick.nes").clear()
    end,
    jump = function()
      require("sidekick.nes").jump()
    end,
  },
  cli = {
    show = function(opts)
      require("sidekick.cli").show(opts)
    end,
    toggle = function(opts)
      require("sidekick.cli").toggle(opts)
    end,
    hide = function(opts)
      require("sidekick.cli").hide(opts)
    end,
    close = function(opts)
      require("sidekick.cli").close(opts)
    end,
    focus = function(opts)
      require("sidekick.cli").focus(opts)
    end,
    select = function(opts)
      require("sidekick.cli").select(opts)
    end,
    new = function(opts)
      require("sidekick.cli").new(opts)
    end,
    send = function(opts)
      require("sidekick.cli").send(opts)
    end,
    prompt = function()
      require("sidekick.cli").prompt()
    end,
  },
  debug = {
    nes = {
      add = function()
        require("sidekick.debug").nes_add()
      end,
      del = function()
        require("sidekick.debug").nes_del()
      end,
      patch = function()
        require("sidekick.debug").nes_patch()
      end,
      edit = function()
        require("sidekick.debug").nes_edit()
      end,
      inspect = function()
        require("sidekick.debug").nes_inspect()
      end,
    },
  },
}

---@param str string
---@param opts? {error?: boolean}
function M.argparse(str, opts)
  ---@type sidekick.command.Args
  local ret, ok = {}, true
  local env = setmetatable({ vim = vim }, {
    __newindex = function(_, k, v)
      ret[k] = v
    end,
    __index = function(_, k)
      return k
    end,
  })
  local function on_error(err)
    ok = false
    return (opts or {}).error ~= false and Util.error(("Invalid args: `%s`\nError: %s"):format(str, err))
  end
  xpcall(function()
    local chunk, err = load(str, "sidekick", "t", env)
    return chunk and (chunk() or true) or on_error(err)
  end, on_error)
  return ok and ret or nil
end

---@param str string
---@param opts? {error?: boolean}
---@overload fun(str: string): sidekick.command.Fn, sidekick.command.Args?
---@overload fun(str: string): string[]
function M.parse(str, opts)
  local parts = vim.split(str, "%s+")
  local cmd = M.commands
  while #parts > 0 and type(cmd) == "table" do
    if cmd[parts[1]] then
      cmd = cmd[table.remove(parts, 1)]
    else
      break
    end
  end
  if type(cmd) == "function" then
    return cmd, M.argparse(table.concat(parts, " "), opts)
  end
  local prefix = #parts > 0 and parts[1] or ""
  ---@param key string
  return vim.tbl_filter(function(key)
    return key:find(prefix) == 1 and key ~= "debug"
  end, vim.tbl_keys(cmd))
end

---@param line string
function M.complete(line)
  line = line:gsub("^%s*Sidekick%s+", "")
  local cmd = M.parse(line, { error = false })
  return type(cmd) == "table" and cmd or {}
end

---@param line vim.api.keyset.create_user_command.command_args
function M.cmd(line)
  local cmd, args = M.parse(line.args or "")
  if type(cmd) == "function" and args then
    if line.range and line.range > 0 then
      vim.fn.feedkeys("gv", "nx") -- restore visual selection
    end
    cmd(args)
  elseif type(cmd) == "table" and #cmd > 0 then
    Util.error(("Incomplete command: `%s`\nExpecting: `[%s]`"):format(line.args or "", table.concat(cmd, "|")))
  elseif type(cmd) ~= "function" then
    Util.error(("Invalid command: `%s`"):format(line.args or ""))
  end
end

return M
