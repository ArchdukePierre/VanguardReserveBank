local cfgmod = require("lib.cfg")
local util = require("lib.util")
local ser = require("lib.ser")
local Client = require("lib.client")
local stats = require("roles.scoreboard.stats")

local M = {}

local STATE = "/.vrb/scoreboard.dat"
local PULL_SEC = 60
local RETRY_SEC = 300
local MAX_BODY = 9000
local PENDING_MAX = 200
local PENDING_AGE = 6 * 3600

local function paint(color)
  if color and term.isColor and term.isColor() then term.setTextColor(color) end
end

local function say(text, color)
  paint(color)
  print(util.clock() .. " " .. text)
  paint(colors.white)
end

local function fail_once(ctx, key, text)
  if ctx.fails[key] ~= text then say(text, colors.red) end
  ctx.fails[key] = text
end

local function recovered(ctx, key)
  ctx.fails[key] = nil
end

local function fatal(title, lines)
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  paint(colors.red)
  print("SCOREBOARD: " .. title)
  paint(colors.white)
  for _, l in ipairs(lines or {}) do print(l) end
end

local function load_state()
  local t = ser.decode(util.read_file(STATE) or "")
  return type(t) == "table" and t or {}
end

local function seconds_until(hour)
  local t = os.date("*t")
  local d = hour * 3600 - (t.hour * 3600 + t.min * 60 + t.sec)
  if d <= 0 then d = d + 86400 end
  return d + 1
end

local function past_hour(hour)
  local t = os.date("*t")
  return t.hour * 3600 + t.min * 60 + t.sec >= hour * 3600
end

local function today() return os.date("%Y%m%d") end

