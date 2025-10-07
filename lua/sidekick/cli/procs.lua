local Util = require("sidekick.util")

---@param pid number
local function get_env(pid)
  local env = {} ---@type table<string, string>
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
  return env
end

---@param pid number
local function get_cwd(pid)
  local ret = vim.uv.fs_readlink("/proc/" .. pid .. "/cwd")
  return ret and vim.fs.normalize(ret) or false
end

local proc_fields = { env = get_env, cwd = get_cwd }

---@class sidekick.cli.Proc
---@field pid number
---@field ppid number
---@field cmd string
---@field env table<string, string>
---@field cwd? string

---@class sidekick.cli.Procs
---@field _procs table<number,sidekick.cli.Proc>
---@field _children table<number, number[]>
local M = {}
M.__index = M

function M.new()
  local self = setmetatable({}, M)
  self._procs = {}
  self._children = {}
  self:update()
  return self
end

function M:update()
  self._procs = {}
  self._children = {}
  if vim.fn.has("win32") == 1 then
    return
  end
  local lines = Util.exec({ "ps", "-u", vim.env.USER or "", "-ww", "-o", "pid,ppid,args", "--no-headers" })
  for _, line in ipairs(lines or {}) do
    local pid, ppid, cmd = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
    if pid and ppid and cmd then
      pid = assert(tonumber(pid), "invalid pid: " .. pid) --[[@as number]]
      ppid = assert(tonumber(ppid), "invalid ppid: " .. ppid) --[[@as number]]
      self._procs[pid] = setmetatable({ pid = pid, ppid = ppid, cmd = cmd }, {
        __index = function(t, k)
          local f = proc_fields[k]
          if f then
            local v = f(t.pid)
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
function M:get(pid)
  return self._procs[pid]
end

---@param pid number
function M:parent(pid)
  local proc = self:get(pid)
  return proc and self:get(proc.ppid) or nil
end

function M:list()
  return vim.tbl_values(self._procs)
end

---@param pid number
function M:children(pid)
  local children = self._children[pid] or {}
  local ret = {} ---@type sidekick.cli.Proc[]
  for _, cpid in ipairs(children) do
    ret[#ret + 1] = self:get(cpid)
  end
  return ret
end

---@param pid number
---@param cb? fun(proc: sidekick.cli.Proc):(true|nil)
function M:walk(pid, cb)
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
function M:find(filter)
  if type(filter) == "string" then
    local pattern = filter --[[@as string]]
    ---@param proc sidekick.cli.Proc
    filter = function(proc)
      return proc.cmd:find(pattern) ~= nil
    end
  end
  return vim.tbl_filter(filter, self._procs)
end

return M.new()
