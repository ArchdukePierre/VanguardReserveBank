local util = require("lib.util")
local theme = require("ui.theme")

local K = {}
local T = theme

function K.center(s, y, text, fg, bg)
  local x = math.floor((s.w - #text) / 2) + 1
  s:text(math.max(1, x), y, text, fg, bg)
end

function K.hline(s, x, y, w, fg, bg, ch)
  s:fill(x, y, w, 1, bg or T.bg, ch or "\140", fg or T.dim)
end

function K.header(s, title, subtitle, right)
  s:fill(1, 1, s.w, 3, T.panel)
  s:text(2, 1, "VANGUARD RESERVE BANK", T.accent, T.panel)
  s:text(2, 2, title or "", T.ink, T.panel)
  if subtitle then s:text(2, 3, util.ellipsis(subtitle, s.w - 2), T.muted, T.panel) end
  if right then s:text(s.w - #right, 1, right, T.accent, T.panel) end
  K.hline(s, 1, 4, s.w, T.accent, T.bg)
end

function K.footer(s, left, right)
  s:fill(1, s.h, s.w, 1, T.panel)
  local room = s.w - 3 - (right and (#right + 1) or 0)
  if left and room > 0 then s:text(2, s.h, util.ellipsis(left, room), T.muted, T.panel) end
  if right then s:text(s.w - #right, s.h, right, T.accent, T.panel) end
end

function K.button(s, x, y, w, label, id, o)
  o = o or {}
  local kind = o.kind or "primary"
  local c = T.btn[kind] or T.btn.primary
  local h = o.h or 1
  local bg, fg = c[1], c[2]
  if o.disabled then bg, fg = T.panel, T.dim end
  if o.active then bg, fg = T.ink, colors.black end
  s:fill(x, y, w, h, bg)
  local ly = y + math.floor((h - 1) / 2)
  local lab = util.ellipsis(label, w - 1)
  s:text(x + math.max(0, math.floor((w - #lab) / 2)), ly, lab, fg, bg)
  if o.sub and h >= 2 then
    local sub = util.ellipsis(o.sub, w - 1)
    s:text(x + math.max(0, math.floor((w - #sub) / 2)), ly + 1, sub, fg, bg)
  end
  local r = s:region(x, y, w, h, id, o.data)
  r.disabled = o.disabled
  return r
end

function K.card(s, x, y, w, h, title, bg)
  bg = bg or T.panel
  s:fill(x, y, w, h, bg)
  if title then
    s:text(x + 1, y, " " .. title .. " ", T.accent, bg)
  end
end

function K.kv(s, x, y, w, label, value, vcolor, bg)
  s:text(x, y, label, T.muted, bg)
  value = tostring(value)
  s:text(x + w - #value, y, value, vcolor or T.ink, bg)
end

function K.money(s, xr, y, cents, color, bg)
  local m = util.money(cents)
  s:text(xr - #m + 1, y, m, color or (cents < 0 and T.bad or T.accent), bg)
end

function K.grid(s, x, y, w, h, cols, items, gap)
  gap = gap or 1
  local rows = math.ceil(#items / cols)
  local bw = math.floor((w - gap * (cols - 1)) / cols)
  local bh = math.max(1, math.floor((h - gap * (rows - 1)) / rows))
  for i, it in ipairs(items) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    K.button(s, x + col * (bw + gap), y + row * (bh + gap), bw, it.label, it.id, { kind = it.kind, h = bh, sub = it.sub, data = it.data, disabled = it.disabled })
  end
end

function K.list(s, x, y, w, h, rows, state, o)
  o = o or {}
  state.offset = state.offset or 0
  local per = h
  if state.offset > math.max(0, #rows - per) then state.offset = math.max(0, #rows - per) end
  for i = 1, per do
    local row = rows[state.offset + i]
    local yy = y + i - 1
    local bg = (i % 2 == 0) and T.bg or colors.black
    if row then
      if row.selected then bg = T.panel end
      s:fill(x, yy, w, 1, bg)
      local right = row.right and tostring(row.right) or ""
      local left = util.ellipsis(row.left or "", w - #right - 2)
      s:text(x + 1, yy, left, row.color or T.ink, bg)
      if right ~= "" then s:text(x + w - #right - 1, yy, right, row.rcolor or T.accent, bg) end
      if row.id then s:region(x, yy, w, 1, row.id, row.data) end
    end
  end
  state.more_up = state.offset > 0
  state.more_down = state.offset + per < #rows
  if state.more_up then s:text(x + w - 1, y, "\30", T.accent, T.bg) end
  if state.more_down then s:text(x + w - 1, y + h - 1, "\31", T.accent, T.bg) end
  return per
end

function K.scroll(state, rows_count, per, delta)
  state.offset = util.clamp((state.offset or 0) + delta, 0, math.max(0, rows_count - per))
end

function K.empty(s, x, y, w, h, title, hint)
  K.card(s, x, y, w, h)
  local cy = y + math.floor(h / 2) - 1
  title = util.ellipsis(title, w - 2)
  s:text(x + math.floor((w - #title) / 2), cy, title, T.ink, T.panel)
  if hint then
    hint = util.ellipsis(hint, w - 2)
    s:text(x + math.floor((w - #hint) / 2), cy + 1, hint, T.muted, T.panel)
  end
end

function K.toast(s, kind, text)
  local bg = ({ ok = T.good, error = T.bad, warn = T.warn, info = T.info })[kind or "info"] or T.info
  local fg = (kind == "error") and colors.white or colors.black
  local w = math.min(s.w - 2, #text + 4)
  local x = math.floor((s.w - w) / 2) + 1
  local y = math.max(1, s.h - 3)
  s:fill(x, y, w, 1, bg)
  s:text(x + 2, y, util.ellipsis(text, w - 4), fg, bg)
end

function K.progress(s, x, y, w, frac, fg, bg)
  frac = util.clamp(frac, 0, 1)
  local n = math.floor(w * frac + 0.5)
  s:fill(x, y, w, 1, bg or T.panel)
  if n > 0 then s:fill(x, y, n, 1, fg or T.good) end
end

function K.wrap(text, w)
  local lines = {}
  for para in tostring(text):gmatch("[^\n]+") do
    local line = ""
    for word in para:gmatch("%S+") do
      if #line + #word + 1 > w and line ~= "" then lines[#lines + 1] = line; line = word
      else line = (line == "") and word or (line .. " " .. word) end
    end
    if line ~= "" then lines[#lines + 1] = line end
  end
  return lines
end

return K