local function setup_objectives(ctx)
  local ok, lines = ctx.exec("scoreboard objectives list")
  local have = ok and stats.parse_objectives(lines) or {}
  local made, failed, first = 0, 0, nil
  for _, e in ipairs(ctx.tbl.list) do
    if not have[e.name] then
      local aok, alines = ctx.exec("scoreboard objectives add " .. e.name .. " " .. e.criterion)
      if aok then
        made = made + 1
      else
        local text = table.concat(stats.lines(alines), " ")
        if not text:lower():find("already exists", 1, true) then
          failed = failed + 1
          first = first or text
        end
      end
      sleep(0)
    end
  end
  say(string.format("objectives: %d ready, %d created", #ctx.tbl.list - failed, made), colors.lightGray)
  if failed > 0 then say(string.format("%d objectives failed: %s", failed, util.ellipsis(first or "", 30)), colors.red) end
end

local function read_player(ctx, name)
  local ok, lines = ctx.exec("scoreboard players list " .. name)
  local scores, found, empty = {}, 0, false
  if ok then scores, found, empty = stats.parse_scores(lines, ctx.tbl.by_name) end
  if ok and found == 0 and not empty and #stats.lines(lines) > 0 then
    for i, e in ipairs(ctx.tbl.essential) do
      local gok, glines = ctx.exec("scoreboard players get " .. name .. " " .. e.name)
      local v = gok and stats.parse_get(glines)
      if v then
        scores[e.key] = v
        found = found + 1
      end
      if i % 10 == 0 then sleep(0) end
    end
  end
  if found == 0 then return nil end
  local dok, dlines = ctx.exec("data get entity " .. name .. " Dimension")
  if dok then scores._dimension = stats.parse_dimension(dlines) end
  return scores
end

local function split(snaps)
  local names = {}
  for name in pairs(snaps) do names[#names + 1] = name end
  table.sort(names)
  local parts, cur, size = {}, {}, 0
  for _, name in ipairs(names) do
    local n = #ser.encode(snaps[name]) + #name + 8
    if size + n > MAX_BODY and next(cur) then
      parts[#parts + 1] = cur
      cur, size = {}, 0
    end
    cur[name] = snaps[name]
    size = size + n
  end
  if next(cur) then parts[#parts + 1] = cur end
  return parts
end

local function snapshot(ctx)
  local ok, lines = ctx.exec("list")
  local names = ok and stats.parse_online(lines) or {}
  if #names == 0 then
    say("earnings: no players online", colors.lightGray)
    return true
  end
  local snaps, read = {}, 0
  for _, name in ipairs(names) do
    local s = read_player(ctx, name)
    if s then
      snaps[name] = s
      read = read + 1
    end
    sleep(0)
  end
  if read == 0 then
    say(string.format("earnings: no statistics for %d players", #names), colors.orange)
    return true
  end
  local paid, total, skipped, problems = 0, 0, 0, {}
  for _, part in ipairs(split(snaps)) do
    local r = ctx.client:call("admin_submit_snapshot", { snapshots = part }, { admin = true })
    if not r.ok then
      fail_once(ctx, "earnings", "earnings failed: " .. tostring(r.err))
      return r.code ~= "timeout"
    end
    for owner, info in pairs(r.results or {}) do
      if info.skipped then skipped = skipped + 1 end
      if not info.error and not info.skipped and (info.total or 0) > 0 then paid, total = paid + 1, total + info.total end
      if info.error then
        local list = problems[info.error] or {}
        list[#list + 1] = owner
        problems[info.error] = list
      end
    end
  end
  recovered(ctx, "earnings")
  say(string.format("earnings: %d read, %d paid %s, %d skipped", read, paid, util.money(total), skipped), colors.lime)
  for code, list in pairs(problems) do
    table.sort(list)
    say(string.format("not paid (%s): %s", code, util.ellipsis(table.concat(list, ", "), 36)), colors.orange)
  end
  return true
end

local function show_tick(r, mc_day)
  if r.paid_already then
    say(string.format("day %d: already paid", mc_day), colors.lightGray)
  else
    say(string.format("day %d: Vanguard %s (%d), civic %s (%d)", mc_day, util.money(r.payroll_total or 0), r.payroll_count or 0, util.money(r.civic_total or 0), r.civic_count or 0), colors.yellow)
  end
end

local function day_tick(ctx, force)
  local mc_day = os.day("ingame")
  local r = ctx.client:call("admin_day_tick", { mc_day = mc_day, force = force or nil }, { admin = true })
  if not r.ok then
    fail_once(ctx, "payroll", "payroll failed: " .. tostring(r.err))
    return false
  end
  recovered(ctx, "payroll")
  show_tick(r, mc_day)
  return true
end

local function send(ctx, n)
  local cmd = stats.tellraw(n.owner, n.message, n.color)
  if not cmd then return true end
  local ok = ctx.exec(cmd)
  return ok
end

local function deliver(ctx)
  local r = ctx.client:call("admin_pull_notifications", { limit = 50, clear = true }, { admin = true })
  if not r.ok then
    fail_once(ctx, "messages", "messages failed: " .. tostring(r.err))
    return
  end
  if ctx.fails.messages then say("messages: bank is back", colors.lightGray) end
  recovered(ctx, "messages")
  local pending = ctx.pending
  local sent, now = 0, util.now()
  for _, n in ipairs(r.notifications or {}) do
    if type(n) == "table" and type(n.owner) == "string" then
      if send(ctx, n) then
        sent = sent + 1
        if sent % 10 == 0 then sleep(0) end
      else
        n.queued = now
        pending[#pending + 1] = n
      end
    end
  end
  if #pending > 0 then
    local ok, lines = ctx.exec("list")
    local online = {}
    for _, name in ipairs(ok and stats.parse_online(lines) or {}) do online[name:lower()] = true end
    local keep = {}
    for _, n in ipairs(pending) do
      if now - (n.queued or now) <= PENDING_AGE then
        if online[n.owner:lower()] and send(ctx, n) then sent = sent + 1 else keep[#keep + 1] = n end
      end
    end
    while #keep > PENDING_MAX do table.remove(keep, 1) end
    ctx.pending = keep
  end
  if sent > 0 then say(string.format("messages: %d delivered", sent), colors.yellow) end
end

local function diagnostics(ctx)
  local r = ctx.client:call("admin_diagnostics", {}, { admin = true })
  if not r.ok then
    say("diagnostics failed: " .. tostring(r.err), colors.red)
    return
  end
  print(string.format("bank %s, up %s", tostring(r.version), util.duration(r.uptime_sec)))
  print(string.format("accounts %d (%d frozen), supply %s", r.accounts or 0, r.accounts_frozen or 0, util.money(r.money_supply or 0)))
  print(string.format("requests %d, rejected %d, errors %d", r.requests or 0, r.rejected or 0, r.errors or 0))
  print(string.format("ledger %d entries, disk free %d KB", r.ledger_entries or 0, math.floor((r.free_space_bytes or 0) / 1024)))
  if (r.farm_flags_pending or 0) > 0 or (r.audit_mismatched or 0) > 0 then
    paint(colors.orange)
    print(string.format("%d farm flags pending, %d audit mismatches", r.farm_flags_pending or 0, r.audit_mismatched or 0))
    paint(colors.white)
  end
  if r.writable == false then say("bank storage is full, writes paused", colors.red) end
end

local function guard(name, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then say(name .. " error: " .. util.ellipsis(tostring(err), 40), colors.red) end
  return ok and err
end

function M.run()
  local cfg = cfgmod.load()
  local secret, admin = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
  if not secret or not admin then
    return fatal("missing keys", {
      secret and "server.secret: found" or "server.secret: MISSING",
      admin and "admin.key: found" or "admin.key: MISSING",
      "",
      "Copy both files from the bank install disk",
      "to /.vrb/keys and start this computer again.",
    })
  end
  local exec = stats.find_exec()
  if not exec then
    return fatal("no command access", { "This role needs a Command Computer.", "Run it on one, or attach one with a modem." })
  end
  local client, why = Client.new({ admin = admin })
  if not client then return fatal("network problem", { tostring(why) }) end
  local ok = exec("list")
  if not ok then return fatal("commands are refused", { "The command computer cannot run /list.", "Check that commands are enabled on the server." }) end

  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  paint(colors.yellow)
  print("VRB scoreboard " .. cfg.VERSION)
  paint(colors.lightGray)
  print("T earnings  V payroll  D info  Q quit")
  paint(colors.white)

  local hour = tonumber(cfg.earnings.daily_tick_hour) or 4
  local ctx = { exec = exec, client = client, tbl = stats.build(cfg), pending = {}, state = load_state(), fails = {} }
  local ping = client:call("ping", {})
  if ping.ok then say("bank online, v" .. tostring(ping.version), colors.lime) else say("bank not responding, will keep trying", colors.orange) end
  setup_objectives(ctx)

  local clock = os.clock()
  local deadlines = { pull = clock + 5, snapshot = clock + seconds_until(hour) }
  if ctx.state.last_snapshot and ctx.state.last_snapshot ~= today() and past_hour(hour) then deadlines.snapshot = clock end
  local last_day
  guard("payroll", function() if day_tick(ctx) then last_day = os.day("ingame") end end)
  say(string.format("earnings run daily at %02d:00", hour), colors.lightGray)

  local function run_snapshot()
    local done = guard("earnings", snapshot, ctx)
    local c = os.clock()
    if done then
      ctx.state.last_snapshot = today()
      util.write_atomic(STATE, ser.encode(ctx.state))
      deadlines.snapshot = c + seconds_until(hour)
    else
      deadlines.snapshot = c + RETRY_SEC
    end
  end

  while true do
    local name, at
    for k, t in pairs(deadlines) do
      if not at or t < at then name, at = k, t end
    end
    local tid = os.startTimer(math.max(0, at - os.clock()))
    local ev, a = os.pullEventRaw()
    os.cancelTimer(tid)
    if ev == "terminate" then
      say("stopped", colors.lightGray)
      return
    elseif ev == "char" then
      local k = tostring(a):lower()
      if k == "q" then
        say("stopped", colors.lightGray)
        return
      elseif k == "t" then
        run_snapshot()
      elseif k == "v" then
        guard("payroll", day_tick, ctx, true)
      elseif k == "d" then
        guard("diagnostics", diagnostics, ctx)
      end
    elseif ev == "timer" and a == tid then
      local c = os.clock() + 0.25
      if deadlines.snapshot <= c then run_snapshot() end
      if deadlines.pull <= c then
        guard("messages", deliver, ctx)
        deadlines.pull = os.clock() + PULL_SEC
      end
      local d = os.day("ingame")
      if last_day ~= d then
        if guard("payroll", day_tick, ctx) then last_day = d end
      end
    end
  end
end

return M
