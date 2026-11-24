local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local T = theme
local M = {}

local GROUPS = { "Enlisted", "Warrant", "Officer" }

function M.pick_rank(ctx)
  local rk = ctx:ranks()
  if not rk then return nil end
  local groups = {}
  for _, g in ipairs(GROUPS) do
    local n = 0
    for _, r in ipairs(rk.ranks) do if r.group == g then n = n + 1 end end
    groups[#groups + 1] = { label = g:upper(), id = g, kind = "panel", sub = n .. " grades" }
  end
  groups[#groups + 1] = { label = "NO RANK", id = "clear", kind = "danger", sub = "Leave the Vanguard" }
  while true do
    local g = ctx:choose("Pick a group", groups, { subtitle = string.format("%.0f of %.0f places filled", rk.current_count, rk.max_members) })
    if not g then return nil end
    if g == "clear" then return "clear" end
    local list, by_id = {}, {}
    for _, r in ipairs(rk.ranks) do
      if r.group == g then
        list[#list + 1] = { label = r.grade .. " " .. r.label, id = r.id, sub = util.money(r.weekly_cents) .. " a week", kind = "panel" }
        by_id[r.id] = r
      end
    end
    local id = ctx:choose(g, list, { subtitle = "Weekly pay is shown" })
    if id then return id, by_id[id] end
  end
end

function M.assign_rank(ctx, acct)
  local id, rank = M.pick_rank(ctx)
  if not id then return false end
  if id == "clear" then
    if not ctx:confirm("Remove rank", { "Take " .. acct.owner .. " out of the Vanguard?", "They stop receiving Vanguard pay." }, { yes = "REMOVE", danger = true }) then return false end
    return ctx:call("admin_set_rank", { account_id = acct.id }) ~= nil
  end
  local lines = { "Make " .. acct.owner .. " " .. rank.label .. " (" .. rank.grade .. ")?", "Pay " .. util.money(rank.weekly_cents) .. " a week.", "That is " .. util.money(rank.yearly_cents) .. " a year before tax." }
  if not ctx:confirm("Assign rank", lines, { yes = "ASSIGN" }) then return false end
  return ctx:call("admin_set_rank", { account_id = acct.id, rank_id = id }) ~= nil
end

local function summary(ctx)
  local r = ctx:call("vanguard_payroll_summary")
  if not r then return end
  local g = r.groups or {}
  ctx:message("Vanguard payroll", {
    Core.n(r.count, "member"),
    "Each day: " .. util.money(r.total_daily),
    "Each week: " .. util.money(r.total_weekly),
    "Each year: " .. util.money(r.total_yearly),
    string.format("Enlisted %.0f, Warrant %.0f, Officer %.0f", g.Enlisted or 0, g.Warrant or 0, g.Officer or 0),
  })
end

local function toggle(ctx, enabled)
  local to
  if enabled == nil then
    local id = ctx:choose("Vanguard pay", { { label = "TURN ON", id = "on", kind = "success" }, { label = "TURN OFF", id = "off", kind = "danger" } })
    if not id then return nil end
    to = id == "on"
  else
    to = not enabled
  end
  local lines = to and { "Turn Vanguard pay ON?", "Members are paid again at the next payroll." } or { "Turn Vanguard pay OFF?", "No Vanguard salary is paid until you turn it on." }
  if not ctx:confirm("Vanguard pay", lines, { yes = to and "TURN ON" or "TURN OFF", danger = not to }) then return nil end
  local r = ctx:call("admin_set_vanguard_enabled", { enabled = to })
  if not r then return nil end
  ctx:say("Vanguard pay is " .. Core.onoff(r.enabled))
  return r.enabled
end

local function member_menu(ctx, m)
  local opts = {
    { label = "CHANGE RANK", id = "rank", kind = "panel" },
    { label = m.on_leave and "END LEAVE" or "PAUSE PAY", id = "leave", kind = "panel" },
    { label = "REMOVE RANK", id = "clear", kind = "danger" },
    { label = "OPEN ACCOUNT", id = "acct", kind = "panel" },
  }
  local id = ctx:choose(m.owner, opts, { subtitle = m.rank_grade .. " " .. m.rank_label })
  local acct = { id = m.account_id, owner = m.owner }
  if id == "rank" then
    if M.assign_rank(ctx, acct) then ctx:say("Rank updated") end
  elseif id == "clear" then
    if ctx:confirm("Remove rank", { "Take " .. m.owner .. " out of the Vanguard?", "They stop receiving Vanguard pay." }, { yes = "REMOVE", danger = true }) then
      if ctx:call("admin_set_rank", { account_id = m.account_id }) then ctx:say("Rank removed") end
    end
  elseif id == "leave" then
    local to = not m.on_leave
    local lines = to and { "Pause Vanguard pay for " .. m.owner .. "?", "They keep the rank but get no salary." } or { "Resume Vanguard pay for " .. m.owner .. "?" }
    if ctx:confirm("Leave", lines, { yes = to and "PAUSE" or "RESUME" }) then
      if ctx:call("admin_set_leave", { account_id = m.account_id, on_leave = to }) then ctx:say(to and "Pay paused" or "Pay resumed") end
    end
  elseif id == "acct" then
    require("roles.admin.accounts").detail(ctx, m.account_id)
  end
end

function M.run(ctx)
  local st = { offset = 0 }
  local data, enabled
  local function load()
    local r = ctx:call("admin_list_vanguard")
    if not r then return false end
    data = r
    local dg = ctx:call("admin_diagnostics", nil, { quiet = true })
    enabled = dg and dg.vanguard_enabled
    return true
  end
  if not load() then return end
  while true do
    local rows = {}
    local wide = ctx.app.s.w >= 45
    for _, m in ipairs(data.members) do
      rows[#rows + 1] = { left = m.rank_grade .. " " .. m.owner .. (m.on_leave and " (leave)" or ""), right = util.money(m.weekly_cents) .. (wide and "/wk" or ""), id = m.account_id, data = m, color = m.on_leave and T.warn or nil }
    end
    local pay = enabled == nil and "PAY: ?" or ("PAY: " .. Core.onoff(enabled))
    local buttons = {
      { label = "ADD", id = "add", kind = "primary" },
      { label = "PAYROLL", id = "sum" },
      { label = pay, id = "toggle", kind = enabled == false and "danger" or "success" },
      { label = "RELOAD", id = "reload" },
    }
    local id, m = Core.list(ctx, {
      title = "Vanguard", subtitle = string.format("%.0f of %.0f places filled", data.count, data.max) .. (enabled == false and ", pay is OFF" or ""),
      rows = rows, buttons = buttons, state = st, empty = "No members yet", hint = "Touch ADD to give a rank",
    })
    if not id then return end
    if id == "add" then
      local acct = ctx:pick_account("Add to Vanguard")
      if acct and M.assign_rank(ctx, acct) then ctx:say("Rank updated"); load() end
    elseif id == "sum" then summary(ctx)
    elseif id == "toggle" then
      local v = toggle(ctx, enabled)
      if v ~= nil then enabled = v end
    elseif id == "reload" then load()
    else
      local c0 = ctx.changes
      member_menu(ctx, m)
      if ctx.changes ~= c0 then load() end
    end
  end
end

return M
