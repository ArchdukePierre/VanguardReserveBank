local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local SHOW = ARGS and ARGS[1] == "dump"
local function show(title, text)
  if SHOW then
    print(title)
    print(text)
  end
end

T.solo({}, function()
  local pos = require("roles.pos")
  local ser = require("lib.ser")
  local name, price = pos.parse_add("burger 8")
  T.check(name == "burger" and price == 800, "add parses dollars to cents")
  name, price = pos.parse_add("Diamond Block $50.25")
  T.check(name == "Diamond Block" and price == 5025, "add keeps spaces in the item name")
  name, price = pos.parse_add("4 fries")
  T.check(name == "fries" and price == 400, "price first form")
  T.check(pos.parse_add("burger free") == nil, "bad price rejected")
  T.check(pos.parse_add("burger 0") == nil, "zero price rejected")
  T.check(pos.parse_add("burger 1.234") == nil, "sub cent price rejected")
  local tab = { owner = "steve", lines = { { name = "burger", price = 800, qty = 2 }, { name = "fries", price = 400, qty = 1 } } }
  T.eq(pos.build_memo(tab), "burger x2 $16.00, fries $4.00 = $20.00", "memo lists items")
  local long = { owner = "steve", lines = {} }
  for i = 1, 60 do long.lines[i] = { name = "item number " .. i, price = 100 + i, qty = 1 } end
  local memo = pos.build_memo(long)
  T.check(#memo <= 200 and memo:find(", %+%d+ more = %$") and memo:find("item number 1 ", 1, true), "long memo truncates by whole items and keeps the total (" .. #memo .. ")")
  local one = { owner = "steve", lines = { { name = string.rep("x", 400), price = 100, qty = 1 } } }
  T.check(#pos.build_memo(one) <= 200 and pos.build_memo(one):find("= $1.00", 1, true), "single huge item still fits")
end)

local function key(C, code) C.queue[#C.queue + 1] = { "key", code, false } end
local ENTER, ESC = 257, 256

local world, server = N.world()
local admin = N.client_pc(world, 2)
local ids = {}
N.run_client(world, admin, function()
  local Client = require("lib.client")
  local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
  for _, o in ipairs({ { "shopkeeper", "1234" }, { "steve", "4321" }, { "alex", "1111" } }) do
    local r = c:call("open_account", { owner = o[1], pin = o[2] })
    T.check(r.ok, "open " .. o[1])
    ids[o[1]] = r.checking_id
  end
end)

local pocket = N.client_pc(world, 5, N.keys(), { w = 26, h = 20 })
local res = { done = false }
local function role() require("roles.pos").run() end
T.setenv(role, pocket.env)
world:start(pocket, function()
  local ok, err = xpcall(role, debug.traceback)
  res.ok, res.err, res.done = ok, err, true
end)

local function settle(s) world:run({ seconds = s or 0.6 }) end
local function typ(s)
  for ch in s:gmatch(".") do pocket.queue[#pocket.queue + 1] = { "char", ch } end
  settle()
end
local function line(s)
  typ(s)
  key(pocket, ENTER)
  settle()
end
local function click(x, y)
  pocket.queue[#pocket.queue + 1] = { "mouse_click", 1, x, y }
  settle()
end
local function dump() return pocket.term._dump() end
local function has(text) return dump():find(text, 1, true) ~= nil end
local function file() return pocket.fs.exists("/.vrb/tabs.dat") and pocket.fs.open("/.vrb/tabs.dat", "r").readAll() or "" end

settle(1)
T.check(has("Sign in") and has("Username"), "sign in asks for the username")
line("shopkeeper")
T.check(has("PIN for shopkeeper"), "then asks for the PIN")
typ("1234")
settle(1)
T.check(has("shopkeeper") and has("No tab open"), "signed in, empty screen")
show("--- pocket, signed in, no tab ---", dump())

line("tab steve")
T.check(has("Tab steve") and has("Tab is empty"), "tab opens")
line("add burger 8")
line("+ fries 4.50")
line("add burger 8")
line("add Diamond Block 50")
T.check(has("burger x2") and has("$16.00") and has("fries") and has("Diamond Block") and has("$70.50"), "items and total shown")
show("--- pocket, tab with items ---", dump())
T.check(file():find("burger", 1, true) and file():find("steve", 1, true), "tabs saved to /.vrb/tabs.dat")

local writes = pocket.F.writes
line("help")
T.check(has("tab <name>") and has("scroll u|d"), "help screen")
key(pocket, ENTER)
settle()
T.check(has("Tab steve"), "help returns")
line("tabs")
T.check(has("Open tabs") and has("steve"), "tabs list")
key(pocket, ESC)
settle()
line("scroll d")
line("scroll u")
line("tab steve")
line("nonsense")
T.check(has("Unknown: nonsense"), "unknown command reported")
line("void ghost")
T.check(has("Not on the tab: ghost"), "void of a missing item reported")
T.eq(pocket.F.writes, writes, "nothing written when no tab changed")
line("void fries")
T.check(has("Removed fries") and file():find("fries", 1, true) == nil, "void removes the item and saves")

line("tab alex")
line("add coffee 3")
line("tab steve")
T.check(has("Tab steve"), "switch tabs")
click(14, 2)
T.check(has("Open tabs") and has("alex") and has("$3.00"), "touching the tab line opens the list")
key(pocket, ESC)
settle()

local before = pocket.term._T.calls
world:run({ seconds = 120 })
T.eq(pocket.term._T.calls, before, "no screen writes while idle")

click(8, 17)
local function row(n)
  local i = 0
  for l in (dump() .. "\n"):gmatch("(.-)\n") do
    i = i + 1
    if i == n then return l end
  end
end
T.check(has("Removed Diamond Block") and row(3):find("burger", 1, true) and not row(4):find("Diamond", 1, true), "VOID touch removes the last line")
line("add Diamond Block 50")
line("add burger 8")
click(20, 17)
T.check(has("scroll u|d"), "HELP touch")
click(5, 5)
T.check(has("Tab steve"), "touch returns from help")

line("bill")
T.check(has("Bill steve") and has("Total $74.00"), "bill asks to confirm")
show("--- bill confirm ---", dump())
key(pocket, ESC)
settle()
T.check(has("Cancelled"), "cancel keeps the tab")
click(3, 17)
T.check(has("Bill steve"), "BILL touch asks to confirm")
key(pocket, ENTER)
settle(1)
T.check(has("Bill sent to steve") and has("No tab open"), "bill sent and tab closed")
T.check(file():find("steve", 1, true) == nil and file():find("alex", 1, true), "closed tab removed from disk")

local seen
local checker = N.client_pc(world, 8)
N.run_client(world, checker, function()
  local Client = require("lib.client")
  local c = assert(Client.new({}))
  local s = c:call("auth_by_owner", { owner = "steve", pin = "4321" })
  local r = c:call("list_payment_requests", { session = s.session })
  seen = r.requests
end)
T.check(seen and #seen == 1 and seen[1].amount == 7400 and seen[1].from_owner == "shopkeeper", "customer got one bill for the total")
T.check(seen and seen[1].memo:find("Diamond Block $50.00", 1, true) and seen[1].memo:find("burger x3 $24.00", 1, true) and seen[1].memo:find("= $74.00", 1, true), "bill memo is itemized (" .. tostring(seen and seen[1].memo) .. ")")

line("tab alex")
line("add pie 6")
N.run_client(world, N.client_pc(world, 7), function()
  local Client = require("lib.client")
  local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
  local r = c:call("admin_reset_pin", { account_id = ids.shopkeeper, new_pin = "9999" }, { admin = true })
  T.check(r.ok, "admin resets the shop PIN")
end)
line("bill")
key(pocket, ENTER)
settle(1)
T.check(has("PIN for") or has("Username"), "no_session leads to a sign in prompt")
key(pocket, ENTER)
settle()
typ("9999")
settle(1)
T.check(has("Bill sent to alex"), "bill retried after signing in again")

line("tab steve")
line("add soda 2")
line("delete steve")
T.check(has("Delete tab"), "delete asks first")
key(pocket, ESC)
settle()
T.check(has("Kept steve"), "delete can be cancelled")
line("delete steve")
key(pocket, ENTER)
settle()
T.check(has("Deleted steve"), "delete removes the tab")

line("tab steve")
line("add soda 2")
world:run({ seconds = 700 })
T.check(has("signed out"), "idle timeout signs the shopkeeper out")
local after = pocket.term._T.calls
world:run({ seconds = 600 })
T.eq(pocket.term._T.calls, after, "signed out and idle writes nothing")
line("bill")
T.check(has("Username") or has("Sign in"), "billing after timeout asks to sign in")
key(pocket, ESC)
settle()
T.check(has("Sign in to bill"), "cancelled sign in keeps the tab")

line("q")
T.check(res.done and res.ok, "q quits: " .. tostring(res.err))

local files = N.keys()
files["/.vrb/tabs.dat"] = file()
local again = N.client_pc(world, 6, files, { w = 51, h = 19 })
local res2 = { done = false }
local role2 = function() require("roles.pos").run() end
T.setenv(role2, again.env)
world:start(again, function() local ok, err = xpcall(role2, debug.traceback); res2.ok, res2.err, res2.done = ok, err, true end)
world:run({ seconds = 1 })
key(again, ESC)
world:run({ seconds = 1 })
local wide = again.term._dump()
show("--- 51x19 terminal, restored tabs ---", wide)
T.check(wide:find("Tab steve", 1, true) and wide:find("soda", 1, true), "tabs restored after restart")
T.check(wide:find("VOID LAST", 1, true), "wide screen shows the full button labels")

local none = N.client_pc(world, 10, {}, { w = 26, h = 20 })
local res3 = { done = false }
local role3 = function() require("roles.pos").run() end
T.setenv(role3, none.env)
world:start(none, function() local ok, err = xpcall(role3, debug.traceback); res3.ok, res3.err, res3.done = ok, err, true end)
world:run({ seconds = 1 })
T.check(res3.done and res3.ok and table.concat(none.printed, " "):find("server.secret is missing", 1, true), "missing key shows a message")
T.done()
