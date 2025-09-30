local Config = require("sidekick.config")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.cli.Session
---@field id string
---@field cwd string
---@field tool string
---@field mux? "tmux"|"zellij"

---@param session sidekick.cli.Session
function M.save(session)
  local path = Config.state(session.id .. ".json")
  local data = vim.fn.json_encode(session)
  vim.fn.writefile(vim.split(data, "\n"), path)
end

---@param id string
---@return sidekick.cli.Session?
function M.get(id)
  local path = Config.state(id .. ".json")
  if vim.fn.filereadable(path) == 1 then
    local data = vim.fn.readfile(path)
    local ok, ret = pcall(vim.fn.json_decode, table.concat(data, "\n"))
    if ok then
      ---@cast ret sidekick.cli.Session
      ---@diagnostic disable-next-line: undefined-field
      ret.tool = type(ret.tool) == "table" and ret.tool.name or ret.tool
      return ret
    end
    Util.error("Failed to decode session data: " .. tostring(ret))
  end
end

---@param tool sidekick.cli.Tool
---@param opts? {cwd?:string}
function M.new(tool, opts)
  local cwd = M.cwd(opts)
  local cwd_id = vim.fn.fnamemodify(cwd, ":p:~")
  cwd_id = cwd_id:gsub("[^%w%-%_~ ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  ---@type sidekick.cli.Session
  local ret = {
    id = ("sidekick " .. tool.name .. " " .. cwd_id),
    cwd = cwd,
    tool = tool.name,
  }
  return ret
end

---@param opts? {cwd?:string}
function M.cwd(opts)
  return vim.fs.normalize(opts and opts.cwd or vim.fn.getcwd(0))
end

return M
