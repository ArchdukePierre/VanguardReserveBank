local cfgmod = require("lib.cfg")
local defaults = require("lib.defaults")
local ser = require("lib.ser")
local util = require("lib.util")

local M = {}

local function walk(root, path)
  local node = root
  for key in path:gmatch("[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[key]
  end
  return node
end

local function set_in(root, path, value)
  local node = root
  local keys = {}
  for key in path:gmatch("[^%.]+") do keys[#keys + 1] = key end
  for i = 1, #keys - 1 do
    node[keys[i]] = node[keys[i]] or {}
    node = node[keys[i]]
  end
  node[keys[#keys]] = value
end

local function flatten(t, prefix, out)
  for k, v in pairs(t) do
    local p = prefix == "" and k or (prefix .. "." .. k)
    if type(v) == "table" and next(v) ~= nil and #v == 0 then flatten(v, p, out) else out[#out + 1] = { p, v } end
  end
end

function M.main(cmd, args)
  local c = cfgmod.load()
  local over = ser.decode(util.read_file(c.path) or "") or {}
  local sub = args[1]
  if sub == "get" and args[2] then
    local v = walk(c, args[2])
    print(args[2] .. " = " .. (type(v) == "table" and ser.encode(v) or tostring(v)))
  elseif sub == "set" and args[2] and args[3] ~= nil then
    local cur = walk(defaults, args[2])
    if cur == nil or type(cur) == "table" then print("Unknown or non-scalar setting: " .. args[2]); return end
    local raw = table.concat(args, " ", 3)
    local v
    if type(cur) == "number" then v = tonumber(raw) elseif type(cur) == "boolean" then v = (raw == "true") else v = raw end
    if v == nil then print("That setting needs a " .. type(cur)); return end
    set_in(over, args[2], v)
    cfgmod.save_override(c.path, over)
    print(args[2] .. " = " .. tostring(v) .. "  (restart the computer to apply)")
  elseif sub == "unset" and args[2] then
    set_in(over, args[2], nil)
    cfgmod.save_override(c.path, over)
    print("Removed override for " .. args[2])
  else
    local rows = {}
    flatten(over, "", rows)
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    print("Overrides in " .. c.path .. ":")
    if #rows == 0 then print("  (none)") end
    for _, r in ipairs(rows) do print("  " .. r[1] .. " = " .. tostring(r[2])) end
    print("")
    print("vrb config get <name>")
    print("vrb config set <name> <value>   e.g. net.network myserver, server.history_depth 30")
    print("vrb config unset <name>")
  end
end

return M
