local flows = require("ui.flows")
local kit = require("ui.kit")
local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local T = theme
local M = {}

local function freeze(ctx, d)
  local to = not d.frozen
  local lines = to and { "Freeze " .. d.owner .. "?", "Every account of this owner is frozen and signed out.", "They cannot sign in until you unfreeze." }
    or { "Unfreeze " .. d.owner .. "?", "They can sign in again." }
  if not ctx:confirm(to and "Freeze account" or "Unfreeze account", lines, { danger = to, yes = to and "FREEZE" or "UNFREEZE" }) then return end
  if ctx:call("admin_freeze", { account_id = d.id, frozen = to }) then ctx:say(to and "Frozen" or "Unfrozen") end
end

local function unlock(ctx, d)
  if not ctx:confirm("Unlock account", { "Clear the PIN lockout for " .. d.owner .. "?", "Both accounts can sign in again." }, { yes = "UNLOCK" }) then return end
  if ctx:call("admin_unlock", { account_id = d.id }) then ctx:say("Unlocked") end
end

local function reset_pin(ctx, d)
  local a = flows.pin(ctx.app, "New PIN for " .. d.owner)
  if not a then return end
  local b = flows.pin(ctx.app, "Repeat the new PIN")
  if not b then return end
  if a ~= b then
    ctx:message("PINs differ", { "The two PINs did not match. Nothing changed." }, "warn")
    return
  end
  local lines = { "Set the new PIN for " .. d.owner .. "?", "Both accounts change and the owner is signed out.", "Tell the owner the PIN in private." }
  if not ctx:confirm("Reset PIN", lines, { yes = "SET PIN", danger = true }) then return end
  if ctx:call("admin_reset_pin", { account_id = d.id, new_pin = a }) then ctx:say("PIN changed") end
end

local function set_balance(ctx, d)
  local v = Core.keypad(ctx, { title = "Set balance", label = "New balance", kind = "money", allow_zero = true, subtitle = d.owner .. " has " .. util.money(d.balance) })
  if not v then return end
  if v == d.balance then
    ctx:message("No change", { "The balance is already " .. util.money(v) .. "." }, "warn")
    return
  end
  local reason = ctx:reason("Reason for the change")
  if not reason then return end
  local delta = v - d.balance
  local lines = { "Account " .. d.id .. " (" .. d.owner .. ")", "Now " .. util.money(d.balance), "New " .. util.money(v), "Change " .. (delta > 0 and "+" or "") .. util.money(delta), "Reason: " .. reason, "The money supply changes by the same amount." }
  if not ctx:confirm("Set balance", lines, { yes = "SET", danger = true }) then return end
  local p = { account_id = d.id, new_balance = v, reason = reason }
  local r, bad = ctx:call("admin_set_balance", p, { quiet = true })
  if not r and bad and (bad.err or ""):find("sane range", 1, true) then
    if not ctx:confirm("Extreme balance", { util.money(v) .. " is outside the normal range.", "Set it anyway?" }, { yes = "SET ANYWAY", danger = true }) then return end
    p.confirm_extreme = true
    r, bad = ctx:call("admin_set_balance", p, { quiet = true })
  end
  if r then ctx:say("Balance set to " .. util.money(r.new_balance)) elseif bad then ctx:fail(bad) end
end

local function issue(ctx, d, sign)
  local verb = sign > 0 and "Issue" or "Recall"
  if sign < 0 and d.balance <= 0 then
    ctx:message("Nothing to recall", { d.owner .. " has no money in this account." }, "warn")
    return
  end
  local v = Core.keypad(ctx, { title = verb .. " money", label = sign > 0 and "Amount to issue" or "Amount to take back", kind = "money", limit = sign < 0 and d.balance or nil, subtitle = d.owner .. " has " .. util.money(d.balance) })
  if not v then return end
  local reason = ctx:reason(verb .. " reason")
  if not reason then return end
  local lines = { verb .. " " .. util.money(v) .. (sign > 0 and " to " or " from ") .. d.owner .. " (" .. d.id .. ")", "Balance after: " .. util.money(d.balance + sign * v), "Reason: " .. reason, "The money supply changes by " .. (sign > 0 and "+" or "-") .. util.money(v) .. "." }
  if not ctx:confirm(verb .. " money", lines, { yes = verb:upper(), danger = sign < 0 }) then return end
  if ctx:call("admin_issue", { account_id = d.id, amount = sign * v, reason = reason }) then
    ctx:say((sign > 0 and "Issued " or "Recalled ") .. util.money(v))
  end
