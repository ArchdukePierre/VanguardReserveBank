local util = require("lib.util")
local common = require("server.common")

local fail, notify = common.fail, common.notify
local floor = math.floor
local M = {}

function M.register(rpc, bank, jobs_sched)
  local cfg = bank.cfg
  local meta = bank.meta
  local jobs = bank.db:coll("jobs")
  local reqs = bank.db:coll("jreq")

  local function rank_view(r)
    return { id = r.id, grade = r.grade, group = r.group, label = r.label, weekly_cents = r.weekly_cents, yearly_cents = r.weekly_cents * 52, daily_cents = floor(r.weekly_cents / 7) }
  end

  local function checking_target(a)
    if a.kind == "savings" then return bank:pair_of(a) end
    return a
  end

  rpc:method("list_ranks", { doc = "Vanguard pay grades" }, function()
    local out = {}
    for _, r in ipairs(cfg.vanguard.ranks) do out[#out + 1] = rank_view(r) end
    return { ok = true, ranks = out, max_members = cfg.vanguard.max_members, current_count = bank:count_vanguard() }
  end)

  rpc:method("admin_set_rank", { write = true, auth = "admin", p = { account_id = "acct", rank_id = "id?" }, doc = "Assign, change or clear a Vanguard rank" }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    if a.treasury then return fail("The treasury cannot hold a rank") end
    a = checking_target(a)
    if not a then return fail("No linked checking account") end
    if not p.rank_id or p.rank_id == "" then
      if not a.vg then return fail("Not a Vanguard member") end
      local prev = a.vg
      a.vg, a.vg_leave, a.vg_since, a.vg_wp, a.vg_wd = nil, nil, nil, nil, nil
      bank:touch(a)
      bank:log("rank_remove", { account = a.id, owner = a.owner, prev = prev })
      return { ok = true, removed = true }
    end
    local rank = bank:rank(p.rank_id)
    if not rank then return fail("Unknown rank") end
    if not a.vg and bank:count_vanguard() >= cfg.vanguard.max_members then
      return fail(string.format("Vanguard is full (%d/%d). Remove a member first.", bank:count_vanguard(), cfg.vanguard.max_members))
    end
    local prev = a.vg
    a.vg = rank.id
    a.vg_since = a.vg_since or util.now()
    bank:touch(a)
    bank:log(prev and "rank_change" or "rank_assign", { account = a.id, owner = a.owner, prev = prev, rank = rank.id, weekly = rank.weekly_cents })
    return { ok = true, rank = rank_view(rank) }
  end)

  rpc:method("admin_set_leave", { write = true, auth = "admin", p = { account_id = "acct", on_leave = "bool" }, doc = "Pause or resume Vanguard pay" }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a or not a.vg then return fail("Not a Vanguard member") end
    a.vg_leave = p.on_leave
    bank:touch(a)
    bank:log("rank_leave", { account = a.id, owner = a.owner, on_leave = p.on_leave })
    return { ok = true, on_leave = p.on_leave }
  end)

  rpc:method("admin_list_vanguard", { auth = "admin" }, function()
    local out = {}
    for _, a in bank.accounts:pairs() do
      if a.vg then
        local r = bank:rank(a.vg)
        out[#out + 1] = { account_id = a.id, owner = a.owner, rank_id = a.vg, rank_grade = r and r.grade or "?", rank_label = r and r.label or "?", weekly_cents = r and r.weekly_cents or 0,
          balance = a.balance, on_leave = a.vg_leave and true or false, week_paid = a.vg_wp or 0, week_days = a.vg_wd or 0, assigned_at = a.vg_since }
      end
    end
    local order = {}
    for i, r in ipairs(cfg.vanguard.ranks) do order[r.id] = i end
    table.sort(out, function(x, y) return (order[x.rank_id] or 0) > (order[y.rank_id] or 0) end)
    return { ok = true, members = out, count = #out, max = cfg.vanguard.max_members }
  end)

  rpc:method("admin_set_vanguard_enabled", { write = true, auth = "admin", p = { enabled = "bool" } }, function(ctx, p)
    meta.vanguard_enabled = p.enabled
    bank:meta_touch()
    bank:log("vanguard_toggle", { enabled = p.enabled })
    return { ok = true, enabled = p.enabled }
  end)

  rpc:method("my_rank", { auth = "session" }, function(ctx)
    local a = ctx.acct
    if not a.vg then return { ok = true, vanguard = false } end
    local r = bank:rank(a.vg)
    return { ok = true, vanguard = true, rank = rank_view(r), on_leave = a.vg_leave and true or false, assigned_at = a.vg_since, week_paid = a.vg_wp or 0, week_days = a.vg_wd or 0 }
  end)

  rpc:method("vanguard_payroll_summary", {}, function()
    local weekly, count, groups = 0, 0, { Officer = 0, Warrant = 0, Enlisted = 0 }
    for _, a in bank.accounts:pairs() do
      local r = a.vg and bank:rank(a.vg)
      if r then weekly, count = weekly + r.weekly_cents, count + 1; groups[r.group] = (groups[r.group] or 0) + 1 end
    end
    return { ok = true, total_weekly = weekly, total_yearly = weekly * 52, total_daily = floor(weekly / 7), count = count, groups = groups }
  end)

  local function daily(annual) return annual > 0 and floor(annual / 365) or 0 end

  rpc:method("admin_create_job", { write = true, auth = "admin", p = { title = "text", annual_cents = "cents+" } }, function(ctx, p)
    local title = util.trim(p.title)
    if #title < 2 or #title > 40 then return fail("Title must be 2 to 40 characters") end
    if p.annual_cents > 1e11 then return fail("Annual pay is capped at $1B") end
    for _, j in jobs:pairs() do if j.title:lower() == title:lower() then return fail("That title already exists") end end
    local jid = bank:id("JOB", 12)
    jobs:put(jid, { id = jid, title = title, annual_cents = p.annual_cents, holders = {}, created_at = util.now() })
    bank:log("job_create", { job_id = jid, title = title, annual = p.annual_cents })
    return { ok = true, job_id = jid, title = title, annual_cents = p.annual_cents, weekly_cents = floor(p.annual_cents / 52), daily_cents = daily(p.annual_cents) }
  end)

  rpc:method("admin_edit_job", { write = true, auth = "admin", p = { job_id = "id", title = "text?", annual_cents = "cents+?" } }, function(ctx, p)
    local job = jobs:get(p.job_id)
    if not job then return fail("Job not found") end
    if p.title then
      local t = util.trim(p.title)
      if #t < 2 or #t > 40 then return fail("Title must be 2 to 40 characters") end
      for id, j in jobs:pairs() do if id ~= job.id and j.title:lower() == t:lower() then return fail("That title already exists") end end
      job.title = t
    end
    if p.annual_cents then job.annual_cents = p.annual_cents end
    jobs:touch(job.id)
    bank:log("job_edit", { job_id = job.id, title = job.title, annual = job.annual_cents })
    return { ok = true, job_id = job.id, title = job.title, annual_cents = job.annual_cents }
  end)

  rpc:method("admin_delete_job", { write = true, auth = "admin", p = { job_id = "id" } }, function(ctx, p)
    local job = jobs:get(p.job_id)
    if not job then return fail("Job not found") end
    local removed = 0
    for aid in pairs(job.holders or {}) do
      local a = bank.accounts:get(aid)
      if a and a.civic then
        a.civic[job.id] = nil
        if not next(a.civic) then a.civic = nil end
        bank:touch(a)
        removed = removed + 1
      end
    end
    jobs:del(job.id)
    bank:log("job_delete", { job_id = job.id, title = job.title, removed = removed })
    return { ok = true, holders_removed = removed }
  end)

  rpc:method("admin_assign_job", { write = true, auth = "admin", p = { account_id = "acct", job_id = "id", force = "bool?" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a or a.treasury then return fail("Account not found") end
    a = checking_target(a)
    if not a then return fail("No linked checking account") end
    local job = jobs:get(p.job_id)
    if not job then return fail("Job not found") end
    if a.civic and next(a.civic) and not p.force then
      local jid = next(a.civic)
      return fail("Already holds " .. ((jobs:get(jid) or {}).title or jid) .. ". Clear it first.")
    end
    a.civic = a.civic or {}
    a.civic[job.id] = { assigned_at = util.now(), on_leave = false, week_paid = 0, week_days = 0 }
    job.holders[a.id] = true
    jobs:touch(job.id)
    bank:touch(a)
    bank:log("job_assign", { job_id = job.id, title = job.title, account = a.id, owner = a.owner, annual = job.annual_cents })
    return { ok = true, job_id = job.id }
  end)

  rpc:method("admin_unassign_job", { write = true, auth = "admin", p = { account_id = "acct", job_id = "id" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a or not a.civic or not a.civic[p.job_id] then return fail("Not a holder") end
    local job = jobs:get(p.job_id)
    a.civic[p.job_id] = nil
    if not next(a.civic) then a.civic = nil end
    bank:touch(a)
    if job then job.holders[a.id] = nil; jobs:touch(job.id) end
    bank:log("job_remove", { job_id = p.job_id, title = job and job.title or "?", account = a.id, owner = a.owner })
    return { ok = true }
  end)

  rpc:method("admin_set_job_leave", { write = true, auth = "admin", p = { account_id = "acct", job_id = "id", on_leave = "bool" } }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a or not a.civic or not a.civic[p.job_id] then return fail("Not a holder") end
    a.civic[p.job_id].on_leave = p.on_leave
    bank:touch(a)
    bank:log("job_leave", { job_id = p.job_id, account = a.id, on_leave = p.on_leave })
    return { ok = true, on_leave = p.on_leave }
  end)

  rpc:method("admin_list_jobs", { auth = "admin" }, function()
    local out, total = {}, 0
    for id, j in jobs:pairs() do
      local n = util.count(j.holders or {})
      out[#out + 1] = { id = id, title = j.title, annual_cents = j.annual_cents, weekly_cents = floor(j.annual_cents / 52), daily_cents = daily(j.annual_cents), holder_count = n, created_at = j.created_at }
      total = total + j.annual_cents * n
    end
    table.sort(out, function(x, y) return x.annual_cents > y.annual_cents end)
    return { ok = true, jobs = out, total_annual = total, total_weekly = floor(total / 52), total_daily = floor(total / 365) }
  end)

  rpc:method("admin_list_job_holders", { auth = "admin", p = { job_id = "id" } }, function(ctx, p)
    local job = jobs:get(p.job_id)
    if not job then return fail("Job not found") end
    local out = {}
    for aid in pairs(job.holders or {}) do
      local a = bank.accounts:get(aid)
      local h = a and a.civic and a.civic[job.id]
      if h then out[#out + 1] = { account_id = a.id, owner = a.owner, balance = a.balance, on_leave = h.on_leave and true or false, week_paid = h.week_paid or 0, week_days = h.week_days or 0, assigned_at = h.assigned_at } end
    end
    table.sort(out, function(x, y) return x.balance > y.balance end)
    return { ok = true, job = { id = job.id, title = job.title, annual_cents = job.annual_cents, weekly_cents = floor(job.annual_cents / 52), daily_cents = daily(job.annual_cents) }, holders = common.cap(out, 200), count = #out }
  end)

  rpc:method("list_civic_jobs", { auth = "session" }, function(ctx)
    local out = {}
    for _, j in jobs:pairs() do out[#out + 1] = { id = j.id, title = j.title, annual_cents = j.annual_cents, holders = util.count(j.holders or {}) } end
    table.sort(out, function(x, y) return x.title < y.title end)
    local current, pending = nil, nil
    if ctx.acct.civic then current = next(ctx.acct.civic) end
    for _, r in reqs:pairs() do if r.account_id == ctx.acct.id and r.status == "pending" then pending = r.id; break end end
    return { ok = true, jobs = out, current_job = current, pending_request = pending }
  end)

  rpc:method("request_civic_job", { write = true, auth = "session", p = { job_id = "id" } }, function(ctx, p)
    local a = ctx.acct
    if not jobs:get(p.job_id) then return fail("Unknown job") end
    if a.civic and next(a.civic) then return fail("You already hold a civic job. Ask staff to clear it first.") end
    for _, r in reqs:pairs() do
      if r.account_id == a.id and r.status == "pending" then return fail("You already have a pending application") end
    end
    local rid = bank:id("REQ", 8)
    reqs:put(rid, { id = rid, account_id = a.id, owner = a.owner, job_id = p.job_id, requested_at = util.now(), status = "pending" })
    bank:log("civic_request", { request = rid, account = a.id, owner = a.owner, job_id = p.job_id })
    return { ok = true, request_id = rid }
  end)

  rpc:method("cancel_civic_request", { write = true, auth = "session", p = { request_id = "id" } }, function(ctx, p)
    local r = reqs:get(p.request_id)
    if not r or r.account_id ~= ctx.acct.id then return fail("Application not found") end
    if r.status ~= "pending" then return fail("That application was already decided") end
    reqs:del(r.id)
    bank:log("civic_request_cancel", { request = r.id, account = ctx.acct.id })
    return { ok = true }
  end)

  rpc:method("admin_list_civic_requests", { auth = "admin" }, function()
    local out = {}
    for id, r in reqs:pairs() do
      if r.status == "pending" then
        local j = jobs:get(r.job_id)
        out[#out + 1] = { id = id, account_id = r.account_id, owner = r.owner, job_id = r.job_id, job_title = j and j.title or "?", annual_cents = j and j.annual_cents or 0, requested_at = r.requested_at }
      end
    end
    table.sort(out, function(x, y) return x.requested_at < y.requested_at end)
    return { ok = true, requests = common.cap(out, 150) }
  end)

  rpc:method("admin_approve_civic_request", { write = true, auth = "admin", p = { request_id = "id" } }, function(ctx, p)
    local r = reqs:get(p.request_id)
    if not r or r.status ~= "pending" then return fail("That application is not pending") end
    local a, job = bank.accounts:get(r.account_id), jobs:get(r.job_id)
    if not a then return fail("Account is gone") end
    if not job then return fail("Job is gone") end
    if a.civic and next(a.civic) then return fail("That player now holds another job") end
    a.civic = { [job.id] = { assigned_at = util.now(), on_leave = false, week_paid = 0, week_days = 0 } }
    job.holders[a.id] = true
    jobs:touch(job.id)
    bank:touch(a)
    r.status, r.decided = "approved", util.now()
    reqs:touch(r.id)
    bank:log("civic_request_approve", { request = r.id, account = a.id, owner = a.owner, job_id = job.id })
    return { ok = true }
  end)

  rpc:method("admin_reject_civic_request", { write = true, auth = "admin", p = { request_id = "id", reason = "text?" } }, function(ctx, p)
    local r = reqs:get(p.request_id)
    if not r or r.status ~= "pending" then return fail("That application is not pending") end
    r.status, r.decided, r.reason = "rejected", util.now(), p.reason
    reqs:touch(r.id)
    bank:log("civic_request_reject", { request = r.id, owner = r.owner, reason = p.reason })
    return { ok = true }
  end)

  rpc:method("my_jobs", { auth = "session" }, function(ctx)
    local out, total = {}, 0
    for jid, h in pairs(ctx.acct.civic or {}) do
      local j = jobs:get(jid)
      if j then
        out[#out + 1] = { job_id = jid, title = j.title, annual_cents = j.annual_cents, weekly_cents = floor(j.annual_cents / 52), daily_cents = daily(j.annual_cents), on_leave = h.on_leave and true or false, week_paid = h.week_paid or 0, week_days = h.week_days or 0 }
        total = total + j.annual_cents
      end
    end
    return { ok = true, jobs = out, count = #out, total_annual = total, total_weekly = floor(total / 52), total_daily = floor(total / 365) }
  end)

  rpc:method("civic_payroll_summary", {}, function()
    local total, nj, nh = 0, 0, 0
    for _, j in jobs:pairs() do
      local n = util.count(j.holders or {})
      nj, nh, total = nj + 1, nh + n, total + j.annual_cents * n
    end
    return { ok = true, jobs = nj, holder_records = nh, total_annual = total, total_weekly = floor(total / 52), total_daily = floor(total / 365) }
  end)

  local function pay_salary(a, label, gross, annual, kind, ledger_kind, extra)
    local rate = bank:income_tax_rate(annual)
    local tax = floor(gross * rate)
    local net = gross - tax
    bank:post(a, net, kind, string.format("%s salary (gross %s, tax %s @ %.0f%%)", label, util.money(gross), util.money(tax), rate * 100))
    bank:supply(gross)
    bank:fund_credit(tax, "income_tax: " .. label .. " " .. a.owner)
    bank:count_tx()
    return net
  end

  local function run_vanguard()
    if not meta.vanguard_enabled then return 0, 0 end
    local total, paid = 0, 0
    for _, a in bank.accounts:pairs() do
      local r = a.vg and bank:rank(a.vg)
      if r and not a.frozen and not a.vg_leave then
        local gross = floor(r.weekly_cents / 7)
        if gross > 0 then
          local net = pay_salary(a, r.grade, gross, r.weekly_cents * 52, "salary")
          a.vg_wp, a.vg_wd = (a.vg_wp or 0) + net, (a.vg_wd or 0) + 1
          total, paid = total + net, paid + 1
        end
      end
    end
    if paid > 0 then bank:log("payroll_tick", { paid = paid, total = total }) end
    return total, paid
  end

  local function run_civic()
    local total, paid = 0, 0
    for _, a in bank.accounts:pairs() do
      if a.civic and not a.frozen then
        for jid, h in pairs(a.civic) do
          local j = jobs:get(jid)
          if j and not h.on_leave then
            local gross = daily(j.annual_cents)
            if gross > 0 then
              local net = pay_salary(a, j.title, gross, j.annual_cents, "civic_pay")
              a.civic_wp = (a.civic_wp or 0) + net
              h.week_paid, h.week_days = (h.week_paid or 0) + net, (h.week_days or 0) + 1
              total, paid = total + net, paid + 1
              bank:touch(a)
            end
          end
        end
      end
    end
    if paid > 0 then bank:log("civic_payroll_tick", { paid = paid, total = total }) end
    return total, paid
  end

  local function weekly_digests()
    for _, a in bank.accounts:pairs() do
      if a.vg and (a.vg_wp or 0) > 0 then
        local r = bank:rank(a.vg)
        notify(bank, a.owner, "daily", "gold", string.format("Weekly salary: %s over %d days as %s", util.money(a.vg_wp), a.vg_wd or 0, r and r.label or a.vg))
        a.vg_wp, a.vg_wd = 0, 0
        bank:touch(a)
      end
      if a.civic and (a.civic_wp or 0) > 0 then
        local parts = {}
        for jid, h in pairs(a.civic) do
          local j = jobs:get(jid)
          if j and (h.week_paid or 0) > 0 then
            parts[#parts + 1] = string.format("%s as %s", util.money(h.week_paid), j.title)
            h.week_paid, h.week_days = 0, 0
          end
        end
        if #parts > 0 then notify(bank, a.owner, "daily", "gold", "Civic pay this week: " .. table.concat(parts, ", ") .. " (total " .. util.money(a.civic_wp) .. ")") end
        a.civic_wp = 0
        bank:touch(a)
      end
    end
  end

  rpc:method("admin_day_tick", { write = true, auth = "admin", p = { mc_day = "int", force = "bool?" }, doc = "Pay Vanguard and civic salaries once per Minecraft day" }, function(ctx, p)
    if not p.force and meta.last_mc_day > 0 and p.mc_day <= meta.last_mc_day then
      return { ok = true, paid_already = true, mc_day = p.mc_day, payroll_total = 0, payroll_count = 0, civic_total = 0, civic_count = 0 }
    end
    local pt, pc = run_vanguard()
    local ct, cc = run_civic()
    if not p.force then meta.last_mc_day = p.mc_day; bank:meta_touch() end
    if tonumber(os.date("%w")) == 1 then weekly_digests() end
    return { ok = true, mc_day = p.mc_day, payroll_total = pt, payroll_count = pc, civic_total = ct, civic_count = cc }
  end)
end

return M
