local ser = require("lib.ser")
local util = require("lib.util")

local M = {}

local function lower_keys(t)
  local o = {}
  for k, v in pairs(t or {}) do o[tostring(k):lower()] = v end
  return o
end

function M.find_v9(cfg)
  local p = cfg.dirs.data .. "/bank.db"
  if fs.exists(p) and not fs.isDir(p) then return p end
end

function M.run(db, cfg, secret, path, say)
  say = say or function() end
  local text = util.read_file(path)
  local old = text and ser.decode(text)
  if type(old) ~= "table" or type(old.accounts) ~= "table" then return false, "the v9 database could not be read" end
  local meta = db.meta
  local hist_max = cfg.server.history_depth
  local counts = {}
  local function put(coll, id, rec)
    db:coll(coll):put(id, rec)
    counts[coll] = (counts[coll] or 0) + 1
  end
  local policy = old.policy or {}
  local frozen, locked = policy.frozen or {}, policy.locked_pins or {}
  local activity = old.activity or {}
  for id, a in pairs(old.accounts) do
    local hist = {}
    local src = a.history or {}
    for i = math.max(1, #src - hist_max + 1), #src do local h = src[i]; hist[#hist + 1] = { t = h.t, y = h.type, a = h.amount, n = h.note, p = h.party, i = #hist + 1 } end
    local lock
    if locked[id] then lock = { fails = locked[id].fails or 0, untl = locked[id]["until"] } end
    put("accounts", id, {
      id = id, owner = a.owner, kind = a.kind or "checking", balance = a.balance or 0, base = a.balance or 0, sum = 0, pin = a.pin_hash, created = a.created or util.now(),
      hist = hist, n_hist = #hist, joint = a.joint or {}, paired = a.paired_savings or a.paired_checking, lots = a.lots, vg = a.vanguard_rank, vg_leave = a.vanguard_on_leave,
      vg_since = a.vanguard_assigned_at, vg_wp = a.vanguard_week_paid, vg_wd = a.vanguard_week_days, civic = a.civic_jobs, civic_wp = a.civic_week_paid,
      frozen = frozen[id] and true or nil, lock = lock, act = activity[id], faction = a.faction_id, treasury = a.is_treasury or nil,
    })
  end
  for id, l in pairs(old.loans or {}) do
    put("loans", id, { id = id, owner = l.owner, account = l.account, principal = l.principal, balance = l.balance, mpr = l.mpr, opened = l.opened, closed = l.closed, collateral = l.collateral, interest = l.interest_accrued or 0 })
  end
  for id, c in pairs(old.certs or {}) do put("certs", id, c) end
  for id, c in pairs(old.cards or {}) do put("notes", id, c) end
  for id, p in pairs(old.progress or {}) do
    local rec = {}
    for pid, r in pairs(p) do
      rec[pid] = { submitted_at = r.submitted_at, evidence = r.evidence, approved = r.approved, approved_at = r.approved_at, count = r.count, last_bounty = r.last_bounty, pending = (r.pending_claim and not r.approved) or nil }
    end
    put("progress", id, rec)
  end
  for id, w in pairs(old.work_orders or {}) do put("orders", id, w) end
  for id, f in pairs(old.factions or {}) do
    local members, names = {}, {}
    for m, role in pairs(f.members or {}) do members[m:lower()] = role; names[m:lower()] = m end
    put("factions", id, { id = id, name = f.name, treasury = f.treasury_account, members = members, names = names, n = f.threshold_n, m = f.threshold_m, created = f.created })
  end
  for id, e in pairs(old.escrows or {}) do put("escrows", id, e) end
  for id, s in pairs(old.shops or {}) do put("shops", id, s) end
  for id, r in pairs(old.recurring or {}) do
    put("recurring", id, { id = id, from = r.from, to = r.to, amount = r.amount, memo = r.memo, interval = r.interval_sec, next_run = r.next_run, remaining = r.remaining, created_by = r.created_by, created = r.created, active = r.active })
  end
  for id, p in pairs(old.pending_tx or {}) do
    put("pending", id, { id = id, faction = p.faction_id, from = p.from, to = p.to, amount = p.amount, memo = p.memo, approvals = lower_keys(p.approvals), created = p.created })
  end
  for id, r in pairs(old.payment_requests or {}) do
    put("requests", id, { id = id, from = r.from_owner, from_account = r.from_account, to = r.to_owner, to_account = r.to_account, amount = r.amount, memo = r.memo, t = r.requested_at, status = r.status, decided = r.decided_at, auto_at = r.auto_armed_at, auto_by = r.auto_by })
  end
  for id, j in pairs(old.civic_jobs or {}) do put("jobs", id, j) end
  for id, r in pairs(old.civic_requests or {}) do put("jreq", id, r) end
  for k, s in pairs(old.earnings_state or {}) do
    put("earn", k, { score = s.scoreboard or {}, streak = s.streak_days or 0, last_day = s.last_active_day, grace = s.grace_used or 0, last_snap = s.last_snapshot_ts or 0, insured_until = s.insurance_until,
      insured_charge = s.insurance_last_charge, build_streak = s.build_streak or 0, boss = s.boss_claimed or {}, last_death = s.last_death_ts })
  end
  for k, v in pairs(old.earnings_last or {}) do put("elast", k, v) end
  for k, v in pairs(old.earnings_history or {}) do put("ehist", k, v) end
  for k, v in pairs(old.earnings_subs or {}) do put("subs", k, v) end
  for k, v in pairs(old.notif_state or {}) do put("nstate", k, v) end
  for i, n in ipairs(old.notif_outbox or {}) do put("outbox", string.format("%012d", i), n) end
  meta.outbox_seq = #(old.notif_outbox or {})
  for id, f in pairs(old.farm_flags or {}) do put("flags", id, f) end
  for id, c in pairs(old.catalog or {}) do put("catalog", id, c) end
  local pol = util.deepcopy(cfg.policy)
  for k, v in pairs(policy) do
    if k ~= "frozen" and k ~= "locked_pins" and k ~= "tax_brackets" and k ~= "tx_tax" and v ~= nil then pol[k] = v end
  end
  put("sys", "policy", pol)
  local m = old.meta or {}
  meta.money_supply, meta.loans_out, meta.tx_count, meta.last_interest = m.money_supply or 0, m.loans_out or 0, m.tx_count or 0, m.last_interest or util.now()
  meta.last_ubi, meta.last_earnings, meta.last_mc_day = old.last_ubi_run or 0, old.last_earnings_run or 0, old.last_mc_day_tick or 0
  if old.earnings_enabled ~= nil then meta.earnings_enabled = old.earnings_enabled end
  if old.earnings_pvp_enabled ~= nil then meta.pvp_enabled = old.earnings_pvp_enabled end
  meta.key = secret
  meta.schema = 10
  meta.migrated_from = "9"
  meta.legacy_ledger_head = m.ledger_head
  db.store.meta_dirty = true
  local ok, err = db:commit()
  if not ok then return false, "could not write the new database: " .. tostring(err) end
  local cok, cerr = db:compact()
  if not cok then return false, "could not compact the new database: " .. tostring(cerr) end
  util.ensure_dir(cfg.dirs.data .. "/legacy")
  pcall(fs.move, path, cfg.dirs.data .. "/legacy/bank.db.v9")
  local lg = cfg.dirs.data .. "/ledger.log"
  if fs.exists(lg) then pcall(fs.move, lg, cfg.dirs.data .. "/legacy/ledger.v9.log") end
  for _, n in ipairs(fs.list(cfg.dirs.data)) do
    if n:match("^ledger%.log%.archive%-") then pcall(fs.move, cfg.dirs.data .. "/" .. n, cfg.dirs.data .. "/legacy/" .. n) end
  end
  say(string.format("Imported v9 data: %d accounts, %d loans, %d certificates, %d shops, %d factions.", counts.accounts or 0, counts.loans or 0, counts.certs or 0, counts.shops or 0, counts.factions or 0))
  return true, counts
end

return M
