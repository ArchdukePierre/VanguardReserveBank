local T = dofile(HERE .. "/lib.lua")
local cc = T.cc

local world = cc.new()
local C = world:computer({ id = 5, monitors = { { w = 57, h = 38, scale = 0.5 } }, w = 51, h = 19 })
T.mount(C)
local mon = C.monitors[1]

local out = {}
local function start(fn)
  out = { done = false }
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    out.ok, out.err, out.done = ok, err, true
  end)
end
local function settle() world:run({ seconds = 0.2 }) end
local function tap(id)
  local app = C.env.APP
  for _, r in ipairs(app.s.regions) do
    if r.id == id then
      C.queue[#C.queue + 1] = { "monitor_touch", mon.__name, r.x + 1, r.y }
      settle()
      return true
    end
  end
  T.check(false, "no region " .. tostring(id) .. " on screen")
end
local function type_chars(s) for ch in s:gmatch(".") do C.queue[#C.queue + 1] = { "char", ch }; settle() end end

start(function()
  local App = require("ui.app")
  local flows = require("ui.flows")
  APP = App.new({ surface = peripheral.wrap("monitor_1"), name = "monitor_1" })
  RESULTS = {}
  RESULTS.pin = flows.pin(APP, "Sign in")
  RESULTS.amount = flows.amount(APP, "Pay", { limit = 100000 })
  RESULTS.text = flows.text(APP, { title = "Username" })
  RESULTS.confirm = flows.confirm(APP, "Pay alice", { "Send $12.50 to alice?" })
  RESULTS.choice = flows.choose(APP, "Pick", { { label = "One", id = "a" }, { label = "Two", id = "b" } })
  RESULTS.list = flows.pick_list(APP, "People", { { left = "alice", right = "$5.00", id = "r1" }, { left = "bob", right = "$1.00", id = "r2" } })
end)
settle()
local screen = mon._dump()
T.check(screen:find("VANGUARD RESERVE BANK"), "header drawn on monitor")
for _, k in ipairs({ "1", "2", "3", "4" }) do tap("key:" .. k) end
settle()
T.eq(C.env.RESULTS.pin, "1234", "pin keypad returns digits and auto submits")

tap("key:1"); tap("key:2"); tap("key:."); tap("key:5")
T.check(C.env.RESULTS.amount == nil, "amount waits for OK")
tap("ok")
T.eq(C.env.RESULTS.amount, 1250, "amount parsed to cents")

type_chars("bob")
C.queue[#C.queue + 1] = { "key", 257, false }
settle()
T.eq(C.env.RESULTS.text, "bob", "text via keyboard")

tap("yes")
T.eq(C.env.RESULTS.confirm, true, "confirm yes")
tap("opt:2")
T.eq(C.env.RESULTS.choice, "b", "choose returns id")
settle()
local calls_before = mon._T.calls
world:run({ seconds = 120 })
T.eq(mon._T.calls, calls_before, "no monitor writes while idle for 120 seconds")
tap("r2")
T.eq(C.env.RESULTS.list, "r2", "pick_list returns row id")
T.check(C.env.APP.s.stats.rows > 0, "renderer sent rows")
T.done()
