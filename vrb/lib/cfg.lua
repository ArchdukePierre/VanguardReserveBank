local ser = require("lib.ser")
local util = require("lib.util")
local defaults = require("lib.defaults")

local cfg = {}

local function merge(base, over)
  for k, v in pairs(over) do
    if type(v) == "table" and type(base[k]) == "table" and next(v) ~= nil and #v == 0 then
      merge(base[k], v)
    else
      base[k] = v
    end
  end
end

function cfg.load(path)
  local c = util.deepcopy(defaults)
  path = path or (c.dirs.data .. "/config")
  local s = util.read_file(path)
  if s then
    local over = ser.decode(s)
    if type(over) == "table" then merge(c, over) end
  end
  c.path = path
  return c
end

function cfg.save_override(path, over)
  return util.write_atomic(path, ser.encode(over))
end

function cfg.channel(c)
  local name = tostring(c.net.network or "vanguard")
  local h = 0
  for i = 1, #name do h = (h * 31 + name:byte(i)) % 65521 end
  return 7000 + h % 2000
end

function cfg.role()
  local s = util.read_file("/.vrb/role")
  if s then return util.trim(s) end
  return nil
end

function cfg.read_key(name)
  local s = util.read_file("/.vrb/keys/" .. name)
  if s then s = util.trim(s) end
  if s and #s >= 32 then return s end
  return nil
end

return cfg
