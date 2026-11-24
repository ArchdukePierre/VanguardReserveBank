local util = require("lib.util")
local crypto = require("lib.crypto")
local common = require("server.common")

local fail = common.fail
local floor = math.floor
local M = {}

function M.register(rpc, bank, jobs, ctl)
  local cfg = bank.cfg
  local pol = bank.policy
  local meta = bank.meta
  local db = bank.db

  local function disk_info()
    local free = util.free_space()
    local cap = fs.getCapacity and fs.getCapacity("/") or nil
    return free, cap
  end

  rpc:method("admin_diagnostics", { auth = "admin", doc = "Live server health" }, function()
    local st = db.store
    local frozen, vg, pending_flags = 0, 0, 0
    for _, a in bank.accounts:pairs() do
      if a.frozen then frozen = frozen + 1 end
      if a.vg then vg = vg + 1 end
    end
    for _, f in db:coll("flags"):pairs() do if f.status == "pending" then pending_flags = pending_flags + 1 end end
    local free, cap = disk_info()
    local s = ctl.stats
    local audit = bank:audit()
    return { ok = true, version = cfg.VERSION, uptime_sec = util.now() - ctl.boot_time, accounts = bank.accounts:count(), accounts_frozen = frozen,
      active_sessions = util.count(bank.sessions), vanguard_members = vg, vanguard_max = cfg.vanguard.max_members, farm_flags_pending = pending_flags,
      pending_factions = db:coll("pending"):count(), civic_jobs = db:coll("jobs"):count(), money_supply = meta.money_supply, tx_count = meta.tx_count,
      ledger_head = meta.ledger_head, ledger_entries = meta.ledger_seq, ledger_bytes = db.ledger.bytes, journal_bytes = st.jbytes, db_bytes = util.dir_size(cfg.dirs.db .. "/snap"),
      free_space_bytes = free, disk_capacity = cap, writable = bank.db:writable(), commits = st.commits, compactions = st.compactions, store_error = st.last_error,
      requests = s.requests, rejected = s.rejected, rate_limited = s.rate_limited, duplicates = s.duplicates, errors = (ctl.rpc.errors or 0), last_error = ctl.rpc.last_error,
      handler_avg_ms = s.requests > 0 and (s.handler_ms / s.requests) or 0, handler_max_ms = s.handler_max, queue_depth = ctl.depth(), queue_peak = s.queue_peak,
      audit_mismatched = #audit.mismatched, jobs = jobs.status(), earnings_enabled = meta.earnings_enabled, vanguard_enabled = meta.vanguard_enabled, recovered_ledger_blocks = db.recovered }
  end)

  rpc:method("admin_stats", { auth = "admin" }, function()
    local loans, cds, frozen = 0, 0, 0
    for _, l in db:coll("loans"):pairs() do if not l.closed then loans = loans + 1 end end
    for _, c in db:coll("certs"):pairs() do if not c.redeemed then cds = cds + 1 end end
    for _, a in bank.accounts:pairs() do if a.frozen then frozen = frozen + 1 end end
    return { ok = true, stats = { accounts = bank.accounts:count(), active_loans = loans, active_cds = cds, frozen = frozen, supply = meta.money_supply, loans_out = meta.loans_out,
      tx_count = meta.tx_count, policy = pol, ledger_head = meta.ledger_head, version = cfg.VERSION, mc_month_sec = cfg.server.month_sec,
      earnings_enabled = meta.earnings_enabled, pvp_enabled = meta.pvp_enabled, vanguard_enabled = meta.vanguard_enabled } }
  end)

  local function account_row(a)
    return { id = a.id, owner = a.owner, kind = a.kind, balance = a.balance, frozen = a.frozen and true or false, vanguard_rank = a.vg, civic_jobs = a.civic, on_leave = a.vg_leave and true or false,
      is_treasury = a.treasury and true or false, paired = a.paired, last_login = a.last_login, created = a.created }
  end

  rpc:method("admin_list_accounts", { auth = "admin", p = { filter = "str?", offset = "int?", limit = "int+?", all_kinds = "bool?" }, doc = "Accounts, filtered and paged" }, function(ctx, p)
    local q = (p.filter or ""):lower()
    local rows = {}
    for id, a in bank.accounts:pairs() do
      if (p.all_kinds or a.kind ~= "savings" or a.treasury) and (q == "" or a.owner:lower():find(q, 1, true) or id:lower():find(q, 1, true)) then rows[#rows + 1] = a end
    end
    table.sort(rows, function(x, y) if x.owner:lower() == y.owner:lower() then return x.id < y.id end; return x.owner:lower() < y.owner:lower() end)
    local offset, limit = math.max(0, p.offset or 0), util.clamp(p.limit or 50, 1, 100)
    local out = {}
    for i = offset + 1, math.min(#rows, offset + limit) do out[#out + 1] = account_row(rows[i]) end
    return { ok = true, accounts = out, total = #rows, offset = offset }
  end)

  rpc:method("admin_account_detail", { auth = "admin", p = { account_id = "acct" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    local r = a.vg and bank:rank(a.vg)
    local row = account_row(a)
    local hist = {}
    for i, h in ipairs(a.hist) do hist[i] = bank.expand(h) end
    row.history, row.joint, row.locked, row.lots = hist, a.joint, a.lock, a.lots
    row.progress = db:coll("progress"):get(a.id) or {}
    row.vanguard_label = r and (r.grade .. "  " .. r.label) or nil
    row.audit_ok = bank:audit_account(a)
    return { ok = true, account = row }
  end)

  rpc:method("admin_account_history", { auth = "admin", p = { account_id = "acct", limit = "int+?" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    local limit = util.clamp(p.limit or 50, 1, 200)
    local out = {}
    for i = #a.hist, math.max(1, #a.hist - limit + 1), -1 do out[#out + 1] = bank.expand(a.hist[i]) end
    return { ok = true, entries = out }
  end)

  rpc:method("admin_reset_pin", { write = true, auth = "admin", p = { account_id = "acct", new_pin = "pin" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a or a.treasury then return fail("Account not found") end
    for _, acc in ipairs(bank:owner_accounts(a.owner)) do
      if not acc.treasury and acc.kind ~= "faction" then acc.pin = bank:hash_pin(p.new_pin, acc.id); acc.lock = nil; bank:touch(acc) end
    end
    bank:drop_sessions_of(a.id)
    bank:log("pin_reset", { account = a.id })
    return { ok = true }
  end)

  rpc:method("admin_set_balance", { write = true, auth = "admin", p = { account_id = "acct", new_balance = "int", reason = "text", confirm_extreme = "bool?" } }, function(ctx, p)
    local lim = 100000000000
    if (p.new_balance < -lim or p.new_balance > lim) and not p.confirm_extreme then return fail("That balance is outside the sane range. Confirm to continue.") end
    if #p.reason < 5 then return fail("A reason of at least 5 characters is required") end
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    local delta = p.new_balance - a.balance
    bank:post(a, delta, "admin_adjust", "ADMIN: " .. p.reason)
    bank:supply(delta)
    bank:log("admin_adjust", { account = a.id, delta = delta, new_balance = p.new_balance, reason = p.reason })
    return { ok = true, new_balance = a.balance }
  end)

  rpc:method("admin_issue", { write = true, auth = "admin", p = { account_id = "acct", amount = "int", reason = "text" }, doc = "Issue or recall money from the treasury" }, function(ctx, p)
    if not pol.issue_enabled then return fail("Issuance is off") end
    if #p.reason < 3 then return fail("A reason is required") end
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    if p.amount < 0 and a.balance + p.amount < 0 then return fail("That would overdraw the account") end
    bank:post(a, p.amount, "issue", "Treasury: " .. p.reason)
    bank:supply(p.amount)
    bank:log("issue", { account = a.id, amount = p.amount, reason = p.reason })
    return { ok = true, balance = a.balance }
  end)

  rpc:method("admin_set_policy", { write = true, auth = "admin", p = { policy = "tbl" }, doc = "Change scalar policy values" }, function(ctx, p)
    local changed = {}
    for k, v in pairs(p.policy) do
      if type(k) == "string" and pol[k] ~= nil and type(pol[k]) ~= "table" and type(v) == type(pol[k]) then
        pol[k] = v
        changed[k] = v
      end
    end
    bank:save_policy()
    bank:log("policy_change", { changes = changed })
    return { ok = true, policy = pol }
  end)

  rpc:method("admin_set_tax_bracket", { write = true, auth = "admin", p = { brackets = "tbl" }, doc = "Replace the income tax brackets" }, function(ctx, p)
    local list = {}
    for _, b in ipairs(p.brackets) do
      if type(b) ~= "table" or type(b.above) ~= "number" or type(b.rate) ~= "number" or b.rate < 0 or b.rate > 0.5 or b.above < 0 then return fail("Each bracket needs above >= 0 and a rate from 0 to 0.5") end
      list[#list + 1] = { above = floor(b.above), rate = b.rate }
    end
    if #list == 0 then return fail("At least one bracket is required") end
    table.sort(list, function(x, y) return x.above < y.above end)
    pol.income_tax_brackets = list
    bank:save_policy()
    bank:log("tax_brackets", { brackets = list })
    return { ok = true }
  end)

  rpc:method("admin_set_ubi", { write = true, auth = "admin", p = { enabled = "bool?", weekly = "cents?" } }, function(ctx, p)
    if p.enabled ~= nil then pol.ubi_enabled = p.enabled end
    if p.weekly then pol.ubi_weekly = p.weekly end
    bank:save_policy()
    bank:log("ubi_set", { enabled = pol.ubi_enabled, weekly = pol.ubi_weekly })
    return { ok = true, ubi_enabled = pol.ubi_enabled, ubi_weekly = pol.ubi_weekly }
  end)

  rpc:method("admin_force_ubi", { write = true, auth = "admin" }, function()
    meta.last_ubi = 0
    bank:meta_touch()
    jobs.run_now("ubi")
    return { ok = true }
  end)

  rpc:method("admin_set_supply_target", { write = true, auth = "admin", p = { enabled = "bool?", low = "cents?", high = "cents?" } }, function(ctx, p)
    if p.enabled ~= nil then pol.supply_target_enabled = p.enabled end
    if p.low then pol.supply_target_low = p.low end
    if p.high then pol.supply_target_high = p.high end
    bank:save_policy()
    bank:log("supply_target", { enabled = pol.supply_target_enabled, low = pol.supply_target_low, high = pol.supply_target_high })
    return { ok = true }
  end)

  rpc:method("admin_set_item_rate", { write = true, auth = "admin", p = { item = "str", rate = "cents?" } }, function(ctx, p)
    pol.item_backing_map[p.item] = p.rate
    bank:save_policy()
    bank:log("item_rate_change", { item = p.item, rate = p.rate })
    return { ok = true, rates = pol.item_backing_map }
  end)

  rpc:method("admin_freeze", { write = true, auth = "admin", p = { account_id = "acct", frozen = "bool" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    for _, acc in ipairs(a.treasury and { a } or bank:owner_accounts(a.owner)) do
      acc.frozen = p.frozen or nil
      bank:touch(acc)
    end
    if p.frozen then bank:drop_sessions_of(a.id) end
    bank:log("freeze", { account = a.id, frozen = p.frozen })
    return { ok = true }
  end)

  rpc:method("admin_unlock", { write = true, auth = "admin", p = { account_id = "acct" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    for _, acc in ipairs(bank:owner_accounts(a.owner)) do acc.lock = nil; bank:touch(acc) end
    bank:log("unlock", { account = a.id })
    return { ok = true }
  end)

  rpc:method("admin_delete_account", { write = true, auth = "admin", p = { account_id = "acct" }, doc = "Close an owner's accounts; the balance goes to the treasury" }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    if a.treasury then return fail("The treasury cannot be deleted") end
    local group = a.faction and { a } or bank:owner_accounts(a.owner)
    local refunded = 0
    local jobs_c = db:coll("jobs")
    for _, acc in ipairs(group) do
      if acc.balance > 0 then
        bank:post(bank:fund(), acc.balance, "account_close", "Closed: " .. acc.owner .. " (" .. acc.id .. ")")
        refunded = refunded + acc.balance
      end
      for jid in pairs(acc.civic or {}) do
        local j = jobs_c:get(jid)
        if j then j.holders[acc.id] = nil; jobs_c:touch(jid) end
      end
      bank:drop_sessions_of(acc.id)
      db:coll("progress"):del(acc.id)
      bank:index_remove(acc)
      bank.accounts:del(acc.id)
    end
    local reqs = db:coll("jreq")
    for rid, r in reqs:pairs() do if r.account_id == a.id then reqs:del(rid) end end
    bank:log("account_delete", { account = a.id, owner = a.owner, refunded = refunded })
    return { ok = true, refunded = refunded }
  end)

  rpc:method("admin_ledger_tail", { auth = "admin", p = { limit = "int+?" } }, function(ctx, p)
    return { ok = true, entries = db.ledger:recent(math.min(p.limit or 50, 400)), head = meta.ledger_head }
  end)

  rpc:method("admin_verify_ledger", { auth = "admin", doc = "Start or poll a full ledger verification" }, function()
    local v = ctl.verify
    if v and v.state == "running" then return { ok = true, state = "running" } end
    if v and v.state == "done" and util.now() - v.finished < 60 then
      return { ok = true, state = "done", chain_ok = v.ok, result = v.ok and v.entries or v.err, blocks = v.blocks, first_seq = v.first_seq, last_seq = v.last_seq }
    end
    ctl.verify = { state = "running", started = util.now() }
    jobs.run_now("verify_ledger")
    return { ok = true, state = "running" }
  end)

  rpc:method("admin_list_factions", { auth = "admin" }, function()
    local out = {}
    for id, f in db:coll("factions"):pairs() do
      local t = bank.accounts:get(f.treasury)
      out[#out + 1] = { id = id, name = f.name, members = util.count(f.members), threshold = f.n .. "/" .. f.m, treasury = f.treasury, treasury_balance = t and t.balance or 0 }
    end
    table.sort(out, function(x, y) return x.name < y.name end)
    return { ok = true, factions = out }
  end)

  rpc:method("admin_list_recurring", { auth = "admin" }, function()
    local out = {}
    for id, r in db:coll("recurring"):pairs() do
      if r.active then out[#out + 1] = { id = id, from = r.from, to = r.to, amount = r.amount, memo = r.memo, interval_sec = r.interval, next_run = r.next_run, remaining = r.remaining } end
    end
    return { ok = true, recurring = common.cap(out, 200) }
  end)

  rpc:method("admin_cancel_recurring", { write = true, auth = "admin", p = { recur_id = "id" } }, function(ctx, p)
    local rc = db:coll("recurring")
    local r = rc:get(p.recur_id)
    if not r then return fail("Not found") end
    r.active = false
    rc:touch(r.id)
    bank:log("recurring_cancel_admin", { recur = r.id })
    return { ok = true }
  end)

  rpc:method("admin_deactivate_shop", { write = true, auth = "admin", p = { shop_id = "id", reason = "text?" } }, function(ctx, p)
    local sh = db:coll("shops")
    local s = sh:get(p.shop_id)
    if not s then return fail("Shop not found") end
    s.active = false
    sh:touch(s.id)
    bank:log("shop_deactivate", { shop = s.id, reason = p.reason })
    return { ok = true }
  end)

  rpc:method("admin_backup", { write = true, auth = "admin", doc = "Compact and copy the snapshot to /.vrb/backups" }, function()
    local ok, err = ctl.backup()
    if not ok then return fail(err or "Backup failed") end
    return { ok = true }
  end)

  rpc:method("admin_audit", { auth = "admin", doc = "Check every account against its posted entries" }, function()
    local r = bank:audit()
    return { ok = true, accounts = r.accounts, total = r.total, mismatched = r.mismatched, supply = meta.money_supply }
  end)
end

return M
