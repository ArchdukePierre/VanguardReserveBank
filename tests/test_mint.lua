local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local SHOW = ARGS and ARGS[1] == "dump"
local function show(title, text)
  if SHOW then
    print(title)
    print(text)
  end
end

local ENTER, ESC = 257, 256

local function make_drive(C)
  local d = { present = false, label = nil, script = {} }
  function d.isDiskPresent()
    if #d.script > 0 then return table.remove(d.script, 1) end
    return d.present
  end
  function d.getMountPath() return d.present and "disk" or nil end
  function d.setDiskLabel(l) d.label = l end
  function d.getDiskLabel() return d.label end
  function d.insert(files)
    C.fs.delete("disk")
    C.fs.makeDir("disk")
    for name, data in pairs(files or {}) do
      local h = C.fs.open("disk/" .. name, "w")
      h.write(data)
      h.close()
    end
    d.present, d.label = true, nil
  end
  function d.eject()
    d.present = false
    C.fs.delete("disk")
  end
  return d
end

local function make_printer()
  local p = { pages = {}, paper = true }
  function p.newPage()
    if not p.paper then return false end
    p.cur = { lines = {} }
    return true
  end
  function p.setPageTitle(t) p.cur.title = t end
  function p.setCursorPos(x, y) p.y = y end
  function p.write(s) p.cur.lines[p.y] = s end
  function p.endPage()
    p.pages[#p.pages + 1] = p.cur
    p.cur = nil
    return true
  end
  function p.getPageSize() return 25, 21 end
  return p
end

local function start(world, C)
  local res = { done = false }
  local fn = function() require("roles.mint").run() end
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    res.ok, res.err, res.done = ok, err, true
  end)
  return res
end

local world, server = N.world()
local ids = {}
N.run_client(world, N.client_pc(world, 2), function()
  local Client = require("lib.client")
  local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
  for _, o in ipairs({ { "alice", "1234" }, { "bob", "4321" } }) do
    local r = c:call("open_account", { owner = o[1], pin = o[2] })
    T.check(r.ok, "open " .. o[1])
    ids[o[1]] = r.checking_id
  end
  T.check(c:call("admin_issue", { account_id = ids.alice, amount = 100000, reason = "seed" }, { admin = true }).ok, "fund alice")
end)

local C = N.client_pc(world, 3, N.keys(), { monitors = { { w = 57, h = 38, scale = 0.5 } } })
local drive, printer = make_drive(C), make_printer()
C.add_peripheral("drive_0", "drive", drive)
C.add_peripheral("printer_0", "printer", printer)
C.fs.makeDir("disk")
local mon = C.monitors[1]
local res = start(world, C)

