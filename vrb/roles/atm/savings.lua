local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local util = require("lib.util")
local theme = require("ui.theme")

local S = {}

local TERMS = { { 30, "cd_mpr_30" }, { 90, "cd_mpr_90" }, { 180, "cd_mpr_180" } }

function S.move(ctx)
  if not ctx:ready() then return end
  local dir = ui.choose(ctx, "Move money", {
    { label = "CHECKING TO SAVINGS", id = "chk_to_sav", sub = "Saves it, earns interest", kind = "primary" },
    { label = "SAVINGS TO CHECKING", id = "sav_to_chk", sub = "Use your savings", kind = "success" },
  })
  if not dir then return end
  local sav, young = ctx:savings()
  local from_bal = dir == "chk_to_sav" and ctx:checking() or sav
  if from_bal <= 0 then
    return ctx:say("Move money", { dir == "chk_to_sav" and "Your checking account is empty." or "Your savings are empty." }, "warn")
  end
  local amount = ui.amount(ctx, dir == "chk_to_sav" and "To savings" or "To checking", from_bal)
  if not amount then return end
  local lines = { "Move " .. util.money(amount), dir == "chk_to_sav" and "From checking to savings." or "From savings to checking." }
  if dir == "sav_to_chk" and young > 0 and ctx.ping then
    local risky = math.min(young, amount)
    local tax = math.floor(risky * (ctx.ping.early_rate or 0))
    lines[#lines + 1] = string.format("Savings under %.0f days old pay %s tax. This can cost up to %s.", ctx.ping.early_days or 0, fmt.pct(ctx.ping.early_rate), util.money(tax))
  end
  if not ui.confirm(ctx, "Confirm move", lines, "MOVE") then return end
  local res = ctx:call("move_internal", { amount = amount, direction = dir })
  if not res.ok then return ctx:fail(res, "Not moved", true) end
  local out = { "Checking: " .. util.money(res.checking or 0), "Savings: " .. util.money(res.savings or 0) }
  if (res.tax or 0) > 0 then table.insert(out, 1, "Early tax taken: " .. util.money(res.tax)) end
  ctx:say("Money moved", out, "ok")
end

local function open_cd(ctx)
  if not ctx:ready() then return end
  local bal = ctx:checking()
  if bal <= 0 then return ctx:say("New CD", { "Your checking account is empty." }, "warn") end
  local amount = ui.amount(ctx, "Lock away", bal)
  if not amount then return end
  local options = {}
  for _, t in ipairs(TERMS) do
    options[#options + 1] = { label = fmt.plural(t[1], "day"):upper(), id = t[1], sub = fmt.pct(ctx:rate(t[2])) .. " a month", kind = "panel" }
  end
  local days = ui.choose(ctx, "How long?", options, "Longer terms pay more")
  if not days then return end
  local rate
  for _, t in ipairs(TERMS) do if t[1] == days then rate = ctx:rate(t[2]) end end
  local lines = { "Lock " .. util.money(amount), "for " .. fmt.plural(days, "day") .. " at " .. fmt.pct(rate) .. " a month.", "Taking it out early returns only 95%." }
  if not ui.confirm(ctx, "Open a CD", lines, "OPEN CD") then return end
  local res = ctx:call("open_cd", { amount = amount, days = days })
  if not res.ok then return ctx:fail(res, "CD not opened", true) end
  ctx:say("CD opened", { "Your CD number is " .. res.cd_id .. ".", "Checking: " .. util.money(res.balance or 0) }, "ok")
end

local function estimate_cd(ctx, cd)
  local month = (ctx.ping and ctx.ping.month_sec) or (30 * 86400)
  local months = (util.now() - cd.opened) / month
  return math.floor(cd.principal * ((1 + cd.mpr) ^ months))
end

local function redeem_cd(ctx, cd)
  local matured = util.now() >= cd.matures
  local lines
  if matured then
    lines = { "This CD is ready.", "You get about " .. util.money(estimate_cd(ctx, cd)) .. "." }
  else
    lines = { "Not ready yet. It matures in " .. fmt.plural(fmt.days_until(cd.matures), "day") .. ".",
      "Cashing in now returns about " .. util.money(math.floor(cd.principal * 0.95)) .. ", a 5% penalty." }
  end
  if not ui.confirm(ctx, "Cash in CD", lines, matured and "CASH IN" or "CASH IN EARLY", not matured) then return end
  local res = ctx:call("redeem_cd", { cd_id = cd.id })
  if not res.ok then return ctx:fail(res, "Not cashed in", true) end
  ctx:say("CD cashed in", { "You received " .. util.money(res.payout or 0) .. ".", "Checking: " .. util.money(res.balance or 0) }, "ok")
end

function S.cds(ctx)
  while true do
    local res = ctx:call("list_cds", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, c in ipairs(res.cds) do
      local matured = util.now() >= c.matures
      rows[#rows + 1] = { left = util.money(c.principal), right = matured and "Ready" or fmt.plural(fmt.days_until(c.matures), "day"), rcolor = matured and theme.good or theme.accent,
        sub = fmt.pct(c.mpr) .. " a month, matures " .. fmt.day(c.matures), id = c.id, data = c }
    end
    local kind, id, data = ui.list(ctx, { title = "Your CDs", sub = "Touch a CD to cash it in", rows = rows, empty = "No CDs yet", hint = "CDs pay a higher rate",
      buttons = { { label = "NEW CD", id = "new", kind = "success" } } })
    if not kind then return end
    if kind == "btn" then open_cd(ctx) else redeem_cd(ctx, data) end
  end
end

local function new_loan(ctx)
  if not ctx:ready() then return end
  local amount = ui.amount(ctx, "Borrow")
  if not amount then return end
  local need = math.floor(amount * ctx:rate("min_loan_col"))
  if ctx:checking() < need then
    return ctx:say("Not enough collateral", { "You must hold " .. util.money(need) .. " in checking", "to borrow " .. util.money(amount) .. ".", "That is " .. fmt.pct(ctx:rate("min_loan_col")) .. " of the loan." }, "warn")
  end
  local lines = { "Borrow " .. util.money(amount), "Keep " .. util.money(need) .. " in checking (" .. fmt.pct(ctx:rate("min_loan_col")) .. ").", "Interest: " .. fmt.pct(ctx:rate("loan_mpr")) .. " a month." }
  if not ui.confirm(ctx, "Confirm loan", lines, "BORROW") then return end
  local res = ctx:call("request_loan", { amount = amount })
  if not res.ok then return ctx:fail(res, "No loan", true) end
  ctx:say("Loan paid out", { "Loan number " .. res.loan_id, "Checking: " .. util.money(res.balance or 0) }, "ok")
end

local function repay(ctx, loan)
  if not ctx:fresh() then return end
  local bal = ctx:checking()
  if bal <= 0 then return ctx:say("Repay", { "Your checking account is empty." }, "warn") end
  local cap = math.min(bal, loan.balance)
  local how = ui.choose(ctx, "Repay loan", {
    { label = "PAY " .. util.money(cap), id = "all", sub = cap >= loan.balance and "Pays off the loan" or "All you can pay now", kind = "success" },
    { label = "ENTER AN AMOUNT", id = "some", kind = "panel" },
  }, "Owed: " .. util.money(loan.balance))
  if not how then return end
  local amount = cap
  if how == "some" then
    amount = ui.amount(ctx, "Repay", cap)
    if not amount then return end
  end
  local res = ctx:call("repay_loan", { loan_id = loan.id, amount = amount })
  if not res.ok then return ctx:fail(res, "Not repaid", true) end
  local out = { "You paid " .. util.money(amount) .. ".", res.closed and "The loan is paid off." or ("Still owed: " .. util.money(res.loan_balance or 0)) }
  ctx:say("Loan payment", out, "ok")
end

function S.loans(ctx)
  while true do
    local res = ctx:call("list_loans", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, l in ipairs(res.loans) do
      rows[#rows + 1] = { left = "Loan " .. l.id:gsub("^LOAN%-", ""), right = util.money(l.balance), rcolor = theme.bad, sub = fmt.pct(l.mpr) .. " a month, opened " .. fmt.day(l.opened), id = l.id, data = l }
    end
    local kind, id, data = ui.list(ctx, { title = "Your loans", sub = "Touch a loan to repay it", rows = rows, empty = "No loans", hint = "You owe nothing",
      buttons = { { label = "NEW LOAN", id = "new", kind = "success" } } })
    if not kind then return end
    if kind == "btn" then new_loan(ctx) else repay(ctx, data) end
  end
end

function S.credit(ctx)
  while true do
    local id = ui.menu(ctx, { title = "CDs and loans", sub = "Save for more or borrow", items = {
      { label = "CDS", id = "cds", kind = "primary", sub = "Lock money for more" },
      { label = "LOANS", id = "loans", kind = "panel", sub = "Borrow or repay" },
    } })
    if not id then return end
    if id == "cds" then S.cds(ctx) else S.loans(ctx) end
  end
end

return S
