local util = require("lib.util")
local Core = require("roles.admin.core")

local M = {}

local function claim_menu(ctx, c)
  local opts = {
    { label = "SHOW PROOF", id = "show", kind = "panel" },
    { label = "APPROVE " .. util.money(c.bounty), id = "approve", kind = "success" },
    { label = "APPROVE OTHER SUM", id = "other", kind = "primary" },
    { label = "REJECT", id = "reject", kind = "danger" },
  }
  while true do
    local id = ctx:choose(c.owner, opts, { subtitle = c.label })
    if id == "show" then
      ctx:message(c.label, { c.owner .. " wrote:", c.evidence or "(nothing)", "Sent " .. Core.stamp(c.submitted_at) })
    elseif id == "approve" then
      local lines = { "Pay " .. util.money(c.bounty) .. " to " .. c.owner .. " for " .. c.label .. "?", "The money is created for them." }
      if ctx:confirm("Approve claim", lines, { yes = "APPROVE" }) and ctx:call("admin_approve_claim", { account_id = c.account, progress_id = c.progress }) then
        ctx:say("Paid " .. util.money(c.bounty) .. " to " .. c.owner)
        return
      end
      return
    elseif id == "other" then
      local v = Core.keypad(ctx, { title = "Other sum", label = "Pay instead", kind = "money", allow_zero = true, subtitle = "Standard " .. util.money(c.bounty) })
      if not v then return end
      local lines = { "Pay " .. util.money(v) .. " to " .. c.owner .. " for " .. c.label .. "?", "The standard bounty is " .. util.money(c.bounty) .. "." }
      if ctx:confirm("Approve claim", lines, { yes = "APPROVE" }) and ctx:call("admin_approve_claim", { account_id = c.account, progress_id = c.progress, override_bounty = v }) then
        ctx:say("Paid " .. util.money(v) .. " to " .. c.owner)
      end
      return
    elseif id == "reject" then
      local reason = ctx:reason("Why reject", { "Not enough proof", "Not completed", "Already paid", "Other reason" }, 3)
      if not reason then return end
      if ctx:confirm("Reject claim", { "Reject " .. c.owner .. "'s claim for " .. c.label .. "?", "Reason: " .. reason, "They can send it again." }, { yes = "REJECT", danger = true })
        and ctx:call("admin_reject_claim", { account_id = c.account, progress_id = c.progress, reason = reason }) then
        ctx:say("Claim rejected")
      end
      return
    else
      return
    end
  end
end

