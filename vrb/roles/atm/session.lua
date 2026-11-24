local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local pay = require("roles.atm.pay")
local savings = require("roles.atm.savings")
local history = require("roles.atm.history")
local earn = require("roles.atm.earn")
local groups = require("roles.atm.groups")
local shops = require("roles.atm.shops")
local items = require("roles.atm.items")
local account = require("roles.atm.account")
local util = require("lib.util")
local kit = require("ui.kit")
local theme = require("ui.theme")

local S = {}

local HANDLERS = {
  pay = pay.send, bills = pay.bills, move = savings.move, history = history.show, credit = savings.credit, earn = earn.menu,
  factions = groups.factions, scheduled = groups.scheduled, escrow = groups.escrow, shops = shops.run, notes = items.menu, settings = account.menu,
}

local function menu_items()
  return {
    { label = "PAY", id = "pay", kind = "primary", sub = "Send money" },
    { label = "BILLS", id = "bills", kind = "primary", sub = "Request or pay a bill" },
    { label = "MOVE MONEY", id = "move", kind = "success", sub = "Checking and savings" },
    { label = "HISTORY", id = "history", kind = "panel", sub = "Recent activity" },
    { label = "CDS AND LOANS", id = "credit", kind = "panel", sub = "Save more or borrow" },
    { label = "EARN", id = "earn", kind = "panel", sub = "Pay, rewards and jobs" },
    { label = "FACTIONS", id = "factions", kind = "panel", sub = "Shared treasuries" },
    { label = "SCHEDULED", id = "scheduled", kind = "panel", sub = "Repeating payments" },
    { label = "ESCROW", id = "escrow", kind = "panel", sub = "Hold money for a deal" },
    { label = "SHOPS", id = "shops", kind = "panel", sub = "Your shop listings" },
  }
end

local function balances(ctx, s, y)
  local w = s.w - 2
  local p = ctx.profile
  if not p then
    kit.card(s, 2, y, w, 1)
    s:text(3, y, "Balances are not available right now.", theme.warn, theme.panel)
    return y + 2
  end
  local sav = p.savings
  local warn
  if sav and (sav.young_cents or 0) > 0 and ctx.ping then
    if s.w >= 39 then
      warn = string.format("%s of your savings is under %.0f days old. Moving it out early costs %s tax.", util.money(sav.young_cents), ctx.ping.early_days or 0, fmt.pct(ctx.ping.early_rate))
    else
      warn = string.format("%s is under %.0f days old. Early move: %s tax.", util.money(sav.young_cents), ctx.ping.early_days or 0, fmt.pct(ctx.ping.early_rate))
    end
  end
  local wrapped = warn and kit.wrap(warn, w - 2) or {}
  kit.card(s, 2, y, w, 2 + #wrapped)
  local wide = s.w >= 45
  local chk, sv = p.checking, sav
  kit.kv(s, 3, y, w - 2, wide and chk and ("Checking  " .. chk.id) or "Checking", util.money(chk and chk.balance or 0), theme.ink, theme.panel)
  kit.kv(s, 3, y + 1, w - 2, wide and sv and ("Savings   " .. sv.id) or "Savings", util.money(sv and sv.balance or 0), theme.ink, theme.panel)
  for i, line in ipairs(wrapped) do s:text(3, y + 1 + i, line, theme.warn, theme.panel) end
  return y + 3 + #wrapped
end

function S.run(ctx)
  while true do
    if ctx.dirty or not ctx.profile then ctx:refresh() end
    local list = menu_items()
    if items.available(ctx) then list[#list + 1] = { label = "NOTES AND ITEMS", id = "notes", kind = "panel", sub = "Redeem or deposit" } end
    list[#list + 1] = { label = "SETTINGS", id = "settings", kind = "panel", sub = "PIN, checks, messages" }
    local id = ui.menu(ctx, {
      title = "Welcome, " .. util.ellipsis(ctx.account and ctx.account.owner or "", 18), sub = "Touch what you want to do",
      top = function(s, y) return balances(ctx, s, y) end, items = list, back = "SIGN OUT", back_kind = "danger",
    })
    if not id then return end
    HANDLERS[id](ctx)
  end
end

return S
