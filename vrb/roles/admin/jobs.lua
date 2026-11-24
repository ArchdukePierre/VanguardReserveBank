local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local T = theme
local M = {}

function M.assign(ctx, acct, job)
  local lines = { "Give " .. acct.owner .. " the job " .. job.title .. "?", "Pay " .. util.money(job.annual_cents) .. " a year before tax." }
  if not ctx:confirm("Assign job", lines, { yes = "ASSIGN" }) then return false end
  local p = { account_id = acct.id, job_id = job.id }
  local r, bad = ctx:call("admin_assign_job", p, { quiet = true })
  if not r and bad and (bad.err or ""):find("Already holds", 1, true) then
    local more = { acct.owner .. " already holds a job.", "Give " .. job.title .. " as well? Both jobs pay." }
    if not ctx:confirm("Already has a job", more, { yes = "ADD JOB" }) then return false end
    p.force = true
    r, bad = ctx:call("admin_assign_job", p, { quiet = true })
  end
  if not r then
    if bad then ctx:fail(bad) end
    return false
  end
  return true
end

function M.assign_to(ctx, acct)
  local r = ctx:call("admin_list_jobs")
  if not r then return false end
  if #r.jobs == 0 then
    ctx:message("No jobs", { "There are no civic jobs yet. Create one in CIVIC JOBS first." }, "warn")
    return false
  end
  local opts, by_id = {}, {}
  for _, j in ipairs(r.jobs) do
    opts[#opts + 1] = { label = j.title, id = j.id, sub = util.money(j.annual_cents) .. " a year", kind = "panel" }
    by_id[j.id] = j
  end
  local id = ctx:choose("Pick a job", opts, { subtitle = "For " .. acct.owner })
  if not id then return false end
  return M.assign(ctx, acct, by_id[id])
end

local function holders(ctx, job)
  local st = { offset = 0 }
  while true do
    local r = ctx:call("admin_list_job_holders", { job_id = job.id })
    if not r then return end
    local rows = {}
    for _, h in ipairs(r.holders) do
      rows[#rows + 1] = { left = h.owner .. (h.on_leave and " (leave)" or ""), right = util.money(h.balance), id = h.account_id, data = h, color = h.on_leave and T.warn or nil }
    end
    local id, h = Core.list(ctx, {
      title = r.job.title, subtitle = Core.n(r.count, "holder") .. ", " .. util.money(r.job.annual_cents) .. " a year",
      rows = rows, buttons = { { label = "ADD", id = "add", kind = "primary" } }, state = st, empty = "No holders yet", hint = "Touch ADD to give this job",
    })
    if not id then return end
    if id == "add" then
      local acct = ctx:pick_account("Give this job to")
      if acct and M.assign(ctx, acct, job) then ctx:say("Job assigned") end
    else
      local opts = {
        { label = "REMOVE FROM JOB", id = "remove", kind = "danger" },
        { label = h.on_leave and "END LEAVE" or "PAUSE PAY", id = "leave", kind = "panel" },
        { label = "OPEN ACCOUNT", id = "acct", kind = "panel" },
      }
      local act = ctx:choose(h.owner, opts, { subtitle = job.title })
      if act == "remove" then
        if ctx:confirm("Remove from job", { "Take " .. h.owner .. " off " .. job.title .. "?", "They stop receiving its pay." }, { yes = "REMOVE", danger = true }) then
          if ctx:call("admin_unassign_job", { account_id = h.account_id, job_id = job.id }) then ctx:say("Removed from the job") end
        end
      elseif act == "leave" then
        local to = not h.on_leave
        if ctx:call("admin_set_job_leave", { account_id = h.account_id, job_id = job.id, on_leave = to }) then ctx:say(to and "Pay paused" or "Pay resumed") end
      elseif act == "acct" then
        require("roles.admin.accounts").detail(ctx, h.account_id)
      end
    end
  end
end

local function create(ctx)
  local title = ctx:text({ title = "New job", label = "_ is a space", subtitle = "Title, 2 to 40 letters", max = 40 })
  if not title then return end
  local pay = Core.keypad(ctx, { title = "Pay for " .. title, label = "Pay for a year", kind = "money", limit = 99999999999 })
  if not pay then return end
  local lines = { "Create the job " .. title .. "?", "Pay " .. util.money(pay) .. " a year.", "That is " .. util.money(math.floor(pay / 365)) .. " a day before tax." }
  if not ctx:confirm("New job", lines, { yes = "CREATE" }) then return end
  if ctx:call("admin_create_job", { title = title, annual_cents = pay }) then ctx:say("Job created") end
end

local function summary(ctx)
  local r = ctx:call("civic_payroll_summary")
  if not r then return end
  ctx:message("Civic payroll", {
    Core.n(r.jobs, "job") .. ", " .. Core.n(r.holder_records, "holder"),
    "Each day: " .. util.money(r.total_daily),
    "Each week: " .. util.money(r.total_weekly),
    "Each year: " .. util.money(r.total_annual),
  })
end

local function job_menu(ctx, job)
  local opts = {
    { label = "HOLDERS", id = "holders", kind = "primary" },
    { label = "ASSIGN HOLDER", id = "assign", kind = "panel" },
    { label = "EDIT TITLE", id = "title", kind = "panel" },
    { label = "EDIT PAY", id = "pay", kind = "panel" },
    { label = "DELETE JOB", id = "delete", kind = "danger" },
  }
  local id = ctx:choose(job.title, opts, { subtitle = util.money(job.annual_cents) .. " a year, " .. Core.n(job.holder_count, "holder") })
  if id == "holders" then holders(ctx, job)
  elseif id == "assign" then
    local acct = ctx:pick_account("Give this job to")
    if acct and M.assign(ctx, acct, job) then ctx:say("Job assigned") end
  elseif id == "title" then
    local t = ctx:text({ title = "Job title", label = "_ is a space", subtitle = "2 to 40 letters", initial = job.title, max = 40 })
    if t and t ~= job.title and ctx:call("admin_edit_job", { job_id = job.id, title = t }) then ctx:say("Title changed") end
  elseif id == "pay" then
    local v = Core.keypad(ctx, { title = "Pay for " .. job.title, label = "Pay for a year", kind = "money", limit = 99999999999, subtitle = "Now " .. util.money(job.annual_cents) })
    if v and v ~= job.annual_cents then
      local lines = { job.title .. " pay changes.", "Now " .. util.money(job.annual_cents) .. " a year.", "New " .. util.money(v) .. " a year.", Core.n(job.holder_count, "holder") .. " get the new pay." }
      if ctx:confirm("Change pay", lines, { yes = "CHANGE" }) and ctx:call("admin_edit_job", { job_id = job.id, annual_cents = v }) then ctx:say("Pay changed") end
    end
  elseif id == "delete" then
    local lines = { "Delete the job " .. job.title .. "?", Core.n(job.holder_count, "holder") .. " lose the job and its pay.", "This cannot be undone." }
    if ctx:confirm("Delete job", lines, { yes = "DELETE", danger = true }) and ctx:call("admin_delete_job", { job_id = job.id }) then ctx:say("Job deleted") end
  end
end

function M.run(ctx)
  local st = { offset = 0 }
  local data
  local function load()
    local r = ctx:call("admin_list_jobs")
    if not r then return false end
    data = r
    return true
  end
  if not load() then return end
  while true do
    local rows = {}
    local wide = ctx.app.s.w >= 45
    for _, j in ipairs(data.jobs) do
      rows[#rows + 1] = { left = j.title .. " x" .. util.int(j.holder_count), right = util.money(j.annual_cents) .. (wide and "/yr" or ""), id = j.id, data = j }
    end
    local id, job = Core.list(ctx, {
      title = "Civic jobs", subtitle = "Payroll " .. util.money(data.total_annual) .. " a year", rows = rows, state = st,
      buttons = { { label = "NEW JOB", id = "new", kind = "primary" }, { label = "PAYROLL", id = "sum" }, { label = "RELOAD", id = "reload" } },
      empty = "No jobs yet", hint = "Touch NEW JOB to create one",
    })
    if not id then return end
    if id == "new" then create(ctx); load()
    elseif id == "sum" then summary(ctx)
    elseif id == "reload" then load()
    else
      job_menu(ctx, job)
      load()
    end
  end
end

return M
