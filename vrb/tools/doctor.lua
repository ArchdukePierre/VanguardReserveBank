local cfgmod = require("lib.cfg")
local util = require("lib.util")
local net = require("lib.net")

local M = {}

local function line(kind, text)
  local c = ({ ok = colors.lime, warn = colors.orange, fail = colors.red, info = colors.lightGray })[kind]
  if term.isColor and term.isColor() then term.setTextColor(c) end
  print(({ ok = "[ok]   ", warn = "[warn] ", fail = "[FAIL] ", info = "       " })[kind] .. text)
  if term.isColor and term.isColor() then term.setTextColor(colors.white) end
end

function M.main()
  local cfg = cfgmod.load()
  local role = cfgmod.role()
  print("Vanguard Reserve Bank " .. cfg.VERSION .. " health check")
  print("")
  if role then line("ok", "Role: " .. role) else line("fail", "No role. Run the installer.") end
  line(fs.exists("/startup.lua") and "ok" or "warn", fs.exists("/startup.lua") and "Startup file present" or "No /startup.lua, so nothing starts at boot")
  local secret, admin = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
  line(secret and "ok" or "fail", secret and "server.secret present" or "server.secret missing (run: vrb join)")
  if role == "admin" or role == "mint" or role == "scoreboard" or role == "server" then
    line(admin and "ok" or "fail", admin and "admin.key present" or "admin.key missing (run: vrb join staff)")
  end
  local m, name = net.find_modem(cfg.net.modem)
  if not m then line("fail", "No modem attached")
  elseif m.isWireless and not m.isWireless() then line("warn", "Modem " .. name .. " is wired. A wireless or ender modem is needed to reach other computers.")
  else line("ok", "Modem " .. name .. (m.isWireless and m.isWireless() and " (wireless)" or "")) end
  line("info", "Network " .. cfg.net.network .. ", channel " .. cfgmod.channel(cfg))
  local free = util.free_space()
  if free ~= math.huge then
    line(free < 60000 and "fail" or free < 150000 and "warn" or "ok", "Disk free " .. math.floor(free / 1024) .. " KB of " .. math.floor((fs.getCapacity and fs.getCapacity("/") or 0) / 1024) .. " KB")
  end
  line(http and "ok" or "warn", http and "HTTP is on (updates work)" or "HTTP is off (updates will not work)")

  if role == "server" and secret then
    local DB = require("lib.db")
    local Bank = require("server.bank")
    if not fs.exists(cfg.dirs.db) then
      line("warn", "No bank data yet. It is created on the first start.")
      return
    end
    local db = DB.open(cfg.dirs.db, {})
    local bank = Bank.new(db, cfg, secret)
    line("ok", string.format("%d accounts, %d journal bytes, %d KB of snapshots", bank.accounts:count(), db.store.jbytes, math.floor(util.dir_size(cfg.dirs.db .. "/snap") / 1024)))
    local audit = bank:audit()
    line(#audit.mismatched == 0 and "ok" or "fail", #audit.mismatched == 0 and "Every account matches its posted entries" or (#audit.mismatched .. " accounts do not match their entries: " .. table.concat(audit.mismatched, ", ", 1, math.min(5, #audit.mismatched))))
    local ok, err, st = db.ledger:verify(function() sleep(0) end)
    line(ok and "ok" or "fail", ok and string.format("Ledger chain intact, %d entries in %d blocks", st.entries, st.blocks) or ("Ledger problem: " .. tostring(err)))
    if fs.exists(cfg.dirs.data .. "/bank.db") then line("warn", "A v9 database is waiting to be imported. Start the server to import it.") end
    if fs.exists(cfg.dirs.data .. "/legacy") then line("info", "Old v9 files are in /.vrb/legacy. Delete the folder when you no longer need it: delete /.vrb/legacy") end
  elseif secret and m then
    local Client = require("lib.client")
    local c = Client.new({ timeout = 2, retries = 2 })
    if c then
      local t0 = os.epoch("utc")
      local r = c:call("ping", {})
      local ms = os.epoch("utc") - t0
      if r.ok then
        line("ok", "Bank answered in " .. ms .. " ms (v" .. tostring(r.version) .. ")")
        if r.version ~= cfg.VERSION then line("warn", "Bank is on " .. tostring(r.version) .. " and this computer is on " .. cfg.VERSION .. ". Run: vrb update") end
        if r.writable == false then line("warn", "The bank's disk is nearly full. Changes are paused.") end
      else
        line("fail", "No answer from the bank: " .. tostring(r.err) .. ". Check the server is running, both modems are active and the network name matches.")
      end
    end
  end
end

return M
