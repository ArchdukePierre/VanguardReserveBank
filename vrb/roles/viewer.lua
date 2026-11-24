local App = require("ui.app")
local kit = require("ui.kit")
local theme = require("ui.theme")
local Client = require("lib.client")
local cfgmod = require("lib.cfg")
local util = require("lib.util")

local M = {}
local T = theme

local WAIT_SEC = 70
local WIDE = 50

local GOOD, COST, RULE, BAD = T.good, T.warn, T.info, T.bad
local EVENTS = {
  transfer = { "Transfer" }, deposit = { "Deposit", GOOD }, withdraw = { "Withdrawal", COST }, loan_origin = { "Loan issued", COST }, loan_repay = { "Loan repaid", GOOD },
  cd_open = { "Certificate opened" }, cd_redeem = { "Certificate redeemed" }, interest = { "Interest paid", GOOD }, ubi_payout = { "Basic income", GOOD },
  policy_change = { "Policy changed", RULE }, auto_policy = { "Policy adjusted", RULE }, wo_post = { "Work order posted", RULE }, wo_complete = { "Work order done", GOOD },
  progress_approve = { "Bounty approved", GOOD }, note_issue = { "Reserve note issued", COST }, note_redeem = { "Reserve note redeemed", GOOD },
  faction_create = { "Faction chartered", RULE }, shop_sale = { "Shop sale", GOOD }, item_deposit = { "Item deposit", GOOD }, issue = { "Money issued", COST },
  admin_adjust = { "Balance adjusted", RULE }, multisig_execute = { "Faction payment" }, earnings = { "Earnings paid", GOOD }, earnings_tick = { "Daily earnings run", GOOD },
  death_penalty = { "Streak penalty", BAD }, insurance_charge = { "Insurance charged", COST }, insurance_lapse = { "Insurance lapsed", BAD }, salary = { "Salary paid", GOOD },
  payroll_tick = { "Vanguard payroll", GOOD }, rank_assign = { "Rank assigned", RULE }, rank_change = { "Rank changed", RULE }, rank_remove = { "Rank removed", RULE },
  civic_pay = { "Civic pay", GOOD }, civic_payroll_tick = { "Civic payroll", GOOD }, job_create = { "Job created", RULE }, job_assign = { "Job filled", RULE }, job_remove = { "Job vacated", RULE },
}

local function commas(n)
  local s = string.format("%.0f", n or 0)
  local out = ""
  while #s > 3 do
    out = "," .. s:sub(-3) .. out
    s = s:sub(1, -4)
  end
  return s .. out
end

local function pct(v)
  if v == nil then return "--" end
  local s = string.format("%.2f", (v or 0) * 100):gsub("0+$", ""):gsub("%.$", "")
  return s .. "%"
end

local function short_money(cents)
  local d = (cents or 0) / 100
  local s
  if d >= 1000000 then
    s = string.format("%.1f", d / 1000000):gsub("%.0$", "") .. "M"
  elseif d >= 1000 then
    s = string.format("%.1f", d / 1000):gsub("%.0$", "") .. "k"
  else
    s = string.format("%.0f", d)
  end
  return "$" .. s
end

local function money(v) return v and util.money(v) or "--" end

local function describe(e)
  local info = EVENTS[e.type]
  local label = info and info[1] or tostring(e.type or "event"):gsub("_", " ")
  local extra = e.recipients or e.players
  if extra then label = label .. " (" .. commas(extra) .. ")" end
  local amount = e.amount or e.total or e.payout or e.bounty or e.delta
  return label, amount and util.money(amount) or "", info and info[2] or T.ink
end

local function stamp(t)
  if type(t) ~= "number" then return "--:--" end
  if os.date("%Y%m%d", t) == os.date("%Y%m%d") then return os.date("%H:%M", t) end
  return os.date("%m-%d", t)
end

