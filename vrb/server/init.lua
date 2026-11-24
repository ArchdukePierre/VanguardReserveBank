local cfgmod = require("lib.cfg")
local crypto = require("lib.crypto")
local net = require("lib.net")
local util = require("lib.util")
local DB = require("lib.db")
local Bank = require("server.bank")
local Rpc = require("server.rpc")
local Jobs = require("server.jobs")
local migrate = require("server.migrate")
local pairing = require("lib.pairing")

local M = {}

local MODULES = { "accounts", "payments", "credit", "groups", "commerce", "earnings", "payroll", "community", "admin", "public" }
local PLAIN = { ping = true, public_stats = true, public_ledger_tail = true, list_catalog = true, item_rates = true, list_ranks = true, list_work_orders = true, get_shop = true }

local function paint(lines, last)
  for i, l in ipairs(lines) do
    if last[i] ~= l then
      term.setCursorPos(1, i)
      term.clearLine()
      term.write(l)
      last[i] = l
    end
  end
end

function M.run()
  local cfg = cfgmod.load()
  local say = print
  local secret, admin = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
  if not secret or not admin then
    printError("Missing keys in /.vrb/keys. Run the installer again and pick Bank server.")
    return
  end
  local ok_c, why = crypto.self_test()
  if not ok_c then printError("Crypto self test failed: " .. tostring(why)); return end
  local modem = net.find_modem(cfg.net.modem)
  if not modem then printError("No modem attached. Place a wireless or ender modem on this computer."); return end
  local channel = cfgmod.channel(cfg)
  modem.open(channel)

  local function logfile(line)
    local f = fs.open(cfg.dirs.data .. "/server.log", "a")
    if f then f.writeLine(os.date("%Y-%m-%d %H:%M:%S") .. " " .. line); f.close() end
    local p = cfg.dirs.data .. "/server.log"
    if fs.exists(p) and fs.getSize(p) > 40000 then
      pcall(fs.delete, p .. ".1")
      pcall(fs.move, p, p .. ".1")
    end
  end

  local db = DB.open(cfg.dirs.db, { compact_bytes = cfg.server.compact_bytes, min_free = cfg.server.min_free_bytes, max_bytes = cfg.server.ledger_max_bytes, keep_bytes = cfg.server.ledger_keep_bytes })
  if db.meta.schema == nil then
    local v9 = migrate.find_v9(cfg)
    if v9 then
      say("Found a v9 bank database. Importing.")
      local ok, err = migrate.run(db, cfg, secret, v9, say)
      if not ok then
        printError("Migration failed: " .. tostring(err))
        printError("The v9 files were not changed. Free disk space and reboot to retry.")
        pcall(fs.delete, cfg.dirs.db)
        return
      end
    end
  end
  local bank = Bank.new(db, cfg, secret)
  db.meta.key = db.meta.key or secret
  db:commit()
  if db:needs_compaction() then db:compact() end

  local log = function(line) logfile(line) end
  local jobs = Jobs.new(log)
  local rpc = Rpc.new(bank, cfg, admin)
  local Q = { items = {}, head = 1, tail = 0 }
  local function depth() return Q.tail - Q.head + 1 end
  local ctl = { bank = bank, db = db, rpc = rpc, jobs = jobs, queue = Q, depth = depth, boot_time = util.now(), channel = channel,
    stats = { requests = 0, rejected = 0, rate_limited = 0, duplicates = 0, handler_ms = 0, handler_max = 0, queue_peak = 0, packets = 0, commits_failed = 0 } }
  for _, name in ipairs(MODULES) do require("server." .. name).register(rpc, bank, jobs, ctl) end

  local seen, dedupe, buckets = {}, {}, {}
  local pair = pairing.server(secret, admin, cfg.net.network)

  local function write_floppy()
    for _, name in ipairs(peripheral.getNames()) do
      if peripheral.getType(name) == "drive" then
        local d = peripheral.wrap(name)
        if d.isDiskPresent() and d.getMountPath() then
          local path = d.getMountPath()
          util.write_atomic(path .. "/server.secret", secret)
          util.write_atomic(path .. "/admin.key", admin)
          d.setDiskLabel("VRB keys")
          return true
        end
      end
    end
    return false
  end
  local stats = ctl.stats
  local pump

  local function step()
    if depth() > 0 then pump() end
    sleep(0)
  end

  function ctl.backup()
    local ok, err = db:compact(step)
    if not ok then return false, err end
    local snap = cfg.dirs.db .. "/snap"
    local size = util.dir_size(snap)
    if util.free_space() < size * 2 + cfg.server.min_free_bytes then return false, "not enough free disk space for a backup" end
    local root = cfg.dirs.data .. "/backups"
    util.ensure_dir(root)
    local stamp = os.date("%Y%m%d-%H%M%S")
    fs.copy(snap, root .. "/" .. stamp)
    local all = fs.list(root)
    table.sort(all)
    while #all > cfg.server.backups_keep do fs.delete(root .. "/" .. table.remove(all, 1)) end
    bank.meta.last_backup = util.now()
    bank:meta_touch()
    return true
  end

  jobs.add("compact", 30, function()
    if db:needs_compaction() then
      local ok, err = db:compact(step)
      if not ok then log("compaction failed: " .. tostring(err)) end
    end
  end)
  jobs.add("housekeeping", 20, function()
    bank:gc_sessions()
    net.prune_seen(seen, cfg.net.rpc_window)
    local t = util.now()
    for id, d in pairs(dedupe) do if t - d.t > cfg.server.dedupe_sec then dedupe[id] = nil end end
    for ch, b in pairs(buckets) do if t - b.t > 120 then buckets[ch] = nil end end
  end)
  jobs.add("backup", 600, function()
    if util.now() - (bank.meta.last_backup or 0) >= cfg.server.backup_every_sec then
      local ok, err = ctl.backup()
      if not ok then log("backup skipped: " .. tostring(err)) end
    end
  end)
  jobs.add("verify_ledger", 21600, function()
    local v = { state = "running", started = util.now() }
    ctl.verify = v
    local ok, err, st = db.ledger:verify(step)
    v.state, v.ok, v.err, v.finished = "done", ok, err, util.now()
    v.entries, v.blocks, v.first_seq, v.last_seq = st.entries, st.blocks, st.first_seq, st.last_seq
    if not ok then log("LEDGER VERIFY FAILED: " .. tostring(err)) end
  end)
  jobs.add("broadcast", cfg.server.beacon_sec, function()
    modem.transmit(channel + 1, channel, net.seal(secret, ctl.public_payload(), false))
  end)

  local function reply_to(chan, id, res, plain)
    modem.transmit(chan, channel, net.seal(secret, { i = id, r = res }, not plain))
  end

  local function handle(item, out)
    local payload, why = net.open_env(secret, item.msg, cfg.net.rpc_window, seen)
    if not payload then
      stats.rejected = stats.rejected + 1
      ctl.last_reject = { why = why, t = util.now() }
      return
    end
    local id, method, p = payload.i, payload.m, payload.p
    if type(id) ~= "string" or #id > 40 or type(method) ~= "string" or type(p) ~= "table" then
      stats.rejected = stats.rejected + 1
      return
    end
    local cached = dedupe[id]
    if cached then
      stats.duplicates = stats.duplicates + 1
      out[#out + 1] = { chan = item.chan, id = id, res = cached.res, plain = cached.plain }
      return
    end
    stats.requests = stats.requests + 1
    local t0 = util.ms()
    local res = rpc:dispatch(payload, item.chan)
    local dt = util.ms() - t0
    stats.handler_ms = stats.handler_ms + dt
    if dt > stats.handler_max then stats.handler_max = dt end
    local spec = rpc.methods[method]
    local plain = spec and PLAIN[method] or false
    dedupe[id] = { res = res, t = util.now(), plain = plain }
    if spec and spec.write and res.ok then ctl.writes = (ctl.writes or 0) + 1 end
    out[#out + 1] = { chan = item.chan, id = id, res = res, plain = plain }
  end

  function pump()
    local t0 = util.ms()
    local out = {}
    while Q.head <= Q.tail and util.ms() - t0 < cfg.server.slice_ms do
      local item = Q.items[Q.head]
      Q.items[Q.head] = nil
      Q.head = Q.head + 1
      handle(item, out)
    end
    if Q.head > Q.tail then Q.head, Q.tail = 1, 0 end
    if db:dirty() then
      local ok, err = db:commit()
      if not ok then
        stats.commits_failed = stats.commits_failed + 1
        log("commit failed: " .. tostring(err))
        for _, o in ipairs(out) do o.res = { ok = false, err = "The bank could not save that change. Try again.", code = "storage" } end
      end
    end
    for _, o in ipairs(out) do reply_to(o.chan, o.id, o.res, o.plain) end
    return #out
  end

  local function enqueue(chan, msg)
    stats.packets = stats.packets + 1
    local t = os.epoch("utc") / 1000
    local b = buckets[chan]
    if not b then b = { tokens = cfg.server.rate_burst, t = t }; buckets[chan] = b end
    b.tokens = math.min(cfg.server.rate_burst, b.tokens + (t - b.t) * cfg.server.rate_per_sec)
    b.t = t
    if b.tokens < 1 then stats.rate_limited = stats.rate_limited + 1; return end
    b.tokens = b.tokens - 1
    if type(msg) ~= "table" or msg.v ~= 3 then stats.rejected = stats.rejected + 1; return end
    if depth() >= cfg.server.queue_max then stats.rate_limited = stats.rate_limited + 1; return end
    Q.tail = Q.tail + 1
    Q.items[Q.tail] = { chan = chan, msg = msg }
    if depth() > stats.queue_peak then stats.queue_peak = depth() end
    os.queueEvent("vrb_work")
  end

  rpc.stats = stats
  local recovered = db.recovered
  if recovered > 0 then log("recovered " .. recovered .. " ledger blocks from the journal") end
  local lok, lerr = db.ledger:verify_tail()
  local last_lines, shown = {}, false
  local started_ms = util.ms()

  local function dashboard()
    local w, h = term.getSize()
    local st = db.store
    local free = util.free_space()
    local lines = {
      "VANGUARD RESERVE BANK  v" .. cfg.VERSION .. "  server",
      string.rep("-", w),
      string.format("Network    %s  (channel %d)", cfg.net.network, channel),
      string.format("Uptime     %s", util.duration(util.now() - ctl.boot_time)),
      string.format("Accounts   %d    Sessions %d", bank.accounts:count(), util.count(bank.sessions)),
      string.format("Requests   %d    Rejected %d    Throttled %d", stats.requests, stats.rejected, stats.rate_limited),
      string.format("Handler    avg %.1f ms   max %d ms   queue %d (peak %d)", stats.requests > 0 and stats.handler_ms / stats.requests or 0, stats.handler_max, depth(), stats.queue_peak),
      string.format("Storage    commits %d   journal %d B   compactions %d", st.commits, st.jbytes, st.compactions),
      string.format("Disk free  %s%s", free == math.huge and "?" or (math.floor(free / 1024) .. " KB"), bank.db:writable() and "" or "   LOW: WRITES PAUSED"),
      string.format("Ledger     %d entries   head %s   %s", bank.meta.ledger_seq, bank.meta.ledger_head:sub(1, 8), lok and "ok" or ("CHECK: " .. tostring(lerr))),
      string.format("Supply     %s", util.money(bank.meta.money_supply)),
      "",
      "Keys: [P] pair a computer  [S] pair staff  [F] keys to floppy",
      "      [B] backup  [V] verify ledger  [A] audit  [Q] quit",
    }
    local pa = pair:state()
    if pa then
      lines[#lines + 1] = string.format("PAIRING %s code: %s  (%ds left)", pa.staff and "STAFF" or "node", pa.code, pa.expires - util.now())
    elseif ctl.pair_open then
      modem.close(pairing.CHANNEL)
    end
    ctl.pair_open = pa ~= nil
    if ctl.message then lines[#lines + 1] = ctl.message end
    for i = 1, #lines do lines[i] = lines[i]:sub(1, w) end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    if not shown then term.clear(); shown = true end
    paint(lines, last_lines)
  end

  say("Serving on channel " .. channel .. ".")
  dashboard()

  parallel.waitForAny(
    function()
      while true do
        local _, _, ch, reply, msg = os.pullEvent("modem_message")
        if ch == channel then
          enqueue(reply, msg)
        elseif ch == pairing.CHANNEL then
          local resp, kind = pair:handle(msg)
          if resp then
            modem.transmit(reply, pairing.CHANNEL, resp)
            modem.close(pairing.CHANNEL)
            ctl.message = "Paired a " .. kind .. " computer."
            log("paired a " .. kind .. " computer on channel " .. reply)
          end
        end
      end
    end,
    function()
      while true do
        if depth() > 0 then
          pump()
          sleep(0)
        else
          jobs.tick(step)
          if db:dirty() then pump() end
          if depth() == 0 then
            local delay = math.max(0.5, math.min(jobs.next_delay(), 5))
            local tid = os.startTimer(delay)
            while true do
              local ev, a = os.pullEvent()
              if ev == "vrb_work" then os.cancelTimer(tid); break end
              if ev == "timer" and a == tid then break end
            end
          end
        end
      end
    end,
    function()
      while true do
        sleep(10)
        dashboard()
      end
    end,
    function()
      while true do
        local _, key = os.pullEvent("key")
        if key == keys.p or key == keys.s then
          modem.open(pairing.CHANNEL)
          pair:start(key == keys.s, 180)
          ctl.message = nil
        elseif key == keys.f then
          ctl.message = write_floppy() and "Keys written to the floppy disk (including the admin key)." or "Put a floppy disk in a disk drive first."
        elseif key == keys.b then
          ctl.message = "Backup: " .. (select(2, ctl.backup()) or "done")
        elseif key == keys.v then
          jobs.run_now("verify_ledger")
          ctl.message = "Ledger verification started"
        elseif key == keys.a then
          local r = bank:audit()
          ctl.message = string.format("Audit: %d accounts, %d mismatched", r.accounts, #r.mismatched)
        elseif key == keys.q then
          db:commit()
          return
        end
        dashboard()
      end
    end
  )
  db:commit()
end

return M
