local kit = require("ui.kit")
local theme = require("ui.theme")
local util = require("lib.util")

local F = {}
local T = theme

local function frame(s, title, sub)
  kit.header(s, title, sub)
end

local function keypad_layout(s, top, rows_needed)
  local avail = s.h - top - 3
  local bh = math.max(1, math.min(3, math.floor((avail - (rows_needed - 1)) / rows_needed)))
  local bw = util.clamp(math.floor((s.w - 6) / 3), 5, 11)
  return bw, bh
end

function F.keypad(app, o)
  o = o or {}
  local mode = o.mode or "digits"
  local max = o.max or (mode == "pin" and 4 or 12)
  local text = ""
  local error_text
  local function value_ok()
    if mode == "pin" then return #text == (o.max or 4) end
    if mode == "amount" then
      local v = util.parse_money(text)
      return v ~= nil and v > 0 and (not o.limit or v <= o.limit)
    end
    return #text > 0
  end
  local function draw(s)
    frame(s, o.title or "Enter value", o.subtitle)
    local cw = math.min(s.w - 4, 36)
    local cx = math.floor((s.w - cw) / 2) + 1
    kit.card(s, cx, 5, cw, 3)
    s:text(cx + 2, 5, util.ellipsis(o.label or "", cw - 4), T.muted, T.panel)
    local shown = text
    if mode == "pin" then shown = string.rep("*", #text) .. string.rep("-", (o.max or 4) - #text)
    elseif mode == "amount" then shown = "$" .. (text == "" and "0" or text) end
    s:text(cx + 2, 6, shown, T.accent, T.panel)
    if error_text then s:text(cx + 2, 7, util.ellipsis(error_text, cw - 4), T.bad, T.panel) end
    local keys = { { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" }, { mode == "amount" and "." or "CLR", "0", "<" } }
    local bw, bh = keypad_layout(s, 8, 5)
    local sx = math.floor((s.w - (bw * 3 + 2)) / 2) + 1
    local y = 9
    for _, row in ipairs(keys) do
      for c, k in ipairs(row) do
        local kind = (k == "<" or k == "CLR") and "secondary" or "panel"
        kit.button(s, sx + (c - 1) * (bw + 1), y, bw, k == "<" and "\27" or k, "key:" .. k, { kind = kind, h = bh })
      end
      y = y + bh + 1
    end
    local half = math.floor((bw * 3 + 2 - 1) / 2)
    kit.button(s, sx, y, half, "CANCEL", "cancel", { kind = "danger" })
    kit.button(s, sx + half + 1, y, bw * 3 + 2 - half - 1, "OK", "ok", { kind = "success", disabled = not value_ok() })
    if o.quick then
      local qx = 2
      for _, q in ipairs(o.quick) do
        local label = util.money(q)
        kit.button(s, qx, 5, #label + 2, label, "quick:" .. q, { kind = "secondary" })
        qx = qx + #label + 3
        if qx > cx - 2 then break end
      end
    end
  end
  local function press(k)
    error_text = nil
    if k == "<" then text = text:sub(1, -2)
    elseif k == "CLR" then text = ""
    elseif k == "." then
      if mode == "amount" and not text:find(".", 1, true) then text = (text == "" and "0" or text) .. "." end
    elseif k:match("^%d$") then
      if mode == "amount" then
        local frac = text:match("%.(%d*)$")
        if frac and #frac >= 2 then return end
      end
      if #text < max then text = text .. k end
    end
  end
  app:show(draw)
  while true do
    local kind, a = app:wait()
    if kind == "tap" then
      local id = a.id
      if id == "cancel" then return nil
      elseif id == "ok" then
        if value_ok() then
          if mode == "amount" then return util.parse_money(text) end
          return text
        end
      elseif id:sub(1, 4) == "key:" then
        press(id:sub(5))
        if mode == "pin" and #text == (o.max or 4) then return text end
      elseif id:sub(1, 6) == "quick:" then return tonumber(id:sub(7)) end
    elseif kind == "char" then
      press(a)
      if mode == "pin" and #text == (o.max or 4) then return text end
    elseif kind == "key" then
      if a == "backspace" then press("<")
      elseif a == "enter" then
        if value_ok() then if mode == "amount" then return util.parse_money(text) end; return text end
      elseif a == "escape" then return nil end
    elseif kind == "timeout" then return nil end
    if mode == "amount" and o.limit then
      local v = util.parse_money(text)
      if v and v > o.limit then error_text = "Over the limit of " .. util.money(o.limit) end
    end
    app:refresh()
  end
end

function F.pin(app, title, label) return F.keypad(app, { mode = "pin", title = title or "Enter PIN", label = label or "4-digit PIN" }) end
function F.amount(app, title, o) o = o or {}; o.mode = "amount"; o.title = title or "Amount"; o.label = o.label or "Dollars and cents"; return F.keypad(app, o) end
function F.number(app, title, o) o = o or {}; o.mode = "digits"; o.title = title or "Number"; return F.keypad(app, o) end

local KEYROWS = { "1234567890", "qwertyuiop", "asdfghjkl_", "zxcvbnm" }

function F.text(app, o)
  o = o or {}
  local text = o.initial or ""
  local max = o.max or 32
  local allowed = o.allowed or "^[%w_]$"
  local shift = o.shift or false
  local function draw(s)
    frame(s, o.title or "Enter text", o.subtitle)
    local cw = math.min(s.w - 4, 40)
    local cx = math.floor((s.w - cw) / 2) + 1
    kit.card(s, cx, 5, cw, 3)
    s:text(cx + 2, 5, o.label or "", T.muted, T.panel)
    s:text(cx + 2, 6, util.ellipsis(text .. "_", cw - 4), T.accent, T.panel)
    if s.w >= 32 then
      local kw = util.clamp(math.floor((s.w - 2) / 10), 3, 5)
      local kh = (s.h >= 24) and 2 or 1
      local sx = math.floor((s.w - kw * 10) / 2) + 1
      local y = 9
      for r, row in ipairs(KEYROWS) do
        local off = (r == 3 or r == 4) and 0 or 0
        for i = 1, #row do
          local ch = row:sub(i, i)
          local label = shift and ch:upper() or ch
          kit.button(s, sx + (i - 1) * kw + off, y, kw - 1, label, "k:" .. label, { kind = "panel", h = kh })
        end
        if r == 4 then
          local bx = sx + #row * kw
          kit.button(s, bx, y, kw * 3 - 1, "\27 DEL", "k:<", { kind = "secondary", h = kh })
        end
        y = y + kh + (kh == 1 and 1 or 0)
      end
      local wide = math.floor(kw * 10 / 3)
      kit.button(s, sx, y, wide - 1, shift and "abc" or "ABC", "shift", { kind = "secondary" })
      kit.button(s, sx + wide, y, wide - 1, "CANCEL", "cancel", { kind = "danger" })
      kit.button(s, sx + wide * 2, y, kw * 10 - wide * 2, "OK", "ok", { kind = "success", disabled = #text == 0 })
    else
      s:text(2, 9, "Type with the keyboard.", T.muted)
      s:text(2, 10, "Enter to confirm, Esc to cancel.", T.muted)
    end
  end
  local function add(ch)
    if #text < max and ch:match(allowed) then text = text .. ch end
  end
  app:show(draw)
  while true do
    local kind, a = app:wait()
    if kind == "tap" then
      if a.id == "cancel" then return nil
      elseif a.id == "ok" then if #text > 0 then return text end
      elseif a.id == "shift" then shift = not shift
      elseif a.id == "k:<" then text = text:sub(1, -2)
      elseif a.id:sub(1, 2) == "k:" then add(a.id:sub(3)) end
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

function F.confirm(app, title, lines, o)
  o = o or {}
  local function draw(s)
    frame(s, title)
    local y = 6
    for _, line in ipairs(lines or {}) do
      for _, wl in ipairs(kit.wrap(line, s.w - 6)) do
        s:text(3, y, wl, T.ink)
        y = y + 1
      end
    end
    local bw = math.min(18, math.floor((s.w - 6) / 2))
    local by = math.max(y + 1, s.h - 4)
    kit.button(s, 3, by, bw, o.no or "CANCEL", "no", { kind = "secondary", h = 2 })
    kit.button(s, s.w - bw - 1, by, bw, o.yes or "CONFIRM", "yes", { kind = o.danger and "danger" or "success", h = 2 })
  end
  app:show(draw)
  while true do
    local kind, a = app:wait()
    if kind == "tap" then return a.id == "yes" end
    if kind == "key" and a == "enter" then return true end
    if kind == "key" and a == "escape" then return false end
    if kind == "timeout" then return false end
  end
end

function F.message(app, title, lines, kind)
  local color = ({ ok = T.good, error = T.bad, warn = T.warn })[kind or ""] or T.ink
  local function draw(s)
    frame(s, title)
    local y = 6
    for _, line in ipairs(lines or {}) do
      for _, wl in ipairs(kit.wrap(line, s.w - 6)) do
        s:text(3, y, wl, color)
        y = y + 1
      end
    end
    kit.button(s, 3, s.h - 4, math.min(20, s.w - 6), "OK", "ok", { h = 2 })
  end
  app:show(draw)
  while true do
    local k, a = app:wait({ timeout = 30 })
    if k == "tap" or k == "timeout" or (k == "key" and (a == "enter" or a == "escape")) then return end
  end
end

function F.choose(app, title, options, o)
  o = o or {}
  local state = { offset = 0 }
  local per
  local function draw(s)
    frame(s, title, o.subtitle)
    local top, bottom = 6, s.h - 3
    local bh = o.h or 2
    per = math.max(1, math.floor((bottom - top + 1) / (bh + 1)))
    local first = state.offset + 1
    local y = top
    for i = first, math.min(#options, first + per - 1) do
      local opt = options[i]
      kit.button(s, 3, y, s.w - 6, opt.label, "opt:" .. i, { kind = opt.kind or "panel", h = bh, sub = opt.sub })
      y = y + bh + 1
    end
    if state.offset > 0 then kit.button(s, s.w - 8, 5, 6, "\30", "up", { kind = "secondary" }) end
    if state.offset + per < #options then kit.button(s, s.w - 8, s.h - 2, 6, "\31", "down", { kind = "secondary" }) end
    kit.button(s, 3, s.h - 2, 12, "\27 BACK", "back", { kind = "secondary" })
  end
  app:show(draw)
  while true do
    local kind, a = app:wait()
    if kind == "tap" then
      if a.id == "back" then return nil
      elseif a.id == "up" then state.offset = math.max(0, state.offset - per)
      elseif a.id == "down" then state.offset = math.min(#options - 1, state.offset + per)
      elseif a.id:sub(1, 4) == "opt:" then
        local i = tonumber(a.id:sub(5))
        return options[i].id or i, options[i]
      end
    elseif kind == "scroll" then state.offset = util.clamp(state.offset + a, 0, math.max(0, #options - per))
    elseif kind == "key" and a == "escape" then return nil
    elseif kind == "timeout" then return nil end
    app:refresh()
  end
end

function F.pick_list(app, title, rows, o)
  o = o or {}
  local state = { offset = 0 }
  local per = 1
  local function draw(s)
    frame(s, title, o.subtitle)
    local top = 5
    local h = s.h - top - 3
    per = h
    if #rows == 0 then
      kit.empty(s, 2, top, s.w - 2, h, o.empty or "Nothing here yet", o.hint)
    else
      kit.list(s, 2, top, s.w - 2, h, rows, state)
    end
    kit.button(s, 3, s.h - 2, 12, "\27 BACK", "back", { kind = "secondary" })
    if #rows > per then
      kit.button(s, s.w - 17, s.h - 2, 7, "\30 UP", "up", { kind = "secondary", disabled = state.offset == 0 })
      kit.button(s, s.w - 9, s.h - 2, 8, "\31 DOWN", "down", { kind = "secondary", disabled = not state.more_down })
    end
    if o.action_label then kit.button(s, 17, s.h - 2, math.max(10, #o.action_label + 2), o.action_label, "action", { kind = "success" }) end
  end
  app:show(draw)
  while true do
    local kind, a = app:wait()
    if kind == "tap" then
      if a.id == "back" then return nil
      elseif a.id == "up" then kit.scroll(state, #rows, per, -per)
      elseif a.id == "down" then kit.scroll(state, #rows, per, per)
      elseif a.id == "action" then return "action"
      else return a.id, a.data end
    elseif kind == "scroll" then kit.scroll(state, #rows, per, a)
    elseif kind == "key" then
      if a == "escape" then return nil
      elseif a == "down" then kit.scroll(state, #rows, per, 1)
      elseif a == "up" then kit.scroll(state, #rows, per, -1)
      elseif a == "pageDown" then kit.scroll(state, #rows, per, per)
      elseif a == "pageUp" then kit.scroll(state, #rows, per, -per) end
    elseif kind == "timeout" then return nil end
    app:refresh()
  end
end

return F
