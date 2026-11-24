local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local world, server = N.world()
local setup = N.client_pc(world, 2)
local acct = {}
N.run_client(world, setup, function()
  local c = assert(require("lib.client").new({ admin = require("lib.cfg").read_key("admin.key") }))
  for i = 1, 6 do
    local r = c:call("open_account", { owner = "user" .. i, pin = "1234" })
    acct[i] = r.account_id
    c:call("admin_issue", { account_id = r.account_id, amount = 1000000, reason = "seed funds" }, { admin = true })
  end
end)

local total_before = 6 * 1000000
local pcs, done_count, ok_count = {}, 0, 0
for i = 1, 5 do
  local pc = N.client_pc(world, 10 + i)
  pcs[i] = pc
  T.setenv(function()
    local c = assert(require("lib.client").new({}))
    local a = c:call("auth", { account_id = acct[i], pin = "1234" })
    for k = 1, 25 do
      local r = c:call("transfer", { session = a.session, target_id = acct[(i % 6) + 1], amount = 100 + k })
      if r.ok then ok_count = ok_count + 1 end
    end
    done_count = done_count + 1
  end, pc.env)
  world:start(pc, function() local ok, e = xpcall(function() end, debug.traceback) end)
end

for i = 1, 5 do
  local pc = pcs[i]
  local fn = T.setenv(function()
    local c = assert(require("lib.client").new({}))
    local a = c:call("auth", { account_id = acct[i], pin = "1234" })
    for k = 1, 25 do
      local r = c:call("transfer", { session = a.session, target_id = acct[(i % 6) + 1], amount = 100 + k })
      if r.ok then ok_count = ok_count + 1 end
    end
    done_count = done_count + 1
  end, pc.env)
  world:start(pc, function() local ok, e = xpcall(fn, debug.traceback); if not ok then print(e); T.failed = T.failed + 1 end end)
end
world:run({ seconds = 600, stop = function() return done_count == 5 end, max_steps = 5e7 })
T.eq(done_count, 5, "all five clients finished")
T.eq(ok_count, 125, "all concurrent transfers acknowledged")

local probe = N.client_pc(world, 3)
local diag
N.run_client(world, probe, function()
  local c = assert(require("lib.client").new({ admin = require("lib.cfg").read_key("admin.key") }))
  diag = c:call("admin_diagnostics", {}, { admin = true })
  local ra = c:call("admin_audit", {}, { admin = true })
  T.check(#ra.mismatched == 0, "audit clean after concurrent load")

  T.eq(ra.total, total_before, "total money is conserved across 125 taxed transfers")
end)
T.check(diag and diag.requests >= 125, "server counted the requests")
T.check(diag.handler_avg_ms < 200, "average handler time is small (" .. tostring(diag.handler_avg_ms) .. " ms)")

local flooder = N.client_pc(world, 4)
local res = {}
N.run_client(world, flooder, function()
  local c = assert(require("lib.client").new({}))
  local net = require("lib.net")
  local secret = require("lib.cfg").read_key("server.secret")
  for i = 1, 200 do
    c.modem.transmit(c.channel, c.reply, net.seal(secret, { i = net.nonce(), m = "ping", p = {} }, true))
  end
  res.flooded = true
end, 5)
world:run({ seconds = 5 })
local d2
N.run_client(world, probe, function()
  local c = assert(require("lib.client").new({ admin = require("lib.cfg").read_key("admin.key") }))
  d2 = c:call("admin_diagnostics", {}, { admin = true })
  local r = c:call("ping", {})
  T.check(r.ok, "server still answers other clients after a flood")
end)
T.check(d2.rate_limited >= 100, "flood was throttled (" .. tostring(d2.rate_limited) .. " dropped)")
T.check(d2.queue_depth == 0, "queue drained")

local before_tx = d2.requests
local attacker = N.client_pc(world, 6)
local dup = {}
N.run_client(world, attacker, function()
  local Client = require("lib.client")
  local net = require("lib.net")
  local c = assert(Client.new({}))
  local secret = require("lib.cfg").read_key("server.secret")
  local a = c:call("auth", { account_id = acct[1], pin = "1234" })
  local payload = { i = "fixed-rpc-id-0001", m = "transfer", p = { session = a.session, target_id = acct[2], amount = 5000 } }
  local env1 = net.seal(secret, payload, true)
  c.modem.transmit(c.channel, c.reply, env1)
  c.modem.transmit(c.channel, c.reply, env1)
  sleep(1)
  local env2 = net.seal(secret, payload, true)
  c.modem.transmit(c.channel, c.reply, env2)
  sleep(1)
  local p = c:call("profile", { session = a.session })
  dup.balance = p.profile.checking.balance
  dup.session = a.session
end)
local start_bal = 1000000 - 25 * 100 - (1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20 + 21 + 22 + 23 + 24 + 25)
T.check(dup.balance ~= nil, "duplicate scenario ran")

local expect = 1000000
for k = 1, 25 do expect = expect - (100 + k) end
expect = expect - 5000
T.eq(dup.balance, expect, "a transfer sent three times with one request id and a replayed packet executes once")

local world2 = T.cc.new({ latency = 0.02 })
local keys = N.keys()
local srv = world2:computer({ id = 1, files = keys, capacity = 1000000 })
T.mount(srv)
srv.F.capacity = srv.F.used + 90000
world2:start(srv, T.setenv(function() require("server.init").run() end, srv.env))
local cl = world2:computer({ id = 2, files = keys })
T.mount(cl)
local fullres = {}
N.run_client(world2, cl, function()
  local c = assert(require("lib.client").new({ admin = require("lib.cfg").read_key("admin.key") }))
  local made, last_err = 0, nil
  for i = 1, 400 do
    local r = c:call("open_account", { owner = "p" .. i, pin = "1234" })
    if r.ok then made = made + 1 else last_err = r; break end
  end
  fullres.made, fullres.err = made, last_err
  local r = c:call("ping", {})
  fullres.ping = r
  local a = c:call("lookup", { owner = "p1" })
  fullres.lookup = a
end, 900)
T.check(fullres.made and fullres.made > 20 and fullres.made < 400, "account opening stops when the disk is nearly full (" .. tostring(fullres.made) .. ")")
T.check(fullres.err and fullres.err.code == "disk_full", "clear disk_full error to the client")
T.check(fullres.ping and fullres.ping.ok and fullres.ping.writable == false, "reads and ping still work, writable=false")
T.check(fullres.lookup and fullres.lookup.ok and #fullres.lookup.accounts == 1, "lookups still work on a full disk")
T.check(not srv.crash, "server did not crash on a full disk")
T.done()
