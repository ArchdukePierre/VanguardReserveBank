local U = {}

local floor, max, min = math.floor, math.max, math.min
local format, rep, sub, find = string.format, string.rep, string.sub, string.find

function U.now() return floor(os.epoch("utc") / 1000) end
function U.ms() return os.epoch("utc") end
function U.int(n) return format("%.0f", n) end
function U.clamp(v, lo, hi) return max(lo, min(hi, v)) end
function U.round(v) return floor(v + 0.5) end

function U.money(c)
  c = floor(c or 0)
  local sign = ""
  if c < 0 then sign = "-"; c = -c end
  local whole, cents = floor(c / 100), c % 100
  local s = format("%.0f", whole)
  local out = ""
  while #s > 3 do out = "," .. sub(s, -3) .. out; s = sub(s, 1, -4) end
  return format("%s$%s%s.%02d", sign, s, out, cents)
end

function U.parse_money(s)
  s = tostring(s or ""):gsub("[%s,$]", "")
  if s == "" or not s:match("^%d*%.?%d*$") or s == "." then return nil end
  local whole, frac = s:match("^(%d*)%.?(%d*)$")
  if #frac > 2 then return nil end
  frac = (frac .. "00"):sub(1, 2)
  local v = (tonumber(whole ~= "" and whole or "0") or 0) * 100 + tonumber(frac)
  return v
end

function U.copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

function U.deepcopy(v, depth)
  if type(v) ~= "table" then return v end
  depth = depth or 0
  if depth > 24 then error("deepcopy: too deep", 2) end
  local o = {}
  for k, x in pairs(v) do o[k] = U.deepcopy(x, depth + 1) end
  return o
end

function U.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function U.sorted_keys(t, cmp)
  local k = {}
  for key in pairs(t) do k[#k + 1] = key end
  table.sort(k, cmp)
  return k
end

function U.trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end

function U.split(s, sep)
  local out = {}
  for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
  return out
end

function U.ellipsis(s, w)
  s = tostring(s)
  if #s <= w then return s end
  if w <= 3 then return sub(s, 1, w) end
  return sub(s, 1, w - 3) .. "..."
end

function U.lpad(s, w) s = tostring(s); if #s >= w then return sub(s, 1, w) end; return rep(" ", w - #s) .. s end
function U.rpad(s, w) s = tostring(s); if #s >= w then return sub(s, 1, w) end; return s .. rep(" ", w - #s) end

function U.duration(sec)
  sec = floor(sec or 0)
  if sec < 60 then return sec .. "s" end
  if sec < 3600 then return floor(sec / 60) .. "m" end
  if sec < 86400 then return floor(sec / 3600) .. "h " .. floor(sec % 3600 / 60) .. "m" end
  return floor(sec / 86400) .. "d " .. floor(sec % 86400 / 3600) .. "h"
end

function U.date(t) return os.date("%Y-%m-%d %H:%M", t) end
function U.clock(t) return os.date("%H:%M", t) end

function U.hex(s) return (s:gsub(".", function(c) return format("%02x", c:byte()) end)) end
function U.unhex(h) return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end)) end

function U.ensure_dir(p)
  if p ~= "" and not fs.exists(p) then fs.makeDir(p) end
end

function U.read_file(path)
  if not fs.exists(path) or fs.isDir(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local s = f.readAll()
  f.close()
  return s
end

function U.write_atomic(path, data)
  U.ensure_dir(fs.getDir(path))
  local tmp = path .. ".tmp"
  local f, err = fs.open(tmp, "w")
  if not f then return false, "open: " .. tostring(err) end
  local ok, werr = pcall(function() f.write(data); f.close() end)
  if not ok then
    pcall(f.close)
    pcall(fs.delete, tmp)
    return false, tostring(werr)
  end
  if fs.exists(path) then fs.delete(path) end
  local mok, merr = pcall(fs.move, tmp, path)
  if not mok then return false, "move: " .. tostring(merr) end
  return true
end

function U.free_space()
  local ok, n = pcall(fs.getFreeSpace, "/")
  if ok and n then return n end
  return math.huge
end

function U.dir_size(path)
  if not fs.exists(path) then return 0 end
  if not fs.isDir(path) then return fs.getSize(path) end
  local n = 0
  for _, name in ipairs(fs.list(path)) do n = n + U.dir_size(fs.combine(path, name)) end
  return n
end

function U.yield() sleep(0) end

function U.pcall_trace(fn, ...)
  return xpcall(fn, function(e)
    if type(e) == "string" then return e end
    return tostring(e)
  end, ...)
end

return U
