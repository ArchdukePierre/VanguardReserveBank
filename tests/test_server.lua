local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local world, server = N.world()
local client = N.client_pc(world, 2)
local alice_chk, alice_sav, bob_chk

N.run_client(world, client, function()
  local Client = require("lib.client")
  local c = assert(Client.new({ admin = (require("lib.cfg")).read_key("admin.key") }))
  local function call(m, p, admin) return c:call(m, p, { admin = admin }) end

  local r = call("ping", {})
  T.check(r.ok and r.version, "ping works")

  r = call("open_account", { owner = "alice", pin = "1234" })
  T.check(r.ok and r.checking_id and r.savings_id, "open alice")
  alice_chk, alice_sav = r.checking_id, r.savings_id
  r = call("open_account", { owner = "Bob", pin = "4321" })
  T.check(r.ok, "open bob")
  bob_chk = r.checking_id
  r = call("open_account", { owner = "ALICE", pin = "1111" })
  T.check(not r.ok, "duplicate username rejected case-insensitively")
  r = call("open_account", { owner = "bad name", pin = "1234" })
  T.check(not r.ok, "invalid username rejected")

  r = call("admin_issue", { account_id = alice_chk, amount = 100000, reason = "seed funds" })
  T.check(not r.ok, "admin call without admin key refused")
  r = call("admin_issue", { account_id = alice_chk, amount = 100000, reason = "seed funds" }, true)
  T.check(r.ok and r.balance == 100000, "admin issue works")

  r = call("auth", { account_id = alice_chk, pin = "9999" })
  T.check(not r.ok, "bad pin refused")
  r = call("auth", { account_id = alice_chk, pin = "1234" })
  T.check(r.ok and r.session, "sign in")
  local s = r.session

  r = call("transfer", { session = s, target_id = bob_chk, amount = 10000, memo = "rent" })
  T.check(r.ok and r.tax == 500 and r.balance == 90000, "transfer with 5% tax")
  r = call("transfer", { session = s, target_id = bob_chk, amount = 10000000 })
  T.check(not r.ok, "overdraft refused")
  r = call("transfer", { session = s, target_id = alice_chk, amount = 100 })
  T.check(not r.ok, "self transfer refused")
  r = call("transfer", { session = s, target_id = alice_sav, amount = 100 })
  T.check(not r.ok, "transfer into own savings refused")

  r = call("move_internal", { session = s, amount = 20000, direction = "chk_to_sav" })
  T.check(r.ok and r.checking == 70000 and r.savings == 20000, "move to savings")
  r = call("move_internal", { session = s, amount = 10000, direction = "sav_to_chk" })
  T.check(r.ok and r.tax == 5000 and r.credited == 5000, "early savings withdrawal taxed 50% of young funds")

  r = call("profile", { session = s })
  T.check(r.ok and r.profile.checking.balance == 75000 and r.profile.savings.balance == 10000, "profile balances")
  r = call("history", { session = s, limit = 10 })
  T.check(r.ok and #r.history >= 4, "history rows")
  r = call("self_audit", { session = s })
  T.check(r.ok and r.ok_match, "self audit matches")

  r = call("request_payment", { session = s, target_owner = "bob", amount = 2500, memo = "lunch" })
  T.check(r.ok, "request payment")
  local rid = r.request_id
  local b = call("auth_by_owner", { owner = "bob", pin = "4321" })
  T.check(b.ok, "bob signs in by name")
  r = call("list_payment_requests", { session = b.session })
  T.check(r.ok and #r.requests == 1 and r.requests[1].from_owner == "alice", "bob sees the bill")
  r = call("approve_payment_request", { session = b.session, request_id = rid })
  T.check(r.ok, "bob pays the bill")
  r = call("balance", { session = b.session })
  T.check(r.ok and r.balance == 7000, "bob balance after bill (" .. tostring(r.balance) .. ")")

  for i = 1, 5 do r = call("auth", { account_id = bob_chk, pin = "0000" }) end
  r = call("auth", { account_id = bob_chk, pin = "4321" })
  T.check(not r.ok and (r.err or ""):find("locked"), "lockout after repeated failures")

  r = call("admin_unlock", { account_id = bob_chk }, true)
  T.check(r.ok, "admin unlock")
  r = call("auth", { account_id = bob_chk, pin = "4321" })
  T.check(r.ok, "bob can sign in again")

  r = call("admin_diagnostics", {}, true)
  T.check(r.ok and r.accounts == 5 and r.audit_mismatched == 0, "diagnostics: 5 accounts incl. treasury and no audit mismatches (" .. tostring(r.accounts) .. ")")
  r = call("admin_audit", {}, true)
  T.check(r.ok and #r.mismatched == 0, "audit clean")
  r = call("admin_ledger_tail", { limit = 5 }, true)
  T.check(r.ok and #r.entries == 5, "ledger tail")
  r = call("public_ledger_tail", { limit = 5 })
  T.check(r.ok and #r.entries > 0 and not tostring(r.entries[1].from or ""):find("ACC%-"), "public tail anonymized")
end)

world:run({ seconds = 30 })
local db_files = N.snapshot(server)
local keep = {}
for p, d in pairs(db_files) do keep[p] = d end

T.check(server.F.bytes_written < 60000, "total bytes written for this session is small (" .. server.F.bytes_written .. ")")

local world2, server2 = N.world({ files = keep })
local client2 = N.client_pc(world2, 2)
N.run_client(world2, client2, function()
  local Client = require("lib.client")
  local c = assert(Client.new({}))
  local r = c:call("auth", { account_id = alice_chk, pin = "1234" })
  T.check(r.ok, "alice signs in after restart (pin hashes persisted)")
  r = c:call("profile", { session = r.session })
  T.check(r.ok and r.profile.checking.balance == 77375 and r.profile.savings.balance == 10000, "balances survive restart")
end)
T.done()
