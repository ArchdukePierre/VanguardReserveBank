local ui = require("roles.atm.ui")
local util = require("lib.util")
local theme = require("ui.theme")

local A = {}

local function change_pin(ctx)
  local old = ui.pin(ctx, "Current PIN", "Your PIN now")
  if not old then return end
  local new
  while true do
    local a = ui.pin(ctx, "New PIN", "4 digits")
    if not a then return end
    local b = ui.pin(ctx, "Confirm new PIN", "Enter it again")
    if not b then return end
    if a == b then new = a; break end
    ctx:say("Change PIN", { "Those PINs did not match.", "Try again." }, "error")
  end
  local res = ctx:call("change_pin", { old_pin = old, new_pin = new })
  old, new = nil, nil
  if not res.ok then return ctx:fail(res, "PIN not changed", true) end
  ctx:say("PIN changed", { "Use the new PIN next time you sign in." }, "ok")
end

local function audit(ctx)
  local res = ctx:call("self_audit", {})
  if not res.ok then return ctx:fail(res) end
  if res.ok_match then
    ctx:say("Account check", { "Your balance matches every entry", "in the bank's books.", "Checking: " .. util.money(res.balance or 0) }, "ok")
  else
    ctx:say("Account check", { "Something does not add up.", "Ask the Reserve staff to check your accounts." }, "warn")
  end
end

local function notifications(ctx)
  local res = ctx:call("my_notif_subs", {})
  if not res.ok then return ctx:fail(res) end
  local channels = res.channels
  while true do
    local rows = {}
    for _, ch in ipairs(channels) do
      rows[#rows + 1] = { left = ch.label, right = ch.subscribed and "ON" or "OFF", rcolor = ch.subscribed and theme.good or theme.muted, sub = ch.description, id = ch.id, data = ch }
    end
    local kind, id, ch = ui.list(ctx, { title = "Notifications", sub = "Touch one to switch it", rows = rows, empty = "No messages to set" })
    if kind ~= "row" then return end
    local r = ctx:call("set_notif_subs", { subs = { [id] = not ch.subscribed } })
    if not r.ok then
      ctx:fail(r, "Not saved", true)
    else
      ch.subscribed = not ch.subscribed
      ctx:toast(ch.label .. (ch.subscribed and " is on" or " is off"), "ok")
    end
  end
end

function A.menu(ctx)
  while true do
    local id = ui.menu(ctx, { title = "Settings", sub = "Your PIN and messages", items = {
      { label = "CHANGE PIN", id = "pin", kind = "primary", sub = "Pick a new 4 digit PIN" },
      { label = "ACCOUNT CHECK", id = "audit", kind = "panel", sub = "Check your books add up" },
      { label = "NOTIFICATIONS", id = "notif", kind = "panel", sub = "Choose your messages" },
    } })
    if not id then return end
    if id == "pin" then change_pin(ctx) elseif id == "audit" then audit(ctx) else notifications(ctx) end
  end
end

return A
