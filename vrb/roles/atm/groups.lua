local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local pay = require("roles.atm.pay")
local util = require("lib.util")
local theme = require("ui.theme")

local G = {}

local function create_faction(ctx)
  local name = ui.text(ctx, { title = "New faction", label = "Faction name (3 to 40)", max = 40, free = true })
  if not name then return end
  if #name < 3 then return ctx:say("New faction", { "The name needs at least 3 letters." }, "error") end
  local m = ui.number(ctx, "Members", 2, "Members in the faction")
  if not m then return end
  m = tonumber(m)
  local n = ui.number(ctx, "Approvals needed", 2, "Approvals per payment")
  if not n then return end
  n = tonumber(n)
  if m < 1 or n < 1 or n > m then return ctx:say("New faction", { "Approvals must be at least 1 and", "no more than the members." }, "error") end
  local lines = { name, string.format("%.0f of %.0f members must approve each payment.", n, m), "You become the founder." }
  if not ui.confirm(ctx, "Create faction", lines, "CREATE") then return end
  local res = ctx:call("create_faction", { name = name, n = n, m = m })
  if not res.ok then return ctx:fail(res, "Not created", true) end
  ctx:say("Faction created", { "Treasury account:", res.treasury_id, "Anyone can pay into it." }, "ok")
end

local function propose(ctx, fac)
  local payee = pay.pick_payee(ctx, "Pay out from " .. util.ellipsis(fac.name, 14))
  if not payee then return end
  if fac.balance <= 0 then return ctx:say("Faction", { "The treasury is empty." }, "warn") end
  local amount = ui.amount(ctx, "Pay " .. util.ellipsis(payee.owner, 16), fac.balance)
  if not amount then return end
  local ok, memo = pay.ask_memo(ctx, "Add a note?")
  if not ok then return end
  local lines = { "From " .. fac.name, "To " .. payee.owner, "Amount: " .. util.money(amount), string.format("Needs %.0f approvals.", fac.n) }
  if not ui.confirm(ctx, "Propose payment", lines, "PROPOSE") then return end
  local res = ctx:call("transfer", { target_id = payee.id, amount = amount, memo = memo, from_faction = fac.id })
  if not res.ok then return ctx:fail(res, "Not proposed", true) end
  if res.executed then
    ctx:say("Payment sent", { "The treasury paid " .. util.money(amount) .. "." }, "ok")
  else
    ctx:say("Waiting for approval", { string.format("Needs %.0f more approvals.", res.needs_approvals or 0), "Other members can approve it", "under PENDING." }, "ok")
  end
end

local function member_name(ctx, title, label)
  local who = ui.text(ctx, { title = title, label = label, max = 32 })
  if who and #who < 2 then ctx:say(title, { "Usernames have at least 2 letters." }, "error"); return nil end
  return who
end

