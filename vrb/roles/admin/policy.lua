local util = require("lib.util")
local Core = require("roles.admin.core")

local M = {}

local FIELDS = {
  { key = "sav_mpr", label = "Savings rate/mo", kind = "percent", prompt = "Percent per month" },
  { key = "chk_mpr", label = "Checking rate/mo", kind = "percent", prompt = "Percent per month" },
  { key = "loan_mpr", label = "Loan rate/mo", kind = "percent", prompt = "Percent per month" },
  { key = "cd_mpr_30", label = "30 day CD rate", kind = "percent", prompt = "Percent per month" },
  { key = "cd_mpr_90", label = "90 day CD rate", kind = "percent", prompt = "Percent per month" },
  { key = "cd_mpr_180", label = "180 day CD rate", kind = "percent", prompt = "Percent per month" },
  { key = "tx_tax_rate", label = "Transfer tax", kind = "percent", prompt = "Percent per transfer" },
  { key = "shop_tax_rate", label = "Shop tax", kind = "percent", prompt = "Percent per sale" },
  { key = "min_loan_col", label = "Loan collateral", kind = "percent", prompt = "Percent of the loan" },
  { key = "multisig_threshold", label = "Multisig limit", kind = "money", prompt = "Needs votes above" },
  { key = "allow_player_deposit", label = "Player deposits", kind = "bool" },
  { key = "issue_enabled", label = "Issuance", kind = "bool" },
}

local function fmt(f, v)
  if v == nil then return "?" end
  if f.kind == "percent" then return Core.pct(v) end
  if f.kind == "money" then return util.money(v) end
  return Core.onoff(v)
end