local function claims(ctx)
  local st = { offset = 0 }
  while true do
    local r = ctx:call("admin_pending_claims")
    if not r then return end
    local rows = {}
    for i, c in ipairs(r.claims) do rows[#rows + 1] = { left = c.owner .. ": " .. c.label, right = util.money(c.bounty), id = "c" .. i, data = c } end
    local id, c = Core.list(ctx, { title = "Claims", subtitle = string.format("%.0f waiting", #r.claims), rows = rows, state = st, empty = "No claims waiting" })
    if not id then return end
    claim_menu(ctx, c)
  end
end

local function civic(ctx)
  local st = { offset = 0 }
  while true do
    local r = ctx:call("admin_list_civic_requests")
    if not r then return end
    local rows = {}
    for i, q in ipairs(r.requests) do rows[#rows + 1] = { left = q.owner .. " > " .. q.job_title, right = util.money(q.annual_cents), id = "q" .. i, data = q } end
    local id, q = Core.list(ctx, { title = "Applications", subtitle = string.format("%.0f waiting", #r.requests), rows = rows, state = st, empty = "No applications waiting" })
    if not id then return end
    local act = ctx:choose(q.owner, { { label = "APPROVE", id = "yes", kind = "success" }, { label = "REJECT", id = "no", kind = "danger" } }, { subtitle = q.job_title .. ", " .. util.money(q.annual_cents) .. " a year" })
    if act == "yes" then
      local lines = { "Give " .. q.owner .. " the job " .. q.job_title .. "?", "Pay " .. util.money(q.annual_cents) .. " a year before tax." }
      if ctx:confirm("Approve application", lines, { yes = "APPROVE" }) and ctx:call("admin_approve_civic_request", { request_id = q.id }) then ctx:say(q.owner .. " got the job") end
    elseif act == "no" then
      local reason = ctx:reason("Why reject", { "Not hiring now", "Try again later", "Other reason" }, 3)
      if reason and ctx:confirm("Reject application", { "Reject " .. q.owner .. " for " .. q.job_title .. "?", "Reason: " .. reason }, { yes = "REJECT", danger = true })
        and ctx:call("admin_reject_civic_request", { request_id = q.id, reason = reason }) then
        ctx:say("Application rejected")
      end
    end
  end
end

local function flags(ctx)
  local st = { offset = 0 }
  while true do
    local r = ctx:call("admin_list_farm_flags")
    if not r then return end
    local rows = {}
    for i, f in ipairs(r.flags) do rows[#rows + 1] = { left = f.owner .. " " .. Core.strip(f.entity) .. " x" .. util.int(f.count), right = util.money(f.estimated_pay), id = "f" .. i, data = f } end
    local id, f = Core.list(ctx, { title = "Farm flags", subtitle = string.format("%.0f waiting", #r.flags), rows = rows, state = st, empty = "No flags waiting" })
    if not id then return end
    local what = f.owner .. " killed " .. util.int(f.count) .. " " .. Core.strip(f.entity)
    local opts = {
      { label = "CONFIRM FARMING", id = "confirm", kind = "danger", sub = "No pay" },
      { label = "OVERRIDE AND PAY", id = "override", kind = "success", sub = util.money(f.estimated_pay) },
    }
    local act = ctx:choose(f.owner, opts, { subtitle = what .. " in one day" })
    if act == "confirm" then
      if ctx:confirm("Confirm farming", { what .. ".", "Treat it as farming. Nothing is paid." }, { yes = "CONFIRM", danger = true }) and ctx:call("admin_review_flag", { flag_id = f.id, action = "confirm" }) then
        ctx:say("Flag confirmed, no pay")
      end
    elseif act == "override" then
      if ctx:confirm("Override flag", { what .. ".", "Pay " .. util.money(f.estimated_pay) .. " anyway?", "The money is created for them." }, { yes = "PAY" }) and ctx:call("admin_review_flag", { flag_id = f.id, action = "override" }) then
        ctx:say("Paid " .. util.money(f.estimated_pay))
      end
    end
  end
end

local function add_item(ctx, existing)
  local id = ctx:text({ title = "New achievement", label = "Letters and digits", subtitle = "Short id for the quest", raw = true, max = 30, allowed = "^[%w_]$" })
  if not id then return end
  id = id:lower()
  if existing[id] then
    ctx:message("Already there", { "An achievement called " .. id .. " exists. Open it from the list to edit it." }, "warn")
    return
  end
  local label = ctx:text({ title = "Name", label = "_ is a space", subtitle = "What players see", max = 40 })
  if not label then return end
  local bounty = Core.keypad(ctx, { title = "Bounty", label = "Pay for the quest", kind = "money", allow_zero = true, subtitle = label })
  if not bounty then return end
  local once = ctx:choose("How often", { { label = "ONE TIME", id = "once", kind = "panel" }, { label = "CAN REPEAT", id = "repeat", kind = "panel" } }, { subtitle = label })
  if not once then return end
  local lines = { "Add " .. label .. " (" .. id .. ")?", "Pay " .. util.money(bounty) .. ", " .. (once == "once" and "one time only." or "can repeat.") }
  if not ctx:confirm("New achievement", lines, { yes = "ADD" }) then return end
  if ctx:call("admin_set_catalog_item", { id = id, label = label, bounty = bounty, once = once == "once" }) then ctx:say("Achievement added") end
end

local function item_menu(ctx, it)
  local opts = {
    { label = "EDIT BOUNTY", id = "bounty", kind = "panel" },
    { label = "RENAME", id = "rename", kind = "panel" },
    { label = it.once and "MAKE REPEATABLE" or "MAKE ONE TIME", id = "once", kind = "panel" },
    { label = "REMOVE", id = "remove", kind = "danger" },
  }
  local id = ctx:choose(it.label, opts, { subtitle = util.money(it.bounty) .. (it.once and ", one time" or ", can repeat") })
  if id == "bounty" then
    local v = Core.keypad(ctx, { title = "Bounty", label = "Pay for the quest", kind = "money", allow_zero = true, subtitle = it.label .. " now " .. util.money(it.bounty) })
    if v and v ~= it.bounty and ctx:confirm("Change bounty", { it.label, "Now " .. util.money(it.bounty), "New " .. util.money(v) }, { yes = "SAVE" }) and ctx:call("admin_set_catalog_item", { id = it.id, bounty = v }) then ctx:say("Bounty saved") end
  elseif id == "rename" then
    local t = ctx:text({ title = "Name", label = "_ is a space", subtitle = "What players see", initial = it.label, max = 40 })
    if t and t ~= it.label and ctx:call("admin_set_catalog_item", { id = it.id, label = t }) then ctx:say("Renamed") end
  elseif id == "once" then
    if ctx:call("admin_set_catalog_item", { id = it.id, once = not it.once }) then ctx:say(it.once and "Now repeatable" or "Now one time") end
  elseif id == "remove" then
    if ctx:confirm("Remove achievement", { "Remove " .. it.label .. " from the catalog?", "Players can no longer claim it." }, { yes = "REMOVE", danger = true }) and ctx:call("admin_set_catalog_item", { id = it.id, remove = true }) then ctx:say("Removed") end
  end
end

local function catalog(ctx)
  local st = { offset = 0 }
  while true do
    local r = ctx:call("list_catalog")
    if not r then return end
    local rows, existing = {}, {}
    for i, it in ipairs(r.catalog) do
      existing[it.id] = true
      rows[#rows + 1] = { left = it.label .. (it.once and "" or " (repeats)"), right = util.money(it.bounty), id = "i" .. i, data = it }
    end
    local id, it = Core.list(ctx, { title = "Catalog", subtitle = string.format("%.0f achievements", #r.catalog), rows = rows, state = st, empty = "The catalog is empty",
      buttons = { { label = "ADD", id = "add", kind = "primary" } } })
    if not id then return end
    if id == "add" then add_item(ctx, existing) else item_menu(ctx, it) end
  end
end

function M.run(ctx)
  local counts
  local function load()
    local c, bad = ctx:queue_counts()
    if not c then ctx:fail(bad); return false end
    counts = c
    return true
  end
  if not load() then return end
  while true do
    local id = Core.menu(ctx, {
      title = "Review queue", subtitle = "Things waiting for staff",
      items = function()
        return {
          { label = "CLAIMS", id = "claims", kind = counts.claims > 0 and "success" or "primary", badge = counts.claims },
          { label = "APPLICATIONS", short = "CIVIC", id = "civic", kind = counts.civic > 0 and "success" or "primary", badge = counts.civic },
          { label = "FARM FLAGS", short = "FLAGS", id = "flags", kind = counts.flags > 0 and "success" or "primary", badge = counts.flags },
          { label = "CATALOG", id = "catalog", kind = "secondary", sub = "Bounties" },
        }
      end,
    })
    if not id then return end
    if id == "claims" then claims(ctx)
    elseif id == "civic" then civic(ctx)
    elseif id == "flags" then flags(ctx)
    elseif id == "catalog" then catalog(ctx) end
    if not load() then return end
  end
end

return M
