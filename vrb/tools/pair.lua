local pairing = require("lib.pairing")
local cfgmod = require("lib.cfg")
local net = require("lib.net")
local ser = require("lib.ser")
local util = require("lib.util")

local M = {}

local function say(color, text)
  if term.isColor and term.isColor() then term.setTextColor(color) end
  print(text)
  if term.isColor and term.isColor() then term.setTextColor(colors.white) end
end

local function save_keys(body, from)
  util.ensure_dir("/.vrb/keys")
  util.write_atomic("/.vrb/keys/server.secret", body.secret)
  if body.admin then util.write_atomic("/.vrb/keys/admin.key", body.admin) end
  if body.network then
    local c = cfgmod.load()
    local over = ser.decode(util.read_file(c.path) or "") or {}
    over.net = over.net or {}
    over.net.network = body.network
    cfgmod.save_override(c.path, over)
  end
  say(colors.lime, "Keys saved" .. (body.admin and " (staff)" or "") .. " from " .. from .. ".")
end

local function find_floppy()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" then
      local d = peripheral.wrap(name)
      if d.isDiskPresent() and d.getMountPath() then
        local path = d.getMountPath()
        if fs.exists(path .. "/server.secret") then return path end
      end
    end
  end
end

function M.join(want_staff)
  local floppy = find_floppy()
  if floppy then
    local body = { secret = util.trim(util.read_file(floppy .. "/server.secret") or "") }
    if want_staff and fs.exists(floppy .. "/admin.key") then body.admin = util.trim(util.read_file(floppy .. "/admin.key")) end
    if #body.secret >= 32 and (not want_staff or body.admin) then
      save_keys(body, "the floppy disk")
      return true
    end
    say(colors.orange, "The floppy does not have the key this role needs. Using a pairing code instead.")
  end
  local modem = net.find_modem()
  if not modem then say(colors.red, "No modem attached. Attach a wireless or ender modem first."); return false end
  say(colors.yellow, "On the bank server press P" .. (want_staff and " then S for a staff code" or "") .. ". It shows a code like ABCD-EFGH-JKLM.")
  for attempt = 1, 3 do
    write("Pairing code: ")
    local code = read()
    if not code or code == "" then return false end
    local reply = net.reply_channel()
    modem.open(reply)
    local req = pairing.request(code, reply)
    modem.transmit(pairing.CHANNEL, reply, req)
    local tid = os.startTimer(6)
    local body
    while true do
      local ev, a, b, c, d = os.pullEvent()
      if ev == "modem_message" and b == reply then
        body = pairing.open_reply(code, d, req.n)
        if body then os.cancelTimer(tid); break end
      elseif ev == "timer" and a == tid then
        break
      end
    end
    modem.close(reply)
    if body then
      if want_staff and not body.admin then
        say(colors.red, "That was a normal code. This role needs a staff code (S on the server).")
      else
        save_keys(body, "the bank server")
        return true
      end
    else
      say(colors.red, "No answer. Check the code, that pairing is open on the server and the modem range.")
    end
  end
  return false
end

function M.main(cmd, args)
  if cmd == "join" or cmd == "pair" then
    local staff = args[1] == "staff"
    M.join(staff)
  elseif cmd == "floppy" then
    local c = cfgmod.load()
    local secret, admin = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
    if not secret then say(colors.red, "This computer has no keys."); return end
    for _, name in ipairs(peripheral.getNames()) do
      if peripheral.getType(name) == "drive" then
        local d = peripheral.wrap(name)
        if d.isDiskPresent() and d.getMountPath() then
          local path = d.getMountPath()
          util.write_atomic(path .. "/server.secret", secret)
          if args[1] == "staff" and admin then util.write_atomic(path .. "/admin.key", admin) end
          d.setDiskLabel("VRB keys")
          say(colors.lime, "Keys written to the disk" .. (args[1] == "staff" and " (staff)." or ". Use 'vrb floppy staff' to add the admin key."))
          return
        end
      end
    end
    say(colors.red, "Put a floppy disk in a disk drive first.")
  end
end

return M