local function edit_scalar(ctx, st, f)
  local old = st.policy[f.key]
  local new
  if f.kind == "bool" then
    new = not old
    if not ctx:confirm(f.label, { f.label .. " is " .. Core.onoff(old) .. ".", "Turn it " .. Core.onoff(new) .. "?" }, { yes = "TURN " .. Core.onoff(new) }) then return end
  else
    new = Core.keypad(ctx, { title = f.label, label = f.prompt, kind = f.kind, allow_zero = true, limit = f.kind == "percent" and 10000 or nil, subtitle = "Now " .. fmt(f, old) })
    if new == nil then return end
    if new == old then
      ctx:message("No change", { f.label .. " is already " .. fmt(f, old) .. "." }, "warn")
      return
    end
    local lines = { f.label, "Now " .. fmt(f, old), "New " .. fmt(f, new) }
    if f.kind == "percent" and new > 0.25 then lines[#lines + 1] = "That is a very high rate." end
    if not ctx:confirm("Change policy", lines, { yes = "SAVE" }) then return end
  end
  local r = ctx:call("admin_set_policy", { policy = { [f.key] = new } })
  if not r then return end
  st.policy = r.policy
  if r.policy[f.key] ~= new then
    ctx:message("Not saved", { "The server did not accept that value." }, "error")
  else
    ctx:say(f.label .. " saved")
  end
end

local function ubi(ctx, st)
  local p = st.policy
  local opts = {
    { label = p.ubi_enabled and "TURN OFF" or "TURN ON", id = "toggle", kind = p.ubi_enabled and "danger" or "success" },
    { label = "WEEKLY SUM", id = "weekly", kind = "panel", sub = util.money(p.ubi_weekly) },
    { label = "PAY NOW", id = "force", kind = "panel", sub = "One week each" },
  }
  local id = ctx:choose("UBI", opts, { subtitle = "Now " .. Core.onoff(p.ubi_enabled) .. ", " .. util.money(p.ubi_weekly) .. " a week" })
  if id == "toggle" then
    local to = not p.ubi_enabled
    local lines = to and { "Turn UBI ON?", "Active players get " .. util.money(p.ubi_weekly) .. " each week." } or { "Turn UBI OFF?", "Weekly payments stop." }
    if ctx:confirm("UBI", lines, { yes = "TURN " .. Core.onoff(to) }) then
      local r = ctx:call("admin_set_ubi", { enabled = to })
      if r then p.ubi_enabled = r.ubi_enabled; ctx:say("UBI is " .. Core.onoff(r.ubi_enabled)) end
    end
  elseif id == "weekly" then
    local v = Core.keypad(ctx, { title = "Weekly UBI", label = "Per active player", kind = "money", allow_zero = true, subtitle = "Now " .. util.money(p.ubi_weekly) })
    if v and v ~= p.ubi_weekly and ctx:confirm("UBI", { "Weekly UBI", "Now " .. util.money(p.ubi_weekly), "New " .. util.money(v) }, { yes = "SAVE" }) then
      local r = ctx:call("admin_set_ubi", { weekly = v })
      if r then p.ubi_weekly = r.ubi_weekly; ctx:say("UBI saved") end
    end
  elseif id == "force" then
    if not p.ubi_enabled or p.ubi_weekly <= 0 then
      ctx:message("UBI is off", { "Turn UBI on and set a weekly sum first. Nothing would be paid now." }, "warn")
    elseif ctx:confirm("Pay UBI now", { "Pay " .. util.money(p.ubi_weekly) .. " to every active player now?", "This restarts the weekly clock." }, { yes = "PAY NOW", danger = true }) then
      if ctx:call("admin_force_ubi") then ctx:say("UBI will be paid within minutes") end
    end
  end
end

local function supply(ctx, st)
  local p = st.policy
  local opts = {
    { label = p.supply_target_enabled and "TURN OFF" or "TURN ON", id = "toggle", kind = p.supply_target_enabled and "danger" or "success" },
    { label = "LOW LIMIT", id = "low", kind = "panel", sub = util.money(p.supply_target_low) },
    { label = "HIGH LIMIT", id = "high", kind = "panel", sub = util.money(p.supply_target_high) },
  }
  local id = ctx:choose("Supply target", opts, { subtitle = "Keeps supply in a range" })
  if id == "toggle" then
    local to = not p.supply_target_enabled
    if ctx:confirm("Supply target", { "Turn the supply target " .. Core.onoff(to) .. "?", "The top income tax brackets move by 0.1% when supply leaves the range." }, { yes = "TURN " .. Core.onoff(to) }) then
      if ctx:call("admin_set_supply_target", { enabled = to }) then p.supply_target_enabled = to; ctx:say("Supply target is " .. Core.onoff(to)) end
    end
  elseif id == "low" or id == "high" then
    local key = "supply_target_" .. id
    local v = Core.keypad(ctx, { title = id == "low" and "Low limit" or "High limit", label = "Money supply", kind = "money", allow_zero = true, subtitle = "Now " .. util.money(p[key]) })
    if v and v ~= p[key] and ctx:confirm("Supply target", { id == "low" and "Low limit" or "High limit", "Now " .. util.money(p[key]), "New " .. util.money(v) }, { yes = "SAVE" }) then
      if ctx:call("admin_set_supply_target", { [id] = v }) then p[key] = v; ctx:say("Limit saved") end
    end
  end
end

local function save_brackets(ctx, st, list)
  local r = ctx:call("admin_set_tax_bracket", { brackets = list })
  if not r then return false end
  table.sort(list, function(a, b) return a.above < b.above end)
  st.policy.income_tax_brackets = list
  ctx:say("Brackets saved")
  return true
end

local function copy_brackets(st)
  local out = {}
  for _, b in ipairs(st.policy.income_tax_brackets or {}) do out[#out + 1] = { above = b.above, rate = b.rate } end
  return out
end

local function bracket_above(ctx, current)
  return Core.keypad(ctx, { title = "Bracket start", label = "Yearly pay above", kind = "money", allow_zero = true, subtitle = current and ("Now " .. util.money(current)) or nil })
end

local function bracket_rate(ctx, current)
  return Core.keypad(ctx, { title = "Bracket rate", label = "Tax percent", kind = "percent", allow_zero = true, limit = 5000, subtitle = current and ("Now " .. Core.pct(current) .. ", pay tax caps at 10%") or "Pay tax caps at 10%" })
end

local function brackets(ctx, st)
  local lst = { offset = 0 }
  while true do
    local rows = {}
    for i, b in ipairs(st.policy.income_tax_brackets or {}) do rows[#rows + 1] = { left = "Above " .. util.money(b.above), right = Core.pct(b.rate), id = "b" .. i, data = i } end
    local id, i = Core.list(ctx, { title = "Income tax", subtitle = "Rate by yearly pay", rows = rows, state = lst, empty = "No brackets",
      buttons = { { label = "ADD", id = "add", kind = "primary" } } })
    if not id then return end
    local list = copy_brackets(st)
    if id == "add" then
      local above = bracket_above(ctx)
      if above then
        local dup = false
        for _, b in ipairs(list) do if b.above == above then dup = true end end
        if dup then
          ctx:message("Already there", { "A bracket already starts at " .. util.money(above) .. "." }, "warn")
        else
          local rate = bracket_rate(ctx)
          if rate and ctx:confirm("Add bracket", { "Above " .. util.money(above), "Rate " .. Core.pct(rate) }, { yes = "ADD" }) then
            list[#list + 1] = { above = above, rate = rate }
            save_brackets(ctx, st, list)
          end
        end
      end
    else
      local b = list[i]
      local act = ctx:choose("Above " .. util.money(b.above), { { label = "EDIT RATE", id = "rate", kind = "panel" }, { label = "EDIT START", id = "above", kind = "panel" }, { label = "REMOVE", id = "remove", kind = "danger" } }, { subtitle = "Rate " .. Core.pct(b.rate) })
      if act == "rate" then
        local v = bracket_rate(ctx, b.rate)
        if v and v ~= b.rate and ctx:confirm("Change rate", { "Above " .. util.money(b.above), "Now " .. Core.pct(b.rate), "New " .. Core.pct(v) }, { yes = "SAVE" }) then
          b.rate = v
          save_brackets(ctx, st, list)
        end
      elseif act == "above" then
        local v = bracket_above(ctx, b.above)
        local dup = false
        for _, o in ipairs(list) do if o ~= b and o.above == v then dup = true end end
        if v and dup then
          ctx:message("Already there", { "A bracket already starts at " .. util.money(v) .. "." }, "warn")
        elseif v and v ~= b.above and ctx:confirm("Change start", { "Rate " .. Core.pct(b.rate), "Now above " .. util.money(b.above), "New above " .. util.money(v) }, { yes = "SAVE" }) then
          b.above = v
          save_brackets(ctx, st, list)
        end
      elseif act == "remove" then
        if #list <= 1 then
          ctx:message("Keep one", { "At least one bracket must stay." }, "warn")
        elseif ctx:confirm("Remove bracket", { "Remove the bracket above " .. util.money(b.above) .. "?", "Its rate " .. Core.pct(b.rate) .. " no longer applies." }, { yes = "REMOVE", danger = true }) then
          table.remove(list, i)
          save_brackets(ctx, st, list)
        end
      end
    end
  end
end

local function items(ctx, st)
  local lst = { offset = 0 }
  while true do
    local r = ctx:call("item_rates")
    if not r then return end
    local rows = {}
    for i, it in ipairs(r.rates) do rows[#rows + 1] = { left = Core.strip(it.item), right = util.money(it.rate), id = "i" .. i, data = it } end
    local id, it = Core.list(ctx, { title = "Item backing", subtitle = r.enabled and "Money paid for each item" or "Item backing is OFF", rows = rows, state = lst,
      empty = r.enabled and "No backed items" or "Turn backing on to list items",
      buttons = { { label = "ADD", id = "add", kind = "primary", disabled = not r.enabled }, { label = "BACKING: " .. Core.onoff(r.enabled), id = "toggle", kind = r.enabled and "success" or "danger" } } })
    if not id then return end
    if id == "toggle" then
      local to = not r.enabled
      if ctx:confirm("Item backing", { "Turn item backing " .. Core.onoff(to) .. "?", to and "Players can pay in backed items again." or "Players cannot deposit items until you turn it on." }, { yes = "TURN " .. Core.onoff(to), danger = not to }) then
        local pr = ctx:call("admin_set_policy", { policy = { item_backing_enabled = to } })
        if pr then st.policy = pr.policy; ctx:say("Item backing is " .. Core.onoff(to)) end
      end
    elseif id == "add" then
      local name = ctx:text({ title = "New item", label = "Item id", subtitle = "Like copper_ingot", raw = true, max = 50, allowed = "^[%w_:%.%-]$" })
      if name then
        name = name:lower()
        if not name:find(":", 1, true) then name = "minecraft:" .. name end
        local v = Core.keypad(ctx, { title = Core.strip(name), label = "Price for one item", kind = "money" })
        if v and ctx:confirm("Back item", { "Pay " .. util.money(v) .. " for each " .. Core.strip(name) .. "?" }, { yes = "ADD" }) and ctx:call("admin_set_item_rate", { item = name, rate = v }) then
          ctx:say("Item added")
        end
      end
    else
      local act = ctx:choose(Core.strip(it.item), { { label = "EDIT RATE", id = "rate", kind = "panel" }, { label = "REMOVE", id = "remove", kind = "danger" } }, { subtitle = "Now " .. util.money(it.rate) .. " each" })
      if act == "rate" then
        local v = Core.keypad(ctx, { title = Core.strip(it.item), label = "Price for one item", kind = "money", subtitle = "Now " .. util.money(it.rate) })
        if v and v ~= it.rate and ctx:confirm("Change rate", { Core.strip(it.item), "Now " .. util.money(it.rate), "New " .. util.money(v) }, { yes = "SAVE" }) and ctx:call("admin_set_item_rate", { item = it.item, rate = v }) then
          ctx:say("Rate saved")
        end
      elseif act == "remove" then
        if ctx:confirm("Remove item", { "Stop backing money with " .. Core.strip(it.item) .. "?" }, { yes = "REMOVE", danger = true }) and ctx:call("admin_set_item_rate", { item = it.item }) then
          ctx:say("Item removed")
        end
      end
    end
  end
end

local function day_text(d)
  if type(d) ~= "number" then return "never" end
  return string.format("%04.0f-%02.0f-%02.0f", math.floor(d / 10000), math.floor(d / 100) % 100, d % 100)
end

local function streak(ctx)
  local owner = ctx:text({ title = "Player streak", label = "Player name", raw = true, max = 32 })
  if not owner then return end
  local r = ctx:call("admin_earnings_state", { owner = owner })
  if not r then return end
  local lines
  local days = 0
  if r.found then
    local s, b = r.state, r.last_breakdown
    days = s.streak_days or 0
    lines = {
      "Streak " .. Core.n(days, "day"),
      "Last active " .. day_text(s.last_active_day),
      "Insurance " .. (s.insurance_until and ("until " .. Core.stamp(s.insurance_until)) or "none"),
      string.format("Build streak %.0f", s.build_streak or 0),
      "Last death " .. (s.last_death_ts and Core.stamp(s.last_death_ts) or "none"),
    }
    if b and b.total then lines[#lines + 1] = "Last pay " .. util.money(b.total) end
  else
    lines = { owner .. " has no earnings record yet." }
  end
  if not ctx:confirm(owner, lines, { yes = "SET STREAK", no = "DONE" }) then return end
  local v = Core.keypad(ctx, { title = "Set streak", label = "Streak days", kind = "int", allow_zero = true, limit = 10000, max = 5, subtitle = owner .. " now " .. Core.n(days, "day") })
  if v == nil then return end
  if ctx:confirm("Set streak", { owner .. "'s streak", "Now " .. Core.n(days, "day"), "New " .. Core.n(v, "day") }, { yes = "SET", danger = true }) and ctx:call("admin_set_streak", { owner = owner, days = v }) then
    ctx:say("Streak set to " .. util.int(v) .. " days")
  end
end

local function pvp_toggle(ctx)
  local id = ctx:choose("PvP kills", { { label = "COUNT PVP KILLS", id = "on", kind = "success" }, { label = "IGNORE PVP KILLS", id = "off", kind = "danger" } }, { subtitle = "The server cannot report the current setting" })
  if not id then return nil end
  local to = id == "on"
  if not ctx:confirm("PvP kills", { to and "Count player kills in daily earnings?" or "Ignore player kills in daily earnings?" }, { yes = to and "TURN ON" or "TURN OFF" }) then return nil end
  local r = ctx:call("admin_set_pvp_enabled", { enabled = to })
  if not r then return nil end
  ctx:say("PvP kills are " .. Core.onoff(r.enabled))
  return r.enabled
end

local function earnings(ctx)
  local dg = ctx:call("admin_diagnostics", nil, { quiet = true })
  local en = dg and dg.earnings_enabled
  local pvp
  while true do
    local id = Core.menu(ctx, {
      title = "Earnings", subtitle = "Daily pay and streaks",
      items = function()
        return {
          { label = "EARNINGS PAY", short = "PAY", id = "toggle", kind = en == false and "danger" or "success", sub = en == nil and "unknown" or Core.onoff(en) },
          { label = "PVP KILLS", id = "pvp", kind = "primary", sub = pvp == nil and "set it" or Core.onoff(pvp) },
          { label = "PLAYER STREAK", short = "STREAK", id = "streak", kind = "primary", sub = "Look up" },
        }
      end,
    })
    if not id then return end
    if id == "toggle" then
      local to = not (en == true)
      if en == nil then
        local pick = ctx:choose("Earnings pay", { { label = "TURN ON", id = "on", kind = "success" }, { label = "TURN OFF", id = "off", kind = "danger" } })
        if not pick then to = nil else to = pick == "on" end
      end
      if to ~= nil and ctx:confirm("Earnings pay", { to and "Turn daily earnings ON?" or "Turn daily earnings OFF?", to and "Players are paid at the next daily tick." or "No daily pay is given while off." }, { yes = to and "TURN ON" or "TURN OFF", danger = not to }) then
        local r = ctx:call("admin_set_earnings_enabled", { enabled = to })
        if r then en = r.enabled; ctx:say("Earnings pay is " .. Core.onoff(r.enabled)) end
      end
    elseif id == "pvp" then
      local v = pvp_toggle(ctx)
      if v ~= nil then pvp = v end
    elseif id == "streak" then streak(ctx) end
  end
end

function M.run(ctx)
  local st = { offset = 0 }
  local info
  local function load()
    local r = ctx:call("admin_stats")
    if not r then return false end
    info = r.stats
    st.policy = r.stats.policy
    return true
  end
  if not load() then return end
  local lst = { offset = 0 }
  while true do
    local p = st.policy
    local rows = {}
    for _, f in ipairs(FIELDS) do rows[#rows + 1] = { left = f.label, right = fmt(f, p[f.key]), id = "f:" .. f.key, data = f } end
    rows[#rows + 1] = { left = "UBI", right = Core.onoff(p.ubi_enabled) .. " " .. util.money(p.ubi_weekly), id = "ubi" }
    rows[#rows + 1] = { left = "Supply target", right = Core.onoff(p.supply_target_enabled), id = "supply" }
    rows[#rows + 1] = { left = "Income tax", right = string.format("%.0f brackets", #(p.income_tax_brackets or {})), id = "brackets" }
    rows[#rows + 1] = { left = "Item backing", right = string.format("%s, %.0f items", Core.onoff(p.item_backing_enabled), util.count(p.item_backing_map or {})), id = "items" }
    rows[#rows + 1] = { left = "Earnings and PvP", right = "open", id = "earn" }
    local id, f = Core.list(ctx, {
      title = "Policy", subtitle = "Touch a line to edit", rows = rows, state = lst,
      buttons = { { label = "RELOAD", id = "reload" } },
    })
    if not id then return end
    if id == "reload" then load()
    elseif id == "ubi" then ubi(ctx, st)
    elseif id == "supply" then supply(ctx, st)
    elseif id == "brackets" then brackets(ctx, st)
    elseif id == "items" then items(ctx, st)
    elseif id == "earn" then earnings(ctx)
    else edit_scalar(ctx, st, f) end
  end
end

return M
