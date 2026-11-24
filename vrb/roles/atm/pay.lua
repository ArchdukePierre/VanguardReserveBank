local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local util = require("lib.util")
local theme = require("ui.theme")

local P = {}

function P.pick_payee(ctx, title)
  local q, offset = "", 0
  local labels = { "\27 BACK", "FIND", "PREV", "NEXT" }
  while true do
    local per = ui.capacity(ctx, labels)
    local res = ctx:call("list_payable_accounts", { q = q ~= "" and q or nil, offset = offset, limit = per })
    if not res.ok then ctx:fail(res); return nil end
    if #res.accounts == 0 and offset > 0 then
      offset = 0
    else
      local rows = {}
      for _, a in ipairs(res.accounts) do
        rows[#rows + 1] = { left = a.owner, detail = a.id, id = a.id, data = a }
      end
      local sub
      if res.total == 0 then
        sub = q ~= "" and ("No one matches " .. q) or "No other players yet"
      else
        sub = string.format("%.0f to %.0f of %.0f", offset + 1, offset + #res.accounts, res.total) .. (ctx.app.s.w >= 40 and ". Touch a name." or "")
      end
      local kind, id, data = ui.list(ctx, {
        title = title, sub = sub, rows = rows, empty = "No players found", hint = "Touch FIND to search",
        buttons = { { label = "FIND", id = "find", kind = "primary" }, { label = "PREV", id = "prev", disabled = offset == 0 },
          { label = "NEXT", id = "next", disabled = offset + #res.accounts >= res.total } },
      })
      if not kind then return nil end
      if kind == "row" then return data end
      if id == "find" then
        local t = ui.text(ctx, { title = "Find a player", label = "Part of the name", max = 32 })
        if t then q, offset = t, 0 end
      elseif id == "prev" then offset = math.max(0, offset - per)
      elseif id == "next" then offset = offset + per end
    end
  end
end

function P.ask_memo(ctx, title)
  local pick = ui.choose(ctx, title, {
    { label = "NO NOTE", id = "skip", kind = "primary" },
    { label = "ADD A NOTE", id = "add", sub = "A short message", kind = "panel" },
  })
  if not pick then return nil end
  if pick == "skip" then return true, nil end
  local t = ui.text(ctx, { title = "Add a note", label = "Up to 100 letters", max = 100, free = true })
  if not t then return nil end
  return true, t
end

function P.receipt(ctx, r)
  local can_print = ctx:find("printer") ~= nil
  while true do
    local rows = {}
    for _, kv in ipairs(r.rows) do rows[#rows + 1] = { left = kv[1], right = kv[2], rcolor = kv[3] or theme.ink } end
    local buttons = {}
    if can_print then buttons[1] = { label = "PRINT RECEIPT", id = "print" } end
    local kind, id = ui.list(ctx, { title = r.title, sub = fmt.when(util.now()), rows = rows, back = "DONE", buttons = buttons })
    if kind ~= "btn" then return end
    local lines = { "VANGUARD RESERVE BANK", r.title, fmt.when(util.now()), "" }
    for _, kv in ipairs(r.rows) do lines[#lines + 1] = kv[1] .. ": " .. kv[2] end
    local ok, err = ctx:print_lines("Receipt", lines)
    if ok then ctx:toast("Receipt printed", "ok") else ctx:say("Printing", { err }, "error") end
  end
end

function P.send(ctx)
  if not ctx:ready() then return end
  local payee = P.pick_payee(ctx, "Pay a player")
  if not payee then return end
  local bal = ctx:checking()
  if bal <= 0 then return ctx:say("Pay", { "Your checking account is empty." }, "warn") end
  local amount = ui.amount(ctx, "Pay " .. util.ellipsis(payee.owner, 16), bal)
  if not amount then return end
  local ok, memo = P.ask_memo(ctx, "Add a note?")
  if not ok then return end
  local rate = ctx:rate("tx_tax_rate")
  local tax = math.floor(amount * rate)
  local lines = { "Pay " .. payee.owner, "You pay: " .. util.money(amount), "Tax: " .. util.money(tax) .. " (" .. fmt.pct(rate) .. ")", payee.owner .. " gets: " .. util.money(amount - tax) }
  if memo then lines[#lines + 1] = "Note: " .. memo end
  if not ui.confirm(ctx, "Confirm payment", lines, "SEND") then return end
  local res = ctx:call("transfer", { target_id = payee.id, amount = amount, memo = memo })
  if not res.ok then return ctx:fail(res, "Payment failed", true) end
  ctx:beep("ok")
  P.receipt(ctx, { title = "Payment sent", rows = {
    { "Paid", payee.owner }, { "Amount", util.money(amount) }, { "Tax", util.money(res.tax or 0) },
    { "New balance", util.money(res.balance or 0), theme.good },
  } })
end

function P.bill(ctx)
  local payee = P.pick_payee(ctx, "Bill a player")
  if not payee then return end
  if payee.owner:sub(1, 1) == "@" then return ctx:say("Bill", { "You can only bill players." }, "warn") end
  local amount = ui.amount(ctx, "Bill " .. util.ellipsis(payee.owner, 16))
  if not amount then return end
  local ok, memo = P.ask_memo(ctx, "Add a note?")
  if not ok then return end
  local lines = { "Bill " .. payee.owner, "Amount: " .. util.money(amount) }
  if memo then lines[#lines + 1] = "Note: " .. memo end
  lines[#lines + 1] = "They can pay or decline."
  if not ui.confirm(ctx, "Send bill", lines, "SEND BILL") then return end
  local res = ctx:call("request_payment", { target_owner = payee.owner, amount = amount, memo = memo })
  if not res.ok then return ctx:fail(res, "Bill not sent", true) end
  ctx:say("Bill sent", { payee.owner .. " has your bill for " .. util.money(amount) .. "." }, "ok")
end

local function bill_actions(ctx, r)
  local armed = r.status == "auto_pending"
  local pick = ui.choose(ctx, "Bill from " .. util.ellipsis(r.from_owner, 14), {
    { label = "PAY NOW", id = "pay", sub = util.money(r.amount), kind = "success" },
    armed and { label = "STOP AUTO-PAY", id = "unarm", sub = "Will not pay by itself", kind = "primary" }
      or { label = "PAY WHEN FUNDED", id = "auto", sub = "Pays when you have enough", kind = "primary" },
    { label = "DECLINE", id = "decline", kind = "danger" },
  }, (r.memo and r.memo ~= "") and r.memo or nil)
  if not pick then return end
  if pick == "pay" then
    if not ui.confirm(ctx, "Pay this bill", { "Pay " .. r.from_owner .. " " .. util.money(r.amount) .. "?" }, "PAY") then return end
    local res = ctx:call("approve_payment_request", { request_id = r.id })
    if not res.ok then return ctx:fail(res, "Not paid", true) end
    ctx:say("Bill paid", { "You paid " .. util.money(r.amount) .. ".", "New balance: " .. util.money(res.balance or 0) }, "ok")
  elseif pick == "auto" then
    local res = ctx:call("auto_payment_request", { request_id = r.id })
    if not res.ok then return ctx:fail(res, "Could not set auto-pay", true) end
    if res.executed then
      ctx:say("Bill paid", { "You had enough, so it was paid now.", "New balance: " .. util.money(res.balance or 0) }, "ok")
    else
      ctx:say("Auto-pay is on", { "This bill will be paid as soon as", "checking holds " .. util.money(r.amount) .. "." }, "ok")
    end
  elseif pick == "unarm" then
    local res = ctx:call("cancel_auto_payment_request", { request_id = r.id })
    if not res.ok then return ctx:fail(res, "Could not stop auto-pay", true) end
    ctx:toast("Auto-pay stopped", "ok")
  elseif pick == "decline" then
    if not ui.confirm(ctx, "Decline bill", { "Decline the bill from " .. r.from_owner .. "?" }, "DECLINE", true) then return end
    local res = ctx:call("reject_payment_request", { request_id = r.id })
    if not res.ok then return ctx:fail(res, "Could not decline", true) end
    ctx:toast("Bill declined", "ok")
  end
end

function P.inbox(ctx)
  while true do
    local res = ctx:call("list_payment_requests", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, r in ipairs(res.requests) do
      local sub = (r.status == "auto_pending") and "Auto-pay is on" or ""
      if r.memo and r.memo ~= "" then sub = (sub ~= "" and (sub .. ". ") or "") .. r.memo end
      rows[#rows + 1] = { left = r.from_owner, right = util.money(r.amount), sub = sub ~= "" and sub or fmt.short(r.requested_at or util.now()), id = r.id, data = r }
    end
    local kind, _, data = ui.list(ctx, { title = "Bills to you", sub = "Touch a bill to pay it", rows = rows, empty = "No bills", hint = "Nobody is waiting on you" })
    if kind ~= "row" then return end
    bill_actions(ctx, data)
  end
end

function P.sent(ctx)
  while true do
    local res = ctx:call("list_my_sent_requests", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, r in ipairs(res.requests) do
      local sub = (r.status == "auto_pending") and "Auto-pay is on" or "Waiting"
      if r.memo and r.memo ~= "" then sub = sub .. ". " .. r.memo end
      rows[#rows + 1] = { left = r.to_owner, right = util.money(r.amount), sub = sub, id = r.id, data = r }
    end
    local kind, _, data = ui.list(ctx, { title = "Bills you sent", sub = "Touch a bill to cancel it", rows = rows, empty = "No open bills", hint = "Use BILL A PLAYER" })
    if kind ~= "row" then return end
    if ui.confirm(ctx, "Cancel bill", { "Cancel your bill to " .. data.to_owner .. " for " .. util.money(data.amount) .. "?" }, "CANCEL BILL", true) then
      local c = ctx:call("cancel_payment_request", { request_id = data.id })
      if not c.ok then ctx:fail(c, "Not cancelled", true) else ctx:toast("Bill cancelled", "ok") end
    end
  end
end

function P.bills(ctx)
  while true do
    local id = ui.menu(ctx, { title = "Bills", sub = "Ask for or pay money", items = {
      { label = "BILL A PLAYER", id = "bill", kind = "primary", sub = "Ask someone to pay you" },
      { label = "BILLS TO YOU", id = "inbox", kind = "success", sub = "Pay or decline" },
      { label = "BILLS YOU SENT", id = "sent", kind = "panel", sub = "See or cancel" },
    } })
    if not id then return end
    if id == "bill" then P.bill(ctx) elseif id == "inbox" then P.inbox(ctx) else P.sent(ctx) end
  end
end

return P
