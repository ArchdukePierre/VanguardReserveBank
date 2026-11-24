local ui = require("roles.atm.ui")
local earn = require("roles.atm.earn")
local public = require("roles.atm.public")
local session = require("roles.atm.session")
local theme = require("ui.theme")

local H = {}

local ITEMS = {
  { label = "SIGN IN", id = "signin", kind = "primary", sub = "Use your PIN" },
  { label = "OPEN ACCOUNT", id = "open", kind = "success", sub = "New to the bank" },
  { label = "REWARDS", id = "rewards", kind = "panel", sub = "Bounties you can earn" },
  { label = "WORK ORDERS", id = "orders", kind = "panel", sub = "Paid jobs" },
  { label = "RATES", id = "rates", kind = "panel", sub = "Interest, tax and fees" },
  { label = "FIND A PLAYER", id = "find", kind = "panel", sub = "Get an account number" },
}

local function start(ctx, res)
  ctx:begin(res)
  session.run(ctx)
  ctx:signout()
end

local function signin(ctx)
  local how = ui.choose(ctx, "Sign in", {
    { label = "USERNAME", id = "owner", sub = "Your player name", kind = "primary" },
    { label = "ACCOUNT NUMBER", id = "acct", sub = "Like ACC-123456", kind = "panel" },
  })
  if not how then return end
  local owner, acct
  if how == "owner" then
    owner = ui.text(ctx, { title = "Sign in", label = "Username", max = 32 })
    if not owner then return end
    if #owner < 2 then return ctx:say("Sign in", { "Usernames have at least 2 letters." }, "error") end
  else
    local digits = ui.number(ctx, "Account number", 6, "The 6 digits after ACC-")
    if not digits then return end
    if #digits ~= 6 then return ctx:say("Sign in", { "Account numbers have 6 digits", "after ACC-." }, "error") end
    acct = "ACC-" .. digits
  end
  local pin = ui.pin(ctx, "Enter PIN")
  if not pin then return end
  local res
  if owner then
    res = ctx:pub("auth_by_owner", { owner = owner, pin = pin, branch = ctx.branch })
  else
    res = ctx:pub("auth", { account_id = acct, pin = pin, branch = ctx.branch })
  end
  pin = nil
  if not res.ok then return ctx:fail(res, "Could not sign in") end
  start(ctx, res)
end

local function open_account(ctx)
  local owner = ui.text(ctx, { title = "Open account", label = "Pick a username", subtitle = "Letters, numbers and _", max = 32 })
  if not owner then return end
  if #owner < 2 then return ctx:say("Open account", { "Usernames have at least 2 letters." }, "error") end
  local pin
  while true do
    local a = ui.pin(ctx, "Choose a PIN", "4 digits to remember")
    if not a then return end
    local b = ui.pin(ctx, "Confirm your PIN", "Enter it again")
    if not b then return end
    if a == b then pin = a; break end
    ctx:say("Open account", { "Those PINs did not match.", "Try again." }, "error")
  end
  local res = ctx:pub("open_account", { owner = owner, pin = pin })
  if not res.ok then pin = nil; return ctx:fail(res, "Account not opened", true) end
  local login = ctx:pub("auth_by_owner", { owner = owner, pin = pin, branch = ctx.branch })
  pin = nil
  ctx:beep("ok")
  ui.list(ctx, { title = "Account opened", sub = "Write these numbers down", back = "CONTINUE", rows = {
    { left = "Username", right = owner },
    { left = "Checking", right = res.checking_id, rcolor = theme.good },
    { left = "Savings", right = res.savings_id, rcolor = theme.good },
    { blank = true },
    { text = "Others pay your checking number. Savings holds money you want to keep.", color = theme.muted },
  } })
  if login.ok then start(ctx, login)
  else ctx:say("Sign in", { "Your account is open.", "Sign in with your PIN to use it." }, "info") end
end

local ACTIONS = {
  signin = signin, open = open_account, rewards = earn.rewards, orders = earn.orders, rates = public.rates, find = public.find,
}

function H.loop(ctx)
  while true do
    local id = ui.menu(ctx, { title = "Welcome", sub = "Touch a card to begin", items = ITEMS, back = false, rest = true })
    ACTIONS[id](ctx)
  end
end

return H
