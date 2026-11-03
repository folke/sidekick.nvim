local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Herdr: sidekick.cli.Session
---@field herdr_pane_id string
---@field herdr_pid number
local M = {}
M.__index = M

--- Run a herdr CLI command and return the decoded `result` table.
---@param args string[]
---@param opts? { notify?: boolean }
---@return table?
function M.herdr(args, opts)
  local _, out = Util.exec(vim.list_extend({ "herdr" }, args), { notify = opts and opts.notify == true })
  local ok, json = pcall(vim.json.decode, out or "")
  return ok and type(json) == "table" and json.result or nil
end

---@param pane_id string
---@return table?
function M.process_info(pane_id)
  local res = M.herdr({ "pane", "process-info", "--pane", pane_id })
  return res and res.process_info
end

function M:init()
  self.external = true -- herdr panes can't be attached to from a Neovim terminal
  self.mux_session = self.mux_session or vim.env.HERDR_WORKSPACE_ID
  self.priority = 10
end

--- Split size args, relative to Neovim's pane.
---@param nvim_pane string
---@return string[]
function M.split_args(nvim_pane)
  local split = Config.cli.mux.split
  -- herdr's `--ratio` is the share kept by Neovim's pane
  local size = split.size
  if size > 1 then
    local total = 0
    local layout = M.herdr({ "pane", "layout", "--pane", nvim_pane })
    for _, p in ipairs(layout and layout.layout and layout.layout.panes or {}) do
      if p.pane_id == nvim_pane then
        total = split.vertical and p.rect.width or p.rect.height
      end
    end
    size = total > 0 and math.min(size / total, 0.9) or 0.5
  end
  -- herdr only splits right/down, so `before` swaps the panes afterwards
  local ratio = split.before and size or (1 - size)
  return { "--ratio", tostring(ratio), "--no-focus" }
end

--- Move the sidekick pane before Neovim's pane (left/above), keeping focus on Neovim.
---@param pane_id string
---@param nvim_pane string
function M.place_before(pane_id, nvim_pane)
  if not Config.cli.mux.split.before then
    return
  end
  M.herdr({ "pane", "swap", "--source-pane", pane_id, "--target-pane", nvim_pane })
  -- swapping moves focus to the sidekick pane; Neovim now sits right/below of it
  local direction = Config.cli.mux.split.vertical and "right" or "down"
  M.herdr({ "pane", "focus", "--pane", pane_id, "--direction", direction })
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  local nvim_pane = vim.env.HERDR_PANE_ID
  if not nvim_pane then
    Util.error("Not running inside a herdr pane")
    return
  end

  local window = Config.cli.mux.create == "window"
  local cmd ---@type string[]
  if window then
    cmd = { "tab", "create", "--no-focus" }
    if vim.env.HERDR_WORKSPACE_ID then
      vim.list_extend(cmd, { "--workspace", vim.env.HERDR_WORKSPACE_ID })
    end
  else
    if Config.cli.mux.create ~= "split" then
      Util.warn("herdr only supports `window` and `split` for `cli.mux.create`, using `split`")
    end
    local direction = Config.cli.mux.split.vertical and "right" or "down"
    cmd = { "pane", "split", "--pane", nvim_pane, "--direction", direction }
    vim.list_extend(cmd, M.split_args(nvim_pane))
  end
  vim.list_extend(cmd, { "--cwd", self.cwd })
  for key, value in pairs(self.tool.env or {}) do
    if value ~= false then
      vim.list_extend(cmd, { "--env", ("%s=%s"):format(key, tostring(value)) })
    end
  end

  local res = M.herdr(cmd, { notify = true })
  local pane = res and (res.pane or res.root_pane)
  if not pane then
    return
  end

  -- `exec` so the pane closes together with the tool
  local run = "exec " .. table.concat(vim.tbl_map(vim.fn.shellescape, self.tool.cmd), " ")
  M.herdr({ "pane", "run", pane.pane_id, run }, { notify = true })

  if not window then
    M.place_before(pane.pane_id, nvim_pane)
  end

  local info = M.process_info(pane.pane_id)
  self.herdr_pane_id = pane.pane_id
  self.herdr_pid = info and info.shell_pid
  self.id = "herdr " .. pane.pane_id
  self.mux_session = pane.workspace_id
  self.started = true

  if not window and Config.cli.mux.split.close_on_exit then
    self:close_on_exit()
  end
  Util.info(("Started **%s** in a new herdr %s"):format(self.tool.name, window and "tab" or "split"))
