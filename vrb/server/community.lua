local util = require("lib.util")
local common = require("server.common")

local fail, memo = common.fail, common.memo
local M = {}

function M.register(rpc, bank)
  local catalog = bank.db:coll("catalog")
  local progress = bank.db:coll("progress")
  local orders = bank.db:coll("orders")

  rpc:method("list_catalog", { doc = "Achievements that pay a bounty" }, function()
    local out = {}
    for id, item in catalog:pairs() do out[#out + 1] = { id = id, label = item.label, bounty = item.bounty, once = item.once } end
    table.sort(out, function(x, y) return x.label < y.label end)
    return { ok = true, catalog = out }
  end)

  rpc:method("my_claims", { auth = "session" }, function(ctx)
    local out = {}
    for pid, rec in pairs(progress:get(ctx.acct.id) or {}) do
      local item = catalog:get(pid)
      out[#out + 1] = { progress = pid, label = item and item.label or pid, approved = rec.approved and true or false, pending = rec.pending and true or false, count = rec.count or 0 }
    end
    table.sort(out, function(x, y) return x.label < y.label end)
    return { ok = true, claims = out }
  end)

  rpc:method("submit_claim", { write = true, auth = "session", p = { progress_id = "id", evidence = "text" }, doc = "Claim an achievement bounty" }, function(ctx, p)
    local item = catalog:get(p.progress_id)
    if not item then return fail("Unknown achievement") end
    local a = ctx.acct
    local all = progress:get(a.id) or {}
    local prior = all[p.progress_id]
    if prior and item.once and prior.approved then return fail("Already awarded") end
    if prior and prior.pending then return fail("You already have a pending claim for that") end
    all[p.progress_id] = { submitted_at = util.now(), evidence = p.evidence, approved = false, count = prior and prior.count or 0, pending = true }
    progress:put(a.id, all)
    bank:log("claim_submit", { account = a.id, progress = p.progress_id })
    return { ok = true }
  end)

  rpc:method("admin_pending_claims", { auth = "admin" }, function()
    local out = {}
    for acct, by in progress:pairs() do
      for pid, rec in pairs(by) do
        if rec.pending and not rec.approved then
          local a = bank.accounts:get(acct)
          local item = catalog:get(pid)
          out[#out + 1] = { account = acct, owner = a and a.owner or "?", progress = pid, label = item and item.label or pid, evidence = rec.evidence, submitted_at = rec.submitted_at, bounty = item and item.bounty or 0 }
        end
      end
    end
    table.sort(out, function(x, y) return x.submitted_at < y.submitted_at end)
    return { ok = true, claims = common.cap(out, 150) }
  end)

  rpc:method("admin_approve_claim", { write = true, auth = "admin", p = { account_id = "acct", progress_id = "id", override_bounty = "cents?" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    local item = catalog:get(p.progress_id)
    if not a then return fail("Account not found") end
    if not item then return fail("Unknown achievement") end
    local all = progress:get(a.id) or {}
    local rec = all[p.progress_id] or { count = 0 }
    if item.once and rec.approved then return fail("Already approved") end
    local bounty = p.override_bounty or item.bounty
    rec.approved, rec.approved_at, rec.pending = true, util.now(), nil
    rec.count = (rec.count or 0) + 1
    rec.last_bounty = bounty
    all[p.progress_id] = rec
    progress:put(a.id, all)
    local target = bank:checking_for(a) or a
    if bounty > 0 then
      bank:post(target, bounty, "progress_reward", item.label)
      bank:supply(bounty)
    end
    bank:log("progress_approve", { account = target.id, progress = p.progress_id, bounty = bounty })
    return { ok = true, balance = target.balance, bounty = bounty }
  end)

  rpc:method("admin_reject_claim", { write = true, auth = "admin", p = { account_id = "acct", progress_id = "id", reason = "text?" } }, function(ctx, p)
    local all = progress:get(p.account_id)
    if all and all[p.progress_id] and not all[p.progress_id].approved then
      all[p.progress_id] = nil
      progress:put(p.account_id, all)
    end
    bank:log("progress_reject", { account = p.account_id, progress = p.progress_id, reason = p.reason })
    return { ok = true }
  end)

  rpc:method("admin_set_catalog_item", { write = true, auth = "admin", p = { id = "id", label = "text?", bounty = "cents?", once = "bool?", remove = "bool?" } }, function(ctx, p)
    if p.remove then catalog:del(p.id); bank:log("catalog_remove", { id = p.id }); return { ok = true } end
    local item = catalog:get(p.id) or { label = p.id, bounty = 0, once = true }
    item.label = p.label or item.label
    if p.bounty then item.bounty = p.bounty end
    if p.once ~= nil then item.once = p.once end
    catalog:put(p.id, item)
    bank:log("catalog_set", { id = p.id, bounty = item.bounty })
    return { ok = true }
  end)

  rpc:method("list_work_orders", { doc = "Open Public Works bounties" }, function()
    local out = {}
    for id, wo in orders:pairs() do
      if not wo.completed then out[#out + 1] = { id = id, title = wo.title, bounty = wo.bounty, posted_by = wo.posted_by, claimed_by = wo.claimed_by, posted_at = wo.posted_at, description = wo.description } end
    end
    table.sort(out, function(x, y) return x.posted_at > y.posted_at end)
    return { ok = true, orders = common.cap(out, 100) }
  end)

  rpc:method("claim_work_order", { write = true, auth = "session", p = { order_id = "id" } }, function(ctx, p)
    local wo = orders:get(p.order_id)
    if not wo or wo.completed then return fail("That order is not available") end
    if wo.claimed_by and wo.claimed_by ~= ctx.acct.id then return fail("Someone already took that order") end
    wo.claimed_by, wo.claimed_at = ctx.acct.id, util.now()
    orders:touch(wo.id)
    bank:log("wo_claim", { order = wo.id, account = ctx.acct.id })
    return { ok = true }
  end)

  rpc:method("cancel_work_order_claim", { write = true, auth = "session", p = { order_id = "id" } }, function(ctx, p)
    local wo = orders:get(p.order_id)
    if not wo or wo.completed or wo.claimed_by ~= ctx.acct.id then return fail("You have not claimed that order") end
    wo.claimed_by, wo.claimed_at = nil, nil
    orders:touch(wo.id)
    bank:log("wo_unclaim", { order = wo.id, account = ctx.acct.id })
    return { ok = true }
  end)

  rpc:method("admin_post_work_order", { write = true, auth = "admin", p = { title = "text", bounty = "cents+", description = "text?" } }, function(ctx, p)
    if #p.title < 3 then return fail("Title is too short") end
    local fund = bank:fund()
    if fund.balance < p.bounty then return fail(string.format("Fund balance %s is below the bounty %s", util.money(fund.balance), util.money(p.bounty))) end
    local id = bank:id("WO", 8)
    bank:post(fund, -p.bounty, "wo_reserve", "Work Order posted: " .. p.title)
    orders:put(id, { id = id, title = p.title, bounty = p.bounty, posted_by = "Vanguard Reserve", posted_at = util.now(), completed = false, description = p.description })
    bank:log("wo_post", { order = id, title = p.title, bounty = p.bounty })
    return { ok = true, order_id = id }
  end)

  rpc:method("admin_complete_work_order", { write = true, auth = "admin", p = { order_id = "id" } }, function(ctx, p)
    local wo = orders:get(p.order_id)
    if not wo or wo.completed then return fail("That order is not open") end
    if not wo.claimed_by then return fail("No worker has accepted this order yet") end
    local a = bank.accounts:get(wo.claimed_by)
    if not a then return fail("The worker's account is gone") end
    wo.completed, wo.completed_at, wo.paid_to = true, util.now(), a.id
    orders:touch(wo.id)
    bank:post(a, wo.bounty, "wo_payout", "Work Order: " .. wo.title)
    bank:log("wo_complete", { order = wo.id, account = a.id, bounty = wo.bounty, owner = a.owner })
    return { ok = true, balance = a.balance, paid_to = a.id, owner = a.owner }
  end)

  rpc:method("admin_delete_work_order", { write = true, auth = "admin", p = { order_id = "id" } }, function(ctx, p)
    local wo = orders:get(p.order_id)
    if not wo then return fail("Order not found") end
    if wo.completed then return fail("A completed order cannot be deleted") end
    bank:post(bank:fund(), wo.bounty, "wo_refund", "Work Order deleted: " .. wo.title)
    orders:del(wo.id)
    bank:log("wo_delete", { order = wo.id, title = wo.title, bounty = wo.bounty })
    return { ok = true }
  end)

  rpc:method("admin_list_work_orders", { auth = "admin", p = { include_completed = "bool?" } }, function(ctx, p)
    local out = {}
    for _, wo in orders:pairs() do
      if not wo.completed or p.include_completed then
        local e = { id = wo.id, title = wo.title, bounty = wo.bounty, posted_by = wo.posted_by, posted_at = wo.posted_at, claimed_by = wo.claimed_by, claimed_at = wo.claimed_at,
          completed = wo.completed, completed_at = wo.completed_at, paid_to = wo.paid_to, description = wo.description }
        if wo.claimed_by then local a = bank.accounts:get(wo.claimed_by); if a then e.claimed_owner = a.owner end end
        out[#out + 1] = e
      end
    end
    table.sort(out, function(x, y) return (x.posted_at or 0) > (y.posted_at or 0) end)
    return { ok = true, orders = common.cap(out, 100) }
  end)
end

return M
