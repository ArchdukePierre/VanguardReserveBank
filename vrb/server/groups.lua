local util = require("lib.util")
local common = require("server.common")

local fail, memo = common.fail, common.memo
local M = {}

function M.register(rpc, bank, jobs)
  local cfg = bank.cfg
  local pol = bank.policy
  local factions = bank.db:coll("factions")
  local pending = bank.db:coll("pending")
  local escrows = bank.db:coll("escrows")
  local recurring = bank.db:coll("recurring")

  local function fac_of(id) return factions:get(id) end

  rpc:method("create_faction", { write = true, auth = "session", p = { name = "text", n = "int+", m = "int+" }, doc = "Charter a faction with a shared treasury" }, function(ctx, p)
    local a = ctx.acct
    if #p.name < 3 or #p.name > 40 then return fail("Faction name must be 3 to 40 characters") end
    if p.n > p.m then return fail("N cannot exceed M") end
    local fid = bank:id("FAC", 8, true)
    local tid = bank:new_account_id()
    local t = bank.accounts:put(tid, { id = tid, owner = "@" .. fid, kind = "checking", balance = 0, sum = 0, pin = "", created = util.now(), hist = {}, joint = {}, faction = fid })
    bank:index_add(t)
    factions:put(fid, { id = fid, name = p.name, treasury = tid, members = { [a.owner:lower()] = "founder" }, names = { [a.owner:lower()] = a.owner }, n = p.n, m = p.m, created = util.now() })
    bank:log("faction_create", { faction = fid, name = p.name, founder = a.owner, treasury = tid })
    return { ok = true, faction_id = fid, treasury_id = tid }
  end)

  rpc:method("faction_add_member", { write = true, auth = "session", p = { faction_id = "id", member = "user" } }, function(ctx, p)
    local fac = fac_of(p.faction_id)
    if not fac then return fail("Faction not found") end
    if fac.members[ctx.acct.owner:lower()] ~= "founder" then return fail("Only the founder can add members") end
    if not bank:checking_of(p.member) then return fail("That player has no account") end
    fac.members[p.member:lower()] = "member"
    fac.names[p.member:lower()] = p.member
    factions:touch(fac.id)
    bank:log("faction_add", { faction = fac.id, member = p.member, by = ctx.acct.owner })
    return { ok = true }
  end)

  rpc:method("faction_remove_member", { write = true, auth = "session", p = { faction_id = "id", member = "user" } }, function(ctx, p)
    local fac = fac_of(p.faction_id)
    if not fac then return fail("Faction not found") end
    local me = ctx.acct.owner:lower()
    if fac.members[me] ~= "founder" then return fail("Only the founder can remove members") end
    if p.member:lower() == me then return fail("The founder cannot be removed") end
    fac.members[p.member:lower()] = nil
    fac.names[p.member:lower()] = nil
    factions:touch(fac.id)
    bank:log("faction_remove", { faction = fac.id, member = p.member, by = ctx.acct.owner })
    return { ok = true }
  end)

  rpc:method("list_factions", { auth = "session", doc = "Factions you belong to" }, function(ctx)
    local me = ctx.acct.owner:lower()
    local out = {}
    for id, f in factions:pairs() do
      if f.members[me] then
        local t = bank.accounts:get(f.treasury)
        local members = {}
        for k in pairs(f.members) do members[#members + 1] = f.names[k] or k end
        table.sort(members)
        out[#out + 1] = { id = id, name = f.name, role = f.members[me], n = f.n, m = f.m, treasury = f.treasury, balance = t and t.balance or 0, members = members }
      end
    end
    table.sort(out, function(x, y) return x.name < y.name end)
    return { ok = true, factions = out }
  end)

  rpc:method("list_pending_tx", { auth = "session" }, function(ctx)
    local me = ctx.acct.owner:lower()
    local out = {}
    for pid, pt in pending:pairs() do
      local fac = fac_of(pt.faction)
      if fac and fac.members[me] then
        out[#out + 1] = { id = pid, faction_id = pt.faction, from = pt.from, to = pt.to, amount = pt.amount, memo = pt.memo, approvals = util.count(pt.approvals), required = fac.n, you_approved = pt.approvals[me] == true, created = pt.created, faction_name = fac.name }
      end
    end
    table.sort(out, function(x, y) return x.created < y.created end)
    return { ok = true, pending = out }
  end)

  rpc:method("approve_pending_tx", { write = true, auth = "session", p = { pending_id = "id" } }, function(ctx, p)
    local pt = pending:get(p.pending_id)
    if not pt then return fail("Proposal not found") end
    if util.now() - (pt.created or 0) > cfg.server.pending_ttl then
      pending:del(p.pending_id)
      bank:log("multisig_expired", { pending = p.pending_id })
      return fail("That proposal expired. Propose it again.")
    end
    local me = ctx.acct.owner:lower()
    local fac = fac_of(pt.faction)
    if not fac or not fac.members[me] then return fail("You are not a member of that faction") end
    pt.approvals[me] = true
    local n = util.count(pt.approvals)
    if n >= fac.n then
      local src, dst = bank.accounts:get(pt.from), bank.accounts:get(pt.to)
      if not src or not dst then pending:del(p.pending_id); return fail("An account in this proposal no longer exists") end
      if src.balance < pt.amount then
        pending:del(p.pending_id)
        bank:log("multisig_fail", { pending = p.pending_id, reason = "insufficient" })
        return fail("The treasury no longer has enough funds")
      end
      local tax = bank:tax_for(pt.amount, src.id, dst.id)
      bank:move(src, dst, pt.amount, tax, "multisig_out", "multisig_in", pt.memo)
      local who = {}
      for k in pairs(pt.approvals) do who[#who + 1] = k end
      bank:log("multisig_execute", { pending = p.pending_id, from = src.id, to = dst.id, amount = pt.amount, tax = tax, approvers = who })
      pending:del(p.pending_id)
      return { ok = true, executed = true, approvals = n }
    end
    pending:touch(pt.id)
    bank:log("multisig_approve", { pending = p.pending_id, by = ctx.acct.owner, approvals = n, required = fac.n })
    return { ok = true, executed = false, approvals = n, required = fac.n }
  end)

  rpc:method("cancel_pending_tx", { write = true, auth = "session", p = { pending_id = "id" } }, function(ctx, p)
    local pt = pending:get(p.pending_id)
    if not pt then return fail("Proposal not found") end
    local fac = fac_of(pt.faction)
    if not fac or fac.members[ctx.acct.owner:lower()] ~= "founder" then return fail("Only the founder can cancel") end
    pending:del(p.pending_id)
    bank:log("multisig_cancel", { pending = p.pending_id, by = ctx.acct.owner })
    return { ok = true }
  end)

  rpc:method("create_escrow", { write = true, auth = "session", p = { counterparty = "acct", amount = "cents+", memo = "text?" }, doc = "Hold funds until you release or the other side refunds" }, function(ctx, p)
    local a = ctx.acct
    if p.counterparty == a.id then return fail("You cannot escrow to yourself") end
    local other = bank.accounts:get(p.counterparty)
    if not other then return fail("Counterparty not found") end
    if a.balance < p.amount then return fail("Insufficient funds") end
    local eid = bank:id("ESC", 12)
    escrows:put(eid, { id = eid, from = a.id, to = p.counterparty, amount = p.amount, memo = memo(p.memo) or "", status = "held", created = util.now(), from_owner = a.owner })
    bank:post(a, -p.amount, "escrow_hold", "Escrow " .. eid)
    bank:mark(a)
    bank:log("escrow_create", { escrow = eid, from = a.id, to = p.counterparty, amount = p.amount })
    return { ok = true, escrow_id = eid }
  end)

  rpc:method("release_escrow", { write = true, auth = "session", p = { escrow_id = "id" } }, function(ctx, p)
    local e = escrows:get(p.escrow_id)
    if not e or e.status ~= "held" then return fail("Escrow is not active") end
    if e.from ~= ctx.acct.id then return fail("Only the sender can release") end
    local dst = bank.accounts:get(e.to)
    if not dst then e.status = "void"; escrows:touch(e.id); return fail("The recipient no longer exists") end
    local tax = bank:tax_for(e.amount, e.from, e.to)
    bank:post(dst, e.amount - tax, "escrow_payout", "Escrow " .. e.id)
    bank:fund_credit(tax, "tx_tax: escrow " .. e.id)
    bank:mark(dst)
    e.status, e.resolved = "released", util.now()
    escrows:touch(e.id)
    bank:log("escrow_release", { escrow = e.id, amount = e.amount, tax = tax })
    return { ok = true }
  end)

  rpc:method("refund_escrow", { write = true, auth = "session", p = { escrow_id = "id" } }, function(ctx, p)
    local e = escrows:get(p.escrow_id)
    if not e or e.status ~= "held" then return fail("Escrow is not active") end
    if e.to ~= ctx.acct.id then return fail("Only the recipient can refund") end
    local src = bank.accounts:get(e.from)
    if not src then e.status = "void"; escrows:touch(e.id); return fail("The sender no longer exists") end
    bank:post(src, e.amount, "escrow_refund", "Escrow " .. e.id)
    e.status, e.resolved = "refunded", util.now()
    escrows:touch(e.id)
    bank:log("escrow_refund", { escrow = e.id, amount = e.amount })
    return { ok = true }
  end)

  rpc:method("list_my_escrows", { auth = "session" }, function(ctx)
    local out = {}
    for id, e in escrows:pairs() do
      if (e.from == ctx.acct.id or e.to == ctx.acct.id) and e.status == "held" then
        out[#out + 1] = { id = id, from = e.from, to = e.to, amount = e.amount, memo = e.memo, status = e.status, you_are = e.from == ctx.acct.id and "sender" or "recipient", created = e.created }
      end
    end
    table.sort(out, function(x, y) return x.created < y.created end)
    return { ok = true, escrows = out }
  end)

  rpc:method("create_recurring", { write = true, auth = "session", p = { target_id = "acct", amount = "cents+", interval_sec = "int+", remaining = "int+", memo = "text?" }, doc = "Schedule repeating payments" }, function(ctx, p)
    local a = ctx.acct
    if not bank.accounts:get(p.target_id) then return fail("Target not found") end
    if p.interval_sec < 3600 then return fail("The interval must be at least one hour") end
    if p.remaining > 365 then return fail("Remaining payments must be 1 to 365") end
    local rid = bank:id("REC", 12)
    recurring:put(rid, { id = rid, from = a.id, to = p.target_id, amount = p.amount, memo = memo(p.memo) or "Recurring", interval = p.interval_sec, next_run = util.now() + p.interval_sec, remaining = p.remaining, created_by = a.owner, created = util.now(), active = true })
    bank:log("recurring_create", { recur = rid, from = a.id, to = p.target_id, amount = p.amount, interval = p.interval_sec, count = p.remaining })
    return { ok = true, recur_id = rid }
  end)

  rpc:method("cancel_recurring", { write = true, auth = "session", p = { recur_id = "id" } }, function(ctx, p)
    local r = recurring:get(p.recur_id)
    if not r or not r.active or r.from ~= ctx.acct.id then return fail("Recurring payment not found") end
    r.active = false
    recurring:touch(r.id)
    bank:log("recurring_cancel", { recur = r.id, by = ctx.acct.owner })
    return { ok = true }
  end)

  rpc:method("list_my_recurring", { auth = "session" }, function(ctx)
    local out = {}
    for id, r in recurring:pairs() do
      if r.from == ctx.acct.id and r.active then out[#out + 1] = { id = id, to = r.to, amount = r.amount, memo = r.memo, interval_sec = r.interval, next_run = r.next_run, remaining = r.remaining } end
    end
    table.sort(out, function(x, y) return x.next_run < y.next_run end)
    return { ok = true, recurring = out }
  end)

  jobs.add("recurring", 30, function()
    local t = util.now()
    for id, r in recurring:pairs() do
      if r.active and r.remaining > 0 and t >= r.next_run then
        local src, dst = bank.accounts:get(r.from), bank.accounts:get(r.to)
        if src and dst and not src.frozen and not dst.frozen and src.balance >= r.amount then
          local tax = bank:tax_for(r.amount, src.id, dst.id)
          bank:move(src, dst, r.amount, tax, "recur_out", "recur_in", r.memo)
          bank:log("recurring_fire", { recur = id, amount = r.amount, tax = tax })
          r.remaining = r.remaining - 1
          if r.remaining <= 0 then r.active = false end
        else
          bank:log("recurring_skip", { recur = id, reason = "insufficient_or_frozen" })
        end
        r.next_run = r.next_run + r.interval
        recurring:touch(id)
      elseif not r.active and (r.next_run or 0) < t - 14 * 86400 then
        recurring:del(id)
      end
    end
  end)

  jobs.add("expire_pending", 3600, function()
    local t = util.now()
    for id, pt in pending:pairs() do
      if t - (pt.created or 0) > cfg.server.pending_ttl then pending:del(id) end
    end
    for id, e in escrows:pairs() do
      if e.status ~= "held" and (e.resolved or e.created) < t - 14 * 86400 then escrows:del(id) end
    end
  end)
end

return M
