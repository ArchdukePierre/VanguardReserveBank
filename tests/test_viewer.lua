local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local SHOW = ARGS and ARGS[1] == "dump"
local function show(title, text)
  if SHOW then
    print(title)
    print(text)
  end
end

local ser = dofile(REPO .. "/vrb/lib/ser.lua")

local function start(world, C)
  local res = { done = false }
  local fn = function() require("roles.viewer").run() end
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    res.ok, res.err, res.done = ok, err, true
  end)
  return res
end

local function seed(world)
  local admin = N.client_pc(world, 2)
  N.run_client(world, admin, function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    local a = c:call("open_account", { owner = "alice", pin = "1234" })
    local b = c:call("open_account", { owner = "bob", pin = "4321" })
    T.check(a.ok and b.ok, "open accounts")
    T.check(c:call("admin_issue", { account_id = a.checking_id, amount = 250000, reason = "seed" }, { admin = true }).ok, "issue money")
    local s = c:call("auth_by_owner", { owner = "alice", pin = "1234" })
    T.check(c:call("transfer", { session = s.session, target_id = b.checking_id, amount = 10000, memo = "rent" }).ok, "transfer")
  end)
  return admin
end

local function issue(world, amount)
  local pc = N.client_pc(world, 40 + math.random(1, 50))
  N.run_client(world, pc, function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    local r = c:call("admin_list_accounts", { filter = "alice" }, { admin = true })
    local id = r.accounts[1].id
    T.check(c:call("admin_issue", { account_id = id, amount = amount, reason = "more" }, { admin = true }).ok, "issue more money")
  end)
end

local SIZES = {
  { name = "57x38 (3x3)", w = 57, h = 38 },
  { name = "29x19 (2x1)", w = 29, h = 19 },
  { name = "51x19", w = 51, h = 19 },
  { name = "39x26", w = 39, h = 26 },
  { name = "29x38", w = 29, h = 38 },
  { name = "57x19", w = 57, h = 19 },
}

do
  local world, server = N.world()
  seed(world)
  local views = {}
  for i, size in ipairs(SIZES) do
    local C = N.client_pc(world, 10 + i, N.keys(), { monitors = { { w = size.w, h = size.h, scale = 0.5 } } })
    views[i] = { C = C, res = start(world, C), size = size }
  end
  world:run({ seconds = 5 })
  for _, v in ipairs(views) do
    local mon = v.C.monitors[1]
    local text = mon._dump()
    local w, h = mon.getSize()
    show(string.format("--- viewer on %s monitor (%dx%d) ---", v.size.name, w, h), text)
    T.check(not v.C.crash and not v.res.done, v.size.name .. " keeps running")
    for _, want in ipairs({ "Money supply", "$2,500.00", "Accounts", "Active this week", "Transactions", "Loans out", "RATES", "INCOME TAX", "RECENT ACTIVITY", "Money issued", "Transfer" }) do
      T.check(text:find(want, 1, true), v.size.name .. " shows " .. want)
    end
    T.check(text:find("2%%/mo") or text:find("2%%/mo"), v.size.name .. " shows the savings rate")
    T.check(text:find("5%", 1, true), v.size.name .. " shows the transaction tax")
    T.check(text:find("$50k+", 1, true) and text:find("10M+", 1, true) == nil or text:find("$10M+", 1, true), v.size.name .. " shows tax brackets")
    T.check(not text:find("Waiting for the bank", 1, true), v.size.name .. " is not waiting")
  end

  local big = views[1].C.monitors[1]
  world:run({ seconds = 30 })
  local calls = big._T.calls
  local small_calls = views[2].C.monitors[1]._T.calls
  world:run({ seconds = 100 })
  T.eq(big._T.calls, calls, "idle monitor writes nothing across several pushes")
  T.eq(views[2].C.monitors[1]._T.calls, small_calls, "small idle monitor writes nothing across several pushes")

  issue(world, 50000)
  world:run({ seconds = 45 })
  T.check(big._dump():find("$3,000.00", 1, true), "a push updates the monitor")
  T.check(views[2].C.monitors[1]._dump():find("$3,000.00", 1, true), "a push updates the small monitor")
  T.check(big._dump():find("$500.00", 1, true), "new event appears in the feed")
end

do
  local world = N.world({ config = ser.encode({ server = { beacon_sec = 100000 } }) })
  seed(world)
  local C = N.client_pc(world, 11, N.keys(), { monitors = { { w = 57, h = 38, scale = 0.5 } } })
  local res = start(world, C)
  world:run({ seconds = 20 })
  local mon = C.monitors[1]
  T.check(mon._dump():find("$2,500.00", 1, true), "first fetch fills the screen without a push")
  issue(world, 50000)
  world:run({ seconds = 40 })
  T.check(not mon._dump():find("$3,000.00", 1, true), "no push and no poll before 70 seconds")
  world:run({ seconds = 50 })
  T.check(mon._dump():find("$3,000.00", 1, true), "after 70 quiet seconds the viewer asks once")
  local calls = mon._T.calls
  world:run({ seconds = 60 })
  T.check(not res.done and not C.crash, "still running")
end

do
  local cc = T.cc
  local world = cc.new({ latency = 0.02 })
  local C = world:computer({ id = 3, files = N.keys(), monitors = { { w = 29, h = 19, scale = 0.5 } } })
  T.mount(C)
  local C2 = world:computer({ id = 4, files = N.keys(), monitors = { { w = 57, h = 38, scale = 0.5 } } })
  T.mount(C2)
  start(world, C)
  start(world, C2)
  world:run({ seconds = 100 })
  local small, big = C.monitors[1]._dump(), C2.monitors[1]._dump()
  show("--- bank offline, 29x19 ---", small)
  show("--- bank offline, 57x38 ---", big)
  T.check(small:find("Waiting for the bank", 1, true), "small monitor shows the waiting banner")
  T.check(big:find("Waiting for the bank", 1, true), "large monitor shows the waiting banner")
  T.check(small:find("--", 1, true) and big:find("RECENT ACTIVITY", 1, true), "layout still drawn without data")
  local server = world:computer({ id = 1, label = "bank", files = N.keys() })
  T.mount(server)
  world:start(server, T.setenv(function() require("server.init").run() end, server.env))
  world:run({ seconds = 120 })
  local small2, big2 = C.monitors[1]._dump(), C2.monitors[1]._dump()
  T.check(not small2:find("Waiting for the bank", 1, true) and small2:find("$0.00", 1, true), "small monitor recovers when the bank returns")
  T.check(not big2:find("Waiting for the bank", 1, true), "large monitor recovers when the bank returns")
end

do
  local world = N.world()
  seed(world)
  local C = N.client_pc(world, 12, N.keys(), { w = 51, h = 19 })
  start(world, C)
  world:run({ seconds = 5 })
  local text = C.term._dump()
  show("--- viewer on the 51x19 terminal (no monitor) ---", text)
  T.check(text:find("Money supply", 1, true) and text:find("RECENT ACTIVITY", 1, true), "terminal fallback works without a monitor")
end

do
  local world = T.cc.new()
  local C = world:computer({ id = 5, files = {} })
  T.mount(C)
  local res = start(world, C)
  world:run({ seconds = 3 })
  T.check(res.done and res.ok and table.concat(C.printed, " "):find("server.secret is missing", 1, true), "missing key gives a message")
end

T.done()
