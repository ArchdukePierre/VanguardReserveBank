local cfgmod = require("lib.cfg")
local Client = require("lib.client")
local App = require("ui.app")
local kit = require("ui.kit")
local theme = require("ui.theme")
local Core = require("roles.admin.core")
local Home = require("roles.admin.home")

local M = {}

local function find_monitor()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      local m = peripheral.wrap(name)
      if m and (not m.isColor or m.isColor()) then return m, name end
    end
  end
end

local function error_screen(app, title, lines)
  app:show(function(s)
    kit.header(s, title)
    local y = 6
    for _, line in ipairs(lines) do
      for _, wl in ipairs(kit.wrap(line, s.w - 6)) do
        s:text(3, y, wl, theme.bad)
        y = y + 1
      end
    end
    kit.button(s, 3, s.h - 4, math.min(20, s.w - 6), "EXIT", "exit", { h = 2 })
  end)
  while true do
    local kind = app:wait({ timeout = 3600 })
    if kind == "tap" or kind == "key" then return end
  end
end

function M.run()
  local mon, name = find_monitor()
  local o = { idle = 300, min_w = 39, min_h = 19 }
  if mon then o.surface, o.name = mon, name end
  local app = App.new(o)
  local secret, admin = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
  if not secret then
    print("This computer is not paired with the bank. Run: vrb join")
    return error_screen(app, "Not paired", { "This computer is not paired with the bank.", "Run: vrb join" })
  end
  if not admin then
    print("This computer has no admin key. Run: vrb join, then choose staff")
    return error_screen(app, "No admin key", { "This computer has no admin key.", "Run: vrb join, then choose staff" })
  end
  local client, why = Client.new({ admin = admin })
  if not client then
    print("Cannot reach the network: " .. tostring(why))
    return error_screen(app, "No network", { "Cannot reach the bank network: " .. tostring(why), "Attach a wireless modem and start the console again." })
  end
  print("Staff console is running" .. (mon and (" on " .. name) or "") .. ".")
  Home.run(Core.new(app, client))
end

return M