local function faction_page(ctx, fac)
  while true do
    local rows = {
      { left = "Balance", right = util.money(fac.balance), rcolor = theme.good },
      { left = "Account", right = fac.treasury },
      { left = "Approvals needed", right = string.format("%.0f of %.0f", fac.n, fac.m) },
      { left = "Your role", right = fac.role },
      { blank = true },
      { head = "Members" },
    }
    for _, name in ipairs(fac.members or {}) do rows[#rows + 1] = { left = name } end
    local buttons = { { label = "PAY OUT", id = "pay", kind = "success" } }
    if fac.role == "founder" then
      buttons[2] = { label = "ADD", id = "add" }
      buttons[3] = { label = "REMOVE", id = "remove", kind = "danger" }
    end
    local kind, id = ui.list(ctx, { title = fac.name, sub = "Pay in by account number", rows = rows, buttons = buttons })
    if kind ~= "btn" then return end
    if id == "pay" then propose(ctx, fac)
    elseif id == "add" then
      local who = member_name(ctx, "Add member", "Username to add")
      if who then
        local res = ctx:call("faction_add_member", { faction_id = fac.id, member = who })
        if not res.ok then ctx:fail(res, "Not added", true) else ctx:toast(who .. " added", "ok"); return end
      end
    else
      local opts = {}
      for _, name in ipairs(fac.members or {}) do
        opts[#opts + 1] = { label = name, id = name, kind = "panel" }
      end
      local who = ui.choose(ctx, "Remove who?", opts)
      if who and ui.confirm(ctx, "Remove member", { "Remove " .. who .. " from " .. fac.name .. "?" }, "REMOVE", true) then
        local res = ctx:call("faction_remove_member", { faction_id = fac.id, member = who })
        if not res.ok then ctx:fail(res, "Not removed", true) else ctx:toast(who .. " removed", "ok"); return end
      end
    end
  end
end

local function pending_page(ctx, roles)
  while true do
    local res = ctx:call("list_pending_tx", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, p in ipairs(res.pending) do
      local sub = string.format("%.0f of %.0f approved", p.approvals or 0, p.required or 0)
      if p.you_approved then sub = sub .. ", including you" end
      rows[#rows + 1] = { left = p.faction_name, right = util.money(p.amount), sub = sub, id = p.id, data = p }
    end
    local kind, _, p = ui.list(ctx, { title = "Pending payments", sub = "Touch one to approve it", rows = rows, empty = "Nothing waiting", hint = "No payments need a vote" })
    if kind ~= "row" then return end
    local opts = {}
    if not p.you_approved then opts[#opts + 1] = { label = "APPROVE", id = "approve", kind = "success", sub = util.money(p.amount) } end
    if roles[p.faction_id] == "founder" then opts[#opts + 1] = { label = "CANCEL PAYMENT", id = "cancel", kind = "danger" } end
    if #opts == 0 then
      ctx:say("Pending payment", { "You already approved this one." }, "info")
    else
      local note = (p.memo and p.memo ~= "") and p.memo or nil
      if p.you_approved then note = "You already approved this one" end
      local pick = ui.choose(ctx, p.faction_name, opts, note)
      if pick == "approve" then
        local a = ctx:call("approve_pending_tx", { pending_id = p.id })
        if not a.ok then ctx:fail(a, "Not approved", true)
        elseif a.executed then ctx:say("Payment sent", { "Enough members approved.", "The payment went through." }, "ok")
        else ctx:say("Approved", { string.format("%.0f of %.0f approvals so far.", a.approvals or 0, a.required or 0) }, "ok") end
      elseif pick == "cancel" then
        local c = ctx:call("cancel_pending_tx", { pending_id = p.id })
        if not c.ok then ctx:fail(c, "Not cancelled", true) else ctx:toast("Payment cancelled", "ok") end
      end
    end
  end
end

function G.factions(ctx)
  while true do
    local res = ctx:call("list_factions", {})
    if not res.ok then return ctx:fail(res) end
    local rows, roles = {}, {}
    for _, f in ipairs(res.factions) do
      roles[f.id] = f.role
      rows[#rows + 1] = { left = f.name, right = util.money(f.balance or 0), rcolor = theme.good,
        sub = string.format("%s, %.0f of %.0f approve", f.role, f.n or 0, f.m or 0), id = f.id, data = f }
    end
    local kind, id, data = ui.list(ctx, { title = "Factions", sub = "Shared treasuries", rows = rows, empty = "No factions yet", hint = "Charter one with NEW",
      buttons = { { label = "NEW", id = "new", kind = "success" }, { label = "PENDING", id = "pending" } } })
    if not kind then return end
    if kind == "row" then faction_page(ctx, data)
    elseif id == "new" then create_faction(ctx)
    else pending_page(ctx, roles) end
  end
end

local function new_recurring(ctx)
  local payee = pay.pick_payee(ctx, "Pay who each time?")
  if not payee then return end
  local amount = ui.amount(ctx, "Each payment")
  if not amount then return end
  local unit = ui.choose(ctx, "How often?", {
    { label = "EVERY FEW HOURS", id = 3600, kind = "panel" },
    { label = "EVERY FEW DAYS", id = 86400, kind = "primary" },
  })
  if not unit then return end
  local every = ui.number(ctx, unit == 3600 and "Hours between" or "Days between", 3, "Whole number, 1 or more")
  if not every then return end
  every = tonumber(every)
  if every < 1 then return ctx:say("Scheduled payment", { "Use 1 or more." }, "error") end
  local times = ui.number(ctx, "How many payments", 3, "1 to 365")
  if not times then return end
  times = tonumber(times)
  if times < 1 or times > 365 then return ctx:say("Scheduled payment", { "Pick a number from 1 to 365." }, "error") end
  local ok, memo = pay.ask_memo(ctx, "Add a note?")
  if not ok then return end
  local sec = every * unit
  local lines = { "Pay " .. payee.owner .. " " .. util.money(amount), fmt.every(sec) .. ", " .. fmt.plural(times, "time") .. ".", "First one is one interval from now." }
  if not ui.confirm(ctx, "Schedule payments", lines, "SCHEDULE") then return end
  local res = ctx:call("create_recurring", { target_id = payee.id, amount = amount, interval_sec = sec, remaining = times, memo = memo })
  if not res.ok then return ctx:fail(res, "Not scheduled", true) end
  ctx:say("Scheduled", { "Your payments are set up.", "You can cancel them here any time." }, "ok")
end

function G.scheduled(ctx)
  while true do
    local res = ctx:call("list_my_recurring", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, r in ipairs(res.recurring) do
      rows[#rows + 1] = { left = "To " .. r.to, right = util.money(r.amount), sub = string.format("%s, %.0f left, next %s", fmt.every(r.interval_sec), r.remaining or 0, fmt.short(r.next_run or 0)), id = r.id, data = r }
    end
    local kind, _, data = ui.list(ctx, { title = "Scheduled payments", sub = "Touch one to cancel it", rows = rows, empty = "Nothing scheduled", hint = "Set one up with NEW",
      buttons = { { label = "NEW", id = "new", kind = "success" } } })
    if not kind then return end
    if kind == "btn" then new_recurring(ctx)
    elseif ui.confirm(ctx, "Cancel payments", { "Stop paying " .. data.to .. " " .. util.money(data.amount) .. " " .. fmt.every(data.interval_sec) .. "?" }, "STOP", true) then
      local c = ctx:call("cancel_recurring", { recur_id = data.id })
      if not c.ok then ctx:fail(c, "Not cancelled", true) else ctx:toast("Payments stopped", "ok") end
    end
  end
end

local function new_escrow(ctx)
  if not ctx:fresh() then return end
  local payee = pay.pick_payee(ctx, "Escrow with who?")
  if not payee then return end
  local bal = ctx:checking()
  if bal <= 0 then return ctx:say("Escrow", { "Your checking account is empty." }, "warn") end
  local amount = ui.amount(ctx, "Hold for " .. util.ellipsis(payee.owner, 14), bal)
  if not amount then return end
  local ok, memo = pay.ask_memo(ctx, "Add a note?")
  if not ok then return end
  local lines = { "Hold " .. util.money(amount), "for " .. payee.owner .. ".", "You release it when the deal is done.", "They can send it back." }
  if not ui.confirm(ctx, "Start escrow", lines, "HOLD") then return end
  local res = ctx:call("create_escrow", { counterparty = payee.id, amount = amount, memo = memo })
  if not res.ok then return ctx:fail(res, "Not held", true) end
  ctx:say("Escrow started", { util.money(amount) .. " is held.", "Escrow " .. res.escrow_id }, "ok")
end

function G.escrow(ctx)
  while true do
    local res = ctx:call("list_my_escrows", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, e in ipairs(res.escrows) do
      local sender = e.you_are == "sender"
      local sub = sender and "You hold it. Touch to release." or "Touch to send it back."
      if e.memo and e.memo ~= "" then sub = e.memo .. ". " .. sub end
      rows[#rows + 1] = { left = (sender and "To " or "From ") .. (sender and e.to or e.from), right = util.money(e.amount), sub = sub, id = e.id, data = e }
    end
    local kind, _, data = ui.list(ctx, { title = "Escrow", sub = "Money held for a deal", rows = rows, empty = "No escrows", hint = "Start one with NEW",
      buttons = { { label = "NEW", id = "new", kind = "success" } } })
    if not kind then return end
    if kind == "btn" then new_escrow(ctx)
    elseif data.you_are == "sender" then
      if ui.confirm(ctx, "Release escrow", { "Pay " .. util.money(data.amount) .. " to " .. data.to .. "?", "Tax applies. This cannot be undone." }, "RELEASE") then
        local r = ctx:call("release_escrow", { escrow_id = data.id })
        if not r.ok then ctx:fail(r, "Not released", true) else ctx:say("Released", { "The money went to " .. data.to .. "." }, "ok") end
      end
    elseif ui.confirm(ctx, "Send back", { "Return " .. util.money(data.amount) .. " to " .. data.from .. "?" }, "SEND BACK", true) then
      local r = ctx:call("refund_escrow", { escrow_id = data.id })
      if not r.ok then ctx:fail(r, "Not sent back", true) else ctx:say("Sent back", { "The money returned to " .. data.from .. "." }, "ok") end
    end
  end
end

return G
