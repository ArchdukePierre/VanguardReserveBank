local theme = {
  bg = colors.black,
  panel = colors.gray,
  ink = colors.white,
  muted = colors.lightGray,
  dim = colors.gray,
  accent = colors.yellow,
  accent_dim = colors.orange,
  good = colors.lime,
  bad = colors.red,
  warn = colors.orange,
  info = colors.lightBlue,
  btn = { primary = { colors.yellow, colors.black }, secondary = { colors.lightGray, colors.black }, danger = { colors.red, colors.white },
    success = { colors.lime, colors.black }, ghost = { colors.black, colors.yellow }, panel = { colors.gray, colors.white } },
}

function theme.fit(mon, want_w, want_h)
  if not mon.setTextScale then return mon.getSize() end
  want_w, want_h = want_w or 51, want_h or 19
  for _, scale in ipairs({ 5, 4, 3, 2.5, 2, 1.5, 1, 0.5 }) do
    local ok = pcall(mon.setTextScale, scale)
    if ok then
      local w, h = mon.getSize()
      if w >= want_w and h >= want_h then return w, h, scale end
    end
  end
  pcall(mon.setTextScale, 0.5)
  local w, h = mon.getSize()
  return w, h, 0.5
end

return theme
