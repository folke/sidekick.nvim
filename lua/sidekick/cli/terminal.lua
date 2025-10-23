local Config = require("sidekick.config")
local Session = require("sidekick.cli.session")
local Util = require("sidekick.util")

---@class sidekick.cli.terminal.Cmd
---@field name string Name of the tool
---@field cmd string[] Command to run the CLI tool
---@field env? table<string, string> Environment variables to set when running the command

---@class sidekick.cli.Terminal: sidekick.cli.Session
---@field opts sidekick.win.Opts
---@field group integer
---@field ctime integer
---@field atime integer
---@field closed? boolean
---@field timer? uv.uv_timer_t
---@field send_queue string[]
---@field job? integer
---@field buf? integer
---@field win? integer
---@field scrollback? sidekick.cli.Scrollback
---@field normal_mode? boolean
local M = {}
M.__index = M
M.priority = 100
M.external = false

local READY_MAX_WAIT = 5000 -- ms
local READY_CHECK_INTERVAL = 100 -- ms
local READY_INIT_DELAY = 500 -- ms
local READY_INIT_LINES = 5
local SEND_DELAY = 100 --ms
local TERM_CLOSE_ERROR_DELAY = 3000 -- ms if the terminal errored, don't close the window
local TERM_CLOSE_DELAY = 500 -- ms if the terminal closed too quickly, don't close the window

M.terminals = {} ---@type table<string, sidekick.cli.Terminal>

---@generic T: table
---@param ... T
---@return T
local function merge(...)
  return vim.tbl_deep_extend("force", ...)
end

---@type vim.wo
local wo = {
  winhighlight = "Normal:SidekickChat,NormalNC:SidekickChat,EndOfBuffer:SidekickChat,SignColumn:SidekickChat",
  colorcolumn = "",
  cursorcolumn = false,
  cursorline = false,
  fillchars = "eob: ",
  list = false,
  listchars = "tab:  ",
  number = false,
  relativenumber = false,
  sidescrolloff = 0,
  signcolumn = "no", -- left padding interferes with terminal reflow, so disable
  statuscolumn = "", -- left padding interferes with terminal reflow, so disable
  spell = false,
  winbar = "",
  wrap = false,
}

---@type vim.bo
local bo = {
  swapfile = false,
  filetype = "sidekick_terminal",
}

local win_opts = {
  ---@type vim.api.keyset.win_config
  float = {
    focusable = true,
    relative = "editor",
    style = "minimal",
    row = 0.5,
    col = 0.5,
    title = " Sidekick ",
    title_pos = "center",
  },
  ---@type vim.api.keyset.win_config
  split = {
    win = -1,
    style = "minimal",
  },
}

---@param session_id string
function M.get(session_id)
  return M.terminals[session_id]
end

---@return sidekick.cli.session.State[]
function M.sessions()
  return vim.tbl_values(M.terminals)
end

---@param opts sidekick.cli.session.Opts
function M.new(opts)
  opts.backend = "terminal"
  return Session.new(opts) --[[@as sidekick.cli.Terminal]]
end

function M:init()
  self.opts = vim.deepcopy(Config.cli.win)
  self.ctime = vim.uv.hrtime()
  self.atime = self.ctime
  self.send_queue = {}
  self.group = vim.api.nvim_create_augroup("sidekick_cli_" .. self.id, { clear = true })
  M.terminals[self.id] = self
  if Config.cli.win.config then
    Config.cli.win.config(self)
  end
  self.scrollback = require("sidekick.cli.scrollback").new(self)
  return self
end

function M:attach() end

function M:is_running()
  return self.job and vim.fn.jobwait({ self.job }, 0)[1] == -1
end

function M:buf_valid()
  return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

function M:win_valid()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

---@param buf? integer
function M:bo(buf)
  for k, v in pairs(merge(vim.deepcopy(bo), self.opts.bo)) do
    ---@diagnostic disable-next-line: no-unknown
    vim.bo[buf or self.buf][k] = v
  end
end

---@param opts? vim.wo
function M:wo(opts)
  for k, v in pairs(merge(vim.deepcopy(wo), vim.deepcopy(self.opts.wo), opts or {})) do
    vim.api.nvim_set_option_value(k, v, { win = self.win, scope = "local" })
  end
end

