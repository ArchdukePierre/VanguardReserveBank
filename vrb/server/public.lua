local util = require("lib.util")
local crypto = require("lib.crypto")

local M = {}

local PUBLISHABLE = {}
for t in ("transfer deposit withdraw loan_origin loan_repay cd_open cd_redeem interest ubi_payout policy_change auto_policy wo_post wo_complete progress_approve note_issue note_redeem faction_create shop_sale item_deposit issue admin_adjust multisig_execute earnings earnings_tick death_penalty insurance_charge insurance_lapse salary payroll_tick rank_assign rank_change rank_remove civic_pay civic_payroll_tick job_create job_assign job_remove"):gmatch("%S+") do PUBLISHABLE[t] = true end

function M.register(rpc, bank, jobs, ctl)
  local cfg = bank.cfg
  local meta = bank.meta
  local pol = bank.policy
  local anon_cache = {}
  local cache = { at = 0 }

  local function anon(id)
    if type(id) ~= "string" or id:sub(1, 4) ~= "ACC-" then return id end
    local a = anon_cache[id]
    if not a then
      a = "acct#" .. crypto.sha256(id):sub(1, 6)
      anon_cache[id] = a
    end
    return a
  end

  local function stats()
    local t = util.now()
    if cache.stats and t - cache.at < 5 then return cache.stats end
    local n_acc, n_active, n_loan, n_shop, n_fac = 0, 0, 0, 0, 0
    local cutoff = t - 7 * 86400
    for _, a in bank.accounts:pairs() do
      n_acc = n_acc + 1
      if (a.act or 0) >= cutoff then n_active = n_active + 1 end
    end
    for _, l in bank.db:coll("loans"):pairs() do if not l.closed then n_loan = n_loan + 1 end end
    for _, s in bank.db:coll("shops"):pairs() do if s.active then n_shop = n_shop + 1 end end
    n_fac = bank.db:coll("factions"):count()
    cache.stats = { accounts = n_acc, active_last_week = n_active, active_loans = n_loan, active_shops = n_shop, factions = n_fac, supply = meta.money_supply, loans_out = meta.loans_out,
      tx_count = meta.tx_count, ledger_head = meta.ledger_head, time = t, version = cfg.VERSION,
      policy = { sav_mpr = pol.sav_mpr, chk_mpr = pol.chk_mpr, loan_mpr = pol.loan_mpr, ubi_enabled = pol.ubi_enabled, ubi_weekly = pol.ubi_weekly, tax_brackets = pol.income_tax_brackets, tx_tax_rate = pol.tx_tax_rate } }
    cache.at = t
    return cache.stats
  end

  local function tail(limit)
    local rows = bank.db.ledger:recent(limit, function(e) return PUBLISHABLE[e.type] end)
    local out = {}
    for _, e in ipairs(rows) do
      local s = { t = e.t, type = e.type }
      for _, k in ipairs({ "account", "from", "to" }) do if e[k] then s[k] = anon(e[k]) end end
      for _, k in ipairs({ "amount", "tax", "bounty", "delta", "payout", "total", "recipients", "players" }) do if e[k] then s[k] = e[k] end end
      out[#out + 1] = s
    end
    return out
  end

  rpc:method("public_stats", { doc = "Economy numbers for dashboards" }, function() return { ok = true, stats = stats() } end)

  rpc:method("public_ledger_tail", { p = { limit = "int+?" }, doc = "Recent anonymized public events" }, function(ctx, p)
    return { ok = true, entries = tail(math.min(p.limit or 30, 60)), head = meta.ledger_head }
  end)

  function ctl.public_payload()
    return { stats = stats(), entries = tail(24), t = util.now() }
  end
end

return M
