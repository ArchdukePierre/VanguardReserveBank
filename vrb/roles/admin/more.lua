local util = require("lib.util")
local Core = require("roles.admin.core")

local M = {}

local function factions(ctx)
  local r = ctx:call("admin_list_factions")
  if not r then return end
  local st = { offset = 0 }
  while true do
    local rows = {}
    for i, f in ipairs(r.factions) do rows[#rows + 1] = { left = f.name .. " (" .. util.int(f.members) .. ")", right = util.money(f.treasury_balance), id = "f" .. i, data = f } end
    local id, f = Core.list(ctx, { title = "Factions", subtitle = string.format("%.0f chartered", #r.factions), rows = rows, state = st, empty = "No factions yet" })
    if not id then return end
    ctx:message(f.name, { Core.n(f.members, "member"), "Votes needed " .. tostring(f.threshold), "Treasury " .. f.treasury, "Balance " .. util.money(f.treasury_balance) })
  end
end

local function recurring(ctx)
  local st = { offset = 0 }
  while true do
    local r = ctx:call("admin_list_recurring")
    if not r then return end
    local rows = {}
    for i, p in ipairs(r.recurring) do rows[#rows + 1] = { left = tostring(p.from) .. " > " .. tostring(p.to), right = util.money(p.amount), id = "p" .. i, data = p } end
    local id, p = Core.list(ctx, { title = "Recurring payments", subtitle = string.format("%.0f active", #r.recurring), rows = rows, state = st, empty = "No recurring payments" })
    if not id then return end
    local lines = { "From " .. tostring(p.from), "To " .. tostring(p.to), util.money(p.amount) .. " every " .. util.duration(p.interval_sec), string.format("%.0f payments left", p.remaining or 0) }
    if p.memo and p.memo ~= "" then lines[#lines + 1] = "Memo: " .. p.memo end
    if ctx:confirm("Cancel payment", lines, { yes = "CANCEL IT", no = "KEEP IT", danger = true }) then
      if ctx:call("admin_cancel_recurring", { recur_id = p.id }) then ctx:say("Payment cancelled") end
    end
  end
end

local function shops(ctx)
  local raw = ctx:text({ title = "Close a shop", label = "Shop code", subtitle = "_ is the dash", raw = true, max = 20, allowed = "^[%w_%-]$" })
  if not raw then return end
  local id = (raw:upper():gsub("_", "-"))
  local r = ctx:call("get_shop", { shop_id = id })
  if not r then return end
  local reason = ctx:reason("Why close it", { "Rule break", "Scam report", "Owner asked", "Other reason" }, 3)
  if not reason then return end
  local lines = { "Close the shop " .. r.shop.label .. " of " .. r.shop.owner .. "?", "Buyers can no longer see or use it.", "Reason: " .. reason }
  if not ctx:confirm("Close shop", lines, { yes = "CLOSE", danger = true }) then return end
  if ctx:call("admin_deactivate_shop", { shop_id = id, reason = reason }) then ctx:say("Shop closed") end
end

local function note(ctx)
  local acct = ctx:pick_account("Reserve Note for")
  if acct then require("roles.admin.accounts").issue_note(ctx, acct) end
end

local function payroll(ctx)
  local day = os.day()
  local lines = { "Pay Vanguard and civic salaries for day " .. util.int(day) .. "?", "Each day is paid once. Income tax applies." }
  if not ctx:confirm("Pay salaries", lines, { yes = "PAY" }) then return end
  local r = ctx:call("admin_day_tick", { mc_day = day })
  if not r then return end
  if r.paid_already then
    if not ctx:confirm("Already paid", { "Salaries for day " .. util.int(day) .. " were already paid.", "Pay them again?" }, { yes = "PAY AGAIN", danger = true }) then return end
    r = ctx:call("admin_day_tick", { mc_day = day, force = true })
    if not r then return end
  end
  ctx:message("Salaries paid", {
    string.format("Vanguard: %.0f paid, %s", r.payroll_count, util.money(r.payroll_total)),
    string.format("Civic: %.0f paid, %s", r.civic_count, util.money(r.civic_total)),
  }, "ok")
end

function M.run(ctx)
  local diag = require("roles.admin.diag")
  while true do
    local id = Core.menu(ctx, {
      title = "More tools", subtitle = "Backup, audit, notes and more",
      items = function()
        return {
          { label = "FACTIONS", id = "factions", kind = "primary", sub = "Treasuries" },
          { label = "RECURRING", id = "recurring", kind = "primary", sub = "Payments" },
          { label = "SHOPS", id = "shops", kind = "primary", sub = "Close one" },
          { label = "ISSUE NOTE", id = "note", kind = "primary", sub = "Notes" },
          { label = "PAY SALARIES", short = "SALARIES", id = "payroll", kind = "primary", sub = "Day tick" },
          { label = "BACKUP", id = "backup", kind = "success", sub = "Copy data" },
          { label = "AUDIT", id = "audit", kind = "secondary", sub = "Check sums" },
        }
      end,
    })
    if not id then return end
    if id == "factions" then factions(ctx)
    elseif id == "recurring" then recurring(ctx)
    elseif id == "shops" then shops(ctx)
    elseif id == "note" then note(ctx)
    elseif id == "payroll" then payroll(ctx)
    elseif id == "backup" then diag.backup(ctx)
    elseif id == "audit" then diag.audit(ctx) end
  end
end

return M
