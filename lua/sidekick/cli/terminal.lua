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
local M = {}
M.__index = M
M.priority = 100
M.external = false

local INITIAL_SEND_DELAY = 500 -- ms
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
  signcolumn = "no",
  statuscolumn = " ",
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

function M:wo()
  for k, v in pairs(merge(vim.deepcopy(wo), self.opts.wo)) do
    ---@diagnostic disable-next-line: no-unknown
    vim.wo[self.win][k] = v
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

  vim.api.nvim_create_autocmd("TermLeave", {
    group = self.group,
    buffer = self.buf,
    callback = vim.schedule_wrap(function()
      if self.buf ~= vim.api.nvim_get_current_buf() or vim.fn.mode() == "t" then
        return
      end
      self:scrollback()
    end),
  })

  -- Neovim sets defaults, so we need to reset them
  -- See |terminal-config
  vim.api.nvim_create_autocmd("TermOpen", {
    group = self.group,
    callback = function(ev)
      if vim.api.nvim_get_current_win() ~= self.win then
        return
      end
      self:wo()
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

  self.timer = vim.uv.new_timer()
  self.timer:start(INITIAL_SEND_DELAY, SEND_DELAY, function()
    local next = table.remove(self.send_queue, 1)
    if next then
      vim.schedule(function()
        if self:is_running() then
          -- Use nvim_paste to send input to the terminal
          -- instead of nvim_chan_send to better simulate user input
          -- vim.api.nvim_chan_send(self.job, next)
          vim.api.nvim_buf_call(self.buf, function()
            vim.api.nvim_paste(next, true, 1)
          end)
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
  self:wo()
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

function M:detach()
  return self
end

function M:close()
  if self.closed then
    return self
  end
  self.closed = true
  self:blur()

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

function M:scrollback()
  ---@param buf integer
  local function scroll(buf)
    -- scroll to beginning of last non-whitespace line
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for l = #lines, 1, -1 do
      if lines[l]:find("%S") then
        return vim.api.nvim_win_set_cursor(self.win, { math.min(l + 1, #lines), 0 })
      end
    end
  end

  local text = self.parent and self.parent:dump() or nil
  if not text then
    return scroll(self.buf)
  end

  -- proper scrollback support
  text = text:gsub("\n$", "")
  local buf = vim.api.nvim_create_buf(false, true)
  self:bo(buf)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_win_set_buf(self.win, buf)
  local term = vim.api.nvim_open_term(buf, {})
  vim.api.nvim_create_autocmd({ "TermEnter" }, {
    buffer = buf,
    callback = function()
      vim.cmd.stopinsert()
      vim.schedule(function()
        if self:buf_valid() and self:win_valid() then
          vim.api.nvim_win_set_buf(self.win, self.buf)
          self:wo()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChangedT", "TextChanged" }, {
    buffer = buf,
    callback = function()
      scroll(buf)
    end,
  })
  vim.api.nvim_chan_send(term, text)
  self:keys(buf)
end

return M