function M:start()
  if self:is_running() then
    return
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  self:bo()
  vim.b[self.buf].sidekick_cli = self.tool

  self:keys()
  self:open_win()

  -- track if we are in normal mode or terminal mode
  vim.api.nvim_create_autocmd("WinLeave", {
    group = self.group,
    callback = function()
      if not self:is_focused() then
        return
      end
      self.normal_mode = vim.fn.mode() ~= "t"
    end,
  })

  -- restore mode when entering the sidekick window
  vim.api.nvim_create_autocmd("WinEnter", {
    group = self.group,
    callback = function()
      if not self:is_focused() then
        return
      end
      self.atime = vim.uv.hrtime()
      if self.normal_mode then
        vim.cmd.stopinsert()
      else
        vim.cmd.startinsert()
      end
    end,
  })

  vim.api.nvim_create_autocmd("TermClose", {
    group = self.group,
    buffer = self.buf,
    callback = function()
      local ms = (vim.uv.hrtime() - self.atime) / 1e6
      if ms < TERM_CLOSE_DELAY then
        -- don't close if the terminal closed too quickly
        return
      elseif vim.v.event.status ~= 0 and ms < TERM_CLOSE_ERROR_DELAY then
        -- don't close if the terminal failed to start
        return
      end
      vim.schedule(function()
        self:close()
      end)
    end,
  })

  local norm_cmd = vim.deepcopy(self.tool.cmd) ---@type string|string[]
  if vim.fn.has("win32") == 1 then
    local cmd1 = vim.fn.exepath(norm_cmd[1])
    if cmd1 == "" or not cmd1:find("%.exe$") then
      norm_cmd = table.concat(self.tool.cmd, " ")
    else
      norm_cmd[1] = cmd1
    end
  end

  local ready = assert(vim.uv.new_timer())
  local ready_start = vim.uv.hrtime()
  local ready_init ---@type integer?
  local ready_lines = 0

  local on_ready = function()
    if not ready:is_closing() then
      ready:stop()
      ready:close()
    end
    vim.schedule(function()
      self:on_ready()
    end)
  end

  ready:start(
    READY_CHECK_INTERVAL,
    READY_CHECK_INTERVAL,
    vim.schedule_wrap(function()
      local elapsed = (vim.uv.hrtime() - ready_start) / 1e6 -- ms
      if not self:buf_valid() then
        return
      end
      if elapsed > READY_MAX_WAIT then
        return on_ready() -- timeout
      end
      local lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
      while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
      end
      local cursor = vim.api.nvim_win_get_cursor(self.win)
      if #lines > READY_INIT_LINES and cursor[1] > 3 then
        ready_init = ready_init or vim.uv.hrtime()
        if #lines ~= ready_lines then
          ready_lines = #lines
          ready_init = vim.uv.hrtime()
        end
        local init_elapsed = (vim.uv.hrtime() - ready_init) / 1e6 -- ms
        if init_elapsed > READY_INIT_DELAY then
          return on_ready()
        end
      end
    end)
  )

  self.timer = vim.uv.new_timer()

  vim.api.nvim_win_call(self.win, function()
    ---@type table<string, string|false>
    local env = vim.tbl_extend("force", {}, vim.uv.os_environ(), self.tool.config.env or {}, self.tool.env or {}, {
      NVIM = vim.v.servername,
      NVIM_LISTEN_ADDRESS = false,
      NVIM_LOG_FILE = false,
      VIM = false,
      VIMRUNTIME = false,
      TERM = "xterm-256color",
    })
    -- add support for clearing env vars
    for k, v in pairs(env) do
      if v == false then
        env[k] = nil
      end
    end
    self.job = vim.fn.jobstart(norm_cmd, {
      cwd = self.cwd,
      term = true,
      clear_env = true,
      env = not vim.tbl_isempty(env) and env or nil,
    })
  end)

  if self.job <= 0 then
    if vim.fn.executable(self.tool.cmd[1]) == 0 then
      Util.error(("`%s` is not installed?"):format(self.tool.cmd[1]))
    else
      Util.error(("Failed to run `%s`"):format(table.concat(self.tool.cmd, " ")))
    end
    self:close()
    return
  end
  self.pids = { vim.fn.jobpid(self.job) }
  self.started = true

  if Config.cli.watch then
    require("sidekick.cli.watch").enable()
  end
end

function M:on_ready()
  self.timer:start(0, SEND_DELAY, function()
    local next = table.remove(self.send_queue, 1) ---@type string?
    if next then
      next = next:gsub("\r\n", "\n") -- normalize line endings
      vim.schedule(function()
        if self:is_running() then
          -- Use nvim_put to send input to the terminal
          -- instead of nvim_chan_send to better simulate user input
          -- vim.api.nvim_chan_send(self.job, next)
          vim.api.nvim_buf_call(self.buf, function()
            vim.api.nvim_put(vim.split(next, "\n", { plain = true }), "c", false, true)
          end)
          if self:is_focused() then
            vim.cmd.startinsert()
          end
        end
      end)
    end
  end)
end

