local Util = require("sidekick.util")

local M = {}

local have_proc = vim.uv.fs_stat("/proc/self") ~= nil
local have_ps, have_lsof = false, false
if vim.fn.has("win32") == 0 then
  have_ps = vim.fn.executable("ps") == 1
  have_lsof = vim.fn.executable("lsof") == 1
end

---@param pid number
function M.env(pid)
  local env = {} ---@type table<string, string>

  if have_proc then
    -- Linux: use /proc filesystem
    local e = io.open("/proc/" .. pid .. "/environ", "r")
    if e then
      local env_data = e:read("*all")
      e:close()
      local env_lines = vim.split(env_data, "\0")
      for _, env_line in ipairs(env_lines) do
        local k, v = env_line:match("^(.-)=(.*)$")
        if k and v then
          env[k] = v
        end
      end
    end
  end

  if not have_ps then
    return
  end

  -- try ps as a fallback (macOS and others)
  local lines = Util.exec({ "ps", "eww", "-p", tostring(pid) })
  if lines and #lines > 0 then
    -- ps eww output format: PID command ENV1=val1 ENV2=val2 ...
    local line = lines[1]
    -- Skip the PID and command, extract environment variables
    for env_var in line:gmatch("(%w+=[^%s]+)") do
      local k, v = env_var:match("^(.-)=(.*)$")
      if k and v then
        env[k] = v
      end
    end
  end
  return env
end

---@param pid number
---@return integer?
function M.parent(pid)
  local ret = vim.api.nvim_get_proc(pid)
  return ret and ret.ppid or nil
end

---@param pid number
---@return integer[]
function M.children(pid)
  return vim.api.nvim_get_proc_children(pid) or {}
end

--- Get all descendant pids of the given pid, including itself
---@param pid number
function M.pids(pid)
  local ret = {} ---@type integer[]
  local todo = { pid }
  while #todo > 0 do
    local current = table.remove(todo, 1)
    ret[#ret + 1] = current
    vim.list_extend(todo, M.children(current))
  end
  return ret
end

---@param pid number
function M.cwd(pid)
  if have_proc then
    -- Linux: use /proc filesystem
    local ret = vim.uv.fs_readlink("/proc/" .. pid .. "/cwd")
    return ret and vim.fs.normalize(ret) or nil
  end

  if not have_lsof then
    return
  end

  -- try lsof as a fallback (macOS and others)
  local lines = Util.exec({ "lsof", "-a", "-d", "cwd", "-p", tostring(pid), "-Fn" })
  for _, line in ipairs(lines or {}) do
    -- lsof -Fn output format: n/path/to/cwd
    local path = line:match("^n(.+)$")
    if path then
      return vim.fs.normalize(path)
    end
  end
end

local proc_fields = { env = M.env, cwd = M.cwd }

---@class sidekick.cli.Proc
---@field pid number
---@field ppid number
---@field cmd string
---@field env? table<string, string>
---@field cwd? string

---@class sidekick.cli.Procs
---@field _procs table<number,sidekick.cli.Proc>
---@field _children table<number, number[]>
local P = {}
P.__index = P

function P.new()
  local self = setmetatable({}, P)
  self._procs = {}
  self._children = {}
  self:update()
  return self
end

function P:update()
  self._procs = {}
  self._children = {}
  if not have_ps then
    return
  end

  local cmd = { "ps" }
  if (vim.env.USER or "") ~= "" then
    local user_flag = (vim.uv.os_uname().sysname == "FreeBSD") and "-U" or "-u"
    vim.list_extend(cmd, { user_flag, vim.env.USER or "" })
  end
  vim.list_extend(cmd, { "-ww", "-o", "pid,ppid,args" })
  local lines = Util.exec(cmd)
  lines = vim.list_slice(lines or {}, 2) -- skip header

  for _, line in ipairs(lines or {}) do
    local pid, ppid, args = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
    if pid and ppid and args then
      pid = assert(tonumber(pid), "invalid pid: " .. pid) --[[@as number]]
      ppid = assert(tonumber(ppid), "invalid ppid: " .. ppid) --[[@as number]]
      self._procs[pid] = setmetatable({ pid = pid, ppid = ppid, cmd = args }, {
        __index = function(t, k)
          local f = proc_fields[k]
          if f then
            local v = f(t.pid) or false
            rawset(t, k, v)
            return v
          end
        end,
      })
      self._children[ppid] = self._children[ppid] or {}
      table.insert(self._children[ppid], pid)
    end
  end
end

---@param pid number
---@return sidekick.cli.Proc?
function P:get(pid)
  return self._procs[pid]
end

---@param pid number
function P:parent(pid)
  local proc = self:get(pid)
  return proc and self:get(proc.ppid) or nil
end

function P:list()
  return vim.tbl_values(self._procs)
end

---@param pid number
function P:children(pid)
  local children = self._children[pid] or {}
  local ret = {} ---@type sidekick.cli.Proc[]
  for _, cpid in ipairs(children) do
    ret[#ret + 1] = self:get(cpid)
  end
  return ret
end

---@param pid number
---@param cb? fun(proc: sidekick.cli.Proc):(true|nil)
function P:walk(pid, cb)
  local todo = { pid }
  local ret = {} ---@type sidekick.cli.Proc[]
  while #todo > 0 do
    local current = table.remove(todo, 1)
    local proc = self:get(current)
    if proc then
      if cb and cb(proc) then
        break
      end
      ret[#ret + 1] = proc
    end
    vim.list_extend(todo, self._children[current] or {})
  end
  return ret
end

---@param filter string|fun(proc: sidekick.cli.Proc):boolean
function P:find(filter)
  if type(filter) == "string" then
    local pattern = filter --[[@as string]]
    ---@param proc sidekick.cli.Proc
    filter = function(proc)
      return proc.cmd:find(pattern) ~= nil
    end
  end
  return vim.tbl_filter(filter, self._procs)
end

M.new = P.new

return M