end

---@param pane_id string
---@return string?
local function tab_id(pane_id)
  local res = M.herdr({ "pane", "get", pane_id })
  return res and res.pane and res.pane.tab_id
end

--- Whether the split pane currently lives in Neovim's herdr tab.
--- Hidden panes are moved into a separate (background) tab.
---@return boolean
function M:is_open()
  local nvim_pane = vim.env.HERDR_PANE_ID
  if Config.cli.mux.create ~= "split" or not self.herdr_pane_id or not nvim_pane then
    return true
  end
  local tab = tab_id(self.herdr_pane_id)
  return tab ~= nil and tab == tab_id(nvim_pane)
end

--- Hide the split by moving its pane into a new background tab.
function M:hide()
  if Config.cli.mux.create ~= "split" or not self.herdr_pane_id then
    return
  end
  M.herdr({ "pane", "move", self.herdr_pane_id, "--new-tab", "--no-focus" })
end

--- Show the split by moving its pane back next to Neovim.
function M:show()
  local nvim_pane = vim.env.HERDR_PANE_ID
  local nvim_tab = nvim_pane and tab_id(nvim_pane)
  if Config.cli.mux.create ~= "split" or not self.herdr_pane_id or not nvim_tab then
    return
  end
  local direction = Config.cli.mux.split.vertical and "right" or "down"
  local cmd = { "pane", "move", self.herdr_pane_id, "--tab", nvim_tab }
  vim.list_extend(cmd, { "--target-pane", nvim_pane, "--split", direction })
  vim.list_extend(cmd, M.split_args(nvim_pane))
  M.herdr(cmd)
  M.place_before(self.herdr_pane_id, nvim_pane)
end

--- Close the split/tab by closing its herdr pane.
function M:close()
  if self.herdr_pane_id then
    M.herdr({ "pane", "close", self.herdr_pane_id })
  end
end

--- Close the herdr pane when Neovim exits.
function M:close_on_exit()
  local pane_id = self.herdr_pane_id
  if not pane_id then
    return
  end
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    callback = function()
      pcall(Util.exec, { "herdr", "pane", "close", pane_id }, { notify = false })
    end,
  })
end

function M:is_running()
  return self.herdr_pid and vim.api.nvim_get_proc(self.herdr_pid) ~= nil
end

function M.sessions()
  local res = M.herdr({ "pane", "list" })
  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()
  local Procs = require("sidekick.cli.procs")

  for _, pane in ipairs(res and res.panes or {}) do
    local info = M.process_info(pane.pane_id)
    local tool = pane.agent and tools[pane.agent] or nil ---@type sidekick.cli.Tool?
    local cwd = pane.foreground_cwd or pane.cwd
    for _, proc in ipairs(info and not tool and info.foreground_processes or {}) do
      for _, t in pairs(tools) do
        if t:is_proc({ pid = proc.pid, ppid = 0, cmd = proc.cmdline or "", cwd = proc.cwd }) then
          tool, cwd = t, proc.cwd or cwd
          break
        end
      end
      if tool then
        break
      end
    end
    if tool and info and info.shell_pid then
      ret[#ret + 1] = {
        id = "herdr " .. pane.pane_id,
        cwd = cwd,
        tool = tool,
        herdr_pane_id = pane.pane_id,
        herdr_pid = info.shell_pid,
        mux_session = pane.workspace_id,
        pids = Procs.pids(info.shell_pid),
      }
    end
  end
  return ret
end

---Send text to a herdr pane
function M:send(text)
  local function send()
    M.herdr({ "pane", "send-text", self.herdr_pane_id, text }, { notify = true })
  end

  if self.tool.mux_focus then
    -- Send focus-in event first (some TUI apps like qwen ignore input when unfocused)
    M.herdr({ "pane", "send-text", self.herdr_pane_id, "\27[I" })
    vim.defer_fn(send, 50) -- slight delay to ensure focus event is processed first
  else
    send()
  end
end

---Submit the current input in a herdr pane
function M:submit()
  M.herdr({ "pane", "send-keys", self.herdr_pane_id, "enter" }, { notify = true })
end

function M:dump()
  if not self.herdr_pane_id then
    return
  end
  local cmd = { "herdr", "pane", "read", self.herdr_pane_id, "--source", "recent" }
  vim.list_extend(cmd, { "--lines", tostring(Config.cli.mux.dump), "--format", "ansi" })
  local _, ret = Util.exec(cmd, { notify = false })
  return ret
end

return M
