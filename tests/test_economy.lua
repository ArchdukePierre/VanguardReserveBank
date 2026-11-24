local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local config = '{server={interest_tick_sec=60,month_sec=3600}}'
local world, server = N.world({ config = config })
local pc = N.client_pc(world, 2)

N.run_client(world, pc, function()
  local c = assert(require("lib.client").new({ admin = require("lib.cfg").read_key("admin.key") }))
  local function call(m, p, admin) return c:call(m, p, { admin = admin }) end
  local function adm(m, p) return c:call(m, p, { admin = true }) end
  local function open(name, pin)
    local r = call("open_account", { owner = name, pin = pin or "1111" })
    assert(r.ok, r.err)
    local a = call("auth_by_owner", { owner = name, pin = pin or "1111" })
    return r, a.session
  end
  local alice, sa = open("alice")
  local bob, sb = open("bob")
  local carol, sc = open("carol")
  adm("admin_issue", { account_id = alice.checking_id, amount = 1000000, reason = "seed" })
  adm("admin_issue", { account_id = bob.checking_id, amount = 200000, reason = "seed" })

  local r = call("open_cd", { session = sa, amount = 10000, days = 30 })
  T.check(r.ok and r.mpr == 0.03, "open 30 day CD")
  T.check(not call("open_cd", { session = sa, amount = 100, days = 10 }).ok, "CD under 30 days refused")
  local cds = call("list_cds", { session = sa })
  r = call("redeem_cd", { session = sa, cd_id = cds.cds[1].id })
  T.check(r.ok and r.payout == 9500 and not r.mature, "early CD redemption pays 95 percent")
  r = call("request_loan", { session = sb, amount = 100000 })
  T.check(r.ok, "loan with collateral on deposit")
  T.check(not call("request_loan", { session = sc, amount = 100000 }).ok, "loan without collateral refused")
  local loans = call("list_loans", { session = sb })
  r = call("repay_loan", { session = sb, loan_id = loans.loans[1].id, amount = 100000 })
  T.check(r.ok and r.closed, "repay loan in full")

  local before = call("profile", { session = sa }).profile.checking.balance
  sleep(130)
  local after = call("profile", { session = sa }).profile.checking.balance
  T.check(after > before, "interest posted by the scheduler (" .. before .. " to " .. after .. ")")

  r = call("move_internal", { session = sa, amount = 100000, direction = "chk_to_sav" })
  T.check(r.ok, "move to savings")
  r = call("profile", { session = sa })
  T.check(r.profile.savings.young_cents == 100000, "young savings tracked")

  r = call("create_faction", { session = sa, name = "Guild", n = 2, m = 2 })
  T.check(r.ok, "create faction")
  local fid, tid = r.faction_id, r.treasury_id
  T.check(call("faction_add_member", { session = sa, faction_id = fid, member = "bob" }).ok, "add member")
  T.check(not call("faction_add_member", { session = sb, faction_id = fid, member = "carol" }).ok, "only the founder adds members")
  r = call("transfer", { session = sa, target_id = tid, amount = 200000 })
  T.check(r.ok, "fund the treasury")
  r = call("transfer", { session = sa, target_id = carol.checking_id, amount = 50000, from_faction = fid, memo = "build fund" })
  T.check(r.ok and r.pending, "treasury payment becomes a proposal")
  local pend = call("list_pending_tx", { session = sb })
  T.check(pend.ok and #pend.pending == 1 and pend.pending[1].required == 2, "bob sees the proposal")
  r = call("approve_pending_tx", { session = sb, pending_id = pend.pending[1].id })
  T.check(r.ok and r.executed, "second approval executes")
  r = call("balance", { session = sc })
  T.check(r.balance == 47500, "carol received the taxed amount (" .. tostring(r.balance) .. ")")
  local fl = call("list_factions", { session = sb })
  T.check(fl.ok and #fl.factions == 1 and fl.factions[1].balance == 190000 - 50000, "faction list shows the treasury")

  r = call("create_escrow", { session = sa, counterparty = bob.checking_id, amount = 10000, memo = "deal" })
  T.check(r.ok, "create escrow")
  local esc = call("list_my_escrows", { session = sb })
  T.check(#esc.escrows == 1 and esc.escrows[1].you_are == "recipient", "recipient sees the escrow")
  local bb = call("balance", { session = sb }).balance
  T.check(call("release_escrow", { session = sa, escrow_id = r.escrow_id }).ok, "release escrow")
  T.eq(call("balance", { session = sb }).balance - bb, 9500, "escrow payout is taxed")
  r = call("create_escrow", { session = sa, counterparty = bob.checking_id, amount = 5000 })
  T.check(call("refund_escrow", { session = sb, escrow_id = r.escrow_id }).ok, "recipient refunds escrow")

  r = call("create_shop", { session = sb, label = "Bob Mining" })
  local shop = r.shop_id
  T.check(r.ok and shop:match("^SHP%-"), "create shop")
  T.check(call("set_shop_listing", { session = sb, shop_id = shop, sku = "dia", item = "Diamond", price = 5000, stock = 10, item_id = "minecraft:diamond" }).ok, "list an item")
  local gs = call("get_shop", { shop_id = shop })
  T.check(gs.ok and #gs.shop.listings == 1, "public shop view")
  local ab = call("balance", { session = sa }).balance
  local bb2 = call("balance", { session = sb }).balance
  r = call("buy_from_shop", { session = sa, shop_id = shop, sku = "dia", qty = 3 })
  T.check(r.ok and r.cost == 15000 and r.dispensed.qty == 3 and r.dispensed.item_id == "minecraft:diamond", "buy from shop")
  T.eq(call("balance", { session = sb }).balance - bb2, 15000 - 150, "seller gets the price minus the shop tax")
  T.check(not call("buy_from_shop", { session = sa, shop_id = shop, sku = "dia", qty = 99 }).ok, "out of stock refused")
  T.eq(call("get_shop", { shop_id = shop }).shop.listings[1].stock, 7, "stock reduced")

  r = call("item_deposit", { session = sc, item = "minecraft:diamond", count = 2 })
  T.check(r.ok and r.credited == 12800, "item deposit credits the backed value")
  T.check(not call("item_deposit", { session = sc, item = "minecraft:dirt", count = 2 }).ok, "unbacked item refused")
  r = adm("admin_issue_note", { account_id = alice.checking_id, denomination = 10 })
  T.check(r.ok and r.note.serial, "issue a reserve note")
  local note = r.note
  local cb = call("balance", { session = sc }).balance
  T.check(call("redeem_note", { session = sc, note = note }).ok, "redeem note")
  T.eq(call("balance", { session = sc }).balance - cb, 1000, "note pays its denomination")
  T.check(not call("redeem_note", { session = sc, note = note }).ok, "a note redeems once")
  local forged = { serial = note.serial, denom = 1000, issued = note.issued, account = note.account, sig = note.sig, v = 10 }
  T.check(not call("redeem_note", { session = sc, note = forged }).ok, "a changed note is refused")

  r = call("submit_claim", { session = sc, progress_id = "first_diamond", evidence = "screenshot" })
  T.check(r.ok, "submit claim")
  local pc_list = adm("admin_pending_claims", {})
  T.check(#pc_list.claims == 1, "claim waits for staff")
  cb = call("balance", { session = sc }).balance
  r = adm("admin_approve_claim", { account_id = carol.checking_id, progress_id = "first_diamond" })
  T.check(r.ok and r.bounty == 500, "approve claim")
  T.eq(call("balance", { session = sc }).balance - cb, 500, "bounty paid")
  r = adm("admin_post_work_order", { title = "Fix the road", bounty = 2000 })
  T.check(r.ok, "post work order from the treasury (" .. tostring(r.err) .. ")")
  local oid = r.order_id
  T.check(call("claim_work_order", { session = sc, order_id = oid }).ok, "claim work order")
  cb = call("balance", { session = sc }).balance
  r = adm("admin_complete_work_order", { order_id = oid })
  T.check(r.ok, "complete work order")
  T.eq(call("balance", { session = sc }).balance - cb, 2000, "work order paid")

  T.check(adm("admin_set_rank", { account_id = alice.checking_id, rank_id = "O1" }).ok, "assign rank")
  r = adm("admin_create_job", { title = "Clerk", annual_cents = 3650000 })
  T.check(r.ok, "create job")
  T.check(adm("admin_assign_job", { account_id = bob.checking_id, job_id = r.job_id }).ok, "assign job")
  local pa = call("balance", { session = sa }).balance
  local pbb = call("balance", { session = sb }).balance
  r = adm("admin_day_tick", { mc_day = 5 })
  T.check(r.ok and r.payroll_count == 1 and r.civic_count == 1, "day tick pays both payrolls")
  local gross = math.floor(1100000 / 7)
  T.eq(call("balance", { session = sa }).balance - pa, gross - math.floor(gross * 0.05), "officer salary net of the 5 percent bracket")
  T.eq(call("balance", { session = sb }).balance - pbb, 10000, "civic salary")
  r = adm("admin_day_tick", { mc_day = 5 })
  T.check(r.paid_already, "a Minecraft day pays once")
  T.check(adm("admin_set_leave", { account_id = alice.checking_id, on_leave = true }).ok, "set leave")
  pa = call("balance", { session = sa }).balance
  adm("admin_day_tick", { mc_day = 6 })
  T.eq(call("balance", { session = sa }).balance, pa, "no pay while on leave")

  local snap = { ["minecraft.custom:minecraft.play_time"] = 72000, ["minecraft.custom:minecraft.time_since_last_death"] = 5000, ["minecraft.killed:minecraft:zombie"] = 10, ["minecraft.custom:minecraft.walk_one_cm"] = 600000, _dimension = "minecraft:overworld" }
  cb = call("balance", { session = sc }).balance
  r = adm("admin_submit_snapshot", { snapshots = { carol = snap }, session_sec = 1500 })
  T.check(r.ok and r.players == 1, "snapshot accepted")
  local gained = call("balance", { session = sc }).balance - cb
  T.check(gained >= 800 + 500 + 1000, "earnings include wage, combat and exploration (" .. gained .. ")")
  r = adm("admin_submit_snapshot", { snapshots = { carol = snap }, session_sec = 1500 })
  T.eq(r.results.carol.skipped, "already_ran_today", "one payout per day")
  local me = call("my_earnings", { session = sc })
  T.check(me.ok and me.streak_days == 1 and me.breakdown and me.breakdown.total == gained, "earnings screen data: streak " .. tostring(me.streak_days) .. " total " .. tostring(me.breakdown and me.breakdown.total) .. " gained " .. tostring(gained))
  T.check(call("set_notif_subs", { session = sc, subs = { daily = true } }).ok, "subscribe to daily notices")
  local snap2 = {}
  for k, v in pairs(snap) do snap2[k] = v end
  r = call("buy_insurance", { session = sc })
  T.check(r.ok, "buy insurance")

  r = adm("admin_set_policy", { policy = { tx_tax_rate = 0.10 } })
  T.check(r.ok, "set tax rate")
  r = call("transfer", { session = sb, target_id = carol.checking_id, amount = 10000 })
  T.eq(r.tax, 1000, "new tax rate applies")
  r = adm("admin_set_policy", { policy = { tx_tax_rate = "free" } })
  T.eq(adm("admin_stats", {}).stats.policy.tx_tax_rate, 0.10, "wrong type is ignored")
  T.check(adm("admin_freeze", { account_id = carol.checking_id, frozen = true }).ok, "freeze")
  T.check(not call("transfer", { session = sb, target_id = carol.checking_id, amount = 100 }).ok, "cannot pay a frozen account")
  T.check(not call("balance", { session = sc }).ok, "frozen account has no session access")
  adm("admin_freeze", { account_id = carol.checking_id, frozen = false })
  T.check(adm("admin_reset_pin", { account_id = carol.checking_id, new_pin = "2222" }).ok, "reset pin")
  T.check(call("auth_by_owner", { owner = "carol", pin = "2222" }).ok, "new pin works")
  r = call("change_pin", { session = sa, old_pin = "1111", new_pin = "9999" })
  T.check(r.ok and call("auth_by_owner", { owner = "alice", pin = "9999" }).ok, "player changes own pin")
  r = adm("admin_set_balance", { account_id = bob.checking_id, new_balance = 123456, reason = "audit fix" })
  T.check(r.ok and r.new_balance == 123456, "set balance")
  r = adm("admin_delete_account", { account_id = carol.checking_id })
  T.check(r.ok and r.refunded > 0, "delete account refunds the treasury")
  T.check(call("lookup", { owner = "carol" }).accounts[1] == nil, "deleted account is gone")
  r = adm("admin_audit", {})
  T.check(#r.mismatched == 0, "audit clean after the whole scenario (" .. table.concat(r.mismatched, ",") .. ")")
  r = adm("admin_verify_ledger", {})
  for _ = 1, 20 do
    if r.state == "done" then break end
    sleep(1)
    r = adm("admin_verify_ledger", {})
  end
  T.check(r.state == "done" and r.chain_ok, "ledger verifies after the whole scenario")
  r = adm("admin_backup", {})
  T.check(r.ok, "manual backup works (" .. tostring(r.err) .. ")")
  local d = adm("admin_diagnostics", {})
  T.check(d.ok and d.errors == 0, "server raised no handler errors (" .. tostring(d.errors) .. " " .. tostring(d.last_error and d.last_error.err) .. ")")
end, 3600)
T.check(not server.crash, "server stayed up")
local bk = server.fs.exists("/.vrb/backups") and server.fs.list("/.vrb/backups") or {}
T.check(#bk == 1 and #server.fs.list("/.vrb/backups/" .. bk[1]) > 3, "backup folder holds the snapshot shards")
T.done()
