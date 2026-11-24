local T = dofile(HERE .. "/lib.lua")

T.solo({}, function()
  local DB = require("lib.db")
  local util = require("lib.util")

  local function read(p) local f = fs.open(p, "r"); local s = f.readAll(); f.close(); return s end
  local function write(p, s) if fs.exists(p) then fs.delete(p) end; local f = fs.open(p, "w"); f.write(s); f.close() end

  local db = DB.open("/d1", { compact_bytes = 1e9 })
  local acc = db:coll("accounts")
  acc:put("A1", { id = "A1", balance = 5, hist = {} })
  for i = 1, 5 do acc:append("A1", "hist", { t = i, y = "x", a = i }, 3) end
  acc:put("A2", { id = "A2", balance = 7, hist = {} })
  db:log("test", { x = 1 })
  T.check(db:commit(), "first commit")
  local r = acc:get("A1")
  T.eq(#r.hist, 3, "history capped at 3")
  T.eq(r.hist[3].i, 5, "entries are numbered")
  local db2 = DB.open("/d1", {})
  local r2 = db2:coll("accounts"):get("A1")
  T.check(r2 and #r2.hist == 3 and r2.hist[3].i == 5 and r2.n_hist == 5, "history survives a restart")
  T.eq(db2:coll("accounts"):count(), 2, "both accounts survive")

  db2:coll("accounts"):get("A2").balance = 99
  db2:coll("accounts"):touch("A2")
  T.check(db2:commit(), "second commit")
  local jf
  for _, n in ipairs(fs.list("/d1")) do if n:match("^journal%.") then jf = "/d1/" .. n end end
  local text = read(jf)
  write(jf, text:sub(1, #text - 12))
  local db3 = DB.open("/d1", {})
  T.eq(db3:coll("accounts"):get("A2").balance, 7, "a half written batch is dropped")
  T.eq(db3:coll("accounts"):get("A1").balance, 5, "older batches stay")

  local db4 = DB.open("/d2", { compact_bytes = 1e9 })
  local c4 = db4:coll("accounts")
  for i = 1, 60 do c4:put("ACC-" .. i, { id = "ACC-" .. i, balance = i, hist = {} }) end
  local sh = db4:coll("loans")
  for i = 1, 40 do sh:put("L" .. i, { n = i }) end
  T.check(db4:commit(), "bulk commit")
  local count = 0
  local ok = pcall(function() db4:compact(function() count = count + 1; if count == 5 then error("power cut") end end) end)
  T.check(not ok, "compaction was interrupted")
  c4:get("ACC-3").balance = 333
  c4:touch("ACC-3")
  local db5 = DB.open("/d2", {})
  T.eq(db5:coll("accounts"):count(), 60, "all accounts present after an interrupted compaction")
  T.eq(db5:coll("loans"):count(), 40, "all loans present after an interrupted compaction")
  T.check(db5:needs_compaction(), "reopened store asks for compaction")
  T.check(db5:compact(), "compaction completes after the restart")
  local db6 = DB.open("/d2", {})
  T.eq(db6:coll("accounts"):get("ACC-9").balance, 9, "data intact after a full compaction")
  T.check(#fs.list("/d2") <= 3, "old journals are removed after compaction")

  local db7 = DB.open("/d3", { compact_bytes = 1e9 })
  db7:coll("accounts"):put("H", { id = "H", balance = 0, hist = {} })
  for i = 1, 4 do db7:coll("accounts"):append("H", "hist", { t = i, y = "p", a = 1 }, 10) end
  db7:commit()
  local jf3
  for _, n in ipairs(fs.list("/d3")) do if n:match("^journal%.") then jf3 = "/d3/" .. n end end
  local saved = read(jf3)
  db7:compact()
  write("/d3/journal.1", saved)
  local db8 = DB.open("/d3", {})
  T.eq(#db8:coll("accounts"):get("H").hist, 4, "replaying an old journal does not duplicate history")

  local db9 = DB.open("/d4", { compact_bytes = 1e9, max_bytes = 700, keep_bytes = 1400 })
  for i = 1, 60 do
    db9:log("transfer", { from = "ACC-1", to = "ACC-2", amount = i })
    if i % 3 == 0 then db9:commit() end
  end
  db9:commit()
  local vok, verr, st = db9.ledger:verify()
  T.check(vok, "ledger verifies across rotated files (" .. tostring(verr) .. ")")
  T.check(fs.exists("/d4/ledger") and #fs.list("/d4/ledger") >= 1, "ledger rotated into archives")
  local total = 0
  for _, n in ipairs(fs.list("/d4/ledger")) do total = total + fs.getSize("/d4/ledger/" .. n) end
  T.check(total <= 1400 + 800, "archives stay under the keep limit (" .. total .. ")")
  local lt = read("/d4/ledger.log")
  write("/d4/ledger.log", (lt:gsub("amount=5(%d)", "amount=9%1", 1)))
  local db10 = DB.open("/d4", {})
  local bad = db10.ledger:verify()
  T.check(not bad, "tampering is detected")
  write("/d4/ledger.log", lt)

  local db11 = DB.open("/d5", { compact_bytes = 1e9 })
  db11:log("a", { n = 1 }); db11:commit()
  db11:log("a", { n = 2 }); db11:commit()
  local lt2 = read("/d5/ledger.log")
  local cut = lt2:find("\n#2|", 1, true)
  write("/d5/ledger.log", lt2:sub(1, cut))
  local db12 = DB.open("/d5", {})
  T.check(db12.recovered >= 1, "a ledger block lost in a crash is rebuilt from the journal")
  T.check(db12.ledger:verify(), "ledger verifies after recovery")
  local tail = db12.ledger:recent(5)
  T.eq(#tail, 2, "ledger tail has both entries")
end)

local world = T.cc.new()
local C = world:computer({ id = 1, capacity = 1000000 })
T.mount(C)
C.F.capacity = C.F.used + 60000
local out = {}
local fn = T.setenv(function()
  local DB = require("lib.db")
  local db = DB.open("/d", { compact_bytes = 1e9, min_free = 20000 })
  local acc = db:coll("accounts")
  local failed_at
  for i = 1, 2000 do
    acc:put("ACC-" .. i, { id = "ACC-" .. i, balance = i, hist = {} })
    local ok, err = db:commit()
    if not ok then failed_at = i; T.check(err == "disk_full", "commit reports disk_full"); break end
  end
  T.check(failed_at ~= nil and failed_at > 20, "writes stop before the disk is completely full")
  T.check(not db:writable(), "writable() turns false")
  local db2 = DB.open("/d", {})
  T.check(db2:coll("accounts"):count() >= failed_at - 1, "everything committed before the limit is intact")
  out.done = true
end, C.env)
world:start(C, function() local ok, e = xpcall(fn, debug.traceback); if not ok then print(e); T.failed = T.failed + 1 end end)
world:run({ seconds = 5, stop = function() return out.done end })
T.check(out.done, "disk full scenario ran")
T.done()
