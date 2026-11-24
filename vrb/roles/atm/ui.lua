local kit = require("ui.kit")
local flows = require("ui.flows")
local theme = require("ui.theme")
local util = require("lib.util")

local T = theme
local U = {}

local function tall(s) return s.h >= 24 end
local function bar_h(s) return tall(s) and 2 or 1 end
local function row_h(s) return tall(s) and 2 or 1 end

local function head(ctx, s, title, sub)
  kit.header(s, util.ellipsis(title or "", s.w - 2), sub)
  local right = util.ellipsis(ctx.branch or "", math.max(0, math.floor(s.w / 2) - 2))
  local left = ctx.account and ((s.w >= 39 and "Signed in: " or "") .. ctx.account.owner) or "VRB ATM"
  s:fill(1, s.h, s.w, 1, T.panel)
  s:text(2, s.h, util.ellipsis(left, s.w - #right - 4), T.muted, T.panel)
  if right ~= "" then s:text(s.w - #right, s.h, right, T.accent, T.panel) end
end

local function stack(s, specs)
  local maxw = s.w - 2
  local rows, cur, used = {}, {}, 0
  for _, sp in ipairs(specs) do
    local w = math.min(maxw, math.max(sp.min or 8, #sp.label + 4))
    if #cur > 0 and used + 1 + w > maxw then rows[#rows + 1] = cur; cur, used = {}, 0 end
    if #cur > 0 then used = used + 1 end
    sp.px, sp.pw = 2 + used, w
    used = used + w
    cur[#cur + 1] = sp
  end
  if #cur > 0 then rows[#rows + 1] = cur end
  return rows
end

local function content_bottom(s, rows)
  if #rows == 0 then return s.h - 2 end
  local bh = bar_h(s)
  return (s.h - bh * 2) - (#rows - 1) * (bh + 1) - 2
end

local function draw_bar(s, rows)
  local bh = bar_h(s)
  for r, row in ipairs(rows) do
    local y = (s.h - bh * 2) - (r - 1) * (bh + 1)
    for _, sp in ipairs(row) do
      kit.button(s, sp.px, y, sp.pw, sp.label, sp.id, { kind = sp.kind or "secondary", h = bh, disabled = sp.disabled })
    end
  end
end

function U.capacity(ctx, labels)
  local s = ctx.app.s
  local specs = {}
  for i, l in ipairs(labels) do specs[i] = { label = l } end
  local avail = content_bottom(s, stack(s, specs)) - 5 + 1
  return math.max(1, math.floor(avail / row_h(s)))
end

local function draw_entry(s, e, y, x, w)
  if e.head then
    s:text(x + 1, y, util.ellipsis(e.head, w - 2), T.accent, T.bg)
    return
  end
  if e.info then
    s:text(x + 1, y, e.info, e.color or T.ink, T.bg)
    return
  end
  if not e.row then return end
  local r = e.row
  local bg = T.bg
  if e.h >= 2 then bg = (e.index % 2 == 1) and T.panel or colors.black end
  s:fill(x, y, w, e.h, bg)
  local right = r.right and tostring(r.right) or ""
  local pad = e.sel and 3 or 1
  local left = r.left or ""
  local room = w - #right - pad - 2
  if e.h == 1 and r.sub and #left + 2 + #r.sub <= room then left = left .. "  " .. r.sub end
  left = util.ellipsis(left, room)
  s:text(x + 1, y, left, r.color or T.ink, bg)
  if right ~= "" then s:text(x + w - #right - pad, y, right, r.rcolor or T.accent, bg) end
  local second = r.sub or r.detail
  if e.h >= 2 and second then s:text(x + 1, y + 1, util.ellipsis(second, w - 4), T.muted, bg) end
  if e.sel then
    s:text(x + w - 2, y, "\16", T.muted, bg)
    s:region(x, y, w, e.h, r.id, e.index)
  end
end

function U.list(ctx, o)
  local app = ctx.app
  local offset, shown, avail = 1, 1, 1
  local ents, max_off = {}, 1
  local visible = {}

  local function flatten(s)
    local out, rh = {}, row_h(s)
    for i, r in ipairs(o.rows or {}) do
      if r.blank then
        out[#out + 1] = { h = 1 }
      elseif r.head then
        out[#out + 1] = { h = 1, head = r.head }
      elseif r.text then
        for _, line in ipairs(kit.wrap(r.text, s.w - 4)) do out[#out + 1] = { h = 1, info = line, color = r.color } end
      else
        out[#out + 1] = { h = (r.id or r.sub or r.detail) and rh or 1, row = r, index = i, sel = r.id ~= nil }
      end
    end
    return out
  end

  local function page_up()
    local used, i = 0, offset - 1
    while i >= 1 and used + ents[i].h <= avail do used = used + ents[i].h; i = i - 1 end
    offset = math.max(1, i + 1)
  end

  local function draw(s)
    head(ctx, s, o.title, o.sub)
    ents = flatten(s)
    visible = {}
    local total = 0
    for _, e in ipairs(ents) do total = total + e.h end
    local specs = { { label = o.back or "\27 BACK", id = "back" } }
    for _, b in ipairs(o.buttons or {}) do
      specs[#specs + 1] = { label = b.label, id = "btn:" .. b.id, kind = b.kind or "primary", disabled = b.disabled }
    end
    local rows = stack(s, specs)
    avail = content_bottom(s, rows) - 5 + 1
    local up, down
    if total > avail then
      up = { label = "\30", id = "up", min = 5 }
      down = { label = "\31", id = "down", min = 5 }
      specs[#specs + 1] = up
      specs[#specs + 1] = down
      rows = stack(s, specs)
      avail = content_bottom(s, rows) - 5 + 1
    end
    local used, i = 0, #ents
    while i >= 1 and used + ents[i].h <= avail do used = used + ents[i].h; i = i - 1 end
    max_off = math.max(1, i + 1)
    offset = util.clamp(offset, 1, max_off)
    used, shown = 0, 0
    for k = offset, #ents do
      if used + ents[k].h > avail and shown > 0 then break end
      used = used + ents[k].h
      shown = shown + 1
    end
    if up then
      up.disabled = offset <= 1
      down.disabled = offset >= max_off
    end
    if #ents == 0 then
      kit.empty(s, 2, 5, s.w - 2, math.max(3, avail), util.ellipsis(o.empty or "Nothing here yet", s.w - 6), o.hint and util.ellipsis(o.hint, s.w - 6))
    else
      local y = 5
      for k = offset, offset + shown - 1 do
        local e = ents[k]
        draw_entry(s, e, y, 2, s.w - 2)
        if e.sel then visible[#visible + 1] = e.row end
        y = y + e.h
      end
    end
    draw_bar(s, rows)
  end

  while true do
    app:show(draw)
    local kind, a = app:wait()
    if kind == "tap" then
      local id = a.id
      if id == "back" then return nil
      elseif id == "up" then page_up()
      elseif id == "down" then offset = math.min(max_off, offset + shown)
      elseif type(id) == "string" and id:sub(1, 4) == "btn:" then return "btn", id:sub(5)
      elseif a.data and o.rows[a.data] then return "row", o.rows[a.data].id, o.rows[a.data].data end
    elseif kind == "scroll" then
      offset = util.clamp(offset + a, 1, max_off)
    elseif kind == "key" then
      if a == "escape" or a == "backspace" then return nil
      elseif a == "down" then offset = math.min(max_off, offset + 1)
      elseif a == "up" then offset = math.max(1, offset - 1)
      elseif a == "pageDown" then offset = math.min(max_off, offset + shown)
      elseif a == "pageUp" then page_up() end
    elseif kind == "char" and a:match("^%d$") then
      local r = visible[tonumber(a)]
      if r then return "row", r.id, r.data end
    end
  end
end

function U.menu(ctx, o)
  local app = ctx.app
  local page, pages = 1, 1
  local shown = {}

  local function draw(s)
    head(ctx, s, o.title, o.sub)
    local y = 5
    if o.top then y = o.top(s, y) end
    local items = o.items
    local n = #items
    local cols = o.cols or (s.w >= 39 and 2 or 1)
    local specs = {}
    if o.back ~= false then specs[1] = { label = o.back or "\27 BACK", id = "back", kind = o.back_kind } end
    local rows = stack(s, specs)
    local avail = content_bottom(s, rows) - y + 1
    local ih, fit
    for h = 8, 1, -1 do
      local f = math.floor((avail + 1) / (h + 1))
      if f >= 1 and f * cols >= n then ih, fit = h, f; break end
    end
    if not ih then
      specs[#specs + 1] = { label = "MORE", id = "more", kind = "primary" }
      rows = stack(s, specs)
      avail = content_bottom(s, rows) - y + 1
      ih = tall(s) and 2 or 1
      fit = math.max(1, math.floor((avail + 1) / (ih + 1)))
    end
    local per = fit * cols
    pages = math.ceil(n / per)
    if page > pages then page = 1 end
    local first = (page - 1) * per + 1
    local bw = math.floor((s.w - 2 - (cols - 1)) / cols)
    shown = {}
    for k = first, math.min(n, first + per - 1) do
      local idx = k - first
      local col, row = idx % cols, math.floor(idx / cols)
      local it = items[k]
      local label = it.label
      if not ctx.is_monitor and idx < 9 then label = string.format("%.0f %s", idx + 1, label) end
      kit.button(s, 2 + col * (bw + 1), y + row * (ih + 1), bw, label, it.id, { kind = it.kind or "panel", h = ih, sub = it.sub, disabled = it.disabled })
      shown[#shown + 1] = it
    end
    draw_bar(s, rows)
  end

  while true do
    app:show(draw)
    ctx.resting = o.rest and true or false
    local kind, a = app:wait()
    ctx.resting = false
    if kind == "tap" then
      if a.id == "back" then return nil
      elseif a.id == "more" then page = page % pages + 1
      else return a.id end
    elseif kind == "char" and a:match("^%d$") then
      local it = shown[tonumber(a)]
      if it and not it.disabled then return it.id end
    elseif kind == "key" and (a == "escape" or a == "backspace") and o.back ~= false then
      return nil
    end
  end
end

local KEYROWS = { "1234567890", "qwertyuiop", "asdfghjkl_", "zxcvbnm" }
local PUNCT = ".,!?'-:"

local function key(s, x, y, w, h, label, id, kind)
  local c = T.btn[kind or "panel"]
  s:fill(x, y, w, h, c[1])
  s:text(x + math.floor((w - #label) / 2), y + math.floor((h - 1) / 2), label, c[2], c[1])
  s:region(x, y, w + 1, h + (h == 1 and 1 or 0), id)
end

function U.text(ctx, o)
  local app = ctx.app
  if app.s.w >= 32 and not o.free then return flows.text(app, o) end
  local text, shift = o.initial or "", false
  local max = o.max or 32
  local allowed = o.allowed or (o.free and "^[%w_ %.,!%?'%-:]$" or "^[%w_]$")

  local function add(ch)
    if #text < max and #ch == 1 and ch:match(allowed) then text = text .. ch end
  end

  local function draw(s)
    kit.header(s, util.ellipsis(o.title or "Enter text", s.w - 2), o.subtitle)
    local cw = math.min(s.w - 4, 44)
    local cx = math.floor((s.w - cw) / 2) + 1
    kit.card(s, cx, 5, cw, 3)
    s:text(cx + 2, 5, util.ellipsis(o.label or "", cw - 4), T.muted, T.panel)
    local shown_text = text .. "_"
    if #shown_text > cw - 4 then shown_text = shown_text:sub(-(cw - 4)) end
    s:text(cx + 2, 6, shown_text, T.accent, T.panel)
    local kh = tall(s) and 2 or 1
    local step = kh + (kh == 1 and 1 or 0)
    local pitch = util.clamp(math.floor((s.w - 2) / 10), 2, 5)
    local sx = math.floor((s.w - pitch * 10) / 2) + 1
    local y = 9
    for r, row in ipairs(KEYROWS) do
      for i = 1, #row do
        local ch = row:sub(i, i)
        local label = shift and ch:upper() or ch
        key(s, sx + (i - 1) * pitch, y, pitch - 1, kh, label, "k:" .. label)
      end
      if r == 4 then key(s, sx + #row * pitch, y, pitch * 3 - 1, kh, "DEL", "k:<", "secondary") end
      y = y + step
    end
    if tall(s) and o.free then
      for i = 1, #PUNCT do
        local ch = PUNCT:sub(i, i)
        key(s, sx + (i - 1) * pitch, y, pitch - 1, kh, ch, "k:" .. ch)
      end
      y = y + step
    end
    local labels = { { shift and "abc" or "ABC", "shift", "secondary" } }
    if (" "):match(allowed) then labels[#labels + 1] = { "SPACE", "space", "panel" } end
    labels[#labels + 1] = { "CANCEL", "cancel", "danger" }
    labels[#labels + 1] = { "OK", "ok", "success" }
    local total_w = s.w - 2
    local mins, sum = {}, 0
    for i, l in ipairs(labels) do mins[i] = #l[1] + 1; sum = sum + mins[i] end
    local extra = math.max(0, total_w - sum - (#labels - 1))
    local x = 2
    for i, l in ipairs(labels) do
      local w = mins[i] + math.floor(extra / #labels)
      if i == #labels then w = math.max(mins[i], 2 + total_w - x) end
      kit.button(s, x, y, w, l[1], l[2], { kind = l[3], h = kh, disabled = l[2] == "ok" and #text == 0 })
      x = x + w + 1
    end
  end

  while true do
    app:show(draw)
    local kind, a = app:wait()
    if kind == "tap" then
      local id = a.id
      if id == "cancel" then return nil
      elseif id == "ok" then if #text > 0 then return text end
      elseif id == "shift" then shift = not shift
      elseif id == "space" then add(" ")
      elseif id == "k:<" then text = text:sub(1, -2)
      elseif id:sub(1, 2) == "k:" then add(id:sub(3)) end
    elseif kind == "char" then add(a)
    elseif kind == "paste" then for ch in a:gmatch(".") do add(ch) end
    elseif kind == "key" then
      if a == "backspace" then text = text:sub(1, -2)
      elseif a == "enter" then if #text > 0 then return text end
      elseif a == "escape" then return nil end
    end
  end
end

function U.pin(ctx, title, label) return flows.pin(ctx.app, title, label) end
function U.amount(ctx, title, limit, label) return flows.amount(ctx.app, title, { limit = limit, label = label }) end
function U.number(ctx, title, max, label) return flows.number(ctx.app, title, { max = max, label = label }) end
function U.choose(ctx, title, options, sub)
  return U.menu(ctx, { title = title, sub = sub, items = options, cols = 1 })
end
function U.confirm(ctx, title, lines, yes, danger) return flows.confirm(ctx.app, title, lines, { yes = yes, danger = danger }) end

return U
