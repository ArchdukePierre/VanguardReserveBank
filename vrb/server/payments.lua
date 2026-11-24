local util = require("lib.util")
local crypto = require("lib.crypto")
local common = require("server.common")

local fail, memo = common.fail, common.memo
local floor = math.floor
local M = {}

function M.register(rpc, bank, jobs)
  local cfg = bank.cfg
  local pol = bank.policy

  rpc:method("deposit", { write = true, auth = "session", p = { amount = "cents+", note = "text?" }, doc = "Cash deposit (only when player deposits are enabled)" }, function(ctx, p)
    if not pol.allow_player_deposit then
      return fail("Direct deposits are off. Earn through play, claim rewards, or redeem a Reserve Note.")
    end
    local a = ctx.acct
    bank:post(a, p.amount, "deposit", p.note or "Cash deposit")
    bank:supply(p.amount)
    bank:count_tx()
    bank:mark(a)
    bank:log("deposit", { account = a.id, amount = p.amount, branch = ctx.req.p.branch })
    return { ok = true, balance = a.balance }
  end)

  rpc:method("withdraw", { write = true, auth = "session", p = { amount = "cents+", note = "text?" }, doc = "Cash withdrawal" }, function(ctx, p)
    local a = ctx.acct
    if a.balance < p.amount then return fail("Insufficient funds") end
    bank:post(a, -p.amount, "withdraw", p.note or "Cash withdrawal")
    bank:supply(-p.amount)
    bank:count_tx()
    bank:mark(a)
    bank:log("withdraw", { account = a.id, amount = p.amount })
    return { ok = true, balance = a.balance }
  end)

  local function faction_transfer(ctx, p, a, b, note)
    local fac = bank.db:coll("factions"):get(p.from_faction)
    if not fac then return fail("Faction not found") end
    if not fac.members[a.owner:lower()] then return fail("You are not a member of that faction") end
    local treasury = bank.accounts:get(fac.treasury)
    if not treasury then return fail("Faction treasury is missing") end
    if treasury.balance < p.amount then return fail("Faction treasury has too little") end
    if p.amount <= (pol.multisig_threshold or 0) and fac.n <= 1 then
      local tax, rate = bank:tax_for(p.amount, treasury.id, b.id)
      bank:move(treasury, b, p.amount, tax, "faction_out", "faction_in", note)
      bank:log("faction_transfer", { faction = fac.id, from = treasury.id, to = b.id, amount = p.amount, tax = tax, by = a.owner })
      return { ok = true, executed = true }
    end
    local pid = bank:id("PND", 12)
    bank.db:coll("pending"):put(pid, { id = pid, faction = fac.id, from = treasury.id, to = b.id, amount = p.amount, memo = note, approvals = { [a.owner:lower()] = true }, created = util.now() })
    bank:log("multisig_propose", { pending = pid, from = treasury.id, to = b.id, amount = p.amount, by = a.owner, faction = fac.id })
    for member in pairs(fac.members) do
      if member ~= a.owner:lower() then
        common.notify(bank, member, "multisig", "yellow", string.format("[%s] %s proposed %s. Needs your approval (%s)", fac.name, a.owner, util.money(p.amount), pid))
      end
    end
    return { ok = true, pending = pid, needs_approvals = fac.n - 1 }
  end

  rpc:method("transfer", { write = true, auth = "session", p = { target_id = "acct", amount = "cents+", memo = "text?", from_faction = "id?" }, doc = "Pay another account" }, function(ctx, p)
    local a = ctx.acct
    local b = bank.accounts:get(p.target_id)
    if not b then return fail("Target account not found") end
    if b.kind == "savings" then
      b = bank:pair_of(b)
      if not b then return fail("That account cannot receive payments") end
    end
    if a.id == b.id then return fail("You cannot pay your own account") end
    if b.frozen then return fail("Target account is frozen") end
    if b.treasury and p.target_id ~= bank.fund_id then return fail("Invalid target") end
    local note = memo(p.memo)
    if p.from_faction then return faction_transfer(ctx, p, a, b, note) end
    if a.kind == "savings" then return fail("Use MOVE to bring funds into checking first") end
    if a.balance < p.amount then return fail("Insufficient funds") end
    local tax = bank:tax_for(p.amount, a.id, b.id)
    bank:move(a, b, p.amount, tax, "transfer_out", "transfer_in", note)
    bank:log("transfer", { from = a.id, to = b.id, amount = p.amount, tax = tax, memo = note })
    return { ok = true, balance = a.balance, tax = tax }
  end)

  rpc:method("move_internal", { write = true, auth = "session", p = { amount = "cents+", direction = { "chk_to_sav", "sav_to_chk" } }, doc = "Move money between your checking and savings" }, function(ctx, p)
    local a = ctx.acct
    if a.kind ~= "checking" then return fail("Sign in with your checking account") end
    local sav = bank:pair_of(a)
    if not sav then return fail("No savings account is linked") end
    if sav.frozen then return fail("Your savings account is frozen") end
    sav.lots = sav.lots or {}
    if p.direction == "chk_to_sav" then
      if a.balance < p.amount then return fail("Insufficient checking balance") end
      bank:post(a, -p.amount, "move_out", "To savings", sav.id)
      bank:post(sav, p.amount, "move_in", "From checking", a.id)
      sav.lots[#sav.lots + 1] = { amount = p.amount, t = util.now() }
      if #sav.lots > 60 then
        local a1, a2 = table.remove(sav.lots, 1), table.remove(sav.lots, 1)
        table.insert(sav.lots, 1, { amount = a1.amount + a2.amount, t = a2.t })
      end
      bank:log("move", { direction = "chk_to_sav", from = a.id, to = sav.id, amount = p.amount })
      return { ok = true, checking = a.balance, savings = sav.balance, tax = 0 }
    end
    if sav.balance < p.amount then return fail("Insufficient savings balance") end
    local window = cfg.server.early_savings_days * 86400
    local remaining, tax, t, i = p.amount, 0, util.now(), 1
    while remaining > 0 and i <= #sav.lots do
      local lot = sav.lots[i]
      if not lot.amount or lot.amount <= 0 then
        table.remove(sav.lots, i)
      else
        local take = math.min(remaining, lot.amount)
        if t - (lot.t or 0) < window then tax = tax + floor(take * cfg.server.early_savings_rate) end
        lot.amount = lot.amount - take
        remaining = remaining - take
        if lot.amount <= 0 then table.remove(sav.lots, i) else i = i + 1 end
      end
    end
    local credited = p.amount - tax
    bank:post(sav, -p.amount, "move_out", string.format("To checking (early tax %s)", util.money(tax)), a.id)
    bank:post(a, credited, "move_in", string.format("From savings (after %s tax)", util.money(tax)), sav.id)
    bank:fund_credit(tax, "early_savings_tax: " .. a.owner)
    bank:log("move", { direction = "sav_to_chk", from = sav.id, to = a.id, amount = p.amount, tax = tax })
    return { ok = true, checking = a.balance, savings = sav.balance, tax = tax, credited = credited }
  end)

  local requests = bank.db:coll("requests")

  local function target_checking(owner)
    local c = bank:checking_of(owner)
    if c and not c.frozen then return c end
  end

  rpc:method("request_payment", { write = true, auth = "session", p = { target_owner = "user", amount = "cents+", memo = "text?" }, doc = "Bill another player" }, function(ctx, p)
    local a = ctx.acct
    if a.kind ~= "checking" then return fail("Sign in with your checking account") end
    if p.amount > 1e9 then return fail("Amount too large") end
    local tl = p.target_owner:lower()
    if tl == a.owner:lower() then return fail("You cannot bill yourself") end
    if tl == cfg.server.fund_owner:lower() then return fail("You cannot bill the treasury") end
    local target = bank:checking_of(p.target_owner)
    if not target then return fail("That player has no account") end
    local pending = 0
    for _, r in requests:pairs() do
      if r.status == "pending" and r.from:lower() == a.owner:lower() and r.to:lower() == tl then pending = pending + 1 end
    end
    if pending >= 5 then return fail("Too many open bills to that player") end
    local rid = bank:id("PRQ", 8)
    requests:put(rid, { id = rid, from = a.owner, from_account = a.id, to = target.owner, to_account = target.id, amount = p.amount, memo = memo(p.memo), t = util.now(), status = "pending" })
    bank:log("payment_request", { id = rid, from = a.owner, to = target.owner, amount = p.amount })
    return { ok = true, request_id = rid }
  end)

  local function view(r, other)
    return { id = r.id, [other] = r[other == "from_owner" and "from" or "to"], from_owner = r.from, to_owner = r.to, amount = r.amount, memo = r.memo, requested_at = r.t, status = r.status, decided_at = r.decided, auto_armed_at = r.auto_at }
  end

  local function list_requests(ctx, p, side)
    local me = ctx.acct.owner:lower()
    local out = {}
    for _, r in requests:pairs() do
      if r[side]:lower() == me then
        local active = r.status == "pending" or r.status == "auto_pending"
        if p.include_decided or active then out[#out + 1] = view(r, side == "to" and "from_owner" or "to_owner") end
      end
    end
    table.sort(out, function(x, y) return (x.requested_at or 0) > (y.requested_at or 0) end)
    return { ok = true, requests = out }
  end

  rpc:method("list_payment_requests", { auth = "session", p = { include_decided = "bool?" }, doc = "Bills sent to you" }, function(ctx, p) return list_requests(ctx, p, "to") end)
  rpc:method("list_my_sent_requests", { auth = "session", p = { include_decided = "bool?" }, doc = "Bills you sent" }, function(ctx, p) return list_requests(ctx, p, "from") end)

  local function settle(r, payer, payee, via)
    local tax = bank:tax_for(r.amount, payer.id, payee.id)
    local note = r.memo or "Bill"
    bank:move(payer, payee, r.amount, tax, "prq_pay_out", "prq_pay_in", via and ("(auto) " .. note) or note)
    bank:log("prq_approved", { request = r.id, from = payer.id, to = payee.id, amount = r.amount, tax = tax, via = via })
    r.status = "approved"
    r.decided = util.now()
    requests:touch(r.id)
    return tax
  end

  rpc:method("approve_payment_request", { write = true, auth = "session", p = { request_id = "id" } }, function(ctx, p)
    local a = ctx.acct
    local r = requests:get(p.request_id)
    if not r or r.to:lower() ~= a.owner:lower() then return fail("Bill not found") end
    if r.status ~= "pending" then return fail("This bill is already " .. r.status) end
    if a.kind ~= "checking" then return fail("Sign in with your checking account") end
    local payee = bank.accounts:get(r.from_account) or bank:checking_of(r.from)
    if not payee then
      r.status, r.decided, r.reason = "rejected", util.now(), "requester_gone"
      requests:touch(r.id)
      return fail("The requester's account no longer exists")
    end
    if payee.frozen then return fail("The requester's account is frozen") end
    if a.balance < r.amount then return fail("Insufficient funds") end
    local tax = settle(r, a, payee)
    return { ok = true, balance = a.balance, tax = tax }
  end)

  rpc:method("reject_payment_request", { write = true, auth = "session", p = { request_id = "id" } }, function(ctx, p)
    local a = ctx.acct
    local r = requests:get(p.request_id)
    if not r or r.to:lower() ~= a.owner:lower() then return fail("Bill not found") end
    if r.status ~= "pending" and r.status ~= "auto_pending" then return fail("This bill is already " .. r.status) end
    r.status, r.decided = "rejected", util.now()
    requests:touch(r.id)
    bank:log("prq_rejected", { request = r.id, by = a.owner, amount = r.amount })
    return { ok = true }
  end)

  rpc:method("cancel_payment_request", { write = true, auth = "session", p = { request_id = "id" } }, function(ctx, p)
    local a = ctx.acct
    local r = requests:get(p.request_id)
    if not r or r.from:lower() ~= a.owner:lower() then return fail("Bill not found") end
    if r.status ~= "pending" and r.status ~= "auto_pending" then return fail("This bill is already " .. r.status) end
    requests:del(r.id)
    bank:log("prq_cancelled", { request = r.id, by = a.owner })
    return { ok = true }
  end)

  rpc:method("auto_payment_request", { write = true, auth = "session", p = { request_id = "id" }, doc = "Pay a bill now, or arm it to pay when funds arrive" }, function(ctx, p)
    local a = ctx.acct
    local r = requests:get(p.request_id)
    if not r or r.to:lower() ~= a.owner:lower() then return fail("Bill not found") end
    if a.kind ~= "checking" then return fail("Sign in with your checking account") end
    if r.status ~= "pending" then return fail("Cannot auto-pay a bill that is " .. r.status) end
    local payee = bank.accounts:get(r.from_account) or bank:checking_of(r.from)
    if a.balance >= r.amount and payee and not payee.frozen then
      local tax = settle(r, a, payee, "auto_immediate")
      return { ok = true, executed = true, balance = a.balance, tax = tax }
    end
    r.status, r.auto_at, r.auto_by = "auto_pending", util.now(), a.id
    requests:touch(r.id)
    bank:log("prq_auto_armed", { request = r.id, by = a.owner, amount = r.amount })
    return { ok = true, executed = false, status = "auto_pending" }
  end)

  rpc:method("cancel_auto_payment_request", { write = true, auth = "session", p = { request_id = "id" } }, function(ctx, p)
    local a = ctx.acct
    local r = requests:get(p.request_id)
    if not r or r.to:lower() ~= a.owner:lower() then return fail("Bill not found") end
    if r.status ~= "auto_pending" then return fail("This bill is not armed") end
    r.status, r.auto_at, r.auto_by = "pending", nil, nil
    requests:touch(r.id)
    bank:log("prq_auto_cancelled", { request = r.id, by = a.owner })
    return { ok = true }
  end)

  jobs.add("auto_payments", 30, function()
    local by_customer = {}
    for _, r in requests:pairs() do
      if r.status == "auto_pending" then
        local k = r.to:lower()
        by_customer[k] = by_customer[k] or {}
        table.insert(by_customer[k], r)
      end
    end
    for key, list in pairs(by_customer) do
      table.sort(list, function(x, y) return (x.auto_at or x.t) < (y.auto_at or y.t) end)
      local payer = bank:checking_of(key)
      if payer and not payer.frozen then
        for _, r in ipairs(list) do
          if payer.balance < r.amount then break end
          local payee = bank.accounts:get(r.from_account) or bank:checking_of(r.from)
          if not payee then
            r.status, r.decided, r.reason = "rejected", util.now(), "sender_gone"
            requests:touch(r.id)
          elseif payee.frozen then break
          else settle(r, payer, payee, "auto_pending") end
        end
      end
    end
  end)

  jobs.add("prune_requests", 3600, function()
    local cutoff = util.now() - 7 * 86400
    for id, r in requests:pairs() do
      if r.status ~= "pending" and r.status ~= "auto_pending" and (r.decided or r.t) < cutoff then requests:del(id) end
    end
  end)
end

return M
