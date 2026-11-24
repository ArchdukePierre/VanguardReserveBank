local kit = require("ui.kit")
local flows = require("ui.flows")
local theme = require("ui.theme")
local util = require("lib.util")

local T = theme
local Core = {}
Core.IDLE = { idle = true }

local Ctx = {}
Ctx.__index = Ctx

function Core.new(app, client)
  return setmetatable({ app = app, client = client, changes = 0 }, Ctx)
end

function Core.stamp(t, short)
  if not t then return "-" end
  return os.date(short and "%H:%M" or "%m-%d %H:%M", t)
end

function Core.pct(v) return string.format("%.2f%%", (v or 0) * 100) end
function Core.onoff(b) return b and "ON" or "OFF" end
function Core.n(count, noun) return string.format("%.0f %s%s", count, noun, count == 1 and "" or "s") end
function Core.strip(item) return (tostring(item):gsub("^minecraft:", "")) end

function Core.bytes(n)
  if type(n) ~= "number" or n ~= n or n == math.huge then return "unknown" end
  if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
  if n >= 1024 then return string.format("%.1f KB", n / 1024) end
  return string.format("%.0f B", n)
end

function Ctx:tall() return self.app.s.h >= 30 end

function Ctx:wait(o)
  local a, b, c, d, e = self.app:wait(o)
  if a == "timeout" and not (o and o.timeout) then error(Core.IDLE, 0) end
  return a, b, c, d, e
end

function Ctx:err_text(r)
  if r.code == "timeout" then return "The bank did not answer. Check the server and the modem, then try again." end
  if r.code == "unauthorized" then return "This terminal's admin key does not match the server" end
  return r.err or "The request failed"
end

function Ctx:fail(r)
  flows.message(self.app, r.code == "timeout" and "No answer" or "Not done", { self:err_text(r) }, "error")
end

function Ctx:call(name, params, o)
  o = o or {}
  local r = self.client:call(name, params or {}, { admin = true, timeout = o.timeout })
  if r.ok then return r end
  if not o.quiet then self:fail(r) end
  return nil, r
end

function Ctx:say(text, kind, secs)
  self.pending = { text, kind or "ok", secs }
  self.changes = self.changes + 1
end

function Ctx:show(draw)
  self.app:show(draw)
  local p = self.pending
  if p then
    self.pending = nil
    self.app:notify(p[1], p[2], p[3])
  end
end

function Ctx:confirm(title, lines, o) return flows.confirm(self.app, title, lines, o) end
function Ctx:message(title, lines, kind) return flows.message(self.app, title, lines, kind) end

function Ctx:choose(title, opts, o)
  o = o or {}
  o.h = o.h or (self:tall() and 2 or 1)
  return flows.choose(self.app, title, opts, o)
end

