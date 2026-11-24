local util = require("lib.util")
local crypto = require("lib.crypto")
local common = require("server.common")

local fail = common.fail
local floor = math.floor
local M = {}

function M.register(rpc, bank, jobs)
  local cfg = bank.cfg
  local pol = bank.policy
  local certs = bank.db:coll("certs")
  local loans = bank.db:coll("loans")

  rpc:method("open_cd", { write = true, auth = "session", p = { amount = "cents+", days = "days" }, doc = "Lock funds in a certificate of deposit" }, function(ctx, p)
    local a = ctx.acct
    if a.balance < p.amount then return fail("Insufficient funds") end
    local mpr
    if p.days >= 180 then mpr = pol.cd_mpr_180 elseif p.days >= 90 then mpr = pol.cd_mpr_90 elseif p.days >= 30 then mpr = pol.cd_mpr_30
    else return fail("Minimum CD term is 30 days") end
    local id = "CD-" .. string.format("%06d", crypto.random_int(100000, 999999))
    while certs:get(id) do id = "CD-" .. string.format("%06d", crypto.random_int(100000, 999999)) end
    local t = util.now()
    certs:put(id, { id = id, owner = a.owner, source = a.id, principal = p.amount, opened = t, matures = t + p.days * 86400, mpr = mpr, redeemed = false })
    bank:post(a, -p.amount, "cd_open", "CD " .. id)
    bank:log("cd_open", { account = a.id, cd = id, amount = p.amount, days = p.days, mpr = mpr })
    return { ok = true, cd_id = id, balance = a.balance, mpr = mpr }
  end)

  rpc:method("redeem_cd", { write = true, auth = "session", p = { cd_id = "id" } }, function(ctx, p)
    local a = ctx.acct
    local cd = certs:get(p.cd_id)
    if not cd or cd.redeemed or cd.source ~= a.id then return fail("CD not found") end
    local t = util.now()
    local mature = t >= cd.matures
    local months = (t - cd.opened) / cfg.server.month_sec
    local payout
    if mature then payout = floor(cd.principal * ((1 + cd.mpr) ^ months)) else payout = math.max(0, floor(cd.principal * 0.95)) end
    cd.redeemed = true
    cd.redeemed_at = t
    certs:touch(cd.id)
    bank:post(a, payout, "cd_redeem", p.cd_id .. (mature and " (matured)" or " (early)"))
    bank:supply(payout - cd.principal)
    bank:log("cd_redeem", { account = a.id, cd = cd.id, payout = payout, mature = mature })
    return { ok = true, balance = a.balance, payout = payout, mature = mature }
  end)

  rpc:method("list_cds", { auth = "session" }, function(ctx)
    local out = {}
    for _, c in certs:pairs() do
      if c.source == ctx.acct.id and not c.redeemed then out[#out + 1] = { id = c.id, principal = c.principal, matures = c.matures, mpr = c.mpr, opened = c.opened } end
    end
    table.sort(out, function(x, y) return x.matures < y.matures end)
    return { ok = true, cds = out }
  end)

  rpc:method("request_loan", { write = true, auth = "session", p = { amount = "cents+" }, doc = "Borrow against collateral held in checking" }, function(ctx, p)
    local a = ctx.acct
    local col = floor(p.amount * pol.min_loan_col)
    if a.balance < col then return fail(string.format("You need %s on deposit as collateral", util.money(col))) end
    local id = "LOAN-" .. string.format("%06d", crypto.random_int(100000, 999999))
    while loans:get(id) do id = "LOAN-" .. string.format("%06d", crypto.random_int(100000, 999999)) end
    loans:put(id, { id = id, owner = a.owner, account = a.id, principal = p.amount, balance = p.amount, mpr = pol.loan_mpr, opened = util.now(), closed = false, collateral = col, interest = 0 })
    bank:post(a, p.amount, "loan_origin", "Loan " .. id)
    bank:supply(p.amount)
    bank.meta.loans_out = bank.meta.loans_out + p.amount
    bank:log("loan_origin", { account = a.id, loan = id, amount = p.amount, mpr = pol.loan_mpr })
    return { ok = true, loan_id = id, balance = a.balance }
  end)

  rpc:method("repay_loan", { write = true, auth = "session", p = { loan_id = "id", amount = "cents+" } }, function(ctx, p)
    local a = ctx.acct
    local l = loans:get(p.loan_id)
    if not l or l.closed or l.account ~= a.id then return fail("Loan not found") end
    local amt = math.min(p.amount, l.balance)
    if amt <= 0 or a.balance < amt then return fail("Insufficient funds") end
    bank:post(a, -amt, "loan_repay", "Loan " .. l.id)
    l.balance = l.balance - amt
    if l.balance <= 0 then l.closed = true end
    loans:touch(l.id)
    bank:supply(-amt)
    bank.meta.loans_out = bank.meta.loans_out - amt
    bank:log("loan_repay", { account = a.id, loan = l.id, amount = amt })
    return { ok = true, balance = a.balance, loan_balance = l.balance, closed = l.closed }
  end)

  rpc:method("list_loans", { auth = "session" }, function(ctx)
    local out = {}
    for _, l in loans:pairs() do
      if l.account == ctx.acct.id and not l.closed then out[#out + 1] = { id = l.id, balance = l.balance, mpr = l.mpr, opened = l.opened } end
    end
    table.sort(out, function(x, y) return x.opened < y.opened end)
    return { ok = true, loans = out }
  end)

  local function growth(mpr, months) return (1 + mpr) ^ months - 1 end

  jobs.add("interest", 60, function(step)
    local t = util.now()
    local dt = t - (bank.meta.last_interest or t)
    if dt < cfg.server.interest_tick_sec then return end
    local months = dt / cfg.server.month_sec
    local paid, count = 0, 0
    local ids = bank.accounts:ids()
    for i, id in ipairs(ids) do
      local a = bank.accounts:get(id)
      if a and not a.frozen and not a.treasury and a.balance > 0 then
        local mpr = (a.kind == "savings") and pol.sav_mpr or pol.chk_mpr
        if mpr > 0 then
          local earned = floor(a.balance * growth(mpr, months))
          if earned > 0 then
            bank:post(a, earned, "interest", "Interest")
            bank:supply(earned)
            paid, count = paid + earned, count + 1
          end
        end
      end
      if i % 100 == 0 and step then step() end
    end
    local accrued = 0
    for _, l in loans:pairs() do
      if not l.closed then
        local add = floor(l.balance * growth(pol.loan_mpr, months))
        if add > 0 then
          l.balance = l.balance + add
          l.interest = (l.interest or 0) + add
          loans:touch(l.id)
          bank.meta.loans_out = bank.meta.loans_out + add
          accrued = accrued + add
        end
      end
    end
    bank.meta.last_interest = t
    bank:meta_touch()
    bank:log("interest", { accounts = count, total = paid, loan_interest = accrued })
  end)

  jobs.add("ubi", 300, function()
    if not pol.ubi_enabled or pol.ubi_weekly <= 0 then return end
    local week = 7 * 24 * 3600
    local t = util.now()
    if t - (bank.meta.last_ubi or 0) < week then return end
    local cutoff = t - (pol.ubi_active_within_sec or week)
    local paid, count = 0, 0
    for _, a in bank.accounts:pairs() do
      if a.kind == "checking" and not a.frozen and not a.treasury and (a.act or a.created or 0) >= cutoff then
        bank:post(a, pol.ubi_weekly, "ubi", "Citizen's dividend")
        bank:supply(pol.ubi_weekly)
        paid, count = paid + pol.ubi_weekly, count + 1
      end
    end
    bank.meta.last_ubi = t
    bank:meta_touch()
    if count > 0 then bank:log("ubi_payout", { recipients = count, total = paid, per_account = pol.ubi_weekly }) end
  end)

  jobs.add("supply_target", 600, function()
    if not pol.supply_target_enabled then return end
    local s = bank.meta.money_supply
    local changed = false
    for _, b in ipairs(pol.income_tax_brackets or {}) do
      if s > (pol.supply_target_high or 0) and b.above >= 1000000 and b.rate < 0.10 then
        b.rate = math.min(0.10, b.rate + 0.001); changed = true
      elseif s < (pol.supply_target_low or 0) and b.above >= 1000000 and b.rate > 0 then
        b.rate = math.max(0, b.rate - 0.001); changed = true
      end
    end
    if changed then
      bank:save_policy()
      bank:log("auto_policy", { supply = s })
    end
  end)

  function bank.force_ubi()
    bank.meta.last_ubi = 0
    jobs.run_now("ubi")
  end
end

return M
