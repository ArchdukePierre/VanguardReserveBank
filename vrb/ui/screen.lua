local Screen = {}
Screen.__index = Screen

local concat, rep, sub = table.concat, string.rep, string.sub

local blit_cache = {}
local function bl(c)
  if type(c) == "string" then return c end
  local v = blit_cache[c]
  if not v then v = colors.toBlit(c); blit_cache[c] = v end
  return v
end

function Screen.new(target, opts)
  opts = opts or {}
  local self = setmetatable({ t = target, fg = bl(opts.fg or colors.white), bg = bl(opts.bg or colors.black), stats = { flushes = 0, rows = 0, blits = 0 } }, Screen)
  self:resize()
  return self
end

function Screen:resize()
  local w, h = self.t.getSize()
  self.w, self.h = w, h
  self.tx, self.cf, self.cb, self.sent, self.dirty = {}, {}, {}, {}, {}
  for y = 1, h do
    local a, b, c = {}, {}, {}
    for x = 1, w do a[x], b[x], c[x] = " ", self.fg, self.bg end
    self.tx[y], self.cf[y], self.cb[y] = a, b, c
    self.dirty[y] = true
  end
  self.regions = {}
  self.sent = {}
end

function Screen:invalidate()
  self.sent = {}
  for y = 1, self.h do self.dirty[y] = true end
end

function Screen:clear(bg, fg)
  bg = bl(bg or self.bg)
  fg = bl(fg or self.fg)
  for y = 1, self.h do
    local a, b, c = self.tx[y], self.cf[y], self.cb[y]
    for x = 1, self.w do a[x], b[x], c[x] = " ", fg, bg end
    self.dirty[y] = true
  end
  self.regions = {}
end

function Screen:text(x, y, str, fg, bg)
  if y < 1 or y > self.h then return end
  str = tostring(str)
  local f, b = fg and bl(fg) or self.fg, bg and bl(bg)
  local a, cf, cb = self.tx[y], self.cf[y], self.cb[y]
  local w = self.w
  for i = 1, #str do
    local c = x + i - 1
    if c >= 1 and c <= w then
      a[c] = sub(str, i, i)
      cf[c] = f
      if b then cb[c] = b end
    end
  end
  self.dirty[y] = true
end

function Screen:fill(x, y, w, h, bg, ch, fg)
  bg = bl(bg)
  for row = y, y + h - 1 do
    if row >= 1 and row <= self.h then
      local a, cf, cb = self.tx[row], self.cf[row], self.cb[row]
      for c = math.max(1, x), math.min(self.w, x + w - 1) do
        a[c] = ch or " "
        cb[c] = bg
        if fg then cf[c] = bl(fg) end
      end
      self.dirty[row] = true
    end
  end
end

function Screen:region(x, y, w, h, id, data)
  local r = { x = x, y = y, w = w, h = h, id = id, data = data }
  self.regions[#self.regions + 1] = r
  return r
end

function Screen:hit(px, py)
  for i = #self.regions, 1, -1 do
    local r = self.regions[i]
    if px >= r.x and px < r.x + r.w and py >= r.y and py < r.y + r.h and not r.disabled then return r end
  end
end

function Screen:flush()
  local t = self.t
  local st = self.stats
  st.flushes = st.flushes + 1
  for y = 1, self.h do
    if self.dirty[y] then
      self.dirty[y] = false
      local a, b, c = concat(self.tx[y]), concat(self.cf[y]), concat(self.cb[y])
      local prev = self.sent[y]
      if not prev or prev[1] ~= a or prev[2] ~= b or prev[3] ~= c then
        local first, last = 1, self.w
        if prev then
          while first <= self.w and sub(a, first, first) == sub(prev[1], first, first) and sub(b, first, first) == sub(prev[2], first, first) and sub(c, first, first) == sub(prev[3], first, first) do first = first + 1 end
          while last > first and sub(a, last, last) == sub(prev[1], last, last) and sub(b, last, last) == sub(prev[2], last, last) and sub(c, last, last) == sub(prev[3], last, last) do last = last - 1 end
        end
        t.setCursorPos(first, y)
        t.blit(sub(a, first, last), sub(b, first, last), sub(c, first, last))
        self.sent[y] = { a, b, c }
        st.rows = st.rows + 1
        st.blits = st.blits + 1
      end
    end
  end
end

return Screen