local function title(s, x, y, w, text)
  s:fill(x, y, w, 1, T.panel)
  s:text(x + 1, y, text, T.accent, T.panel)
end

local function row(s, x, y, w, label, value, color)
  value = tostring(value)
  s:text(x, y, util.ellipsis(label, math.max(1, w - #value - 1)), T.muted)
  s:text(x + w - #value, y, value, color or T.ink)
end

local function economy(s, x, y, w, st)
  title(s, x, y, w, "ECONOMY")
  st = st or {}
  row(s, x, y + 1, w, "Money supply", money(st.supply), T.accent)
  row(s, x, y + 2, w, "Accounts", st.accounts and commas(st.accounts) or "--")
  row(s, x, y + 3, w, "Active this week", st.active_last_week and commas(st.active_last_week) or "--", T.good)
  row(s, x, y + 4, w, "Transactions", st.tx_count and commas(st.tx_count) or "--")
  row(s, x, y + 5, w, "Loans out", money(st.loans_out), T.warn)
  return 6
end

local function rate_items(pol, compact)
  return {
    { compact and "Save" or "Savings", pol.sav_mpr and (pct(pol.sav_mpr) .. "/mo") or "--" },
    { compact and "Check" or "Checking", pol.chk_mpr and (pct(pol.chk_mpr) .. "/mo") or "--" },
    { "Loan", pol.loan_mpr and (pct(pol.loan_mpr) .. "/mo") or "--" },
    { compact and "Tx tax" or "Transaction tax", pct(pol.tx_tax_rate) },
  }
end

local function rates(s, x, y, w, st, compact)
  title(s, x, y, w, "RATES")
  local pol = st and st.policy or {}
  local items = rate_items(pol, compact)
  if not compact then
    for i, it in ipairs(items) do row(s, x, y + i, w, it[1], it[2]) end
    return 5
  end
  local cw = math.floor((w - 1) / 2)
  for i, it in ipairs(items) do
    local cx = x + ((i - 1) % 2) * (cw + 1)
    local text = it[1] .. " " .. it[2]
    s:text(cx, y + 1 + math.floor((i - 1) / 2), util.ellipsis(text, cw), T.ink)
  end
  return 3
end

local function tax_rows(n, cols) return 1 + math.ceil(n / cols) end

local function tax(s, x, y, w, st, cols)
  title(s, x, y, w, "INCOME TAX")
  local brackets = st and st.policy and st.policy.tax_brackets or {}
  local per = math.ceil(#brackets / cols)
  local cw = math.floor((w - (cols - 1)) / cols)
  for i, b in ipairs(brackets) do
    local col, r = math.floor((i - 1) / per), (i - 1) % per
    local cx = x + col * (cw + 1)
    local label, rate = short_money(b.above) .. "+", pct(b.rate)
    s:text(cx, y + 1 + r, label, T.muted)
    s:text(cx + cw - #rate, y + 1 + r, rate, T.ink)
  end
  if #brackets == 0 then s:text(x, y + 1, "--", T.muted) end
  return tax_rows(#brackets, cols)
end

local function feed(s, x, y, w, h, entries)
  if h < 2 then return end
  title(s, x, y, w, "RECENT ACTIVITY")
  local rows = h - 1
  if #entries == 0 then
    if rows > 0 then s:text(x, y + 1, "No activity yet", T.muted) end
    return
  end
  local shown, stamps = {}, true
  for i = 1, math.min(rows, #entries) do
    local e = entries[#entries - i + 1]
    local label, amount, color = describe(e)
    shown[i] = { stamp = stamp(e.t), label = label, amount = amount, color = color }
    if #shown[i].stamp + 1 + #label + #amount + 1 > w then stamps = false end
  end
  for i, r in ipairs(shown) do
    local yy = y + i
    if i % 2 == 0 then s:fill(x, yy, w, 1, colors.black) end
    local left = stamps and (r.stamp .. " " .. r.label) or r.label
    s:text(x, yy, util.ellipsis(left, math.max(1, w - #r.amount - 1)), r.color)
    s:text(x + w - #r.amount, yy, r.amount, T.ink)
  end
end

local function header(s, stale)
  if s.h >= 24 then
    kit.header(s, "Public ledger", "Economy at a glance")
    if stale then
      s:fill(1, 3, s.w, 1, T.warn)
      s:text(2, 3, "Waiting for the bank", colors.black, T.warn)
    end
    return 4
  end
  local bg = stale and T.warn or T.panel
  s:fill(1, 1, s.w, 1, bg)
  if stale then
    s:text(2, 1, "Waiting for the bank", colors.black, bg)
  else
    s:text(2, 1, "VANGUARD RESERVE BANK", T.accent, bg)
  end
  return 1
end

local function layout(s, data, stale)
  local used = header(s, stale)
  local st = data and data.stats
  local entries = data and data.entries or {}
  local n = st and st.policy and st.policy.tax_brackets and #st.policy.tax_brackets or 0
  local top, avail = used + 1, s.h - used
  if s.w >= WIDE then
    local lw = math.max(26, math.floor((s.w - 3) / 2))
    local rx = 2 + lw + 1
    local rw = s.w - rx
    local y = top
    y = y + economy(s, 2, y, lw, st) + 1
    y = y + rates(s, 2, y, lw, st, false) + 1
    if s.h - y + 1 >= tax_rows(n, 1) then
      tax(s, 2, y, lw, st, 1)
      feed(s, rx, top, rw, avail, entries)
    else
      local used_rows = tax(s, rx, top, rw, st, 2)
      feed(s, rx, top + used_rows + 1, rw, avail - used_rows - 1, entries)
    end
    return
  end
  local w = s.w - 2
  local tr = tax_rows(n, 2)
  local compact = avail < 6 + 5 + tr + 3
  local rr = compact and 3 or 5
  local gaps = (avail >= 6 + rr + tr + 3 + 3) and 1 or 0
  local y = top
  y = y + economy(s, 2, y, w, st) + gaps
  y = y + rates(s, 2, y, w, st, compact) + gaps
  y = y + tax(s, 2, y, w, st, 2) + gaps
  feed(s, 2, y, w, s.h - y + 1, entries)
end

local function find_monitor()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then return peripheral.wrap(name), name end
  end
end

local function fatal(lines)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  for _, l in ipairs(lines) do print(l) end
end

function M.run()
  if not cfgmod.read_key("server.secret") then
    return fatal({ "VIEWER: no bank key", "", "server.secret is missing.", "Copy it to /.vrb/keys and", "start this computer again." })
  end
  local client, why = Client.new({})
  if not client then return fatal({ "VIEWER: network problem", "", tostring(why) }) end
  local mon, name = find_monitor()
  local app = App.new({ surface = mon, name = name, scale = true })
  local S = { stale = true }

  local function draw(s) layout(s, S.data, S.stale) end

  local function show()
    local w, h = app.target.getSize()
    if w ~= app.s.w or h ~= app.s.h then
      if mon then theme.fit(mon) end
      app.s:resize()
      app.s:invalidate()
    end
    app:show(draw)
  end

  local function fetch()
    local opts = { timeout = 3, retries = 1 }
    local a = client:call("public_stats", {}, opts)
    local b = client:call("public_ledger_tail", { limit = 24 }, opts)
    if a.ok and b.ok then
      S.data = { stats = a.stats, entries = b.entries or {} }
      S.stale = false
    else
      S.stale = true
    end
  end

  client:open_broadcast()
  show()
  fetch()
  show()
  while true do
    local p = client:wait_broadcast(WAIT_SEC)
    if p == nil then
      fetch()
    elseif type(p.stats) == "table" then
      S.data = { stats = p.stats, entries = type(p.entries) == "table" and p.entries or {} }
      S.stale = false
    end
    show()
  end
end

return M
