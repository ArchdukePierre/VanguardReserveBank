local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local util = require("lib.util")
local theme = require("ui.theme")

local P = {}

local function interest(ctx)
  local res = ctx:pub("ping", {})
  if not res.ok then return ctx:fail(res) end
  ctx.ping = res
  local p = res.policy
  ui.list(ctx, { title = "Interest and fees", sub = "Interest is paid each month", rows = {
    { head = "Interest" },
    { left = "Checking", right = fmt.pct(p.chk_mpr) },
    { left = "Savings", right = fmt.pct(p.sav_mpr) },
    { left = "CD, 30 days", right = fmt.pct(p.cd_mpr_30) },
    { left = "CD, 90 days", right = fmt.pct(p.cd_mpr_90) },
    { left = "CD, 180 days", right = fmt.pct(p.cd_mpr_180) },
    { left = "Loans (you pay)", right = fmt.pct(p.loan_mpr), rcolor = theme.bad },
    { blank = true },
    { head = "Fees and rules" },
    { left = "Tax on payments", right = fmt.pct(p.tx_tax_rate) },
    { left = "Loan collateral", right = fmt.pct(p.min_loan_col) },
    { left = "Early savings tax", right = fmt.pct(res.early_rate) },
    { text = string.format("Early savings tax applies to savings moved out within %.0f days.", res.early_days or 0), color = theme.muted },
  } })
end

local function taxes(ctx)
  local res = ctx:pub("public_stats", {})
  if not res.ok then return ctx:fail(res) end
  local pol = res.stats.policy or {}
  local rows = { { text = "Income tax comes out of salaries. Bigger yearly pay pays a higher rate.", color = theme.muted }, { blank = true } }
  for _, b in ipairs(pol.tax_brackets or {}) do
    rows[#rows + 1] = { left = "From " .. util.money(b.above or 0) .. " a year", right = fmt.pct(b.rate) }
  end
  ui.list(ctx, { title = "Income tax", rows = rows, empty = "No tax brackets" })
end

local function values(ctx)
  local res = ctx:pub("item_rates", {})
  if not res.ok then return ctx:fail(res) end
  local rows = {}
  if res.enabled then
    for _, r in ipairs(res.rates) do rows[#rows + 1] = { left = fmt.item_name(r.item), right = util.money(r.rate) .. " each" } end
  end
  ui.list(ctx, { title = "Item values", sub = "Items behind the currency", rows = rows, empty = res.enabled and "No items listed" or "Item deposits are off" })
end

local function numbers(ctx)
  local res = ctx:pub("public_stats", {})
  if not res.ok then return ctx:fail(res) end
  local s = res.stats
  local pol = s.policy or {}
  local rows = {
    { left = "Accounts", right = string.format("%.0f", s.accounts or 0) },
    { left = "Active this week", right = string.format("%.0f", s.active_last_week or 0) },
    { left = "Money in the bank", right = util.money(s.supply or 0) },
    { left = "Loans out", right = util.money(s.loans_out or 0) },
    { left = "Open loans", right = string.format("%.0f", s.active_loans or 0) },
    { left = "Open shops", right = string.format("%.0f", s.active_shops or 0) },
    { left = "Factions", right = string.format("%.0f", s.factions or 0) },
    { left = "Payments made", right = string.format("%.0f", s.tx_count or 0) },
  }
  if pol.ubi_enabled then rows[#rows + 1] = { left = "Weekly dividend", right = util.money(pol.ubi_weekly or 0), rcolor = theme.good } end
  ui.list(ctx, { title = "Bank numbers", rows = rows })
end

local function activity(ctx)
  local res = ctx:pub("public_ledger_tail", { limit = 30 })
  if not res.ok then return ctx:fail(res) end
  local list = {}
  for _, e in ipairs(res.entries) do list[#list + 1] = e end
  table.sort(list, function(a, b) return (a.t or 0) > (b.t or 0) end)
  local rows = {}
  for _, e in ipairs(list) do
    local amount = e.amount or e.total or e.payout or e.bounty
    rows[#rows + 1] = { left = fmt.ledger_name(e.type), right = amount and util.money(math.abs(amount)) or nil, sub = fmt.short(e.t or 0) }
  end
  ui.list(ctx, { title = "Recent activity", sub = "Names are hidden", rows = rows, empty = "Nothing yet" })
end

function P.rates(ctx)
  while true do
    local id = ui.menu(ctx, { title = "Rates", sub = "What the bank pays or takes", items = {
      { label = "INTEREST AND FEES", id = "interest", kind = "primary", sub = "Savings, CDs, loans" },
      { label = "INCOME TAX", id = "taxes", kind = "panel", sub = "Tax brackets" },
      { label = "ITEM VALUES", id = "values", kind = "panel", sub = "What items are worth" },
      { label = "BANK NUMBERS", id = "numbers", kind = "panel", sub = "Money and accounts" },
      { label = "RECENT ACTIVITY", id = "activity", kind = "panel", sub = "Latest public events" },
    } })
    if not id then return end
    if id == "interest" then interest(ctx)
    elseif id == "taxes" then taxes(ctx)
    elseif id == "values" then values(ctx)
    elseif id == "numbers" then numbers(ctx)
    else activity(ctx) end
  end
end

function P.find(ctx)
  while true do
    local name = ui.text(ctx, { title = "Find a player", label = "Their exact username", max = 32 })
    if not name then return end
    if #name < 2 then
      ctx:say("Find a player", { "Usernames have at least 2 letters." }, "error")
    else
      local res = ctx:pub("lookup", { owner = name })
      if not res.ok then return ctx:fail(res) end
      local rows = {}
      for _, a in ipairs(res.accounts) do rows[#rows + 1] = { left = a.owner, right = a.id, sub = a.kind } end
      ui.list(ctx, { title = "Find a player", sub = "Use this number to pay them", rows = rows, empty = "No player found", hint = "Check the spelling" })
      return
    end
  end
end

return P