function M:open_win()
  if self:is_open() or not self.buf then
    return
  end

  local is_float = self.opts.layout == "float"

  ---@type vim.api.keyset.win_config
  local opts = vim.tbl_extend(
    "force",
    vim.deepcopy(is_float and win_opts.float or win_opts.split),
    vim.deepcopy(is_float and self.opts.float or self.opts.split)
  )

  opts.width = opts.width <= 1 and math.floor(vim.o.columns * opts.width) or opts.width
  opts.height = opts.height <= 1 and math.floor(vim.o.lines * opts.height) or opts.height

  if is_float then
    opts.width, opts.height = math.max(opts.width, 80), math.max(opts.height, 10) -- minimum size
    opts.row = opts.row <= 1 and math.floor((vim.o.lines - opts.height) * opts.row) or opts.row
    opts.col = opts.col <= 1 and math.floor((vim.o.columns - opts.width) * opts.col) or opts.col
  else
    opts.width = opts.width > 0 and opts.width or nil -- auto split width
    opts.height = opts.height > 0 and opts.height or nil -- auto split height
    opts.vertical = self.opts.layout == "top" or self.opts.layout == "bottom"
    opts.split = ({ top = "above", left = "left", bottom = "below", right = "right" })[self.opts.layout] or "right"
  end

  self.win = vim.api.nvim_open_win(self.buf, false, opts)

  if opts.vertical then
    vim.wo[self.win].winfixheight = true
  else
    vim.wo[self.win].winfixwidth = true
  end
  vim.w[self.win].sidekick_cli = self.tool
  vim.w[self.win].sidekick_session_id = self.id
  self:wo()
end

function M:focus()
  self:show()
  if not self:is_running() then
    return self
  end
  vim.api.nvim_set_current_win(self.win)
  vim.cmd.startinsert()
  self.normal_mode = false
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
  return vim.api.nvim_get_current_win() == self.win
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
    self:blur()
    local wins = vim.api.nvim_list_wins()
    if #wins == 1 and wins[1] == self.win then
      -- last window, switch to another buffer, or create a new one
      local buf = vim.tbl_filter(function(b)
        return vim.bo[b].buflisted
      end, vim.api.nvim_list_bufs())[1] --[[@as integer?]]
      if buf then
        -- switch to another buffer
        vim.cmd.sbuffer(buf)
      else
        -- no other buffers to switch to, create a new empty buffer
        vim.cmd.enew()
      end
    end
    pcall(vim.api.nvim_win_close, self.win, true)
    self.win = nil
  end
  return self
end

function M:detach()
  return self
end

function M:close()
  if self.closed then
    return self
  end
  self.closed = true

  M.terminals[self.id] = nil
  if vim.tbl_isempty(M.terminals) then
    require("sidekick.cli.watch").disable()
  end
  Session.detach(self)
  if self.timer and not self.timer:is_closing() then
    self.timer:close()
    self.timer = nil
  end
  self:hide()
  if self:is_running() then
    vim.fn.jobstop(self.job)
    self.job = nil
  end
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

---@param buf? integer
function M:keys(buf)
  buf = buf or self.buf
  local Actions = require("sidekick.cli.actions")
  ---@type table<string, sidekick.cli.Keymap|false>
  local keys = vim.tbl_extend("force", {}, self.opts.keys, self.tool.keys or {})
  for name, km in pairs(keys) do
    if type(km) == "table" then
      local lhs, rhs = km[1], km[2] or name
      ---@type sidekick.cli.Action?
      local action = type(rhs) == "function" and rhs or nil
      if type(rhs) == "string" then
        action = Actions[rhs] -- global actions
          or M[rhs] -- terminal methods
            and function()
              M[rhs](self)
            end
          or (vim.fn.exists(":" .. rhs) > 0 and function()
            vim.cmd[rhs]()
          end)
          or rhs
      end

      if not lhs then
        Util.error(("No lhs for keymap `%s`"):format(name))
      elseif not action then
        Util.error(("No action for keymap `%s`: %s"):format(name, tostring(rhs)))
      else
        local mode = km.mode or "t"
        mode = type(mode) == "table" and table.concat(mode, "") or mode --[[@as string]]
        mode = vim.split(mode, "", { plain = true })
        local km_opts = vim.deepcopy(km) ---@type vim.keymap.set.Opts
        ---@diagnostic disable-next-line: inject-field, no-unknown
        km_opts.mode, km_opts[1], km_opts[2] = nil, nil, nil
        km_opts.silent = km_opts.silent ~= false
        km_opts.buffer = buf
        km_opts.desc = km_opts.desc or ("Sidekick: %s"):format(name:gsub("^%l", string.upper))
        vim.keymap.set(mode, lhs, type(action) == "string" and action or function()
          return action(self)
        end, km_opts)
      end
    end
  end
end

function M:is_float()
  return self.opts.layout == "float"
end

return M