local function settle(s) world:run({ seconds = s or 0.6 }) end
local function tap(x, y)
  C.queue[#C.queue + 1] = { "monitor_touch", mon.__name, x, y }
  settle()
end
local function typ(s)
  for ch in s:gmatch(".") do C.queue[#C.queue + 1] = { "char", ch } end
  settle()
end
local function key(code)
  C.queue[#C.queue + 1] = { "key", code, false }
  settle(1)
end
local function dump() return mon._dump() end
local function has(text) return dump():find(text, 1, true) ~= nil end
local function all_text() return dump() .. table.concat(C.printed, "\n") end

local function option_y(i) return 6 + (i - 1) * 3 end
local function start_issue(who, option)
  tap(10, 12)
  typ(who)
  key(ENTER)
  settle(1)
  if option then tap(10, option_y(option)) end
end

local function bank(fn)
  local o = {}
  local pc = N.client_pc(world, 30 + math.random(1, 60))
  N.run_client(world, pc, function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    fn(c, o)
  end)
  return o
end

local function balance(owner)
  return bank(function(c, o)
    local r = c:call("admin_list_accounts", { filter = owner }, { admin = true })
    o.balance = r.accounts[1].balance
  end).balance
end

local function note_on_disk()
  if not C.fs.exists("disk/note.vrb") then return nil end
  return C.env.textutils.unserialize(C.fs.open("disk/note.vrb", "r").readAll())
end

settle(2)
show("--- mint home, 57x38 ---", dump())
T.check(has("Mint station") and has("Insert a disk") and has("Attached") and has("ISSUE A NOTE"), "home shows the devices")

drive.insert()
C.queue[#C.queue + 1] = { "disk", "drive_0" }
settle()
T.check(has("Disk ready"), "inserting a disk updates the screen")

start_issue("alice", nil)
show("--- denominations ---", dump())
T.check(has("Note value") and has("$1000") and has("$50"), "denominations listed")
tap(10, option_y(4))
show("--- confirm ---", dump())
T.check(has("alice") and has("Note value $50") and has("$1,000.00") and has("$950.00") and has("written to the disk"), "confirm shows the account and the balance change")
key(ENTER)
settle(1)
show("--- issued ---", dump())
local note = note_on_disk()
T.check(note and note.serial and note.serial:find("^VRN%-") and note.denom == 50 and note.account == ids.alice and type(note.sig) == "string", "note written to the disk as note.vrb")
T.eq(drive.label, note and ("VRN " .. note.serial .. " $50"), "disk labelled with serial and value")
T.check(has("Note issued") and has(note.serial) and has("Written to the disk") and has("Balance now $950.00"), "result shown")
T.check(not all_text():find(note.sig:sub(1, 12), 1, true), "signature never shown")
T.check(not C.fs.exists("/.vrb/mint/" .. note.serial .. ".vrb"), "recovery copy removed once the disk has the note")
T.eq(#printer.pages, 0, "printer not used when a disk is present")
T.eq(balance("alice"), 95000, "alice debited $50")
key(ENTER)

local redeemed = bank(function(c, o)
  local s = c:call("auth_by_owner", { owner = "bob", pin = "4321" })
  local r = c:call("redeem_note", { session = s.session, note = note })
  o.ok, o.err = r.ok, r.err
  o.balance = r.balance
end)
T.check(redeemed.ok and redeemed.balance == 5000, "the written note redeems for its value (" .. tostring(redeemed.err) .. ")")

start_issue("alice", 2)
T.check(has("No place for the note") and has("already holds a note") and has("Nothing was issued"), "a disk that already holds a note is refused before issuing")
T.eq(balance("alice"), 95000, "nothing debited for a refused disk")
key(ENTER)

drive.eject()
C.queue[#C.queue + 1] = { "disk_eject", "drive_0" }
settle()
T.check(has("Insert a disk"), "ejecting updates the screen")
start_issue("alice", 3)
T.check(has("It will be printed."), "no disk and a printer: confirm says it will be printed")
key(ENTER)
settle(1)
local page = printer.pages[1]
local text = page and table.concat(page.lines, "\n", 1, 8) or ""
T.check(page and page.title:find("VRN%-") and text:find("Value $10", 1, true) and text:find("VRN-", 1, true), "slip printed with serial and value")
local serial = page and page.title:match("(VRN%-%x+)")
T.check(serial and C.fs.exists("/.vrb/mint/" .. serial .. ".vrb"), "record kept on this computer for a printed slip")
local kept = serial and C.fs.open("/.vrb/mint/" .. serial .. ".vrb", "r").readAll() or ""
local kept_note = C.env.textutils.unserialize(kept)
T.check(kept_note and not text:find(kept_note.sig, 1, true) and not all_text():find(kept_note.sig:sub(1, 12), 1, true), "signature never printed or shown")
T.check(has("Slip printed"), "result says the slip was printed")
key(ENTER)
T.eq(balance("alice"), 94000, "alice debited $10")

drive.insert()
C.queue[#C.queue + 1] = { "disk", "drive_0" }
settle()
local digits = ids.alice:match("%d+")
start_issue("acc" .. digits, 1)
key(ENTER)
settle(1)
T.check(has("Note issued") and has("Value $1"), "account numbers work without the hyphen")
key(ENTER)
T.check(note_on_disk() and note_on_disk().denom == 1, "second note written")
T.eq(balance("alice"), 93900, "alice debited $1")

drive.eject()
drive.insert()
start_issue("ACC-" .. digits, 1)
T.check(has("alice") and has("Note value $1"), "full account numbers work")
key(ESC)
settle()
T.check(has("Mint station"), "cancel returns home")

start_issue("bob", 5)
T.check(has("Not enough funds") and has("$50.00") and has("$100"), "not enough funds is reported before anything is issued")
key(ENTER)
T.eq(balance("bob"), 5000, "bob untouched")

start_issue("nobody", nil)
T.check(has("No account") and has("nobody"), "unknown player reported")
key(ENTER)

drive.eject()
C.peripherals["printer_0"] = nil
start_issue("alice", 1)
T.check(has("No place for the note") and has("Insert a disk first"), "no disk and no printer: refused before issuing")
key(ENTER)
T.eq(balance("alice"), 93900, "nothing debited without an output")

drive.insert()
drive.script = { true, false }
start_issue("alice", 1)
key(ENTER)
settle(1)
show("--- not delivered ---", dump())
T.check(has("Note not delivered") and has("/.vrb/mint/VRN-"), "delivery failure keeps the note and says where")
local backup = dump():match("(/%.vrb/mint/VRN%-%x+%.vrb)")
T.check(backup and C.fs.exists(backup), "recovery copy exists")
local bnote = backup and C.env.textutils.unserialize(C.fs.open(backup, "r").readAll())
T.check(bnote and not all_text():find(bnote.sig:sub(1, 12), 1, true), "signature not shown on the failure screen")
key(ENTER)
T.check(has("Note issued") and has("Written to the disk"), "retry writes the note")
T.check(backup and not C.fs.exists(backup), "recovery copy removed after the retry")
key(ENTER)
T.eq(balance("alice"), 93800, "alice debited once for the retried note")

C.queue[#C.queue + 1] = { "char", "q" }
settle()
T.check(res.done and res.ok, "Q quits: " .. tostring(res.err))

do
  local w2 = N.world()
  N.run_client(w2, N.client_pc(w2, 2), function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    local r = c:call("open_account", { owner = "carol", pin = "1234" })
    T.check(c:call("admin_issue", { account_id = r.checking_id, amount = 20000, reason = "seed" }, { admin = true }).ok, "fund carol")
  end)
  local pc = N.client_pc(w2, 3, N.keys(), { w = 51, h = 19 })
  local drv, prn = make_drive(pc), make_printer()
  pc.add_peripheral("drive_0", "drive", drv)
  pc.add_peripheral("printer_0", "printer", prn)
  drv.insert()
  local r2 = start(w2, pc)
  local function s2(s) w2:run({ seconds = s or 0.6 }) end
  local function click(x, y)
    pc.queue[#pc.queue + 1] = { "mouse_click", 1, x, y }
    s2()
  end
  s2(2)
  show("--- mint on the 51x19 terminal ---", pc.term._dump())
  T.check(pc.term._dump():find("Disk ready", 1, true) and pc.term._dump():find("ISSUE A NOTE", 1, true), "terminal fallback shows the home screen")
  click(10, 12)
  for ch in ("carol"):gmatch(".") do pc.queue[#pc.queue + 1] = { "char", ch } end
  s2()
  pc.queue[#pc.queue + 1] = { "key", ENTER, false }
  s2(1)
  show("--- terminal denominations ---", pc.term._dump())
  click(10, 12)
  T.check(pc.term._dump():find("Note value $50", 1, true), "choose list works on the terminal")
  pc.queue[#pc.queue + 1] = { "key", ENTER, false }
  s2(1)
  T.check(pc.term._dump():find("Note issued", 1, true) and pc.fs.exists("disk/note.vrb"), "note issued from the terminal")
  T.check(not r2.done and not pc.crash, "terminal mint keeps running")
end

do
  local w3 = T.cc.new()
  local pc = w3:computer({ id = 5, files = {} })
  T.mount(pc)
  local r3 = start(w3, pc)
  w3:run({ seconds = 3 })
  T.check(r3.done and r3.ok and table.concat(pc.printed, " "):find("missing keys", 1, true), "missing keys give a message")
  local pc2 = w3:computer({ id = 6, files = N.keys() })
  T.mount(pc2)
  local r4 = start(w3, pc2)
  w3:run({ seconds = 3 })
  T.check(r4.done and r4.ok and table.concat(pc2.printed, " "):find("no output device", 1, true), "no drive and no printer gives a message")
end

T.done()
