local Config = require("sidekick.config")
local Mux = require("sidekick.cli.mux")
local Session = require("sidekick.cli.session")
local Util = require("sidekick.util")

---@class sidekick.cli.Terminal
---@field tool sidekick.cli.Tool
---@field session sidekick.cli.Session
---@field group integer
---@field ctime integer
---@field atime integer
---@field closed? boolean
---@field timer? uv.uv_timer_t
---@field send_queue string[]
---@field job? integer
---@field buf? integer
---@field win? integer
---@field mux? sidekick.cli.Muxer
local M = {}
M.__index = M

local INITIAL_SEND_DELAY = 2000 -- ms
local SEND_DELAY = 100 --ms

M.terminals = {} ---@type table<string, sidekick.cli.Terminal>

---@generic T: table
---@param ... T
---@return T
local function merge(...)
  return vim.tbl_deep_extend("force", ...)
end

---@type vim.wo
local wo = {
  winhighlight = "Normal:SidekickChat,NormalNC:SidekickChat",
  colorcolumn = "",
  cursorcolumn = false,
  cursorline = false,
  fillchars = "eob: ",
  list = false,
  listchars = "tab:  ",
  number = false,
  relativenumber = false,
  sidescrolloff = 0,
  signcolumn = "no",
  spell = false,
  winbar = "",
  statuscolumn = " ",
  wrap = false,
}

---@type vim.bo
local bo = {
  swapfile = false,
}

---@param session_id string
function M.get(session_id)
  return M.terminals[session_id]
end

function M.sessions()
  local ret = {} ---@type table<string, sidekick.cli.Session>
  for _, t in pairs(M.terminals) do
    ret[t.session.id] = t.session
  end
  return ret
end

---@param tool sidekick.cli.Tool
function M.new(tool)
  local existing = tool.session and M.get(tool.session.id)
  if existing then
    return existing
  end
  local self = setmetatable({}, M)
  self.tool = tool
  self.ctime = vim.uv.hrtime()
  self.session = tool.session or Session.new(tool)
  self.atime = self.ctime
  self.send_queue = {}
  self.group = vim.api.nvim_create_augroup("sidekick_cli_" .. self.session.id, { clear = true })
  M.terminals[self.session.id] = self
  return self
end

function M:is_running()
  return self.job and vim.fn.jobwait({ self.job }, 0)[1] == -1
end

function M:buf_valid()
  return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

function M:win_valid()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

