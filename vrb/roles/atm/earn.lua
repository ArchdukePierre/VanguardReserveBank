local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local util = require("lib.util")
local theme = require("ui.theme")

local E = {}

local PARTS = {
  { "survival_wage", "Survival wage" }, { "combat_pay", "Combat pay" }, { "explorer_bonus", "Explorer bonus" },
  { "builder_bonus", "Builder bonus" }, { "danger_pay", "Danger pay" }, { "boss_bounty", "Boss bounty" },
  { "build_streak_bonus", "Build streak bonus" },
}

local function earnings_history(ctx)
  local res = ctx:call("my_earnings_history", { limit = 30 })
  if not res.ok then return ctx:fail(res) end
  local rows = {}
  if #res.history > 0 then
    rows[#rows + 1] = { left = "Last 7 days", right = util.money(res.week_total or 0), rcolor = theme.good }
    rows[#rows + 1] = { blank = true }
  end
  for _, h in ipairs(res.history) do
    local sub = h.died and "You died" or string.format("Streak day %.0f, %.2fx", h.streak_days or 0, h.streak_mult or 1)
    rows[#rows + 1] = { left = fmt.date_num(h.date), right = util.money(h.total or 0), rcolor = theme.good, sub = sub }
  end
  ui.list(ctx, { title = "Earnings history", sub = "Newest first", rows = rows, empty = "No payouts yet", hint = "Play to earn a daily wage" })
end

local function insurance(ctx)
  while true do
    local res = ctx:call("my_earnings", {})
    if not res.ok then return ctx:fail(res) end
    local cost = res.insurance_cost or 0
    local rows = {
      { left = "Cost for 30 days", right = util.money(cost) },
      { left = "Your policy", right = res.insurance_active and "Active" or "None", rcolor = res.insurance_active and theme.good or theme.muted },
    }
    if res.insurance_active and res.insurance_until then
      rows[#rows + 1] = { left = "Ends", right = fmt.day(res.insurance_until) .. " (" .. fmt.plural(fmt.days_until(res.insurance_until), "day") .. ")" }
    end
    rows[#rows + 1] = { blank = true }
    rows[#rows + 1] = { text = "Insurance protects your streak when you die. It renews by itself each month while checking can pay.", color = theme.muted }
    local buttons = { { label = res.insurance_active and "ADD 30 DAYS" or "BUY", id = "buy", kind = "success" } }
    if res.insurance_active then buttons[2] = { label = "CANCEL POLICY", id = "cancel", kind = "danger" } end
    local kind, id = ui.list(ctx, { title = "Death insurance", rows = rows, buttons = buttons })
    if kind ~= "btn" then return end
    if id == "buy" then
      if ui.confirm(ctx, "Buy insurance", { "Pay " .. util.money(cost) .. " for 30 days of cover?" }, "BUY") then
        local b = ctx:call("buy_insurance", {})
        if not b.ok then ctx:fail(b, "Not bought", true)
        else ctx:say("Insured", { "Covered until " .. fmt.day(b.insurance_until) .. ".", "Checking: " .. util.money(b.balance or 0) }, "ok") end
      end
    elseif ui.confirm(ctx, "Cancel policy", { "Stop your death insurance now?", "No refund is given." }, "CANCEL POLICY", true) then
      local c = ctx:call("cancel_insurance", {})
      if not c.ok then ctx:fail(c, "Not cancelled", true) else ctx:toast("Insurance cancelled", "ok") end
    end
  end
end

local function earnings(ctx)
  while true do
    local res = ctx:call("my_earnings", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    if not res.enabled then rows[#rows + 1] = { text = "Daily earnings are switched off right now.", color = theme.warn } end
    rows[#rows + 1] = { left = "Streak", right = fmt.plural(res.streak_days or 0, "day") }
    rows[#rows + 1] = { left = "Streak bonus", right = string.format("%.2fx %s", res.streak_mult or 1, res.streak_label or ""), rcolor = theme.good }
    rows[#rows + 1] = { left = "Death insurance", right = res.insurance_active and "Active" or "None" }
    local b = res.breakdown
    rows[#rows + 1] = { blank = true }
    if b then
      rows[#rows + 1] = { head = "Last payout " .. fmt.date_num(b.date) }
      if b.skipped then
        rows[#rows + 1] = { text = "No pay that day. You need about 20 minutes of play.", color = theme.muted }
      else
        for _, part in ipairs(PARTS) do
          if (b[part[1]] or 0) > 0 then rows[#rows + 1] = { left = part[2], right = util.money(b[part[1]]) } end
        end
        if b.died_today then rows[#rows + 1] = { text = "You died that day, so your streak dropped.", color = theme.bad } end
        rows[#rows + 1] = { left = "Total paid", right = util.money(b.total or 0), rcolor = theme.good }
      end
    else
      rows[#rows + 1] = { text = "No payout yet. Play to earn your first daily wage.", color = theme.muted }
    end
    local kind, id = ui.list(ctx, { title = "My earnings", rows = rows, buttons = { { label = "HISTORY", id = "history" }, { label = "INSURANCE", id = "insurance" } } })
    if kind ~= "btn" then return end
    if id == "history" then earnings_history(ctx) else insurance(ctx) end
  end
end

local function claim_reward(ctx, item, state)
  if item.once and state and state.approved then return ctx:say("Reward", { "You already got this one." }, "warn") end
  if state and state.pending then return ctx:say("Reward", { "Staff are still checking your claim." }, "warn") end
  local evidence = ui.text(ctx, { title = "Claim reward", label = "Tell staff how you earned it", max = 120, free = true })
  if not evidence then return end
  local res = ctx:call("submit_claim", { progress_id = item.id, evidence = evidence })
  if not res.ok then return ctx:fail(res, "Claim not sent", true) end
  ctx:say("Claim sent", { "Staff will review it and pay the", "reward if it checks out." }, "ok")
end

function E.rewards(ctx)
  local cat = ctx:pub("list_catalog", {})
  if not cat.ok then return ctx:fail(cat) end
  while true do
    local claims = {}
    if ctx.session then
      local mine = ctx:call("my_claims", {})
      if mine.ok then for _, c in ipairs(mine.claims) do claims[c.progress] = c end end
    end
    local rows = {}
    for _, item in ipairs(cat.catalog) do
      local st = claims[item.id]
      local sub = item.once and "One time" or "Can be earned again"
      if st and st.pending then sub = "Waiting for staff"
      elseif st and st.approved then sub = item.once and "Done" or string.format("Earned %.0f times", st.count or 1)
      elseif not ctx.session then sub = sub .. ". Sign in to claim." end
      rows[#rows + 1] = { left = item.label, right = (item.bounty or 0) > 0 and util.money(item.bounty) or "Varies", sub = sub, id = ctx.session and item.id or nil, data = item }
    end
    local kind, _, data = ui.list(ctx, { title = "Rewards", sub = ctx.session and "Touch a reward to claim it" or "Sign in to claim these", rows = rows, empty = "No rewards listed", hint = "Check back later" })
    if kind ~= "row" then return end
    claim_reward(ctx, data, claims[data.id])
  end
end

local function order_detail(ctx, o)
  local mine = ctx.account and o.claimed_by == ctx.account.id
  local status = mine and "Yours" or (o.claimed_by and "Taken" or "Open")
  local rows = {
    { head = o.title },
    { text = (o.description and o.description ~= "") and o.description or "No details were given." },
    { blank = true },
    { left = "Pay", right = util.money(o.bounty or 0), rcolor = theme.good },
    { left = "Status", right = status },
    { left = "Posted by", right = o.posted_by or "Reserve" },
  }
  local buttons = {}
  if ctx.session and mine then buttons[1] = { label = "GIVE BACK", id = "cancel", kind = "danger" }
  elseif ctx.session and not o.claimed_by then buttons[1] = { label = "TAKE THIS JOB", id = "claim", kind = "success" } end
  local kind, id = ui.list(ctx, { title = "Work order", rows = rows, buttons = buttons })
  if kind ~= "btn" then return end
  if id == "claim" then
    local res = ctx:call("claim_work_order", { order_id = o.id })
    if not res.ok then return ctx:fail(res, "Not taken", true) end
    ctx:say("Work order taken", { "Finish the job, then tell staff.", "They pay you when it is done." }, "ok")
  else
    local res = ctx:call("cancel_work_order_claim", { order_id = o.id })
    if not res.ok then return ctx:fail(res, "Not released", true) end
    ctx:toast("Work order released", "ok")
  end
end

function E.orders(ctx)
  while true do
    local res = ctx:pub("list_work_orders", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, o in ipairs(res.orders) do
      local mine = ctx.account and o.claimed_by == ctx.account.id
      rows[#rows + 1] = { left = o.title, right = util.money(o.bounty or 0), sub = mine and "Yours" or (o.claimed_by and "Taken" or "Open"), id = o.id, data = o }
    end
    local kind, _, data = ui.list(ctx, { title = "Work orders", sub = "Paid jobs from the Reserve", rows = rows, empty = "No open work orders", hint = "Check back later" })
    if kind ~= "row" then return end
    order_detail(ctx, data)
  end
end

local function my_job(ctx)
  local res = ctx:call("my_jobs", {})
  if not res.ok then return ctx:fail(res) end
  local rows = {}
  for _, j in ipairs(res.jobs) do
    rows[#rows + 1] = { head = j.title }
    rows[#rows + 1] = { left = "Pay per day", right = util.money(j.daily_cents or 0) }
    rows[#rows + 1] = { left = "Pay per week", right = util.money(j.weekly_cents or 0) }
    rows[#rows + 1] = { left = "Paid this week", right = util.money(j.week_paid or 0), rcolor = theme.good }
    rows[#rows + 1] = { left = "On leave", right = j.on_leave and "Yes" or "No" }
  end
  ui.list(ctx, { title = "My civic job", rows = rows, empty = "No civic job", hint = "Apply from the job list" })
end

function E.civic(ctx)
  while true do
    local res = ctx:call("list_civic_jobs", {})
    if not res.ok then return ctx:fail(res) end
    local rows, titles = {}, {}
    for _, j in ipairs(res.jobs) do titles[j.id] = j.title end
    if res.current_job then rows[#rows + 1] = { left = "You hold", right = titles[res.current_job] or "a job", rcolor = theme.good } end
    if res.pending_request then rows[#rows + 1] = { text = "Your application is waiting for staff.", color = theme.warn } end
    if #rows > 0 then rows[#rows + 1] = { blank = true } end
    for _, j in ipairs(res.jobs) do
      rows[#rows + 1] = { left = j.title, right = util.money(j.annual_cents or 0) .. "/yr", sub = fmt.plural(j.holders or 0, "worker"), id = j.id, data = j }
    end
    local buttons = { { label = "MY JOB", id = "mine" } }
    if res.pending_request then buttons[2] = { label = "CANCEL APPLICATION", id = "cancel", kind = "danger" } end
    local kind, id, data = ui.list(ctx, { title = "Civic jobs", sub = "Touch a job to apply", rows = rows, empty = "No jobs posted", hint = "Check back later", buttons = buttons })
    if not kind then return end
    if kind == "btn" and id == "mine" then my_job(ctx)
    elseif kind == "btn" then
      local c = ctx:call("cancel_civic_request", { request_id = res.pending_request })
      if not c.ok then ctx:fail(c, "Not cancelled", true) else ctx:toast("Application cancelled", "ok") end
    elseif res.current_job then ctx:say("Civic jobs", { "You already hold a job.", "Ask staff to clear it first." }, "warn")
    elseif res.pending_request then ctx:say("Civic jobs", { "You already applied.", "Wait for staff or cancel it." }, "warn")
    elseif ui.confirm(ctx, "Apply for a job", { "Apply to be " .. data.title .. "?", "It pays " .. util.money(data.annual_cents or 0) .. " a year." }, "APPLY") then
      local a = ctx:call("request_civic_job", { job_id = data.id })
      if not a.ok then ctx:fail(a, "Not sent", true) else ctx:say("Application sent", { "Staff will look at it soon." }, "ok") end
    end
  end
end

local function all_ranks(ctx)
  local res = ctx:pub("list_ranks", {})
  if not res.ok then return ctx:fail(res) end
  local rows = {}
  for _, r in ipairs(res.ranks) do
    rows[#rows + 1] = { left = r.label, right = util.money(r.weekly_cents or 0) .. "/wk", sub = r.grade .. ", " .. r.group }
  end
  ui.list(ctx, { title = "Vanguard ranks", sub = fmt.plural(res.current_count or 0, "member") .. " of " .. string.format("%.0f", res.max_members or 0), rows = rows, empty = "No ranks set" })
end

function E.rank(ctx)
  while true do
    local res = ctx:call("my_rank", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    if not res.vanguard then
      rows[#rows + 1] = { text = "You are not in the Vanguard. Ask staff how to join.", color = theme.muted }
    else
      local r = res.rank
      rows[#rows + 1] = { left = "Rank", right = r.label, rcolor = theme.good }
      rows[#rows + 1] = { left = "Grade", right = r.grade .. ", " .. r.group }
      rows[#rows + 1] = { left = "Pay per week", right = util.money(r.weekly_cents or 0) }
      rows[#rows + 1] = { left = "Pay per day", right = util.money(r.daily_cents or 0) }
      rows[#rows + 1] = { left = "Paid this week", right = util.money(res.week_paid or 0), rcolor = theme.good }
      rows[#rows + 1] = { left = "Days paid", right = string.format("%.0f", res.week_days or 0) }
      rows[#rows + 1] = { left = "On leave", right = res.on_leave and "Yes" or "No" }
      if res.assigned_at then rows[#rows + 1] = { left = "Since", right = fmt.day(res.assigned_at) } end
    end
    local kind = ui.list(ctx, { title = "Vanguard rank", rows = rows, buttons = { { label = "ALL RANKS", id = "all" } } })
    if kind ~= "btn" then return end
    all_ranks(ctx)
  end
end

function E.menu(ctx)
  while true do
    local id = ui.menu(ctx, { title = "Earn", sub = "Pay, rewards and jobs", items = {
      { label = "MY EARNINGS", id = "earnings", kind = "primary", sub = "Daily pay and streak" },
      { label = "INSURANCE", id = "insurance", kind = "panel", sub = "Protect your streak" },
      { label = "REWARDS", id = "rewards", kind = "success", sub = "Claim a bounty" },
      { label = "WORK ORDERS", id = "orders", kind = "panel", sub = "Paid jobs" },
      { label = "CIVIC JOBS", id = "civic", kind = "panel", sub = "Apply for a job" },
      { label = "VANGUARD RANK", id = "rank", kind = "panel", sub = "Your rank and pay" },
    } })
    if not id then return end
    if id == "earnings" then earnings(ctx)
    elseif id == "insurance" then insurance(ctx)
    elseif id == "rewards" then E.rewards(ctx)
    elseif id == "orders" then E.orders(ctx)
    elseif id == "civic" then E.civic(ctx)
    else E.rank(ctx) end
  end
end

return E
