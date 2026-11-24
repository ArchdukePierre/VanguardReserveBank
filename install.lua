local BASE = "https://raw.githubusercontent.com/ArchdukePierre/VanguardReserveBank/"
local args = { ... }

local ROLES = {
  { id = "server", label = "Bank server", note = "One per bank. Holds every account. Needs a wireless or ender modem." },
  { id = "atm", label = "ATM", note = "Customer touchscreen on Advanced Monitors. Needs a modem." },
  { id = "admin", label = "Staff terminal", note = "Admin console. Needs a staff pairing code." },
  { id = "viewer", label = "Public dashboard", note = "Read-only economy board on a monitor." },
  { id = "shop", label = "Shop kiosk", note = "Sells one player shop's items from a monitor." },
  { id = "mint", label = "Mint station", note = "Issues physical Reserve Notes. Staff code, disk drive or printer." },
  { id = "pos", label = "Pocket POS", note = "Shopkeeper tabs on a pocket computer." },
  { id = "scoreboard", label = "Earnings reader", note = "Command Computer that pays play earnings and salaries." },
}

local function paint(color, text)
  if term.isColor and term.isColor() then term.setTextColor(color) end
  print(text)
  if term.isColor and term.isColor() then term.setTextColor(colors.white) end
end
local function ok(t) paint(colors.lime, "  + " .. t) end
local function bad(t) paint(colors.red, "  ! " .. t) end
local function info(t) paint(colors.lightGray, "  " .. t) end
local function head(t) print(""); paint(colors.yellow, t) end

local function ask(prompt, default)
  write(prompt .. (default and (" [" .. default .. "]") or "") .. ": ")
  local s = read()
  if s == nil or s == "" then return default end
  return s
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
paint(colors.yellow, "Vanguard Reserve Bank installer")
paint(colors.lightGray, string.rep("-", 31))

if not http then
  bad("The HTTP API is off. Set http.enabled = true in the CC:Tweaked config and restart the world.")
  return
end

local want_role, ref = nil, "main"
local updating = false
for _, a in ipairs(args) do
  if a == "update" then
    updating = true
  else
    local known = false
    for _, r in ipairs(ROLES) do if r.id == a then known = true; want_role = a end end
    if not known then ref = a end
  end
end

local function fetch(path)
  local ok_h, h, err = pcall(http.get, BASE .. ref .. "/" .. path)
  if not ok_h or not h then return nil, tostring(err or h) end
  local body = h.readAll()
  h.close()
  if not body or #body == 0 then return nil, "empty reply" end
  return body
end

