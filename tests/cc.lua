local cc = {}
cc.__index = cc

local COLORS = {
  white = 1, orange = 2, magenta = 4, lightBlue = 8, yellow = 16, lime = 32, pink = 64, gray = 128,
  lightGray = 256, cyan = 512, purple = 1024, blue = 2048, brown = 4096, green = 8192, red = 16384, black = 32768,
}
local BLIT = "0123456789abcdef"
local NAMES = { "white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray", "lightGray", "cyan", "purple", "blue", "brown", "green", "red", "black" }

local function deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local t = {}
  seen[v] = t
  for k, x in pairs(v) do t[deepcopy(k, seen)] = deepcopy(x, seen) end
  return t
end
cc.deepcopy = deepcopy

local function normpath(p)
  local parts = {}
  for seg in tostring(p):gmatch("[^/\\]+") do
    if seg == ".." then parts[#parts] = nil elseif seg ~= "." and seg ~= "" then parts[#parts + 1] = seg end
  end
  return table.concat(parts, "/")
end

local function make_fs(capacity)
  local F = { files = {}, dirs = { [""] = true }, used = 0, capacity = capacity or 1000000, writes = 0, bytes_written = 0, opens = 0 }
  local api = {}
  local function size_of(f) return #f end
  function api.combine(...)
    local t = {}
    for _, p in ipairs({ ... }) do t[#t + 1] = p end
    return normpath(table.concat(t, "/"))
  end
  function api.getName(p) p = normpath(p); return p:match("([^/]*)$") or "" end
  function api.getDir(p) p = normpath(p); return p:match("^(.*)/[^/]*$") or "" end
  function api.exists(p) p = normpath(p); return F.files[p] ~= nil or F.dirs[p] == true end
  function api.isDir(p) return F.dirs[normpath(p)] == true end
  function api.isReadOnly(p) return false end
  function api.getSize(p)
    p = normpath(p)
    if F.files[p] then return #F.files[p].data end
    if F.dirs[p] then return 0 end
    error("No such file", 2)
  end
  function api.getFreeSpace(p) return F.capacity - F.used end
  function api.getCapacity(p) return F.capacity end
  function api.makeDir(p)
    p = normpath(p)
    local cur = ""
    for seg in p:gmatch("[^/]+") do
      cur = cur == "" and seg or (cur .. "/" .. seg)
      if F.files[cur] then error("File exists", 2) end
      F.dirs[cur] = true
    end
  end
  function api.list(p)
    p = normpath(p)
    if not F.dirs[p] then error("Not a directory", 2) end
    local out, seen = {}, {}
    local prefix = p == "" and "" or (p .. "/")
    local function consider(path)
      if path:sub(1, #prefix) == prefix and path ~= p then
        local rest = path:sub(#prefix + 1)
        local name = rest:match("^([^/]+)")
        if name and not seen[name] then seen[name] = true; out[#out + 1] = name end
      end
    end
    for path in pairs(F.files) do consider(path) end
    for path in pairs(F.dirs) do consider(path) end
    table.sort(out)
    return out
  end
  function api.delete(p)
    p = normpath(p)
    if F.files[p] then
      F.used = F.used - #F.files[p].data
      F.files[p] = nil
      return
    end
    if F.dirs[p] then
      local prefix = p .. "/"
      for path, f in pairs(F.files) do
        if path:sub(1, #prefix) == prefix then F.used = F.used - #f.data; F.files[path] = nil end
      end
      for path in pairs(F.dirs) do
        if path == p or path:sub(1, #prefix) == prefix then F.dirs[path] = nil end
      end
    end
  end
  function api.move(a, b)
    a, b = normpath(a), normpath(b)
    if not F.files[a] and not F.dirs[a] then error("No such file", 2) end
    if F.files[b] or F.dirs[b] then error("File exists", 2) end
    if F.files[a] then
      F.files[b] = F.files[a]; F.files[a] = nil
      local d = api.getDir(b)
      if d ~= "" and not F.dirs[d] then api.makeDir(d) end
    else
      local prefix = a .. "/"
      local moves = {}
      for path, f in pairs(F.files) do if path:sub(1, #prefix) == prefix then moves[#moves + 1] = path end end
      for _, path in ipairs(moves) do F.files[b .. "/" .. path:sub(#prefix + 1)] = F.files[path]; F.files[path] = nil end
      local dmoves = {}
      for path in pairs(F.dirs) do if path == a or path:sub(1, #prefix) == prefix then dmoves[#dmoves + 1] = path end end
      for _, path in ipairs(dmoves) do F.dirs[b .. path:sub(#a + 1)] = true; F.dirs[path] = nil end
    end
  end
  function api.copy(a, b)
    a, b = normpath(a), normpath(b)
    if F.dirs[a] then
      if F.files[b] or F.dirs[b] then error("File exists", 2) end
      api.makeDir(b)
      for _, name in ipairs(api.list(a)) do api.copy(a .. "/" .. name, b .. "/" .. name) end
      return
    end
    if not F.files[a] then error("No such file", 2) end
    if F.files[b] then error("File exists", 2) end
    local data = F.files[a].data
    if F.used + #data > F.capacity then error("Out of space", 2) end
    F.files[b] = { data = data }
    F.used = F.used + #data
  end
  function api.open(p, mode)
    p = normpath(p)
    F.opens = F.opens + 1
    local m = mode:sub(1, 1)
    local binary = mode:find("b") ~= nil
    if m == "r" then
      local f = F.files[p]
      if not f then return nil, "No such file" end
      local data, pos = f.data, 1
      local h = {}
      function h.readAll() if pos > #data then return nil end; local s = data:sub(pos); pos = #data + 1; return s end
      function h.readLine(trailing)
        if pos > #data then return nil end
        local e = data:find("\n", pos, true)
        local line
        if e then line = data:sub(pos, trailing and e or e - 1); pos = e + 1 else line = data:sub(pos); pos = #data + 1 end
        return line
      end
      function h.read(n)
        if pos > #data then return nil end
        n = n or 1
        local s = data:sub(pos, pos + n - 1); pos = pos + n
        if binary and (n == 1 or not n) then return s:byte() end
        return s
      end
      function h.seek(whence, off)
        whence = whence or "cur"; off = off or 0
        if whence == "set" then pos = off + 1 elseif whence == "cur" then pos = pos + off else pos = #data + off + 1 end
        return pos - 1
      end
      function h.close() end
      return h
    elseif m == "w" or m == "a" then
      if F.dirs[p] then return nil, "Cannot write to directory" end
      local d = api.getDir(p)
      if d ~= "" and not F.dirs[d] then return nil, "No such file" end
      local f = F.files[p]
      if m == "w" or not f then
        if f then F.used = F.used - #f.data end
        f = { data = "" }
        F.files[p] = f
      end
      local buf, closed = {}, false
      local h = {}
      local function commit()
        if #buf == 0 then return true end
        local add = table.concat(buf)
        buf = {}
        if F.used + #add > F.capacity then
          return false
        end
        f.data = f.data .. add
        F.used = F.used + #add
        F.bytes_written = F.bytes_written + #add
        F.writes = F.writes + 1
        return true
      end
      function h.write(s)
        if closed then error("attempt to use a closed file", 2) end
        buf[#buf + 1] = tostring(s)
      end
      function h.writeLine(s) h.write(tostring(s)); h.write("\n") end
      function h.flush() if not commit() then error("Out of space", 2) end end
      function h.close()
        if closed then return end
        closed = true
        if not commit() then error("Out of space", 2) end
      end
      return h
    end
    return nil, "Unsupported mode"
  end
  api.attributes = function(p)
    p = normpath(p)
    if not api.exists(p) then error("No such file", 2) end
    return { size = api.isDir(p) and 0 or #F.files[p].data, isDir = api.isDir(p), created = 0, modified = 0 }
  end
  api.find = function(pattern)
    local out = {}
    local lua = "^" .. normpath(pattern):gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", "[^/]*") .. "$"
    for p in pairs(F.files) do if p:match(lua) then out[#out + 1] = p end end
    for p in pairs(F.dirs) do if p ~= "" and p:match(lua) then out[#out + 1] = p end end
    table.sort(out)
    return out
  end
  return api, F
end

local function make_terminal(w, h, color)
  local T = { w = w, h = h, x = 1, y = 1, fg = "0", bg = "f", scale = 1, color = color ~= false, calls = 0, cells = 0, clears = 0, blink = false }
  T.text, T.fgs, T.bgs = {}, {}, {}
  local function blank() return string.rep(" ", T.w), string.rep("0", T.w), string.rep("f", T.w) end
  for y = 1, h do T.text[y], T.fgs[y], T.bgs[y] = blank() end
  local api = {}
  local function put(s, f, b)
    local y = T.y
    if y < 1 or y > T.h then T.x = T.x + #s; return end
    local x = T.x
    local n = #s
    if x + n - 1 < 1 or x > T.w then T.x = x + n; return end
    local sx = 1
    if x < 1 then sx = 2 - x; x = 1 end
    local ex = n
    if x + (ex - sx) > T.w then ex = sx + (T.w - x) end
    local piece = s:sub(sx, ex)
    local len = #piece
    T.text[y] = T.text[y]:sub(1, x - 1) .. piece .. T.text[y]:sub(x + len)
    T.fgs[y] = T.fgs[y]:sub(1, x - 1) .. f:sub(sx, ex) .. T.fgs[y]:sub(x + len)
    T.bgs[y] = T.bgs[y]:sub(1, x - 1) .. b:sub(sx, ex) .. T.bgs[y]:sub(x + len)
    T.cells = T.cells + len
    T.x = T.x + n
  end
  function api.write(s)
    T.calls = T.calls + 1
    s = tostring(s)
    put(s, string.rep(T.fg, #s), string.rep(T.bg, #s))
  end
  function api.blit(s, f, b)
    T.calls = T.calls + 1
    assert(#s == #f and #s == #b, "Arguments must be the same length")
    put(s, f, b)
  end
  function api.clear()
    T.calls = T.calls + 1; T.clears = T.clears + 1
    for y = 1, T.h do T.text[y] = string.rep(" ", T.w); T.fgs[y] = string.rep(T.fg, T.w); T.bgs[y] = string.rep(T.bg, T.w) end
    T.cells = T.cells + T.w * T.h
  end
  function api.clearLine()
    T.calls = T.calls + 1
    local y = T.y
    if y >= 1 and y <= T.h then T.text[y] = string.rep(" ", T.w); T.fgs[y] = string.rep(T.fg, T.w); T.bgs[y] = string.rep(T.bg, T.w); T.cells = T.cells + T.w end
  end
  function api.setCursorPos(x, y) T.calls = T.calls + 1; T.x = math.floor(x); T.y = math.floor(y) end
  function api.getCursorPos() return T.x, T.y end
  function api.setCursorBlink(b) T.blink = b end
  function api.getCursorBlink() return T.blink end
  function api.getSize() return T.w, T.h end
  function api.isColor() return T.color end
  api.isColour = api.isColor
  local function tob(c) local i = 0; while c > 1 do c = c / 2; i = i + 1 end; return BLIT:sub(i + 1, i + 1) end
  function api.setTextColor(c) T.calls = T.calls + 1; T.fg = tob(c) end
  function api.setBackgroundColor(c) T.calls = T.calls + 1; T.bg = tob(c) end
  api.setTextColour, api.setBackgroundColour = api.setTextColor, api.setBackgroundColor
  local function fromb(ch) return 2 ^ (BLIT:find(ch, 1, true) - 1) end
  function api.getTextColor() return fromb(T.fg) end
  function api.getBackgroundColor() return fromb(T.bg) end
  api.getTextColour, api.getBackgroundColour = api.getTextColor, api.getBackgroundColor
  function api.scroll(n)
    T.calls = T.calls + 1
    for _ = 1, math.abs(n) do
      if n > 0 then
        table.remove(T.text, 1); table.remove(T.fgs, 1); table.remove(T.bgs, 1)
        T.text[T.h], T.fgs[T.h], T.bgs[T.h] = string.rep(" ", T.w), string.rep(T.fg, T.w), string.rep(T.bg, T.w)
      end
    end
  end
  function api.setTextScale(s)
    T.scale = s
    local bw = math.floor(T.base_w / s + 0.5)
    local bh = math.floor(T.base_h / s + 0.5)
    if T.base_w then
      T.w, T.h = math.max(1, bw), math.max(1, bh)
      for y = 1, T.h do T.text[y], T.fgs[y], T.bgs[y] = blank() end
    end
  end
  function api.getTextScale() return T.scale end
  function api.setPaletteColor() end
  function api.getPaletteColor() return 1, 1, 1 end
  api.setPaletteColour, api.getPaletteColour = api.setPaletteColor, api.getPaletteColor
  api.native = function() return api end
  api._T = T
  function api._dump()
    local out = {}
    for y = 1, T.h do out[y] = T.text[y] end
    return table.concat(out, "\n")
  end
  return api
end
cc.make_terminal = make_terminal

local function ser_value(v, indent, seen)
  local t = type(v)
  if t == "table" then
    if seen[v] then error("Cannot serialize table with repeated entries", 0) end
    seen[v] = true
    if next(v) == nil then seen[v] = nil; return "{}" end
    local out = { "{\n" }
    local n = #v
    local ind2 = indent .. "  "
    local done = {}
    for i = 1, n do
      done[i] = true
      out[#out + 1] = ind2 .. ser_value(v[i], ind2, seen) .. ",\n"
    end
    local keys = {}
    for k in pairs(v) do if not done[k] then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local ks
      if type(k) == "string" and k:match("^[%a_][%w_]*$") then ks = k else ks = "[" .. ser_value(k, ind2, seen) .. "]" end
      out[#out + 1] = ind2 .. ks .. " = " .. ser_value(v[k], ind2, seen) .. ",\n"
    end
    out[#out + 1] = indent .. "}"
    seen[v] = nil
    return table.concat(out)
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" then
    if v ~= v then return "0/0" elseif v == math.huge then return "math.huge" elseif v == -math.huge then return "-math.huge" end
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%.0f", v) end
    return string.format("%.14g", v)
  elseif t == "boolean" then return tostring(v)
  end
  error("Cannot serialize type " .. t, 0)
end

local function json_enc(v)
  local t = type(v)
  if t == "table" then
    if next(v) == nil then return "[]" end
    if #v > 0 or (function() for k in pairs(v) do if type(k) ~= "number" then return false end end return true end)() then
      local o = {}
      for i = 1, #v do o[i] = json_enc(v[i]) end
      return "[" .. table.concat(o, ",") .. "]"
    end
    local o, keys = {}, {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do o[#o + 1] = json_enc(k) .. ":" .. json_enc(v[k]) end
    return "{" .. table.concat(o, ",") .. "}"
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
      return m[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
  elseif t == "number" then if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%.0f", v) end; return string.format("%.14g", v)
  elseif t == "boolean" then return tostring(v) end
  return "null"
end

local function json_dec(s)
  local pos = 1
  local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
  local val
  local function str()
    local out = {}
    pos = pos + 1
    while true do
      local c = s:sub(pos, pos)
      if c == '"' then pos = pos + 1; break
      elseif c == "\\" then
        local n = s:sub(pos + 1, pos + 1)
        local m = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
        if n == "u" then out[#out + 1] = string.char(tonumber(s:sub(pos + 2, pos + 5), 16) % 256); pos = pos + 6
        else out[#out + 1] = m[n] or n; pos = pos + 2 end
      elseif c == "" then error("bad json") else out[#out + 1] = c; pos = pos + 1 end
    end
    return table.concat(out)
  end
  function val()
    ws()
    local c = s:sub(pos, pos)
    if c == "{" then
      local t = {}
      pos = pos + 1; ws()
      if s:sub(pos, pos) == "}" then pos = pos + 1; return t end
      while true do
        ws(); local k = str(); ws(); pos = pos + 1
        t[k] = val(); ws()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "}" then break end
      end
      return t
    elseif c == "[" then
      local t = {}
      pos = pos + 1; ws()
      if s:sub(pos, pos) == "]" then pos = pos + 1; return t end
      while true do
        t[#t + 1] = val(); ws()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "]" then break end
      end
      return t
    elseif c == '"' then return str()
    elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
    elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
    elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
    else
      local n = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
      pos = pos + #n
      return tonumber(n)
    end
  end
  return val()
end

function cc.new(opts)
  opts = opts or {}
  local world = setmetatable({
    time = 0, base_epoch = opts.base_epoch or 1767225600000, computers = {}, timers = {}, next_timer = 1, next_id = 1,
    net_latency = opts.latency or 0.02, log = {}, sent = 0, instr_scale = 1e-7, channels = {}, hosts = {},
  }, cc)
  return world
end

local function add_timer(world, at, fn)
  local rec = { at = at, fn = fn, seq = world.next_timer }
  world.next_timer = world.next_timer + 1
  world.timers[#world.timers + 1] = rec
  return rec
end

function cc:computer(o)
  o = o or {}
  local world = self
  local C = {
    id = o.id or self.next_id, label = o.label, queue = {}, world = self, boot = self.time, peripherals = {}, order = {},
    instr = 0, slice = 0, running = true, out = {}, files_preload = o.files, errors = {}, name = o.name or ("pc" .. (o.id or self.next_id)),
    open_channels = {}, rednet_open = false, timer_owner = {}, ev_count = 0,
  }
  self.next_id = math.max(self.next_id, C.id) + 1
  self.computers[C.id] = C
  local fsapi, F = make_fs(o.capacity or 1000000)
  C.fs, C.F = fsapi, F
  C.term = make_terminal(o.w or 51, o.h or 19, o.color ~= false)
  function C:now_s() return world.time + self.slice * world.instr_scale end
  local env = {}
  C.env = env
  for _, n in ipairs({ "assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "rawequal", "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "xpcall", "_VERSION", "rawlen" }) do env[n] = _G[n] end
  env.string, env.table, env.math, env.bit32 = _G.string, _G.table, _G.math, _G.bit32
  env.unpack = table.unpack
  env._G = env
  local newco = {}
  for k, v in pairs(coroutine) do newco[k] = v end
  local function hook_co(co)
    debug.sethook(co, function() C.instr = C.instr + 200; C.slice = C.slice + 200 end, "", 200)
    return co
  end
  C.hook_co = hook_co
  function newco.create(f) return hook_co(coroutine.create(f)) end
  function newco.wrap(f)
    local co = hook_co(coroutine.create(f))
    return function(...)
      local r = { coroutine.resume(co, ...) }
      if not r[1] then error(r[2], 0) end
      return table.unpack(r, 2)
    end
  end
  env.coroutine = newco
  env.load = function(chunk, name, mode, e) return load(chunk, name, mode or "t", e or env) end
  env.loadstring = function(s, name) return load(s, name, "t", env) end
  env.colors = {}
  for k, v in pairs(COLORS) do env.colors[k] = v end
  env.colors.grey, env.colors.lightGrey = COLORS.gray, COLORS.lightGray
  env.colors.toBlit = function(c) local i = 0; while c > 1 do c = c / 2; i = i + 1 end; return BLIT:sub(i + 1, i + 1) end
  env.colors.fromBlit = function(ch) return 2 ^ (BLIT:find(ch, 1, true) - 1) end
  env.colors.combine = function(...) local r = 0; for _, v in ipairs({ ... }) do r = bit32.bor(r, v) end; return r end
  env.colours = env.colors
  local KEYS = { enter = 257, backspace = 259, tab = 258, space = 32, left = 263, right = 262, up = 265, down = 264, home = 268, ["end"] = 269, delete = 261, pageUp = 266, pageDown = 267, leftCtrl = 341, rightCtrl = 345, leftShift = 340, rightShift = 344, escape = 256, f1 = 290, one = 49, two = 50, three = 51, zero = 48 }
  for i = 0, 25 do KEYS[string.char(97 + i)] = 65 + i end
  env.keys = KEYS
  env.keys.getName = function(code) for k, v in pairs(KEYS) do if v == code then return k end end end
  env.keys.names = KEYS

  local osapi = {}
  env.os = osapi
  function osapi.epoch(kind)
    kind = kind or "ingame"
    local ms = world.base_epoch + math.floor(C:now_s() * 1000)
    if kind == "utc" or kind == "local" then return ms end
    return math.floor(world.time * 1000 + 6000 * 50)
  end
  function osapi.clock() return C:now_s() - C.boot end
  function osapi.time(t)
    if type(t) == "table" then return os.time(t) end
    if t == "utc" or t == "local" then return math.floor((world.base_epoch + world.time * 1000) / 1000) end
    return ((world.time * 20 / 60 / 60 + 6) % 24)
  end
  function osapi.day() return 1 + math.floor((world.time + 6 * 50) / 1200) end
  osapi.date = function(fmt, t) return os.date(fmt, t or math.floor((world.base_epoch + world.time * 1000) / 1000)) end
  osapi.getComputerID = function() return C.id end
  osapi.computerID = osapi.getComputerID
  osapi.getComputerLabel = function() return C.label end
  osapi.setComputerLabel = function(l) C.label = l end
  osapi.version = function() return "CraftOS 1.9" end
  function osapi.startTimer(t)
    local rec
    local id = world.next_timer
    rec = add_timer(world, world.time + math.max(t, 0.05), function() C.queue[#C.queue + 1] = { "timer", id } end)
    rec.owner = C
    C.timer_owner[id] = rec
    return id
  end
  function osapi.cancelTimer(id)
    local rec = C.timer_owner[id]
    if rec then rec.cancelled = true end
  end
  function osapi.queueEvent(...) C.queue[#C.queue + 1] = { ... } end
  function osapi.pullEventRaw(filter) return coroutine.yield(filter) end
  function osapi.pullEvent(filter)
    local ev = { coroutine.yield(filter) }
    if ev[1] == "terminate" then error("Terminated", 0) end
    return table.unpack(ev)
  end
  function osapi.reboot() error({ reboot = true }, 0) end
  function osapi.shutdown() error({ shutdown = true }, 0) end
  env.sleep = function(t)
    local id = osapi.startTimer(t or 0)
    repeat local _, p = osapi.pullEvent("timer") until p == id
  end
  osapi.sleep = env.sleep

  env.fs = fsapi
  env.textutils = {
    serialize = function(v) return ser_value(v, "", {}) end,
    unserialize = function(s)
      if type(s) ~= "string" then return nil end
      local f = load("return " .. s, "unserialize", "t", {})
      if not f then return nil end
      local ok, r = pcall(f)
      if ok then return r end
    end,
    serializeJSON = json_enc,
    unserializeJSON = function(s) local ok, r = pcall(json_dec, s); if ok then return r end; return nil, "bad json" end,
    formatTime = function(t, h24) local h = math.floor(t); local m = math.floor((t - h) * 60); return string.format("%d:%02d", h, m) end,
    empty_json_array = {},
  }
  env.textutils.serialise, env.textutils.unserialise = env.textutils.serialize, env.textutils.unserialize
  env.textutils.serialiseJSON, env.textutils.unserialiseJSON = env.textutils.serializeJSON, env.textutils.unserializeJSON

  env.term = C.term
  local out_log = {}
  C.printed = out_log
  env.print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    out_log[#out_log + 1] = table.concat(t, "\t")
    if #out_log > 400 then table.remove(out_log, 1) end
  end
  env.write = function(s) out_log[#out_log + 1] = tostring(s) end
  env.printError = env.print
  env.read = function(replace, history, completion, default)
    local ev = { coroutine.yield("vrb_read") }
    return ev[2]
  end

  local function add_peripheral(name, ptype, obj) C.peripherals[name] = { type = ptype, obj = obj }; C.order[#C.order + 1] = name end
  C.add_peripheral = add_peripheral
  env.peripheral = {
    getNames = function() local o = {}; for _, n in ipairs(C.order) do if C.peripherals[n] then o[#o + 1] = n end end; return o end,
    getType = function(n) local p = C.peripherals[n]; return p and p.type end,
    getName = function(obj)
      for name, p in pairs(C.peripherals) do if p.obj == obj then return name end end
    end,
    isPresent = function(n) return C.peripherals[n] ~= nil end,
    wrap = function(n) local p = C.peripherals[n]; return p and p.obj end,
    find = function(t, f)
      local r = {}
      for _, n in ipairs(C.order) do
        local p = C.peripherals[n]
        if p and p.type == t and (not f or f(n, p.obj)) then r[#r + 1] = p.obj end
      end
      return table.unpack(r)
    end,
    call = function(n, m, ...) local p = C.peripherals[n]; return p.obj[m](...) end,
    hasType = function(n, t) local p = C.peripherals[n]; return p and p.type == t end,
  }
  C.modems = {}
  local function make_modem(wireless)
    local M = { channels = {} }
    function M.open(ch) M.channels[ch] = true; world.channels[ch] = world.channels[ch] or {}; world.channels[ch][M] = C end
    function M.close(ch) M.channels[ch] = nil; if world.channels[ch] then world.channels[ch][M] = nil end end
    function M.closeAll() for ch in pairs(M.channels) do M.close(ch) end end
    function M.isOpen(ch) return M.channels[ch] == true end
    function M.isWireless() return wireless end
    function M.transmit(ch, reply, msg)
      world.sent = world.sent + 1
      C.tx = (C.tx or 0) + 1
      local copy = deepcopy(msg)
      local fire = function()
        local targets = world.channels[ch]
        if not targets then return end
        for m, comp in pairs(targets) do
          if comp ~= C or true then
            if comp.running then comp.queue[#comp.queue + 1] = { "modem_message", M.name or "back", ch, reply, deepcopy(copy), 10 } end
          end
        end
      end
      add_timer(world, world.time + world.net_latency, fire)
    end
    return M
  end
  if o.modem ~= false then
    local m = make_modem(true)
    m.name = "back"
    C.modems.back = m
    add_peripheral("back", "modem", m)
  end
  for i, mon in ipairs(o.monitors or {}) do
    local t = make_terminal(mon.w or 57, mon.h or 38, mon.color ~= false)
    t._T.base_w, t._T.base_h = (mon.w or 57) * 0.5, (mon.h or 38) * 0.5
    local name = "monitor_" .. i
    add_peripheral(name, "monitor", t)
    C.monitors = C.monitors or {}
    C.monitors[i] = t
    t.__name = name
    local oldscale = t.setTextScale
    t.setTextScale = function(s)
      local bw = math.floor((mon.w or 57) * 0.5 / s + 0.5)
      local bh = math.floor((mon.h or 38) * 0.5 / s + 0.5)
      t._T.scale = s
      t._T.w, t._T.h = bw, bh
      for y = 1, bh do t._T.text[y] = string.rep(" ", bw); t._T.fgs[y] = string.rep("0", bw); t._T.bgs[y] = string.rep("f", bw) end
      for y = bh + 1, #t._T.text do t._T.text[y], t._T.fgs[y], t._T.bgs[y] = nil, nil, nil end
    end
    t.setTextScale(mon.scale or 1)
  end
  for name, spec in pairs(o.extra or {}) do add_peripheral(name, spec.type, spec.obj) end

  local rn = { opened = {}, last = {}, msgid = 0 }
  env.rednet = rn
  function rn.open(side)
    local m = C.modems[side]
    if not m then error("No such modem: " .. tostring(side), 2) end
    m.open(C.id); m.open(65535)
    rn.opened[side] = true
  end
  function rn.close(side) if side then rn.opened[side] = nil; if C.modems[side] then C.modems[side].close(C.id); C.modems[side].close(65535) end end end
  function rn.isOpen(side)
    if side then return rn.opened[side] == true end
    return next(rn.opened) ~= nil
  end
  local function rsend(ch, id, msg, proto)
    for side in pairs(rn.opened) do
      rn.msgid = rn.msgid + 1
      C.modems[side].transmit(ch, C.id, { nMessageID = rn.msgid, nRecipient = id, message = msg, sProtocol = proto })
    end
  end
  function rn.send(id, msg, proto) rsend(id, id, msg, proto); return true end
  function rn.broadcast(msg, proto) rsend(65535, 65535, msg, proto) end
  function rn.receive(proto, timeout)
    local tid = timeout and osapi.startTimer(timeout) or nil
    while true do
      local ev = { coroutine.yield() }
      if ev[1] == "rednet_message" then
        if not proto or ev[4] == proto then return ev[2], ev[3], ev[4] end
      elseif ev[1] == "timer" and ev[2] == tid then return nil end
      if ev[1] == "terminate" then error("Terminated", 0) end
    end
  end
  function rn.host(proto, name) world.hosts[proto] = world.hosts[proto] or {}; world.hosts[proto][name] = C.id; C.hosting = C.hosting or {}; C.hosting[proto] = name end
  function rn.unhost(proto) if world.hosts[proto] and C.hosting then world.hosts[proto][C.hosting[proto]] = nil end end
  function rn.lookup(proto, name)
    osapi.sleep(0.2)
    local h = world.hosts[proto]
    if not h then return nil end
    if name then return h[name] end
    local r = {}
    for _, id in pairs(h) do r[#r + 1] = id end
    return table.unpack(r)
  end
  C.deliver_hook = function(ev)
    if ev[1] == "modem_message" then
      local ch, msg = ev[3], ev[5]
      if type(msg) == "table" and msg.nMessageID and next(rn.opened) and (ch == C.id or ch == 65535) then
        if msg.nRecipient == C.id or msg.nRecipient == 65535 then
          C.queue[#C.queue + 1] = { "rednet_message", ev[4], msg.message, msg.sProtocol }
        end
      end
    end
  end

  env.parallel = {}
  local function par(fns, mode)
    local cos, filters, alive = {}, {}, #fns
    for i, f in ipairs(fns) do cos[i] = newco.create(f) end
    local ev = {}
    while true do
      for i, co in ipairs(cos) do
        if co and (filters[i] == nil or filters[i] == ev[1] or ev[1] == "terminate") then
          local r = { coroutine.resume(co, table.unpack(ev)) }
          if not r[1] then error(r[2], 0) end
          if coroutine.status(co) == "dead" then
            cos[i] = false; alive = alive - 1
            if mode == "any" then return i end
            if alive == 0 then return end
          else
            filters[i] = r[2]
          end
        end
      end
      ev = { coroutine.yield() }
    end
  end
  env.parallel.waitForAny = function(...) return par({ ... }, "any") end
  env.parallel.waitForAll = function(...) return par({ ... }, "all") end

  env.package = { path = "/?.lua;/?/init.lua", loaded = {}, preload = {} }
  env.require = function(name)
    if env.package.loaded[name] ~= nil then return env.package.loaded[name] end
    if env.package.preload[name] then
      local r = env.package.preload[name](name)
      env.package.loaded[name] = r == nil and true or r
      return env.package.loaded[name]
    end
    local rel = name:gsub("%.", "/")
    local tried = {}
    for pat in env.package.path:gmatch("[^;]+") do
      local p = pat:gsub("%?", rel)
      tried[#tried + 1] = p
      if fsapi.exists(p) and not fsapi.isDir(p) then
        local h = fsapi.open(p, "r")
        local src = h.readAll() or ""
        h.close()
        local fn, err = load(src, "@" .. p, "t", env)
        if not fn then error(err, 2) end
        local r = fn(name, p)
        if r == nil then r = true end
        env.package.loaded[name] = r
        return r
      end
    end
    error("module '" .. name .. "' not found:\n  " .. table.concat(tried, "\n  "), 2)
  end
  env.dofile = function(p)
    local h = fsapi.open(p, "r"); local src = h.readAll(); h.close()
    return assert(load(src, "@" .. p, "t", env))()
  end
  env.loadfile = function(p, mode, e)
    local h = fsapi.open(p, "r"); if not h then return nil, "no file" end
    local src = h.readAll(); h.close()
    return load(src, "@" .. p, "t", e or env)
  end
  env.shell = {
    dir = function() return "" end,
    getRunningProgram = function() return C.program or "startup" end,
    run = function(path, ...)
      local args = { ... }
      local p = path
      if not fsapi.exists(p) and fsapi.exists(p .. ".lua") then p = p .. ".lua" end
      local h = fsapi.open(p, "r")
      if not h then return false end
      local src = h.readAll(); h.close()
      local fn, err = load(src, "@" .. p, "t", env)
      if not fn then error(err, 0) end
      fn(table.unpack(args))
      return true
    end,
    resolve = function(p) return p end,
  }
  env.http = { get = function(url) local body = world.http and world.http[url]; if not body then return nil, "404" end; local pos = 1; return { readAll = function() return body end, close = function() end, getResponseCode = function() return 200 end } end, checkURL = function() return true end }
  env.disk = {}
  env.commands = nil
  env.window = nil
  env.settings = { get = function(k, d) return d end, set = function() end, save = function() end, load = function() return false end }
  env.multishell = nil
  env.term.current = function() return C.term end
  env.term.native = function() return C.term end
  env.term.redirect = function(t) return C.term end
  env.pocket = nil

  C.computer_env = env
  if o.files then
    for path, data in pairs(o.files) do
      local d = fsapi.getDir(path)
      if d ~= "" and not fsapi.isDir(d) then fsapi.makeDir(d) end
      local h = fsapi.open(path, "w"); h.write(data); h.close()
    end
  end
  return C
end

function cc:mount(C, host_dir, vpath)
  local sep = package.config:sub(1, 1)
  local function ls(dir)
    local p = io.popen((sep == "\\" and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul')) or ('ls -1 "' .. dir .. '" 2>/dev/null'))
    local out = {}
    if p then for line in p:lines() do out[#out + 1] = line end; p:close() end
    return out
  end
  return ls
end

function cc.load_tree(C, files, vpath)
  for path, data in pairs(files) do
    local full = C.fs.combine(vpath, path)
    local d = C.fs.getDir(full)
    if d ~= "" and not C.fs.isDir(d) then C.fs.makeDir(d) end
    local saved = C.F.capacity
    C.F.capacity = 1e12
    local h = C.fs.open(full, "w"); h.write(data); h.close()
    C.F.capacity = saved
  end
end

function cc:start(C, fn, ...)
  local args = { ... }
  C.running = true
  C.crash = nil
  C.queue = {}
  C.main = coroutine.create(function() return fn(table.unpack(args)) end)
  C.hook_co(C.main)
  C.main_filter = nil
  C.started = true
  C.queue[#C.queue + 1] = { "__start" }
end

function cc:resume(C, ev)
  if not C.running or not C.main then return end
  C.slice = 0
  local ok, res = coroutine.resume(C.main, table.unpack(ev))
  C.slice = 0
  if coroutine.status(C.main) == "dead" then
    C.running = false
    if not ok then
      if type(res) == "table" and res.reboot then C.rebooted = true
      elseif type(res) == "table" and res.shutdown then C.shutdown = true
      else C.crash = tostring(res); C.errors[#C.errors + 1] = tostring(res) end
    end
    return
  end
  C.main_filter = res
end

function cc:send_event(C, ...)
  C.queue[#C.queue + 1] = { ... }
end

function cc:step()
  for _, C in pairs(self.computers) do
    if C.running and C.main and #C.queue > 0 then
      local idx
      for i, ev in ipairs(C.queue) do
        if ev[1] == "__start" then
          idx = i; break
        end
        if C.main_filter == nil or ev[1] == C.main_filter or ev[1] == "terminate" then idx = i; break end
      end
      if idx then
        local ev = table.remove(C.queue, idx)
        if ev[1] == "__start" then ev = {} end
        if C.deliver_hook then C.deliver_hook(ev) end
        C.ev_count = C.ev_count + 1
        self:resume(C, ev)
        return true
      else

        if #C.queue > 5000 then table.remove(C.queue, 1) end
      end
    end
  end
  return false
end

function cc:run(opts)
  opts = opts or {}
  local limit = self.time + (opts.seconds or 10)
  local stop = opts.stop
  local steps = 0
  while true do
    local progressed = false
    while self:step() do
      progressed = true
      steps = steps + 1
      if stop and stop() then return true end
      if steps > (opts.max_steps or 5e6) then error("too many steps") end
    end
    if stop and stop() then return true end
    local best, bi
    for i, t in ipairs(self.timers) do
      if not t.cancelled and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then best, bi = t, i end
    end
    if not best or best.at > limit then
      self.time = math.max(self.time, limit)
      return stop == nil
    end
    table.remove(self.timers, bi)
    self.time = math.max(self.time, best.at)
    best.fn()
  end
end

function cc.screen(term_api) return term_api._dump() end

function cc.touch(world, C, mon_index, x, y)
  local m = C.monitors[mon_index]
  C.queue[#C.queue + 1] = { "monitor_touch", m.__name, x, y }
end

function cc.type_text(C, text)
  for ch in text:gmatch(".") do C.queue[#C.queue + 1] = { "char", ch } end
end

function cc.key(C, name)
  C.queue[#C.queue + 1] = { "key", C.env.keys[name], false }
  C.queue[#C.queue + 1] = { "key_up", C.env.keys[name] }
end

return cc