end

local DENOMS = { 1, 5, 10, 50, 100, 500, 1000 }

local function write_disk(note)
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" then
      local drive = peripheral.wrap(name)
      if drive.isDiskPresent() and drive.getMountPath() then
        local ok = util.write_atomic(drive.getMountPath() .. "/note.vrb", textutils.serialize(note))
        if ok then pcall(drive.setDiskLabel, string.format("VRN %s $%s", note.serial, note.denom)) end
        return ok
      end
    end
  end
  return false
end

function M.issue_note(ctx, d)
  local opts = {}
  for _, n in ipairs(DENOMS) do opts[#opts + 1] = { label = util.money(n * 100) .. " note", id = n, kind = "panel" } end
  local n = ctx:choose("Reserve Note value", opts, { subtitle = d.owner .. " has " .. util.money(d.balance) })
  if not n then return end
  if d.balance < n * 100 then
    ctx:message("Balance too low", { d.owner .. " has " .. util.money(d.balance) .. ", less than " .. util.money(n * 100) .. "." }, "warn")
    return
  end
  local lines = { "Make a " .. util.money(n * 100) .. " Reserve Note from " .. d.owner .. "?", "The money leaves the account now.", "The note goes onto a disk if this terminal has one in its drive." }
  if not ctx:confirm("Issue note", lines, { yes = "ISSUE", danger = true }) then return end
  local r = ctx:call("admin_issue_note", { account_id = d.id, denomination = n })
  if not r then return end
  local path = "/.vrb/mint/" .. r.note.serial .. ".vrb"
  local saved = util.write_atomic(path, textutils.serialize(r.note))
  if saved then
    local on_disk = write_disk(r.note)
    ctx:message("Note issued", { "Serial " .. r.note.serial, on_disk and "Written to the disk as note.vrb." or "No disk in a drive. Copy " .. path .. " to a disk as note.vrb.", "A copy stays in " .. path .. "." }, "ok")
  else
    ctx:message("Note not saved", { "Serial " .. r.note.serial, "The account was charged but the note could not be saved here.", "Give the money back with ISSUE MONEY." }, "error")
  end
end

local function delete(ctx, d)
  local total = d.balance
  if d.paired then
    local other = ctx:call("admin_account_detail", { account_id = d.paired }, { quiet = true })
    if other then total = total + other.account.balance end
  end
  local lines = { "Delete every account of " .. d.owner .. "?", "The balance of " .. util.money(total) .. " goes to the treasury.", "Jobs and ranks are removed. This cannot be undone." }
  if not ctx:confirm("Delete account", lines, { yes = "DELETE", danger = true }) then return false end
  if not ctx:confirm("Are you sure?", { "Last check.", "Delete " .. d.owner .. " (" .. d.id .. ") for good?" }, { yes = "YES, DELETE", danger = true }) then return false end
  local r = ctx:call("admin_delete_account", { account_id = d.id })
  if r then
    ctx:say("Deleted. " .. util.money(r.refunded) .. " went to the treasury")
    return true
  end
  return false
end

function M.history(ctx, d)
  local r = ctx:call("admin_account_history", { account_id = d.id, limit = 50 })
  if not r then return end
  local rows = {}
  for _, e in ipairs(r.entries) do
    local amount = e.amount or 0
    rows[#rows + 1] = { left = Core.stamp(e.t, ctx.app.s.w < 45) .. " " .. tostring(e.type) .. " " .. tostring(e.note or ""), right = util.money(amount), rcolor = amount < 0 and T.bad or T.good }
  end
  Core.list(ctx, { title = "History of " .. d.owner, subtitle = d.id .. ", newest first", rows = rows, empty = "No activity yet", state = { offset = 0 } })
end

local function info_lines(d, job_text)
  local lines = {}
  local function add(l, v, c) lines[#lines + 1] = { l, v, c } end
  add("Owner", d.owner .. " (" .. (d.is_treasury and "treasury" or d.kind) .. ")")
  add("Balance", util.money(d.balance), d.balance < 0 and T.bad or T.accent)
  add("Status", d.frozen and "FROZEN" or "Active", d.frozen and T.bad or T.good)
  local lock = d.locked
  if lock and lock.untl and lock.untl > util.now() then add("PIN", "locked until " .. util.clock(lock.untl), T.bad)
  elseif lock and (lock.fails or 0) > 0 then add("PIN", util.int(lock.fails) .. " failed tries", T.warn)
  else add("PIN", "ok") end
  add("Linked", d.paired or "none")
  add("Vanguard", d.vanguard_label or "none")
  add("Civic job", job_text)
  add("Audit", d.audit_ok and "balance matches" or "MISMATCH", d.audit_ok and T.good or T.bad)
  return lines
end

local function actions(d)
  local t = d.is_treasury
  return {
    { label = d.frozen and "UNFREEZE" or "FREEZE", id = "freeze", kind = d.frozen and "success" or "danger" },
    { label = "UNLOCK", id = "unlock", kind = "secondary", disabled = t },
    { label = "RESET PIN", id = "pin", kind = "secondary", disabled = t },
    { label = "SET BALANCE", id = "setbal", kind = "primary" },
    { label = "ISSUE MONEY", id = "issue", kind = "success" },
    { label = "RECALL MONEY", id = "recall", kind = "danger" },
    { label = "ISSUE NOTE", id = "note", kind = "primary", disabled = t },
    { label = "SET RANK", id = "rank", kind = "primary", disabled = t },
    { label = "ASSIGN JOB", id = "job", kind = "primary", disabled = t },
    { label = "DELETE", id = "delete", kind = "danger", disabled = t },
  }
end

function M.detail(ctx, id)
  local d, job_text
  local function load()
    local r = ctx:call("admin_account_detail", { account_id = id })
    if not r then return false end
    d = r.account
    job_text = "none"
    if d.civic_jobs and next(d.civic_jobs) then
      local titles = {}
      local jr = ctx:call("admin_list_jobs", nil, { quiet = true })
      for _, j in ipairs(jr and jr.jobs or {}) do if d.civic_jobs[j.id] then titles[#titles + 1] = j.title end end
      job_text = #titles > 0 and table.concat(titles, ", ") or "yes"
    end
    return true
  end
  if not load() then return end
  local function draw(s)
    kit.header(s, d.owner, d.id)
    local y = 5
    for _, ln in ipairs(info_lines(d, job_text)) do
      kit.kv(s, 2, y, s.w - 2, ln[1], util.ellipsis(ln[2], s.w - 4 - #ln[1]), ln[3])
      y = y + 1
    end
    local items = { { label = "\27 BACK", id = "back", kind = "secondary" }, { label = "HISTORY", id = "hist", kind = "primary" } }
    local tall = s.h >= 30
    if not tall then items[#items + 1] = { label = "ACTIONS", id = "menu", kind = "success" } end
    local top = Core.bar_place(s, items, Core.bar_bottom(s))
    if tall then
      y = y + 1
      s:text(2, y, "Recent activity", T.accent)
      y = y + 1
      local hist = d.history or {}
      for i = #hist, math.max(1, #hist - 5), -1 do
        local e = hist[i]
        local right = util.money(e.amount or 0)
        s:text(2, y, util.ellipsis(Core.stamp(e.t, s.w < 45) .. " " .. tostring(e.type) .. " " .. tostring(e.note or ""), s.w - #right - 4), T.ink)
        s:text(s.w - #right, y, right, (e.amount or 0) < 0 and T.bad or T.good)
        y = y + 1
      end
      if #hist == 0 then s:text(2, y, "No activity yet", T.muted); y = y + 1 end
      Core.grid(s, actions(d), y + 1, top - 2)
    end
    Core.bar_draw(s, items)
    kit.footer(s, d.id)
  end
  ctx:show(draw)
  while true do
    local kind, r = ctx:wait()
    local act
    local c0 = ctx.changes
    if kind == "tap" then
      act = r.id
      if act == "back" then return false end
      if act == "menu" then
        local opts = {}
        for _, a in ipairs(actions(d)) do
          if not a.disabled then opts[#opts + 1] = { label = a.label, id = a.id, kind = "panel" } end
        end
        act = ctx:choose("Actions for " .. d.owner, opts)
      end
    elseif kind == "key" and r == "escape" then return false end
    if act == "hist" then M.history(ctx, d)
    elseif act == "freeze" then freeze(ctx, d)
    elseif act == "unlock" then unlock(ctx, d)
    elseif act == "pin" then reset_pin(ctx, d)
    elseif act == "setbal" then set_balance(ctx, d)
    elseif act == "issue" then issue(ctx, d, 1)
    elseif act == "recall" then issue(ctx, d, -1)
    elseif act == "note" then M.issue_note(ctx, d)
    elseif act == "rank" then
      if require("roles.admin.vanguard").assign_rank(ctx, d) then ctx:say("Rank updated") end
    elseif act == "job" then
      if require("roles.admin.jobs").assign_to(ctx, d) then ctx:say("Job assigned") end
    elseif act == "delete" then
      if delete(ctx, d) then return true end
    end
    if ctx.changes ~= c0 then
      if not load() then return false end
    end
    ctx:show(draw)
  end
end

function M.run(ctx)
  local st = { offset = 0, filter = "", all = false, list = { offset = 0 } }
  local data
  local function limit() return util.clamp(ctx.app.s.h - 12, 5, 40) end
  local function fetch()
    return ctx:call("admin_list_accounts", { filter = st.filter ~= "" and st.filter or nil, offset = st.offset, limit = limit(), all_kinds = st.all or nil })
  end
  local function load()
    local r = fetch()
    if r and #r.accounts == 0 and r.total > 0 and r.offset > 0 then
      st.offset = math.max(0, r.total - limit())
      r = fetch()
    end
    if not r then return false end
    data = r
    st.offset = r.offset
    st.list.offset = 0
    return true
  end
  if not load() then return end
  while true do
    local rows = {}
    for _, a in ipairs(data.accounts) do
      local tag = ""
      if a.kind == "savings" then tag = " (sav)" elseif a.kind == "faction" then tag = " (fac)" end
      rows[#rows + 1] = { left = a.owner .. tag .. (a.frozen and " (frozen)" or ""), right = util.money(a.balance), id = a.id, color = a.frozen and T.bad or (a.is_treasury and T.accent or nil) }
    end
    local last = data.offset + #data.accounts
    local buttons = { { label = "SEARCH", id = "search", kind = "primary" } }
    if st.filter ~= "" then buttons[#buttons + 1] = { label = "CLEAR", id = "clear" } end
    buttons[#buttons + 1] = { label = st.all and "NO SAVINGS" or "SAVINGS", id = "all" }
    buttons[#buttons + 1] = { label = "PREV", id = "prev", disabled = data.offset == 0 }
    buttons[#buttons + 1] = { label = "NEXT", id = "next", disabled = last >= data.total }
    local id = Core.list(ctx, {
      title = "Accounts", subtitle = st.filter ~= "" and ("Search: " .. st.filter) or "Touch an account",
      rows = rows, buttons = buttons, state = st.list, empty = "No accounts match",
      footer = data.total > 0 and string.format("Showing %.0f-%.0f of %.0f", data.offset + 1, last, data.total) or "0 accounts",
    })
    if not id then return end
    if id == "search" then
      local f = ctx:text({ title = "Search accounts", label = "Name or number part", raw = true, max = 32, allowed = "^[%w_%-]$" })
      if f then
        st.filter, st.offset = f, 0
        load()
      end
    elseif id == "clear" then st.filter, st.offset = "", 0; load()
    elseif id == "all" then st.all, st.offset = not st.all, 0; load()
    elseif id == "prev" then st.offset = math.max(0, data.offset - limit()); load()
    elseif id == "next" then st.offset = data.offset + limit(); load()
    else
      M.detail(ctx, id)
      load()
    end
  end
end

return M