head("Reading the file list (" .. ref .. ")")
local mtext, merr = fetch("manifest.lua")
if not mtext then bad("Could not download the manifest: " .. tostring(merr)); info("Check the internet connection and that raw.githubusercontent.com is allowed."); return end
local mfn = load(mtext, "manifest", "t", {})
local manifest = mfn and mfn()
if type(manifest) ~= "table" or type(manifest.files) ~= "table" then bad("The manifest is damaged."); return end
ok("Version " .. tostring(manifest.version) .. ", " .. #manifest.files .. " files")

local role = want_role
if updating and not role and fs.exists("/.vrb/role") then
  local f = fs.open("/.vrb/role", "r"); role = (f.readAll() or ""):gsub("%s", ""); f.close()
end

local has_modem, has_monitor, has_drive = false, false, false
for _, n in ipairs(peripheral.getNames()) do
  local t = peripheral.getType(n)
  if t == "modem" then has_modem = true elseif t == "monitor" then has_monitor = true elseif t == "drive" then has_drive = true end
end

if not role then
  head("What is this computer for?")
  local rec
  if pocket then rec = "pos" elseif commands then rec = "scoreboard" end
  for i, r in ipairs(ROLES) do
    paint(r.id == rec and colors.lime or colors.white, string.format("  %d  %-17s %s", i, r.label, r.id == rec and "(suggested)" or ""))
    info("     " .. r.note)
  end
  info("Modem: " .. (has_modem and "yes" or "NO") .. "   Monitor: " .. (has_monitor and "yes" or "no") .. "   Disk drive: " .. (has_drive and "yes" or "no"))
  while not role do
    local s = ask("Number", nil)
    local n = tonumber(s)
    if n and ROLES[n] then role = ROLES[n].id
    else for _, r in ipairs(ROLES) do if r.id == s then role = r.id end end end
    if not role then bad("Pick a number from the list.") end
  end
end

local function wanted(entry)
  if entry.all then return true end
  for _, r in ipairs(entry.roles or {}) do if r == role then return true end end
  return false
end

local list, total = {}, 0
for _, e in ipairs(manifest.files) do
  if wanted(e) then list[#list + 1] = e; total = total + e.size end
end
head("Downloading " .. #list .. " files (" .. math.floor(total / 1024) .. " KB) for the " .. role .. " role")
local function dir_size(p)
  if not fs.exists(p) then return 0 end
  if not fs.isDir(p) then return fs.getSize(p) end
  local n = 0
  for _, name in ipairs(fs.list(p)) do n = n + dir_size(fs.combine(p, name)) end
  return n
end
local free = fs.getFreeSpace("/")
if free + dir_size("/vrb") < total + 16384 then
  bad("Not enough disk space (" .. math.floor(free / 1024) .. " KB free). Raise computer_space_limit in the CC:Tweaked server config or clear files.")
  return
end

local bodies = {}
for i, e in ipairs(list) do
  local body, err = fetch(e.path)
  if not body then bad(e.path .. ": " .. tostring(err)); return end
  if #body ~= e.size then bad(e.path .. ": size " .. #body .. " does not match " .. e.size); return end
  bodies[i] = body
  local _, y = term.getCursorPos()
  term.setCursorPos(1, y)
  term.clearLine()
  write(string.format("  %d/%d  %s", i, #list, e.path))
end
print("")

local sha_ok = false
do
  local env = setmetatable({}, { __index = _G })
  for i, e in ipairs(list) do
    if e.path == "vrb/lib/crypto.lua" then
      local fn = load(bodies[i], "crypto", "t", env)
      local crypto = fn and fn()
      if crypto and crypto.self_test and crypto.self_test() then
        sha_ok = true
        for j, f in ipairs(list) do
          if f.sha and crypto.sha256(bodies[j]) ~= f.sha then bad(f.path .. ": checksum mismatch"); return end
        end
      end
    end
  end
end
ok(sha_ok and "All checksums match" or "Downloaded (checksums skipped)")

if fs.exists("/vrb") then fs.delete("/vrb") end
for i, e in ipairs(list) do
  local dest = "/" .. (e.dest or e.path)
  local dir = fs.getDir(dest)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f = fs.open(dest, "w")
  if not f then bad("Cannot write " .. dest); return end
  f.write(bodies[i])
  f.close()
end
ok("Program files written to /vrb")

local function put(path, text)
  local f = fs.open(path, "w")
  f.write(text)
  f.close()
end
if not fs.exists("/.vrb") then fs.makeDir("/.vrb") end
put("/.vrb/role", role)
put("/vrb.lua", 'shell.run("/vrb/boot.lua", ...)\n')
put("/startup.lua", 'local ok = shell.run("/vrb/boot.lua")\nif not ok then\n  print("VRB stopped with an error. Restarting in 8 seconds. Press Ctrl+T to stay in the shell.")\n  sleep(8)\n  os.reboot()\nend\n')
ok("Startup file written. The " .. role .. " role runs on every boot.")

package.path = "/vrb/?.lua;/vrb/?/init.lua;" .. package.path
local cfgmod = require("lib.cfg")
local crypto = require("lib.crypto")
local util = require("lib.util")

local staff_role = (role == "admin" or role == "mint" or role == "scoreboard")

if role == "server" then
  head("Bank keys")
  if cfgmod.read_key("server.secret") and cfgmod.read_key("admin.key") then
    ok("Keys already exist. Keeping them.")
  else
    info("Type some random letters and press Enter. This mixes your typing into the key.")
    write("> ")
    local mash = read()
    crypto.add_entropy(tostring(mash) .. os.epoch("utc"))
    util.ensure_dir("/.vrb/keys")
    util.write_atomic("/.vrb/keys/server.secret", crypto.random_hex(64))
    util.write_atomic("/.vrb/keys/admin.key", crypto.random_hex(64))
    ok("server.secret and admin.key created in /.vrb/keys")
  end
  local cfg = cfgmod.load()
  if not updating then
    local name = ask("Bank network name (every computer of this bank uses the same name)", cfg.net.network)
    if name and name ~= cfg.net.network then
      local ser = require("lib.ser")
      local over = ser.decode(util.read_file(cfg.path) or "") or {}
      over.net = over.net or {}
      over.net.network = name
      cfgmod.save_override(cfg.path, over)
    end
  end
  if fs.exists("/.vrb/bank.db") then ok("Found a v9 bank database. It is imported on the first start.") end
  head("Next steps")
  info("Reboot, then on the server screen press P to pair a computer or S to pair staff.")
  info("Other computers run the installer, pick their role and type the code.")
elseif not updating then
  head("Keys")
  if cfgmod.read_key("server.secret") and (not staff_role or cfgmod.read_key("admin.key")) then
    ok("Keys already present.")
  else
    local paired = require("tools.pair").join(staff_role)
    if not paired then
      bad("Not paired yet. Run 'vrb join" .. (staff_role and " staff" or "") .. "' when you have a code.")
    end
  end
end

if role == "shop" and not fs.exists("/.vrb/shop.cfg") and not updating then
  head("Shop")
  local id = ask("Shop id (create the shop at an ATM first, it looks like SHP-1A2B3C4D)", nil)
  if id then
    local ser = require("lib.ser")
    util.write_atomic("/.vrb/shop.cfg", ser.encode({ shop_id = id }))
  end
end
if role == "scoreboard" and not commands then bad("This is not a Command Computer. The earnings reader needs one.") end
if (role == "atm" or role == "admin" or role == "viewer" or role == "shop") and not has_monitor then info("No monitor found. The program will use this terminal until you attach one.") end
if not has_modem then bad("No modem found. Attach a wireless or ender modem before the first start.") end

print("")
paint(colors.lime, "Done. Rebooting in 4 seconds.")
sleep(4)
os.reboot()
