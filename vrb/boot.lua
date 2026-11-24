local args = { ... }

package.path = "/vrb/?.lua;/vrb/?/init.lua;" .. package.path

local cfgmod = require("lib.cfg")
local util = require("lib.util")

local function out(color, text)
  if term.isColor and term.isColor() then term.setTextColor(color) end
  print(text)
  if term.isColor and term.isColor() then term.setTextColor(colors.white) end
end

local ROLES = { server = "server", atm = "roles.atm", admin = "roles.admin", viewer = "roles.viewer", shop = "roles.shop", mint = "roles.mint", scoreboard = "roles.scoreboard", pos = "roles.pos" }

local function run_role(name)
  local mod = ROLES[name]
  if not mod then
    out(colors.red, "Unknown role: " .. tostring(name))
    return
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  if name == "server" then
    require("server.init").run()
  else
    require(mod).run()
  end
end

local function status()
  local cfg = cfgmod.load()
  local role = cfgmod.role() or "(none)"
  out(colors.yellow, "Vanguard Reserve Bank " .. cfg.VERSION)
  print("Role      : " .. role)
  print("Network   : " .. cfg.net.network .. " (channel " .. cfgmod.channel(cfg) .. ")")
  print("Keys      : server.secret " .. (cfgmod.read_key("server.secret") and "yes" or "NO") .. ", admin.key " .. (cfgmod.read_key("admin.key") and "yes" or "no"))
  local net = require("lib.net")
  local m, name = net.find_modem(cfg.net.modem)
  print("Modem     : " .. (m and (name .. (m.isWireless and m.isWireless() and " (wireless)" or " (wired)")) or "NONE"))
  local free = util.free_space()
  print("Disk free : " .. (free == math.huge and "?" or (math.floor(free / 1024) .. " KB")))
  if role == "server" then
    print("Data      : " .. math.floor(util.dir_size(cfg.dirs.db) / 1024) .. " KB in " .. cfg.dirs.db)
  end
  if role ~= "server" and role ~= "(none)" and m and cfgmod.read_key("server.secret") then
    local Client = require("lib.client")
    local c = Client.new({ timeout = 2 })
    local r = c and c:call("ping", {}, { timeout = 2 })
    if r and r.ok then out(colors.lime, "Bank      : online, v" .. tostring(r.version))
    else out(colors.red, "Bank      : not responding (" .. tostring(r and r.err) .. ")") end
  end
end

local cmd = args[1]
if cmd == "update" or cmd == "install" then
  shell.run("/vrb/install.lua", "update")
elseif cmd == nil or cmd == "run" then
  local role = cfgmod.role()
  if not role then
    out(colors.red, "This computer has no role yet.")
    print("Run the installer: wget run https://raw.githubusercontent.com/ArchdukePierre/VanguardReserveBank/main/install.lua")
    return
  end
  run_role(role)
elseif cmd == "status" then
  status()
elseif cmd == "role" and args[2] then
  run_role(args[2])
else
  local tool = ({ doctor = "tools.doctor", pair = "tools.pair", join = "tools.pair", config = "tools.config", floppy = "tools.pair", reset = "tools.reset", backup = "tools.backup", restore = "tools.backup", keys = "tools.reset", scoreboard_test = "tools.scoreboard_check" })[cmd]
  if tool then
    require(tool).main(cmd, { table.unpack(args, 2) })
  else
    print("vrb commands: run, status, doctor, update, join [staff], floppy [staff], config, backup, restore, keys, reset")
  end
end
