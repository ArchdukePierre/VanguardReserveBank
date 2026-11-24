local Screen = require("ui.screen")
local kit = require("ui.kit")
local theme = require("ui.theme")

local App = {}
App.__index = App

function App.new(o)
  o = o or {}
  local target = o.surface or term.current()
  local self = setmetatable({ target = target, name = o.name, is_monitor = o.name ~= nil, idle = o.idle, toast_timer = nil, draw_fn = nil, last_input = os.clock() }, App)
  if o.scale ~= false and target.setTextScale then
    theme.fit(target, o.min_w, o.min_h)
  end
  self.s = Screen.new(target)
  self.s:invalidate()
  return self
end

function App:render()
  local s = self.s
  s:clear(theme.bg, theme.ink)
  if self.draw_fn then self.draw_fn(s, self) end
  if self.toast then kit.toast(s, self.toast.kind, self.toast.text) end
  s:flush()
end

function App:show(draw_fn)
  self.draw_fn = draw_fn
  self:render()
end

function App:refresh() self:render() end

function App:notify(text, kind, secs)
  self.toast = { text = text, kind = kind or "info" }
  if self.toast_timer then os.cancelTimer(self.toast_timer) end
  self.toast_timer = os.startTimer(secs or 3)
  self:render()
end

function App:clear_toast()
  if self.toast then
    self.toast = nil
    self:render()
  end
end

local KEYNAMES = { [257] = "enter", [259] = "backspace", [256] = "escape", [258] = "tab", [265] = "up", [264] = "down", [263] = "left", [262] = "right", [266] = "pageUp", [267] = "pageDown", [261] = "delete", [335] = "enter" }

local function keyname(code)
  return KEYNAMES[code] or (keys.getName and keys.getName(code)) or tostring(code)
end

function App:wait(o)
  o = o or {}
  local timeout = o.timeout or self.idle
  local tid = timeout and os.startTimer(timeout) or nil
  while true do
    local ev, a, b, c, d = os.pullEvent()
    if ev == "timer" then
      if a == self.toast_timer then
        self.toast_timer = nil
        self:clear_toast()
      elseif a == tid then
        return "timeout"
      end
    elseif ev == "monitor_touch" and (not self.name or a == self.name) then
      if tid then os.cancelTimer(tid) end
      local r = self.s:hit(b, c)
      if self.toast then self:clear_toast() end
      if r then return "tap", r end
      tid = timeout and os.startTimer(timeout) or nil
    elseif ev == "mouse_click" and not self.is_monitor then
      if tid then os.cancelTimer(tid) end
      local r = self.s:hit(b, c)
      if r then return "tap", r end
      tid = timeout and os.startTimer(timeout) or nil
    elseif ev == "mouse_scroll" and not self.is_monitor then
      if tid then os.cancelTimer(tid) end
      return "scroll", a
    elseif ev == "char" then
      if tid then os.cancelTimer(tid) end
      return "char", a
    elseif ev == "key" then
      if tid then os.cancelTimer(tid) end
      return "key", keyname(a)
    elseif ev == "paste" then
      if tid then os.cancelTimer(tid) end
      return "paste", a
    elseif ev == "term_resize" or ev == "monitor_resize" then
      self.s:resize()
      self.s:invalidate()
      self:render()
    elseif o.events and o.events[ev] then
      if tid then os.cancelTimer(tid) end
      return "event", ev, a, b, c, d
    end
  end
end

return App
