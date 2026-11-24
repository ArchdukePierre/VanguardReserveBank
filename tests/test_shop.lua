local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local SHOW = ARGS and ARGS[1] == "dump"
local function show(title, text)
  if SHOW then
    print(title)
    print(text)
  end
end

local ser = dofile(REPO .. "/vrb/lib/ser.lua")

local ENTER, ESC = 257, 256

local function start(world, C)
  local res = { done = false }
  local fn = function() require("roles.shop").run() end
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    res.ok, res.err, res.done = ok, err, true
  end)
  return res
end

local function make_inventory(slots, room)
  local inv = { slots = slots, room = room, pushes = 0, received = {} }
  function inv.list()
    local out = {}
    for slot, it in pairs(inv.slots) do out[slot] = { name = it.name, count = it.count } end
    return out
  end
  return inv
end

local function link(from, to_name, to)
  function from.pushItems(name, slot, count)
    from.pushes = from.pushes + 1
    assert(name == to_name, "unknown target " .. tostring(name))
    local it = from.slots[slot]
    if not it then return 0 end
    local n = math.min(count, it.count)
    if to.room then n = math.min(n, to.room) end
    if n <= 0 then return 0 end
    it.count = it.count - n
    if it.count == 0 then from.slots[slot] = nil end
    if to.room then to.room = to.room - n end
    to.received[it.name] = (to.received[it.name] or 0) + n
    return n
  end
end

local world, server = N.world()
local shop_id
local admin = N.client_pc(world, 2)
N.run_client(world, admin, function()
  local Client = require("lib.client")
  local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
  local o = c:call("open_account", { owner = "owner", pin = "1111" })
  local b = c:call("open_account", { owner = "buyer", pin = "1234" })
  T.check(o.ok and b.ok, "open accounts")
  T.check(c:call("admin_issue", { account_id = b.checking_id, amount = 100000, reason = "seed" }, { admin = true }).ok, "fund buyer")
  local s = c:call("auth_by_owner", { owner = "owner", pin = "1111" })
  local r = c:call("create_shop", { session = s.session, label = "Corner Store" })
  T.check(r.ok, "create shop")
  shop_id = r.shop_id
  local function list(sku, item, price, stock, note, item_id)
    local res = c:call("set_shop_listing", { session = s.session, shop_id = shop_id, sku = sku, item = item, price = price, stock = stock, note = note, item_id = item_id })
    T.check(res.ok, "listing " .. sku)
  end
  list("01", "Diamond", 3200, 10, "Fresh from the mine", "minecraft:diamond")
  list("02", "Apple", 150, 0, "", "minecraft:apple")
  list("03", "Iron Pickaxe", 5000, 2, "Efficiency III", "minecraft:iron_pickaxe")
  list("04", "Cobblestone", 10, 100, "No delivery", nil)
  c:call("signout", { session = s.session })
end)

local files = N.keys()
files["/.vrb/shop.cfg"] = ser.encode({ shop_id = shop_id, stock = "chest_stock", output = "chest_out" })
local C = N.client_pc(world, 3, files, { monitors = { { w = 57, h = 38, scale = 0.5 } } })
local stock = make_inventory({ [1] = { name = "minecraft:diamond", count = 6 }, [3] = { name = "minecraft:diamond", count = 4 }, [5] = { name = "minecraft:iron_pickaxe", count = 1 } })
local out = make_inventory({}, nil)
link(stock, "chest_out", out)
C.add_peripheral("chest_stock", "inventory", stock)
C.add_peripheral("chest_out", "inventory", out)
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
  settle()
end
local function dump() return mon._dump() end
local function has(text) return dump():find(text, 1, true) ~= nil end

local function bank(fn)
  local out_t = {}
  local pc = N.client_pc(world, 30 + math.random(1, 60))
  N.run_client(world, pc, function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = require("lib.cfg").read_key("admin.key") }))
    fn(c, out_t)
  end)
  return out_t
end

local function state()
  return bank(function(c, o)
    local s = c:call("auth_by_owner", { owner = "buyer", pin = "1234" })
    o.buyer = c:call("balance", { session = s.session }).balance
    c:call("signout", { session = s.session })
    local shop = c:call("get_shop", { shop_id = shop_id })
    o.stock = {}
    for _, l in ipairs(shop.shop.listings) do o.stock[l.sku] = l.stock end
    o.sessions = c:call("admin_diagnostics", {}, { admin = true }).active_sessions
  end)
