local kit = require("ui.kit")
local ser = require("lib.ser")
local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local T = theme
local M = {}

local MONEY_KEYS = { "amount", "delta", "total", "bounty", "payout", "refunded", "paid", "new_balance" }
local STEPS = { 30, 60, 90 }

local function who(e)
  if e.owner then return e.owner end
  if e.from and e.to then return tostring(e.from) .. ">" .. tostring(e.to) end
  return e.account or e.faction or e.shop or e.job_id or e.id or ""
end

local function money_of(e)
  for _, k in ipairs(MONEY_KEYS) do
    if type(e[k]) == "number" then return e[k] end
  end
end

local function show_entry(ctx, e)
  local keys = {}
  for k in pairs(e) do keys[#keys + 1] = k end
  table.sort(keys)
  local w = ctx.app.s.w - 6
  local lines = {}
  local cap = math.max(3, ctx.app.s.h - 11)
  for _, k in ipairs(keys) do
    if #lines >= cap then lines[#lines] = "and more fields"; break end
    local v = e[k]
    if k == "t" then v = Core.stamp(v) elseif type(v) == "table" then v = ser.encode(v) end
    lines[#lines + 1] = util.ellipsis(k .. ": " .. tostring(v), w)
  end
  ctx:message("Ledger entry", lines)
end

local function verify(ctx)
  local app = ctx.app
  local waited = 0
  local function working()
    app:show(function(s)
      kit.header(s, "Ledger check", "Reading every block")
      s:text(3, 6, "Checking the ledger. Please wait.", T.ink)
      s:text(3, 8, string.format("Waited %.0f of 60 seconds", waited), T.muted)
    end)
  end
  local r = ctx:call("admin_verify_ledger", nil, { timeout = 10 })
  while r and r.state == "running" and waited < 60 do
    working()
    sleep(2)
    waited = waited + 2
    r = ctx:call("admin_verify_ledger", nil, { timeout = 10 })
  end
  if not r then return end
  if r.state == "running" then
    ctx:message("Still working", { "The check is still running after 60 seconds.", "Touch VERIFY again later to see the result." }, "warn")
  elseif r.chain_ok then
    ctx:message("Ledger is intact", { string.format("%.0f entries in %.0f blocks.", r.result or 0, r.blocks or 0), string.format("Entries %.0f to %.0f.", r.first_seq or 0, r.last_seq or 0), "Every block links to the one before." }, "ok")
  else
    ctx:message("Ledger check FAILED", { "The ledger does not verify:", tostring(r.result) }, "error")
  end
end

function M.run(ctx)
  local st = { offset = 0 }
  local step = 1
  local data
  local function load()
    local r = ctx:call("admin_ledger_tail", { limit = STEPS[step] })
    if not r then return false end
    data = r
    return true
  end
  if not load() then return end
  while true do
    local rows, entries = {}, data.entries
    for i = #entries, 1, -1 do
      local e = entries[i]
      local amount = money_of(e)
      rows[#rows + 1] = { left = Core.stamp(e.t, ctx.app.s.w < 45) .. " " .. tostring(e.type) .. " " .. tostring(who(e)), right = amount and util.money(amount) or nil, rcolor = (amount or 0) < 0 and T.bad or T.accent, id = "e" .. i, data = e }
    end
    local id, e = Core.list(ctx, {
      title = "Ledger", subtitle = string.format("Latest %.0f entries, newest first", #entries), rows = rows, state = st, empty = "The ledger is empty",
      buttons = { { label = "REFRESH", id = "refresh" }, { label = "OLDER", id = "older", disabled = step >= #STEPS or #entries < STEPS[step] }, { label = "VERIFY", id = "verify", kind = "primary" } },
    })
    if not id then return end
    if id == "refresh" then st.offset = 0; load()
    elseif id == "older" then step = step + 1; load()
    elseif id == "verify" then verify(ctx)
    else show_entry(ctx, e) end
  end
end

return M
