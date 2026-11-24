local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local function slurp(name)
  local f = assert(io.open(HERE .. "/fixtures/v9/" .. name, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local files = {
  ["/.vrb/keys/server.secret"] = slurp("server.secret"),
  ["/.vrb/keys/admin.key"] = slurp("admin.key"),
  ["/.vrb/bank.db"] = slurp("bank.db"),
  ["/.vrb/ledger.log"] = slurp("ledger.log"),
}
local ids = {}
for k, v in slurp("ids.txt"):gmatch("([%w_]+)=(%S+)") do ids[k] = v end
local ALICE, BOB = ids.alice_chk, ids.bob_chk
local NOTE = assert(load("return " .. slurp("note.txt"), "note", "t", {}))()

local world, server = N.world({ files = files })
local client = N.client_pc(world, 2, { ["/.vrb/keys/server.secret"] = files["/.vrb/keys/server.secret"], ["/.vrb/keys/admin.key"] = files["/.vrb/keys/admin.key"] })
N.run_client(world, client, function()
  local Client = require("lib.client")
  local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
  local r = c:call("auth", { account_id = ALICE, pin = "1234" })
  T.check(r.ok, "v9 alice PIN still works after migration")
  local s = r.session
  r = c:call("profile", { session = s })
  T.check(r.ok and r.profile.checking.balance == 419000 and r.profile.savings.balance == 50000, "alice balances carried over")
  r = c:call("list_cds", { session = s })
  T.check(r.ok and #r.cds == 1 and r.cds[1].principal == 20000, "certificate of deposit carried over")
  r = c:call("my_rank", { session = s })
  T.check(r.ok and r.vanguard and r.rank.id == "E3", "vanguard rank carried over")
  r = c:call("history", { session = s })
  T.check(r.ok and #r.history > 0 and r.history[1].type, "history carried over with readable fields")
  r = c:call("list_factions", { session = s })
  T.check(r.ok and #r.factions == 1 and r.factions[1].n == 2, "faction carried over")
  local b = c:call("auth_by_owner", { owner = "bob", pin = "4321" })
  T.check(b.ok, "bob signs in by name")
  r = c:call("list_loans", { session = b.session })
  T.check(r.ok and #r.loans == 1 and r.loans[1].balance == 40000, "loan carried over")
  r = c:call("list_my_shops", { session = b.session })
  T.check(r.ok and #r.shops == 1 and r.shops[1].label == "Bobs Shop", "shop carried over")
  r = c:call("list_payment_requests", { session = b.session })
  T.check(r.ok and #r.requests == 1 and r.requests[1].amount == 1500, "pending bill carried over")
  r = c:call("transfer", { session = s, target_id = BOB, amount = 1000, memo = "after migration" })
  T.check(r.ok and r.balance == 418000, "new transfers work on migrated accounts")
  local bb = c:call("balance", { session = b.session }).balance
  r = c:call("redeem_note", { session = b.session, note = NOTE })
  T.check(r.ok, "a v9 reserve note still redeems (" .. tostring(r.err) .. ")")
  T.eq(c:call("balance", { session = b.session }).balance - bb, 1000, "the note paid its face value")
  T.check(not c:call("redeem_note", { session = b.session, note = NOTE }).ok, "the migrated note registry stops a second redemption")
  r = c:call("admin_diagnostics", {}, { admin = true })
  T.check(r.ok and r.audit_mismatched == 0, "audit is clean after migration")
  r = c:call("admin_list_accounts", { all_kinds = true }, { admin = true })
  T.check(r.ok and r.total == 6, "six accounts (two pairs, the faction treasury and the bank treasury)")
end)
world:run({ seconds = 10 })
T.check(server.fs.exists("/.vrb/legacy/bank.db.v9"), "v9 database kept under legacy")
T.check(not server.fs.exists("/.vrb/bank.db"), "v9 database no longer in the way")

local keep = N.snapshot(server)
local world2 = N.world({ files = keep })
local client2 = N.client_pc(world2, 2, { ["/.vrb/keys/server.secret"] = files["/.vrb/keys/server.secret"] })
N.run_client(world2, client2, function()
  local c = assert(require("lib.client").new({}))
  local r = c:call("auth", { account_id = ALICE, pin = "1234" })
  T.check(r.ok, "alice signs in after restart")
  r = c:call("profile", { session = r.session })
  T.check(r.ok and r.profile.checking.balance == 418000, "post-migration transfer persisted")
end)
T.done()