function M:start()
  if self:is_running() then
    return
  end

  if Config.cli.mux.enabled then
    self.mux = Mux.new(self.tool, self.session)
    if not self.mux then
      return
    end
    Session.save(self.session)
  end

  local cmd = self.mux and self.mux:cmd() or self.tool

  self.buf = vim.api.nvim_create_buf(false, true)
  for k, v in pairs(merge(vim.deepcopy(bo), Config.cli.win.bo)) do
    ---@diagnostic disable-next-line: no-unknown
    vim.bo[self.buf][k] = v
  end
  vim.b[self.buf].sidekick_cli = self.tool.name

  local Actions = require("sidekick.cli.actions")

  for name, km in pairs(Config.cli.win.keys) do
    if type(km) == "table" then
      local lhs, rhs = km[1], km[2] or name
      ---@type sidekick.cli.Action?
      local action = type(rhs) == "function" and rhs or nil
      if type(rhs) == "string" then
        action = Actions[rhs] -- global actions
          or M[rhs] -- terminal methods
          or (vim.fn.exists(":" .. rhs) > 0 and function()
            vim.cmd[rhs]()
          end)
      end

      if not lhs then
        Util.error(("No lhs for keymap `%s`"):format(name))
      elseif not action then
        Util.error(("No action for keymap `%s`: %s"):format(name, tostring(rhs)))
      else
        local km_opts = vim.deepcopy(km) ---@type vim.keymap.set.Opts
        ---@diagnostic disable-next-line: inject-field, no-unknown
        km_opts.mode, km_opts[1], km_opts[2] = nil, nil, nil
        km_opts.silent = km_opts.silent ~= false
        km_opts.buffer = self.buf
        km_opts.desc = km_opts.desc or ("Sidekick: %s"):format(name:gsub("^%l", string.upper))
        vim.keymap.set(km.mode or "t", lhs, function()
          action(self)
        end, km_opts)
      end
    end
  end

  self:open_win()

  vim.api.nvim_create_autocmd("BufEnter", {
    group = self.group,
    buffer = self.buf,
    callback = function()
      self.atime = vim.uv.hrtime()
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == self.buf then
          vim.cmd.startinsert()
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("TermClose", {
    group = self.group,
    buffer = self.buf,
    callback = function()
      -- don't close if the terminal failed to start
      if vim.v.event.status ~= 0 and vim.uv.hrtime() - self.atime < 3e9 then
        return
      end
      vim.schedule(function()
        self:close()
      end)
    end,
  })

  vim.api.nvim_buf_call(self.buf, function()
    local env = vim.tbl_extend("force", {}, vim.fn.environ(), self.tool.env or {}, cmd.env or {})
    -- add support for clearing env vars
    for k, v in pairs(env) do
      if v == false then
        env[k] = nil
      end
    end
    self.job = vim.fn.jobstart(cmd.cmd, {
      cwd = self.session.cwd,
      term = true,
      clear_env = true,
      env = not vim.tbl_isempty(env) and env or nil,
    })
  end)

  if self.job <= 0 then
    local display = table.concat(cmd.cmd, " ")
    Util.error("Failed to run `" .. display .. "`")
    self:close()
    return
  end

  self.timer = vim.uv.new_timer()
  self.timer:start(INITIAL_SEND_DELAY, SEND_DELAY, function()
    local next = table.remove(self.send_queue, 1)
    if next then
      vim.schedule(function()
        if self:is_running() then
          vim.api.nvim_chan_send(self.job, next)
        end
      end)
    end
  end)
  if Config.cli.watch then
    require("sidekick.cli.watch").enable()
  end
end

function M:open_win()
  if self:is_open() or not self.buf then
    return
  end
  vim.api.nvim_win_call(0, function()
    local wincmd = {
      left = "H",
      bottom = "J",
      top = "K",
      right = "L",
    }

    local cmd = ("%s sbuffer %d | wincmd %s"):format(
      Config.cli.win.layout,
      self.buf,
      wincmd[Config.cli.win.position] or "L"
    )

    vim.cmd(cmd)
    self.win = vim.api.nvim_get_current_win()
    if Config.cli.win.layout == "vertical" then
      vim.api.nvim_win_set_width(self.win, Config.cli.win.width)
    else
      vim.api.nvim_win_set_height(self.win, Config.cli.win.height)
    end
  end)
  for k, v in pairs(merge(vim.deepcopy(wo), Config.cli.win.wo)) do
    ---@diagnostic disable-next-line: no-unknown
    vim.wo[self.win][k] = v
  end
end

function M:focus()
  self:show()
  if not self:is_running() then
    return self
  end
  vim.api.nvim_set_current_win(self.win)
  vim.cmd.startinsert()
  return self
end

function M:blur()
  if not self:is_focused() then
    return
  end
  vim.cmd.wincmd("p")
  vim.cmd.stopinsert()
end

function M:is_focused()
  return self:is_open() and vim.api.nvim_get_current_win() == self.win
end

function M:show()
  self:start()
  if not self:is_running() then
    return
  end
  self:open_win()
  return self
end

function M:hide()
  if self:is_open() then
    vim.api.nvim_win_close(self.win, true)
    self.win = nil
  end
  return self
end

function M:close()
  M.terminals[self.session.id] = nil
  if vim.tbl_isempty(M.terminals) then
    require("sidekick.cli.watch").disable()
  end
  if self.timer and not self.timer:is_closing() then
    self.timer:close()
    self.timer = nil
  end
  self.closed = true
  self:hide()
  if self:is_running() then
    vim.fn.jobstop(self.job)
    self.job = nil
  end
  self.mux = nil
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_delete(self.buf, { force = true })
    self.buf = nil
  end
  pcall(vim.api.nvim_clear_autocmds, { group = self.group })
  pcall(vim.api.nvim_del_augroup_by_id, self.group)
  return self
end

function M:toggle()
  if self:is_open() then
    self:hide()
  else
    self:show()
  end
  return self
end

function M:is_open()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

---@param input string
function M:send(input)
  self:show()
  if not self:is_running() then
    return
  end
  table.insert(self.send_queue, input)
end

function M:submit()
  if not self:is_running() then
    return
  end
  self:send("\r") -- Updated to use the send method
end

return M