end

settle(2)
show("--- shop listing, 57x38 ---", dump())
T.check(has("Corner Store") and has("Run by owner"), "header shows the shop")
T.check(has("Diamond") and has("$32.00") and has("10 in stock") and has("Fresh from the mine"), "listing shows item, price, stock and note")
T.check(has("Apple") and has("SOLD OUT"), "sold out item marked")
T.check(has("Iron Pickaxe") and has("Efficiency III") and has("Cobblestone"), "all listings shown")

tap(10, 7)
T.check(has("SOLD OUT") and not has("how many"), "sold out item cannot be bought")

tap(10, 5)
T.check(has("Diamond: how many?"), "asks for the quantity")
typ("2")
key(ENTER)
T.check(has("Sign in") and has("Minecraft username"), "then asks who is buying")
typ("buyer")
key(ENTER)
T.check(has("PIN for buyer"), "then the PIN")
typ("1234")
settle(1)
T.check(has("Confirm purchase") and has("2 x Diamond") and has("Total $64.00") and has("Your balance $1,000.00"), "confirmation shows the total and the balance")
show("--- confirm ---", dump())
key(ENTER)
settle(1)
T.check(has("Thank you") and has("Paid $64.00") and has("Balance $936.00"), "purchase done")
show("--- done ---", dump())
T.eq(out.received["minecraft.diamond"] or out.received["minecraft:diamond"], 2, "two diamonds moved to the output chest")
local st = state()
T.eq(st.buyer, 93600, "buyer charged")
T.eq(st.stock["01"], 8, "server stock reduced")
T.eq(st.sessions, 0, "buyer signed out after the purchase")
key(ENTER)
T.check(has("8 in stock"), "listing refreshed after the purchase")

local pushes = stock.pushes
tap(10, 9)
typ("2")
key(ENTER)
typ("buyer")
key(ENTER)
typ("1234")
settle(1)
key(ENTER)
settle(1)
T.check(has("Not enough in the chest") and has("Nothing was charged"), "refuses when the chest has too little")
T.eq(stock.pushes, pushes, "nothing pushed when the chest is short")
key(ENTER)
st = state()
T.eq(st.buyer, 93600, "buyer not charged for a refused order")
T.eq(st.sessions, 0, "signed out after a refused order")

tap(10, 5)
typ("1")
key(ENTER)
typ("buyer")
key(ENTER)
typ("0000")
settle(1)
T.check(has("Could not sign in") and has("Invalid credentials"), "wrong PIN refused")
key(ENTER)
T.eq(state().sessions, 0, "no session left after a wrong PIN")

tap(10, 5)
typ("1")
key(ENTER)
typ("buyer")
key(ENTER)
typ("1234")
settle(1)
key(ESC)
settle()
T.check(has("Run by owner") and not has("Confirm purchase"), "cancel returns to the listing")
st = state()
T.eq(st.buyer, 93600, "cancel keeps the money")
T.eq(st.sessions, 0, "cancel signs out")

tap(10, 5)
settle(1)
local before = mon._T.calls
world:run({ seconds = 100 })
T.check(has("Run by owner") and not has("how many"), "idle timeout returns to the listing")
T.eq(state().sessions, 0, "idle timeout leaves no session")

tap(10, 5)
typ("1")
key(ENTER)
typ("buyer")
key(ENTER)
typ("1234")
settle(1)
world:run({ seconds = 100 })
T.check(has("Run by owner") and not has("Confirm purchase"), "idle on the confirm screen returns to the listing")
T.eq(state().sessions, 0, "idle on the confirm screen signs out")
T.eq(state().buyer, 93600, "idle keeps the money")

settle(1)
before = mon._T.calls
world:run({ seconds = 300 })
T.eq(mon._T.calls, before, "idle listing writes nothing")

out.room = 1
tap(10, 5)
typ("3")
key(ENTER)
typ("buyer")
key(ENTER)
typ("1234")
settle(1)
key(ENTER)
settle(1)
show("--- partial delivery ---", dump())
T.check(has("Contact the owner") and has("Only 1 came out") and has("owner before you leave"), "short delivery tells the buyer to contact the owner")
local used = stock.pushes
key(ENTER)
st = state()
T.eq(st.buyer, 93600 - 9600, "the purchase stands")
T.eq(st.sessions, 0, "signed out after a short delivery")
T.check(stock.pushes == used, "no retry after a short delivery")

