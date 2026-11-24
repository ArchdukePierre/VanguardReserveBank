local util = require("lib.util")
local crypto = require("lib.crypto")
local common = require("server.common")

local fail, notify = common.fail, common.notify
local floor = math.floor
local M = {}

local function stat_delta(prev, curr)
  if type(prev) ~= "number" then return curr or 0, false end
  if type(curr) ~= "number" then return 0, false end
  if curr < prev then return 0, true end
  return curr - prev, false
end

local function threshold_pay(value, tiers)
  local pay = 0
  for _, t in ipairs(tiers) do
    if value >= (t.blocks or t.count or t.damage or 0) then pay = t.pay end
  end
  return pay
end

local function day_gap(last_day)
  local s = tostring(last_day)
  local y, m, d = tonumber(s:sub(1, 4)), tonumber(s:sub(5, 6)), tonumber(s:sub(7, 8))
  if not (y and m and d) then return nil end
  return floor((util.now() - os.time({ year = y, month = m, day = d, hour = 12 })) / 86400)
end

function M.register(rpc, bank, jobs)
  local cfg = bank.cfg
  local E = cfg.earnings
  local states = bank.db:coll("earn")
  local lasts = bank.db:coll("elast")
  local hists = bank.db:coll("ehist")
  local flags = bank.db:coll("flags")
  local outbox = bank.db:coll("outbox")
  local meta = bank.meta

  local function streak_tier(days)
    local tier, idx = E.streak_tiers[1], 1
    for i, t in ipairs(E.streak_tiers) do if days >= t.day then tier, idx = t, i end end
    return tier, idx
  end

  local function state_for(key)
    local s = states:get(key)
    if not s then
      s = { score = {}, streak = 0, last_day = nil, grace = 0, last_snap = 0, insured_until = nil, build_streak = 0, boss = {}, last_death = nil }
      states:put(key, s)
    end
    return s
  end

  local function death_penalty(st)
    local days = st.streak or 0
    local insured = st.insured_until and st.insured_until > util.now()
    local drop = E.streak_drop_tiers
    if insured then drop = math.max(0, floor(drop * 0.5)) end
    local _, idx = streak_tier(days)
    local new_idx = math.max(1, idx - drop)
    st.streak = E.streak_tiers[new_idx].day
    st.penalty_from = days
    return st.streak
  end

  local function compute(owner, snap, session_sec)
    local key = owner:lower()
    local st = state_for(key)
    local prev = st.score or {}
    local date_key = tonumber(os.date("%Y%m%d"))
    if st.last_day == date_key then return { skipped = "already_ran_today" } end
    local b = { owner = owner, date = date_key, survival_wage = 0, combat_pay = 0, explorer_bonus = 0, builder_bonus = 0, danger_pay = 0, boss_bounty = 0,
      build_streak_bonus = 0, base = 0, streak_mult = 1.0, dimension_mult = 1.0, total = 0, flagged = {}, components = {}, streak_before = st.streak, died_today = false }
    local tsd_key = "minecraft.custom:minecraft.time_since_last_death"
    local tsd_prev, tsd_curr = prev[tsd_key] or 0, snap[tsd_key] or 0
    if tsd_curr < tsd_prev or (tsd_curr < 1200 and st.last_snap > 0) then
      b.died_today = true
      st.last_death = util.now()
    end
    local play_prev = prev["minecraft.custom:minecraft.play_time"] or prev["minecraft.custom:minecraft.play_one_minute"] or 0
    local play_curr = snap["minecraft.custom:minecraft.play_time"] or snap["minecraft.custom:minecraft.play_one_minute"] or 0
    local play_sec = math.max(0, play_curr - play_prev) / 20
    if session_sec then play_sec = math.max(play_sec, session_sec) end
    b.play_sec = play_sec
    if play_sec < E.min_session_sec then
      b.skipped = "below_session_threshold"
      return b
    end
    b.survival_wage = E.survival_wage
    local combat = 0
    for entity, weight in pairs(E.combat_tier) do
      local k = "minecraft.killed:" .. entity
      local delta = stat_delta(prev[k], snap[k])
      if delta > E.combat_velocity_limit then
        b.flagged[entity] = delta
        local fid = "FLG-" .. crypto.random_hex(12)
        flags:put(fid, { id = fid, owner = owner, entity = entity, count = delta, weight = weight, estimated_pay = delta * weight * E.combat_unit_cents, ts = util.now(), status = "pending" })
        bank:log("farm_flag", { flag = fid, owner = owner, entity = entity, count = delta })
        delta = 0
      end
      if delta > 0 then
        combat = combat + delta * weight
        b.components[entity] = (b.components[entity] or 0) + delta * weight
      end
    end
    if meta.pvp_enabled then
      local d = stat_delta(prev["minecraft.killed:minecraft.player"], snap["minecraft.killed:minecraft.player"])
      combat = combat + d * 2
    end
    b.combat_pay = math.min(combat * E.combat_unit_cents, E.combat_daily_cap)
    for entity, bounty in pairs(E.boss_bounty) do
      local k = "minecraft.killed:" .. entity
      local delta = stat_delta(prev[k], snap[k])
      if delta > 0 then
        if entity == "minecraft:ender_dragon" then
          if not st.boss.ender_dragon then b.boss_bounty = b.boss_bounty + bounty; st.boss.ender_dragon = true end
        else
          b.boss_bounty = b.boss_bounty + bounty * delta
        end
      end
    end
    local cm = 0
    for _, stat in ipairs(E.explore_stats) do cm = cm + stat_delta(prev[stat], snap[stat]) end
    local blocks = floor(cm / 100)
    local explore = threshold_pay(blocks, E.explore_tiers)
    local dim = snap["_dimension"]
    if dim == "minecraft:the_nether" or dim == "minecraft:the_end" then
      b.dimension_mult = 1 + E.nether_end_bonus
      explore = floor(explore * b.dimension_mult)
    end
    b.explorer_bonus, b.blocks_traveled = explore, blocks
    local built = 0
    for block, weight in pairs(E.build_materials) do
      local placed = stat_delta(prev["minecraft.used:" .. block], snap["minecraft.used:" .. block])
      local mined = stat_delta(prev["minecraft.mined:" .. block], snap["minecraft.mined:" .. block])
      built = built + math.max(0, placed - mined) * weight
    end
    built = floor(built)
    b.blocks_built = built
    b.builder_bonus = threshold_pay(built, E.build_tiers)
    if built >= 2000 then
      st.build_streak = (st.build_streak or 0) + 1
      if st.build_streak == 3 then b.build_streak_bonus = E.build_streak_pay end
    else
      st.build_streak = 0
    end
    if not b.died_today then
      local dmg = stat_delta(prev["minecraft.custom:minecraft.damage_taken"], snap["minecraft.custom:minecraft.damage_taken"])
      b.damage_taken = dmg
      b.danger_pay = threshold_pay(dmg, E.danger_tiers)
    end
    b.base = b.survival_wage + b.combat_pay + b.explorer_bonus + b.builder_bonus + b.danger_pay + b.boss_bounty + b.build_streak_bonus
    if b.died_today then
      death_penalty(st)
    else
      local gap = st.last_day and day_gap(st.last_day) or 0
      if gap == 0 and st.last_day ~= nil then
      elseif gap <= 1 + E.streak_grace_days then
        st.streak = (st.streak or 0) + 1
        st.grace = math.max(0, gap - 1)
      else
        st.streak, st.grace = 1, 0
      end
    end
    local tier = streak_tier(st.streak)
    b.streak_mult, b.streak_label, b.streak_after = tier.mult, tier.label, st.streak
    b.total = floor(b.base * b.streak_mult)
    b.multiplied = b.total
    if st.insured_until and st.insured_until > util.now() then b.insurance_active = true end
    st.score, st.last_day, st.last_snap = snap, date_key, util.now()
    states:touch(key)
    return b
  end

  local function pay(owner, b)
    local key = owner:lower()
    local acct = bank:primary(owner)
    if not b then return b end
    if b.skipped == "already_ran_today" then return b end
    if b.skipped then lasts:put(key, b); return b end
    if not acct then b.error = "no_account"; lasts:put(key, b); return b end
    if acct.frozen then b.error = "account_frozen"; lasts:put(key, b); return b end
    local amt = b.total or 0
    if amt > 0 then
      bank:post(acct, amt, "earnings", string.format("Daily earnings (streak day %d, %.2fx)", b.streak_after or 0, b.streak_mult or 1))
      bank:supply(amt)
      bank:count_tx()
      bank:log("earnings", { account = acct.id, owner = owner, amount = amt, survival = b.survival_wage, combat = b.combat_pay, explore = b.explorer_bonus, build = b.builder_bonus,
        danger = b.danger_pay, boss = b.boss_bounty, streak = b.streak_after, mult = b.streak_mult, died = b.died_today })
    elseif b.died_today then
      bank:log("death_penalty", { account = acct.id, owner = owner, before = b.streak_before, after = b.streak_after })
    end
    lasts:put(key, b)
    local h = hists:get(key) or {}
    h[#h + 1] = { t = util.now(), date = b.date, total = b.total or 0, survival_wage = b.survival_wage, combat_pay = b.combat_pay, explorer_bonus = b.explorer_bonus,
      builder_bonus = b.builder_bonus, danger_pay = b.danger_pay, boss_bounty = b.boss_bounty, build_streak_bonus = b.build_streak_bonus,
      streak_days = b.streak_after, streak_mult = b.streak_mult, died = b.died_today and true or false }
    while #h > E.history_depth do table.remove(h, 1) end
    hists:put(key, h)
    return b
  end

  local function charge_insurance(owner)
    local st = states:get(owner:lower())
    if not st or not st.insured_until or st.insured_until <= util.now() then return end
    if not st.insured_charge or st.insured_charge + E.insurance_duration <= util.now() then
      local a = bank:checking_of(owner)
      if a and a.balance >= E.insurance_cost then
        bank:post(a, -E.insurance_cost, "insurance", "Death Insurance renewal")
        bank:supply(-E.insurance_cost)
        st.insured_charge = util.now()
        st.insured_until = util.now() + E.insurance_duration
        bank:log("insurance_charge", { account = a.id, amount = E.insurance_cost })
      else
        st.insured_until = util.now()
        bank:log("insurance_lapse", { account = a and a.id, owner = owner })
      end
      states:touch(owner:lower())
    end
  end

  rpc:method("admin_submit_snapshot", { write = true, auth = "admin", p = { snapshots = "tbl", session_sec = "num?" }, doc = "Daily stat snapshots from the scoreboard reader" }, function(ctx, p)
    if not meta.earnings_enabled then return fail("Earnings are off") end
    local results, total, count = {}, 0, 0
    local names = {}
    for owner in pairs(p.snapshots) do names[#names + 1] = owner end
    table.sort(names)
    for _, owner in ipairs(names) do
      local snap = p.snapshots[owner]
      if type(owner) == "string" and #owner >= 2 and #owner <= 32 and owner:match("^[A-Za-z0-9_]+$") and type(snap) == "table" then
        local b = compute(owner, snap, p.session_sec)
        pay(owner, b)
        charge_insurance(owner)
        results[owner] = { total = b.error and 0 or (b.total or 0), skipped = b.skipped, died = b.died_today, streak = b.streak_after, error = b.error }
        if b.total and b.total > 0 and not b.error then total, count = total + b.total, count + 1 end
        if b.error then
        elseif b.died_today then
          notify(bank, owner, "death", "red", string.format("You died. Streak dropped from %d to %d.", b.streak_before or 0, b.streak_after or 0))
        elseif b.total and b.total > 0 then
          local extra = ""
          if b.streak_mult and b.streak_mult > 1 then extra = string.format(" (streak day %d, %.2fx)", b.streak_after or 0, b.streak_mult) end
          notify(bank, owner, "daily", "green", string.format("+%s earned today%s", util.money(b.total), extra))
          for _, t in ipairs(E.streak_tiers) do
            if (b.streak_before or 0) < t.day and (b.streak_after or 0) >= t.day and t.day > 0 then
              notify(bank, owner, "streak", "gold", string.format("Streak milestone: %s tier (%.2fx)", t.label, t.mult))
            end
          end
        end
        local st = states:get(owner:lower())
        if st and st.insured_until then
          local left = floor((st.insured_until - util.now()) / 86400)
          st.warned = st.warned or 0
          if left == cfg.notify.insurance_warn_days and util.now() - st.warned > 86400 then
            notify(bank, owner, "insurance", "yellow", string.format("Death Insurance expires in %d days.", left))
            st.warned = util.now()
            states:touch(owner:lower())
          end
        end
      end
    end
    meta.last_earnings = util.now()
    bank:meta_touch()
    bank:log("earnings_tick", { players = count, total = total })
    return { ok = true, results = results, total_paid = total, players = count }
  end)

  rpc:method("admin_set_earnings_enabled", { write = true, auth = "admin", p = { enabled = "bool" } }, function(ctx, p)
    meta.earnings_enabled = p.enabled
    bank:meta_touch()
    bank:log("earnings_toggle", { enabled = p.enabled })
    return { ok = true, enabled = p.enabled }
  end)

  rpc:method("admin_set_pvp_enabled", { write = true, auth = "admin", p = { enabled = "bool" } }, function(ctx, p)
    meta.pvp_enabled = p.enabled
    bank:meta_touch()
    bank:log("pvp_toggle", { enabled = p.enabled })
    return { ok = true, enabled = p.enabled }
  end)

  rpc:method("admin_earnings_state", { auth = "admin", p = { owner = "user" } }, function(ctx, p)
    local st = states:get(p.owner:lower())
    if not st then return { ok = true, found = false } end
    return { ok = true, found = true, state = { streak_days = st.streak, last_active_day = st.last_day, insurance_until = st.insured_until, build_streak = st.build_streak, boss_claimed = st.boss, last_death_ts = st.last_death }, last_breakdown = lasts:get(p.owner:lower()) }
  end)

  rpc:method("admin_set_streak", { write = true, auth = "admin", p = { owner = "user", days = "int" } }, function(ctx, p)
    if p.days < 0 or p.days > 10000 then return fail("Days must be 0 to 10000") end
    local st = state_for(p.owner:lower())
    st.streak = p.days
    states:touch(p.owner:lower())
    bank:log("streak_override", { owner = p.owner, days = p.days })
    return { ok = true, streak_days = p.days }
  end)

  rpc:method("my_earnings", { auth = "session", doc = "Latest daily earnings breakdown and streak" }, function(ctx)
    local key = ctx.acct.owner:lower()
    local st = states:get(key)
    local days = st and st.streak or 0
    local tier = streak_tier(days)
    local b = lasts:get(key)
    local out
    if b and b.date then out = b end
    return { ok = true, breakdown = out, streak_days = days, streak_mult = tier.mult, streak_label = tier.label, insurance_active = (st and st.insured_until and st.insured_until > util.now()) and true or false,
      insurance_until = st and st.insured_until, enabled = meta.earnings_enabled, insurance_cost = E.insurance_cost }
  end)

  rpc:method("buy_insurance", { write = true, auth = "session" }, function(ctx)
    local a = ctx.acct
    if a.balance < E.insurance_cost then return fail("You need " .. util.money(E.insurance_cost)) end
    local st = state_for(a.owner:lower())
    bank:post(a, -E.insurance_cost, "insurance", "Death Insurance policy")
    bank:supply(-E.insurance_cost)
    local start = (st.insured_until and st.insured_until > util.now()) and st.insured_until or util.now()
    st.insured_until = start + E.insurance_duration
    st.insured_charge = util.now()
    states:touch(a.owner:lower())
    bank:log("insurance_charge", { account = a.id, amount = E.insurance_cost })
    return { ok = true, insurance_until = st.insured_until, balance = a.balance }
  end)

  rpc:method("cancel_insurance", { write = true, auth = "session" }, function(ctx)
    local st = state_for(ctx.acct.owner:lower())
    st.insured_until = util.now()
    states:touch(ctx.acct.owner:lower())
    bank:log("insurance_cancel", { account = ctx.acct.id })
    return { ok = true }
  end)

  rpc:method("my_notif_subs", { auth = "session" }, function(ctx)
    local s = common.subs_for(bank, ctx.acct.owner:lower())
    local out = {}
    for _, ch in ipairs(cfg.notify.channels) do out[#out + 1] = { id = ch[1], default = ch[2], label = ch[3], description = ch[4], subscribed = s[ch[1]] and true or false } end
    return { ok = true, channels = out }
  end)

  rpc:method("set_notif_subs", { write = true, auth = "session", p = { subs = "tbl" } }, function(ctx, p)
    local key = ctx.acct.owner:lower()
    local s = common.subs_for(bank, key)
    for _, ch in ipairs(cfg.notify.channels) do
      if p.subs[ch[1]] ~= nil then s[ch[1]] = p.subs[ch[1]] and true or false end
    end
    bank.db:coll("subs"):touch(key)
    return { ok = true, subs = s }
  end)

  rpc:method("my_earnings_history", { auth = "session", p = { limit = "int+?" } }, function(ctx, p)
    local h = hists:get(ctx.acct.owner:lower()) or {}
    local limit = math.min(p.limit or 30, E.history_depth)
    local out = {}
    for i = #h, math.max(1, #h - limit + 1), -1 do out[#out + 1] = h[i] end
    local week, total = {}, 0
    local comps = { survival_wage = 0, combat_pay = 0, explorer_bonus = 0, builder_bonus = 0, danger_pay = 0, boss_bounty = 0, build_streak_bonus = 0 }
    for i = math.max(1, #h - 6), #h do
      local e = h[i]
      week[#week + 1] = e
      total = total + (e.total or 0)
      for k in pairs(comps) do comps[k] = comps[k] + (e[k] or 0) end
    end
    return { ok = true, history = out, week = week, week_total = total, week_components = comps }
  end)

  rpc:method("admin_pull_notifications", { write = true, auth = "admin", p = { limit = "int+?", clear = "bool?" }, doc = "Pending in-game messages for the scoreboard reader" }, function(ctx, p)
    local ids = outbox:ids()
    local n = math.min(p.limit or 50, #ids)
    local out = {}
    for i = 1, n do
      out[i] = outbox:get(ids[i])
      if p.clear then outbox:del(ids[i]) end
    end
    return { ok = true, notifications = out, remaining = #ids - (p.clear and n or 0) }
  end)

  rpc:method("admin_list_farm_flags", { auth = "admin" }, function()
    local out = {}
    for id, f in flags:pairs() do
      if f.status == "pending" then out[#out + 1] = { id = id, owner = f.owner, entity = f.entity, count = f.count, estimated_pay = f.estimated_pay, ts = f.ts } end
    end
    table.sort(out, function(x, y) return x.ts < y.ts end)
    return { ok = true, flags = common.cap(out, 150) }
  end)

  rpc:method("admin_review_flag", { write = true, auth = "admin", p = { flag_id = "id", action = { "confirm", "override" } } }, function(ctx, p)
    local f = flags:get(p.flag_id)
    if not f or f.status ~= "pending" then return fail("That flag is not pending") end
    f.decided = util.now()
    if p.action == "confirm" then
      f.status = "confirmed"
      bank:log("farm_flag_confirm", { flag = f.id, owner = f.owner })
    else
      f.status = "override"
      local acc = bank:checking_of(f.owner)
      if acc and not acc.frozen then
        bank:post(acc, f.estimated_pay, "farm_flag_override", "Admin override on flag " .. f.id)
        bank:supply(f.estimated_pay)
        bank:log("farm_flag_override", { flag = f.id, owner = f.owner, paid = f.estimated_pay, account = acc.id })
      end
    end
    flags:touch(f.id)
    return { ok = true, status = f.status }
  end)

  jobs.add("streak_warnings", 3600, function()
    local nstate = bank.db:coll("nstate")
    for key, st in states:pairs() do
      if st.streak and st.streak > 0 and st.last_day then
        local gap = day_gap(st.last_day)
        if gap and gap >= 1 and gap <= 1 + E.streak_grace_days then
          local ns = nstate:get(key) or {}
          local cool = cfg.notify.streak_warn_hours * 3600
          if not ns.last_streak_warn or util.now() - ns.last_streak_warn > cool then
            local acct = bank:primary(key)
            local owner = acct and acct.owner or key
            notify(bank, owner, "streak", "yellow", string.format("Streak warning: day %d streak ends in about %dh. Play 20+ minutes today to keep it.", st.streak, (1 + E.streak_grace_days - gap) * 24))
            ns.last_streak_warn = util.now()
            nstate:put(key, ns)
          end
        end
      end
    end
  end)

  bank.streak_tier = streak_tier
end

return M
