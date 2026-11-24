local util = require("lib.util")

local F = {}

local TYPES = {
  transfer_out = "Payment sent", transfer_in = "Payment received",
  move_out = "Moved out", move_in = "Moved in",
  deposit = "Deposit", withdraw = "Withdrawal", interest = "Interest",
  cd_open = "CD opened", cd_redeem = "CD redeemed",
  loan_origin = "Loan paid out", loan_repay = "Loan payment",
  escrow_hold = "Escrow held", escrow_payout = "Escrow received", escrow_refund = "Escrow refunded",
  prq_pay_out = "Bill paid", prq_pay_in = "Bill received",
  faction_out = "Faction payment", faction_in = "Faction payment in",
  multisig_out = "Faction payment", multisig_in = "Faction payment in",
  recur_out = "Scheduled payment", recur_in = "Scheduled payment in",
  shop_buy = "Shop purchase", shop_sale = "Shop sale",
  item_deposit = "Items deposited", note_issue = "Note issued", note_redeem = "Note redeemed",
  earnings = "Daily earnings", insurance = "Insurance", progress_reward = "Reward",
  wo_payout = "Work order pay", salary = "Vanguard pay", civic_pay = "Civic pay",
  ubi = "Citizen dividend", tax_in = "Tax", issue = "Bank credit", admin_adjust = "Adjustment",
  farm_flag_override = "Earnings review", death_penalty = "Death penalty",
}

function F.type_name(t)
  local name = TYPES[t]
  if name then return name end
  local s = tostring(t or "entry"):gsub("_", " ")
  return s:sub(1, 1):upper() .. s:sub(2)
end

local LEDGER = {
  transfer = "Payment", deposit = "Deposit", withdraw = "Withdrawal", loan_origin = "Loan paid out", loan_repay = "Loan payment",
  cd_open = "CD opened", cd_redeem = "CD cashed in", interest = "Interest paid", ubi_payout = "Citizen dividend",
  policy_change = "Rates changed", auto_policy = "Rates adjusted", wo_post = "Work order posted", wo_complete = "Work order paid",
  progress_approve = "Reward paid", note_issue = "Note issued", note_redeem = "Note redeemed", faction_create = "Faction chartered",
  shop_sale = "Shop sale", item_deposit = "Items deposited", issue = "Money issued", admin_adjust = "Balance adjusted",
  multisig_execute = "Faction payment", earnings = "Daily earnings", earnings_tick = "Daily earnings run", death_penalty = "Death penalty",
  insurance_charge = "Insurance charged", insurance_lapse = "Insurance lapsed", salary = "Vanguard pay", payroll_tick = "Vanguard payday",
  rank_assign = "Rank given", rank_change = "Rank changed", rank_remove = "Rank removed", civic_pay = "Civic pay",
  civic_payroll_tick = "Civic payday", job_create = "Job created", job_assign = "Job given", job_remove = "Job removed",
}

function F.ledger_name(t)
  return LEDGER[t] or F.type_name(t)
end

function F.item_name(id)
  local s = tostring(id):gsub("^[^:]*:", ""):gsub("_", " ")
  return s:sub(1, 1):upper() .. s:sub(2)
end

function F.pct(x)
  local s = string.format("%.1f", (x or 0) * 100)
  s = s:gsub("%.0$", "")
  return s .. "%"
end

function F.signed(cents)
  if cents < 0 then return util.money(cents) end
  return "+" .. util.money(cents)
end

function F.when(t) return os.date("%Y-%m-%d %H:%M", t) end
function F.short(t) return os.date("%m-%d %H:%M", t) end
function F.day(t) return os.date("%Y-%m-%d", t) end

function F.date_num(n)
  local s = string.format("%.0f", n or 0)
  if #s ~= 8 then return s end
  return s:sub(1, 4) .. "-" .. s:sub(5, 6) .. "-" .. s:sub(7, 8)
end

function F.days_until(ts)
  return math.ceil((ts - util.now()) / 86400)
end

function F.plural(n, word)
  n = math.floor(n)
  return string.format("%.0f %s%s", n, word, n == 1 and "" or "s")
end

function F.every(sec)
  if sec % 86400 == 0 then return "every " .. F.plural(sec / 86400, "day") end
  return "every " .. F.plural(math.floor(sec / 3600), "hour")
end

return F