tap(10, 11)
typ("5")
key(ENTER)
typ("buyer")
key(ENTER)
typ("1234")
settle(1)
key(ENTER)
settle(1)
T.check(has("Thank you") and has("5 x Cobblestone"), "items without an item id sell without moving anything")
key(ENTER)
T.eq(state().sessions, 0, "signed out")

bank(function(c)
  local s = c:call("auth_by_owner", { owner = "owner", pin = "1111" })
  T.check(c:call("set_shop_listing", { session = s.session, shop_id = shop_id, sku = "01", item = "Diamond", price = 3200, stock = 25, note = "Restocked", item_id = "minecraft:diamond" }).ok, "owner restocks")
  c:call("signout", { session = s.session })
end)
T.check(not has("25 in stock"), "no timer refresh of the listing")
tap(48, 37)
T.check(has("25 in stock") and has("Restocked"), "REFRESH button fetches the listing again")

C.queue[#C.queue + 1] = { "monitor_touch", "monitor_9", 10, 5 }
settle()
T.check(not has("how many"), "touches from other monitors are ignored")
T.check(not C.crash and not res.done, "kiosk still running")

do
  local w2 = N.world()
  local pc = N.client_pc(w2, 3, N.keys(), { monitors = { { w = 29, h = 19, scale = 0.5 } } })
  local shop = nil
  N.run_client(w2, N.client_pc(w2, 2), function()
    local Client = require("lib.client")
    local c = assert(Client.new({}))
    c:call("open_account", { owner = "owner", pin = "1111" })
    local s = c:call("auth_by_owner", { owner = "owner", pin = "1111" })
    shop = c:call("create_shop", { session = s.session, label = "Tiny Shop" }).shop_id
    for i = 1, 9 do c:call("set_shop_listing", { session = s.session, shop_id = shop, sku = "0" .. i, item = "Item number " .. i, price = 100 * i, stock = i, note = "note " .. i }) end
  end)
  pc.fs.makeDir("/.vrb")
  local h = pc.fs.open("/.vrb/shop.cfg", "w")
  h.write(ser.encode({ shop_id = shop }))
  h.close()
  local r2 = start(w2, pc)
  w2:run({ seconds = 3 })
  local m2 = pc.monitors[1]
  show("--- shop listing, 29x19 ---", m2._dump())
  T.check(m2._dump():find("Tiny Shop", 1, true) and m2._dump():find("Item number 1", 1, true), "small monitor shows the listing")
  T.check(m2._dump():find("\31 DOWN", 1, true), "small monitor offers paging")
  pc.queue[#pc.queue + 1] = { "monitor_touch", m2.__name, 14, 18 }
  w2:run({ seconds = 1 })
  T.check(m2._dump():find("Item number 9", 1, true) and not m2._dump():find("Item number 1 ", 1, true), "paging moves down")
  T.check(not pc.crash and not r2.done, "small kiosk runs")
end

do
  local w3 = N.world()
  local pc = N.client_pc(w3, 3, N.keys(), { monitors = { { w = 57, h = 38, scale = 0.5 } } })
  local r3 = start(w3, pc)
  w3:run({ seconds = 2 })
  pc.queue[#pc.queue + 1] = { "vrb_read", "bad id!" }
  w3:run({ seconds = 1 })
  pc.queue[#pc.queue + 1] = { "vrb_read", "SHP-TEST1234" }
  w3:run({ seconds = 3 })
  local h = pc.fs.exists("/.vrb/shop.cfg") and pc.fs.open("/.vrb/shop.cfg", "r").readAll() or ""
  T.check(h:find("SHP-TEST1234", 1, true) and not h:find("bad id", 1, true), "first run asks for the shop id once and saves it")
  T.check(pc.monitors[1]._dump():find("Shop unavailable", 1, true), "unknown shop shows a message")
  T.check(not pc.crash and not r3.done, "kiosk runs with an unknown shop")
end

do
  local w4 = T.cc.new()
  local pc = w4:computer({ id = 5, files = {} })
  T.mount(pc)
  local r4 = start(w4, pc)
  w4:run({ seconds = 3 })
  T.check(r4.done and r4.ok and table.concat(pc.printed, " "):find("server.secret is missing", 1, true), "missing key gives a message")
end

T.done()
