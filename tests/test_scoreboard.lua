local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")
local ser = dofile(REPO .. "/vrb/lib/ser.lua")

T.solo({}, function()
  local stats = require("roles.scoreboard.stats")
  local cfg = require("lib.cfg").load()
  local tbl = stats.build(cfg)
  local names, bad = {}, 0
  for _, e in ipairs(tbl.list) do
    if names[e.name] or #e.name > 16 or not e.name:match("^[%w_%.%+%-]+$") then bad = bad + 1 end
    names[e.name] = true
  end
  T.eq(bad, 0, "objective names are unique, short and use allowed characters")
  T.check(#tbl.list > 90, "objective table covers every statistic the bank reads (" .. #tbl.list .. ")")
  T.eq(tbl.by_key["minecraft.killed:minecraft:zombie"].criterion, "minecraft.killed:minecraft.zombie", "entity criterion")
  T.eq(tbl.by_key["minecraft.custom:minecraft.play_time"].criterion, "minecraft.custom:minecraft.play_time", "custom criterion stays")
  T.eq(tbl.by_key["minecraft.custom:minecraft.time_since_last_death"].criterion, "minecraft.custom:minecraft.time_since_death", "real death statistic")
  T.eq(tbl.by_key["minecraft.killed:minecraft.player"].criterion, "playerKillCount", "player kills criterion")
  T.eq(tbl.by_key["minecraft.used:minecraft:cobblestone"].criterion, "minecraft.used:minecraft.cobblestone", "item criterion")
  T.eq(tbl.by_key["minecraft.custom:minecraft.walk_one_cm"].criterion, "minecraft.custom:minecraft.walk_one_cm", "explore criterion")
  local again = stats.build(cfg)
  T.eq(again.by_key["minecraft.killed:minecraft:zombie"].name, tbl.by_key["minecraft.killed:minecraft:zombie"].name, "names are deterministic")

  local scores, found = stats.parse_scores({ "Alice has 2 scores:", "[vrb_k_zombie]: 5", "[other]: 4", "vrb_k_spider: 7" }, { vrb_k_zombie = "z", vrb_k_spider = "s" })
  T.check(found == 2 and scores.z == 5 and scores.s == 7, "parse bracketed and plain score lines")
  local _, f2, empty = stats.parse_scores({ "Alice has no scores to show" }, {})
  T.check(f2 == 0 and empty, "empty scores recognised")
  T.eq(table.concat(stats.parse_online({ "There are 3 of a max of 20 players online: Alice, Bob_2, Cy" }), ","), "Alice,Bob_2,Cy", "parse online players")
  T.eq(#stats.parse_online({ "There are 0 of a max of 20 players online: " }), 0, "no players online")
  T.eq(stats.parse_dimension({ 'Alice has the following entity data: "minecraft:the_nether"' }), "minecraft:the_nether", "parse dimension")
  T.eq(stats.parse_dimension({ "Alice has the following entity data: -1" }), "minecraft:the_nether", "parse old numeric dimension")
  T.eq(stats.parse_get({ "Alice has 42 [vrb_k_zombie]" }), 42, "parse players get")
  local cmd = stats.tellraw("Alice", 'say "hi" \\ there\nnext', "green")
  T.check(cmd:find('say \\"hi\\" \\\\ there next', 1, true) and cmd:find('"color":"green"', 1, true), "tellraw escapes quotes and backslashes")
  T.eq(stats.tellraw("Al ice;kill @a", "x", "red"), nil, "tellraw refuses a bad name")
  T.check(stats.tellraw("Alice", "x", "evil"):find('"color":"white"', 1, true), "unknown colors fall back to white")
end)

local function ticks(minutes) return minutes * 60 * 20 end

local function make_mock()
  local M = { log = {}, objectives = {}, count = 0, tells = {}, deaf = {}, crowd = {}, online = { "Alice", "Bob", "Carol" } }
  local values = {
    Alice = {
      ["minecraft.custom:minecraft.play_time"] = ticks(40), ["minecraft.killed:minecraft.zombie"] = 20,
      ["minecraft.custom:minecraft.walk_one_cm"] = 800000, ["minecraft.custom:minecraft.damage_taken"] = 50,
      ["minecraft.custom:minecraft.time_since_death"] = 30000,
    },
    Bob = { ["minecraft.custom:minecraft.play_time"] = ticks(41), ["minecraft.custom:minecraft.walk_one_cm"] = 800000 },
    Carol = { ["minecraft.custom:minecraft.play_time"] = ticks(50), ["minecraft.killed:minecraft.zombie"] = 10 },
  }
  local dims = { Alice = "minecraft:overworld", Bob = "minecraft:the_nether", Carol = "minecraft:overworld" }
  local function criterion_ok(c)
    return c:match("^minecraft%.[a-z]+:minecraft%.[a-z_]+$") ~= nil or c == "playerKillCount"
  end
  function M.exec(cmd)
    M.log[#M.log + 1] = cmd
    M.count = M.count + 1
    if cmd == "list" then
      return true, { "There are " .. #M.online .. " of a max of 20 players online: " .. table.concat(M.online, ", ") }
    elseif cmd == "scoreboard objectives list" then
      local parts = {}
      for name in pairs(M.objectives) do parts[#parts + 1] = "[" .. name .. "]" end
      if #parts == 0 then return true, { "There are no objectives" } end
      table.sort(parts)
      return true, { "There are " .. #parts .. " objectives: " .. table.concat(parts, ", ") }
    end
    local name, crit = cmd:match("^scoreboard objectives add (%S+) (%S+)$")
    if name then
      if M.objectives[name] then return false, { "An objective already exists by that name" } end
      if #name > 16 or not name:match("^[%w_%.%+%-]+$") then return false, { "Invalid objective name" } end
      if not criterion_ok(crit) then return false, { "Unknown scoreboard criterion '" .. crit .. "'" } end
      M.objectives[name] = crit
      return true, { "Created new objective [" .. name .. "]" }
    end
    local who = cmd:match("^scoreboard players list (%S+)$")
    if who and M.crowd[who] then
      local lines = { who .. " has many scores:" }
      for oname, c in pairs(M.objectives) do
        lines[#lines + 1] = "[" .. oname .. "]: " .. (c == "minecraft.custom:minecraft.play_time" and ticks(30) or 7)
      end
      return true, lines
    end
    if who then
      if who == "Carol" then return true, { "Carol -> layout from another version", "no brackets here" } end
      local lines = { who .. " has some scores:" }
      local names = {}
      for oname, c in pairs(M.objectives) do if values[who] and values[who][c] then names[#names + 1] = oname end end
      table.sort(names)
      for _, oname in ipairs(names) do
        local v = values[who][M.objectives[oname]]
        lines[#lines + 1] = (who == "Alice") and ("[" .. oname .. "]: " .. v) or (oname .. ": " .. v)
      end
      if #names == 0 then return true, { who .. " has no scores to show" } end
      return true, lines
    end
    local p, o = cmd:match("^scoreboard players get (%S+) (%S+)$")
    if p then
      local c = M.objectives[o]
      local v = c and values[p] and values[p][c]
      if v then return true, { p .. " has " .. v .. " [" .. o .. "]" } end
      return false, { "Can't get value of " .. o .. " for " .. p .. "; none is set" }
    end
    local dp = cmd:match("^data get entity (%S+) Dimension$")
    if dp then return true, { dp .. ' has the following entity data: "' .. (dims[dp] or "minecraft:overworld") .. '"' } end
    local owner, rest = cmd:match("^tellraw (%S+) (.+)$")
    if owner then
      if M.deaf[owner] then return false, { "No player was found" } end
      M.tells[#M.tells + 1] = { owner = owner, json = rest }
      return true, { "" }
    end
    return false, { "Unknown command" }
  end
  function M.count_for(name)
    local n = 0
    for _, c in ipairs(M.log) do
      if c:find(" " .. name .. " ", 1, true) or c:sub(-#name - 1) == " " .. name then n = n + 1 end
    end
    return n
  end
  return M
end

local function hour_after_start(world)
  local t = os.date("*t", math.floor(world.base_epoch / 1000))
  return (t.hour + 1) % 24
end

local function start(world, C, fn)
  local res = { done = false }
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    res.ok, res.err, res.done = ok, err, true
  end)
  return res
end

local function role() require("roles.scoreboard").run() end

local function setup(owners)
  local world, server = N.world()
  local admin = N.client_pc(world, 2)
  N.run_client(world, admin, function()
    local Client = require("lib.client")
    local c = assert(Client.new({}))
    for _, o in ipairs(owners) do
      local r = c:call("open_account", { owner = o, pin = "1234" })
      T.check(r.ok, "open " .. o)
    end
    local s = c:call("auth_by_owner", { owner = "Alice", pin = "1234" })
    c:call("set_notif_subs", { session = s.session, subs = { daily = true } })
    s = c:call("auth_by_owner", { owner = "Bob", pin = "1234" })
    c:call("set_notif_subs", { session = s.session, subs = { daily = true } })
  end)
  return world, server
end

local function balances(world, owners)
  local out = {}
  local pc = N.client_pc(world, 9)
  N.run_client(world, pc, function()
    local Client = require("lib.client")
    local c = assert(Client.new({}))
    for _, o in ipairs(owners) do
      local s = c:call("auth_by_owner", { owner = o, pin = "1234" })
      out[o] = c:call("balance", { session = s.session }).balance
    end
  end)
  return out
end

do
  local world = setup({ "Alice", "Bob", "Carol" })
  local C = N.client_pc(world, 3, N.keys())
  local mock = make_mock()
  mock.deaf.Bob = true
  C.env.commands = mock
  local res = start(world, C, role)
  world:run({ seconds = 20 })
  T.check(not C.crash and not res.done, "role keeps running")

  local created = 0
  for _ in pairs(mock.objectives) do created = created + 1 end
  T.check(created > 90, "objectives created at start (" .. created .. ")")
  local adds = 0
  for _, c in ipairs(mock.log) do if c:find("^scoreboard objectives add") then adds = adds + 1 end end
  T.eq(adds, created, "no objective added twice and none rejected")

  local before = #mock.log
  C.queue[#C.queue + 1] = { "char", "t" }
  world:run({ seconds = 15 })
  local used = {}
  for i = before + 1, #mock.log do used[#used + 1] = mock.log[i] end
  local function count(name)
    local n = 0
    for _, c in ipairs(used) do if c:find(name, 1, true) then n = n + 1 end end
    return n
  end
  T.check(count("Alice") <= 3, "at most 3 commands for Alice (" .. count("Alice") .. ")")
  T.check(count("Bob") <= 3, "at most 3 commands for Bob (" .. count("Bob") .. ")")
  T.check(count("Carol") > 20 and count("Carol") <= 60, "fallback reads only the matter objectives for Carol (" .. count("Carol") .. ")")

  local paid = balances(world, { "Alice", "Bob", "Carol" })
  T.eq(paid.Alice, 3600, "Alice paid from bracketed output")
  T.eq(paid.Bob, 2300, "Bob paid from plain output with nether bonus")
  T.eq(paid.Carol, 1300, "Carol paid through the fallback")

  local printed = table.concat(C.printed, "\n")
  T.check(printed:find("earnings: 3 read, 3 paid $72.00", 1, true), "earnings summary line printed")
  T.check(#C.printed < 14, "status output stays short (" .. #C.printed .. " lines)")

  world:run({ seconds = 70 })
  local alice_tell
  for _, t in ipairs(mock.tells) do if t.owner == "Alice" then alice_tell = t end end
  T.check(alice_tell and alice_tell.json:find("earned today", 1, true) and alice_tell.json:find('"text":"[VRB] "', 1, true), "bank message delivered with tellraw")
  T.eq(#mock.tells, 1, "offline player is not messaged yet")
  mock.deaf.Bob = nil
  world:run({ seconds = 130 })
  local bob_tells = 0
  for _, t in ipairs(mock.tells) do if t.owner == "Bob" then bob_tells = bob_tells + 1 end end
  T.eq(bob_tells, 1, "queued message delivered once the player is reachable")

  local log_n, ev_n = #mock.log, C.ev_count
  world:run({ seconds = 600 })
  T.eq(#mock.log, log_n, "no game commands while idle")
  T.check(C.ev_count - ev_n <= 25, "computer sleeps between deadlines (" .. (C.ev_count - ev_n) .. " wakes in 10 minutes)")

  local p0 = #C.printed
  C.queue[#C.queue + 1] = { "char", "v" }
  world:run({ seconds = 3 })
  C.queue[#C.queue + 1] = { "char", "d" }
  world:run({ seconds = 3 })
  local later = table.concat(C.printed, "\n", p0 + 1)
  T.check(later:find("Vanguard", 1, true), "V forces the payroll tick")
  T.check(later:find("accounts %d+ %(0 frozen%)") and later:find("bank 10.0.0", 1, true), "D shows diagnostics")

  C.queue[#C.queue + 1] = { "char", "q" }
  world:run({ seconds = 5 })
  T.check(res.done and res.ok, "Q quits cleanly")
end

do
  local world = setup({ "Alice", "Bob", "Carol" })
  local hour = hour_after_start(world)
  local files = N.keys()
  files["/.vrb/config"] = ser.encode({ earnings = { daily_tick_hour = hour } })
  local C = N.client_pc(world, 3, files)
  local mock = make_mock()
  C.env.commands = mock
  local res = start(world, C, role)
  world:run({ seconds = 600 })
  local paid = balances(world, { "Alice" })
  T.eq(paid.Alice, 0, "nothing paid before the configured hour")
  world:run({ seconds = 3700 })
  paid = balances(world, { "Alice", "Bob" })
  T.eq(paid.Alice, 3600, "daily earnings sent at the configured hour")
  T.eq(paid.Bob, 2300, "daily earnings for every online player")
  local state = C.fs.exists("/.vrb/scoreboard.dat") and C.fs.open("/.vrb/scoreboard.dat", "r").readAll() or ""
  T.check(state:find("last_snapshot", 1, true), "last snapshot day is remembered")

  local checker = N.client_pc(world, 8)
  local ok = N.run_client(world, checker, function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    local day = os.day("ingame")
    local r = c:call("admin_day_tick", { mc_day = day }, { admin = true })
    T.check(r.ok and r.paid_already, "payroll was already run for this Minecraft day")
    r = c:call("admin_day_tick", { mc_day = day + 1 }, { admin = true })
    T.check(r.ok and not r.paid_already, "later days are not yet paid")
  end)
  T.check(ok.ok, "checker finished")
  T.check(not C.crash and not res.done, "role still running after a day")
end

do
  local world = setup({ "Alice" })
  local C = N.client_pc(world, 3, N.keys())
  local mock = make_mock()
  local crowd = {}
  for i = 1, 14 do crowd[i] = string.format("Crowd%02d", i) end
  mock.online = crowd
  for _, n in ipairs(crowd) do mock.crowd[n] = true end
  C.env.commands = mock
  local res = start(world, C, role)
  world:run({ seconds = 20 })
  C.queue[#C.queue + 1] = { "char", "t" }
  world:run({ seconds = 40 })
  local printed = table.concat(C.printed, "\n")
  T.check(printed:find("earnings: 14 read, 0 paid $0.00, 0 skipped", 1, true), "large snapshots are split and all players reach the bank")
  T.check(printed:find("not paid (no_account): Crowd01, Crowd02", 1, true), "players without an account are summed up in one line")
  local seen = {}
  N.run_client(world, N.client_pc(world, 8), function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    seen.first = c:call("admin_earnings_state", { owner = "Crowd01" }, { admin = true }).found
    seen.last = c:call("admin_earnings_state", { owner = "Crowd14" }, { admin = true }).found
  end)
  T.check(seen.first and seen.last, "first and last player of a big crowd were processed")
  T.check(not C.crash and not res.done, "role keeps running after a big snapshot")
end

do
  local solo = T.cc.new()
  local C = solo:computer({ id = 4 })
  T.mount(C)
  local mock = make_mock()
  C.env.commands = mock
  local res = {}
  local fn = function() require("tools.scoreboard_check").main({}) end
  T.setenv(fn, C.env)
  solo:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    res.ok, res.err = ok, err
  end)
  solo:run({ seconds = 5 })
  T.check(res.ok, "check tool runs: " .. tostring(res.err))
  local text = table.concat(C.printed, "\n")
  T.check(text:find("There are 3 of a max of 20 players online", 1, true), "check tool shows raw list output")
  T.check(text:find("parsed players: Alice, Bob, Carol", 1, true), "check tool shows parsed players")
  T.check(text:find("scoreboard players list Alice", 1, true), "check tool shows the player list command")
  T.check(text:find("parsed dimension: minecraft:overworld", 1, true), "check tool shows the dimension")
end

do
  local solo = T.cc.new()
  local C = solo:computer({ id = 5, files = {} })
  T.mount(C)
  local res = {}
  local function fn() require("roles.scoreboard").run() end
  T.setenv(fn, C.env)
  solo:start(C, function() local ok, err = xpcall(fn, debug.traceback); res.ok, res.err, res.done = ok, err, true end)
  solo:run({ seconds = 5 })
  T.check(res.done and res.ok, "missing keys end in a message, not an error: " .. tostring(res.err))
  T.check(table.concat(C.printed, "\n"):find("missing keys", 1, true), "missing keys screen")
  T.check(not table.concat(C.printed, "\n"):find("stack traceback", 1, true), "no stack trace shown")
end

T.done()