local function narrow_text(app, o)
  local text = o.initial or ""
  local max = o.max or 32
  local allowed = o.allowed or "^[%w_]$"
  local function draw(s)
    kit.header(s, o.title or "Enter text", o.subtitle)
    kit.card(s, 2, 5, s.w - 2, 3)
    s:text(4, 5, util.ellipsis(o.label or "", s.w - 6), T.muted, T.panel)
    local shown = text .. "_"
    if #shown > s.w - 6 then shown = shown:sub(-(s.w - 6)) end
    s:text(4, 6, shown, T.accent, T.panel)
    local y = 9
    for _, line in ipairs(kit.wrap("Type on the keyboard. Enter confirms and Esc cancels.", s.w - 4)) do
      s:text(3, y, line, T.muted)
      y = y + 1
    end
    local half = math.floor((s.w - 5) / 2)
    kit.button(s, 3, s.h - 4, half, "CANCEL", "cancel", { kind = "danger", h = 2 })
    kit.button(s, s.w - half - 1, s.h - 4, half, "OK", "ok", { kind = "success", h = 2, disabled = #text == 0 })
  end
  local function add(ch)
    if #text < max and ch:match(allowed) then text = text .. ch end
  end
  app:show(draw)
  while true do
    local kind, a = app:wait()
    if kind == "tap" then
      if a.id == "cancel" then return nil end
      if a.id == "ok" and #text > 0 then return text end
    elseif kind == "char" then add(a)
    elseif kind == "paste" then for ch in a:gmatch(".") do add(ch) end
    elseif kind == "key" then
      if a == "backspace" then text = text:sub(1, -2)
      elseif a == "enter" then if #text > 0 then return text end
      elseif a == "escape" then return nil end
    elseif kind == "timeout" then return nil end
    app:refresh()
  end
end

function Ctx:text(o)
  local args = { title = o.title, label = o.label, subtitle = o.subtitle, max = o.max or 40, initial = o.initial, allowed = o.allowed or "^[%w%p ]$" }
  local s
  if self.app.s.w < 32 then s = narrow_text(self.app, args) else s = flows.text(self.app, args) end
  if not s then return nil end
  if not o.raw then s = s:gsub("_", " ") end
  s = util.trim(s)
  if s == "" then return nil end
  return s
end

local MONEY_REASONS = { "Correction", "Event prize", "Refund", "Reward", "Penalty", "Other reason" }

function Ctx:reason(title, presets, min)
  presets = presets or MONEY_REASONS
  min = min or 5
  local opts = {}
  for _, p in ipairs(presets) do opts[#opts + 1] = { label = p, id = p, kind = "panel" } end
  while true do
    local id = self:choose(title or "Reason", opts, { subtitle = "Pick one or type your own" })
    if not id then return nil end
    if id ~= presets[#presets] then return id end
    local typed = self:text({ title = "Reason", label = "_ is a space", subtitle = "At least " .. min .. " letters", max = 80 })
    if not typed then return nil end
    if #typed >= min then return typed end
    self:message("Too short", { "Write at least " .. min .. " characters." }, "warn")
  end
end

function Ctx:queue_counts()
  local out = {}
  local r, bad = self:call("admin_pending_claims", nil, { quiet = true })
  if not r then return nil, bad end
  out.claims = #r.claims
  r, bad = self:call("admin_list_civic_requests", nil, { quiet = true })
  if not r then return nil, bad end
  out.civic = #r.requests
  r, bad = self:call("admin_list_farm_flags", nil, { quiet = true })
  if not r then return nil, bad end
  out.flags = #r.flags
  return out
end

function Ctx:ranks()
  return self:call("list_ranks")
end

function Ctx:pick_account(title)
  while true do
    local filter = self:text({ title = title or "Find account", label = "Owner name or number", raw = true, max = 32, allowed = "^[%w_%-]$" })
    if not filter then return nil end
    local r = self:call("admin_list_accounts", { filter = filter, limit = 20 })
    if not r then return nil end
    if r.total == 0 then
      self:message("No match", { "No account matches " .. filter .. "." }, "warn")
    elseif #r.accounts == 1 then
      return r.accounts[1]
    else
      local rows = {}
      for _, a in ipairs(r.accounts) do rows[#rows + 1] = { left = a.owner .. " " .. a.id, right = util.money(a.balance), id = a.id, data = a } end
      local id, data = flows.pick_list(self.app, "Choose account", rows, { subtitle = string.format("%.0f found, showing %.0f", r.total, #r.accounts) })
      if id then return data end
    end
  end
end

function Core.bar_bottom(s) return s.h >= 30 and s.h - 1 or s.h - 2 end

local function bar_place(s, items, bottom)
  local bh = s.h >= 30 and 2 or 1
  local lines, cur, curw = {}, {}, 0
  for _, it in ipairs(items) do
    it.bw = math.min(s.w - 2, it.w or math.max(5, #it.label + 2))
    if #cur > 0 and curw + 1 + it.bw > s.w - 2 then lines[#lines + 1] = cur; cur, curw = {}, 0 end
    curw = curw + (#cur > 0 and 1 or 0) + it.bw
    cur[#cur + 1] = it
  end
  if #cur > 0 then lines[#lines + 1] = cur end
  for r, row in ipairs(lines) do
    local y = bottom - (r - 1) * (bh + 1) - (bh - 1)
    local lx, rx = 2, s.w
    for _, it in ipairs(row) do
      it.y, it.h = y, bh
      if not it.right then it.x = lx; lx = lx + it.bw + 1 end
    end
    for i = #row, 1, -1 do
      local it = row[i]
      if it.right then it.x = rx - it.bw; rx = it.x - 1 end
    end
  end
  return bottom - (#lines - 1) * (bh + 1) - (bh - 1)
end

local function bar_draw(s, items)
  for _, it in ipairs(items) do
    kit.button(s, it.x, it.y, it.bw, it.label, it.id, { kind = it.kind or "secondary", h = it.h, disabled = it.disabled, active = it.active })
  end
end

Core.bar_place, Core.bar_draw = bar_place, bar_draw

function Core.list(ctx, o)
  local app = ctx.app
  local st = o.state or { offset = 0 }
  local rows = o.rows
  local per = 1
  local function base(scroll)
    local items = { { label = "\27 BACK", id = "back", kind = "secondary" } }
    for _, b in ipairs(o.buttons or {}) do items[#items + 1] = { label = b.label, id = b.id, kind = b.kind, disabled = b.disabled, w = b.w } end
    if scroll then
      items[#items + 1] = { label = "\30", id = "up", w = 4, right = true }
      items[#items + 1] = { label = "\31", id = "down", w = 4, right = true }
    end
    return items
  end
  local function draw(s)
    kit.header(s, o.title, o.subtitle)
    local items = base(false)
    local top = bar_place(s, items, Core.bar_bottom(s))
    if #rows > top - 6 then
      items = base(true)
      top = bar_place(s, items, Core.bar_bottom(s))
    end
    per = math.max(1, top - 6)
    if #rows == 0 then
      kit.empty(s, 2, 5, s.w - 2, per, o.empty or "Nothing here", o.hint)
    else
      kit.list(s, 2, 5, s.w - 2, per, rows, st)
    end
    for _, it in ipairs(items) do
      if it.id == "up" then it.disabled = not st.more_up end
      if it.id == "down" then it.disabled = not st.more_down end
    end
    bar_draw(s, items)
    kit.footer(s, o.footer)
  end
  ctx:show(draw)
  while true do
    local kind, a = ctx:wait()
    if kind == "tap" then
      if a.id == "back" then return nil end
      if a.id == "up" then kit.scroll(st, #rows, per, -per)
      elseif a.id == "down" then kit.scroll(st, #rows, per, per)
      else return a.id, a.data end
    elseif kind == "scroll" then kit.scroll(st, #rows, per, a)
    elseif kind == "key" then
      if a == "escape" then return nil
      elseif a == "down" then kit.scroll(st, #rows, per, 1)
      elseif a == "up" then kit.scroll(st, #rows, per, -1)
      elseif a == "pageDown" then kit.scroll(st, #rows, per, per)
      elseif a == "pageUp" then kit.scroll(st, #rows, per, -per) end
    end
    app:refresh()
  end
end

function Core.grid(s, items, y0, y1)
  local cols = (s.w >= 50) and 3 or 2
  local nrows = math.ceil(#items / cols)
  local avail = y1 - y0 + 1
  local bh = util.clamp(math.floor((avail - (nrows - 1)) / nrows), 1, 5)
  local bw = math.floor((s.w - 2 - (cols - 1)) / cols)
  for i, it in ipairs(items) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local x, y = 2 + col * (bw + 1), y0 + row * (bh + 1)
    local label, sub = it.label, it.sub
    if #label > bw - 1 and it.short then label = it.short end
    if it.badge ~= nil then
      if bh >= 2 then sub = nil else label = (it.short or it.label) .. " " .. (it.badge == false and "?" or util.int(it.badge)) end
    end
    kit.button(s, x, y, bw, label, it.id, { kind = it.kind, h = bh, sub = sub, disabled = it.disabled })
    if it.badge ~= nil and bh >= 2 then
      local n = it.badge
      local text = " " .. (n == false and "?" or util.int(n)) .. " "
      s:text(x + math.floor((bw - #text) / 2), y + bh - 1, text, colors.white, (n and n > 0) and colors.red or T.panel)
    end
  end
  return nrows * bh + (nrows - 1)
end

function Core.menu(ctx, o)
  local function draw(s)
    kit.header(s, o.title, o.subtitle)
    local items = { { label = "\27 BACK", id = "back", kind = "secondary" } }
    local top = bar_place(s, items, Core.bar_bottom(s))
    local used = Core.grid(s, o.items(), 5, top - 2)
    if o.note and s.h >= 30 then s:text(2, 5 + used + 1, util.ellipsis(o.note, s.w - 2), T.muted) end
    bar_draw(s, items)
    kit.footer(s, o.footer)
  end
  ctx:show(draw)
  while true do
    local kind, a = ctx:wait()
    if kind == "tap" then
      if a.id == "back" then return nil end
      return a.id
    elseif kind == "key" and a == "escape" then return nil end
  end
end

function Core.keypad(ctx, o)
  local app = ctx.app
  local kind = o.kind or "money"
  local max = o.max or 12
  local text, err = "", nil
  local function value()
    if text == "" or text == "." then return nil end
    if kind == "int" then return tonumber(text) end
    return util.parse_money(text)
  end
  local function good()
    local v = value()
    if v == nil then return nil end
    if v == 0 and not o.allow_zero then return nil end
    if o.limit and v > o.limit then return nil end
    return v
  end
  local function result()
    local v = good()
    if v == nil then return nil end
    if kind == "percent" then return v / 10000 end
    return v
  end
  local function draw(s)
    kit.header(s, o.title or "Enter value", o.subtitle)
    local cw = math.min(s.w - 4, 36)
    local cx = math.floor((s.w - cw) / 2) + 1
    kit.card(s, cx, 5, cw, 3)
    s:text(cx + 2, 5, util.ellipsis(o.label or "", cw - 4), T.muted, T.panel)
    local shown = text == "" and "0" or text
    if kind == "money" then shown = "$" .. shown elseif kind == "percent" then shown = shown .. "%" end
    s:text(cx + 2, 6, shown, T.accent, T.panel)
    if err then s:text(cx + 2, 7, util.ellipsis(err, cw - 4), T.bad, T.panel) end
    local rows = { { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" }, { kind == "int" and "CLR" or ".", "0", "<" } }
    local avail = s.h - 11
    local bh = math.max(1, math.min(3, math.floor((avail - 4) / 5)))
    local bw = util.clamp(math.floor((s.w - 6) / 3), 5, 11)
    local sx = math.floor((s.w - (bw * 3 + 2)) / 2) + 1
    local y = 9
    for _, row in ipairs(rows) do
      for c, k in ipairs(row) do
        local special = k == "<" or k == "CLR"
        kit.button(s, sx + (c - 1) * (bw + 1), y, bw, k == "<" and "\27" or k, "key:" .. k, { kind = special and "secondary" or "panel", h = bh })
      end
      y = y + bh + 1
    end
    local half = math.floor((bw * 3 + 1) / 2)
    kit.button(s, sx, y, half, "CANCEL", "cancel", { kind = "danger" })
    kit.button(s, sx + half + 1, y, bw * 3 + 2 - half - 1, "OK", "ok", { kind = "success", disabled = good() == nil })
  end
  local function press(k)
    err = nil
    if k == "<" then text = text:sub(1, -2)
    elseif k == "CLR" then text = ""
    elseif k == "." then
      if kind ~= "int" and not text:find(".", 1, true) then text = (text == "" and "0" or text) .. "." end
    elseif k:match("^%d$") then
      local frac = text:match("%.(%d*)$")
      if frac and #frac >= 2 then return end
      if #text < max then text = text .. k end
    end
  end
  app:show(draw)
  while true do
    local k, a = app:wait()
    if k == "tap" then
      if a.id == "cancel" then return nil
      elseif a.id == "ok" then
        local v = result()
        if v ~= nil then return v end
      elseif a.id:sub(1, 4) == "key:" then press(a.id:sub(5)) end
    elseif k == "char" then press(a)
    elseif k == "key" then
      if a == "backspace" then press("<")
      elseif a == "enter" then
        local v = result()
        if v ~= nil then return v end
      elseif a == "escape" then return nil end
    elseif k == "timeout" then return nil end
    local v = value()
    if v and o.limit and v > o.limit then err = "Over the limit" end
    app:refresh()
  end
end

return Core
