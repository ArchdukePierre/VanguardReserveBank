local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local DUMP = ARGS and ARGS[1] == "dump"
local world, server = N.world()
local nextpc = 10

local SECTION = "setup"
local raw_check = T.check
T.check = function(cond, msg) return raw_check(cond, "[" .. SECTION .. "] " .. tostring(msg)) end
local function section(name) SECTION = name end

local function rpc(body)
  local out
  nextpc = nextpc + 1
  local pc = N.client_pc(world, nextpc)
  N.run_client(world, pc, function()
    local Client = require("lib.client")
    local c = assert(Client.new({ admin = (require("lib.cfg")).read_key("admin.key") }))
    out = body(function(m, p, admin) return c:call(m, p, { admin = admin }) end)
  end)
  return out
end

local function login(call, owner, pin)
  local r = call("auth_by_owner", { owner = owner, pin = pin })
  assert(r.ok, "login " .. owner)
  return r.session
end

local function profile(owner, pin)
  return rpc(function(call)
    local s = login(call, owner, pin)
    local p = call("profile", { session = s })
    call("signout", { session = s })
    return p.profile
  end)
end

local function fake_speaker()
  local S = { notes = {} }
  function S.playNote(instrument, volume, pitch) S.notes[#S.notes + 1] = instrument end
  return S
end

local function fake_printer()
  local P = { pages = {}, paper = 4, ink = 4 }
  local cur
  function P.getPaperLevel() return P.paper end
  function P.getInkLevel() return P.ink end
  function P.newPage() cur = { lines = {}, y = 1 }; return true end
  function P.setPageTitle(t) cur.title = t end
  function P.getPageSize() return 25, 21 end
  function P.setCursorPos(x, y) cur.y = y end
  function P.write(s) cur.lines[cur.y] = s end
  function P.endPage() P.pages[#P.pages + 1] = cur; cur = nil; return true end
  return P
end

local function fake_drive(mount)
  local D = { present = true }
  function D.isDiskPresent() return D.present end
  function D.getMountPath() return D.present and mount or nil end
  return D
end

local function fake_inventory(registry, name, slots)
  local I = { slots = slots, name = name }
  registry[name] = I
  function I.list()
    local out = {}
    for s, st in pairs(I.slots) do out[s] = { name = st.name, count = st.count } end
    return out
  end
  function I.pushItems(to, slot, limit)
    local target, st = registry[to], I.slots[slot]
    if not target or not st then return 0 end
    local n = math.min(limit or st.count, st.count)
    st.count = st.count - n
    if st.count == 0 then I.slots[slot] = nil end
    for _, ts in pairs(target.slots) do
      if ts.name == st.name then ts.count = ts.count + n; return n end
    end
    local free = 1
    while target.slots[free] do free = free + 1 end
    target.slots[free] = { name = st.name, count = n }
    return n
  end
  return I
end

local function rig(C, name, mon)
  local R = { C = C, name = name, mon = mon, clipped = {}, calls = {}, overlaps = {}, cells = {}, audited = 0 }
  C.env.require("ui.app")
  C.env.require("lib.client")
  local App = C.env.package.loaded["ui.app"]
  local Screen = C.env.package.loaded["ui.screen"]
  local Client = C.env.package.loaded["lib.client"]
  local orig_new = App.new
  App.new = function(o) local a = orig_new(o); R.app = a; return a end
  local orig_clear, orig_text, orig_fill = Screen.clear, Screen.text, Screen.fill
  Screen.clear = function(self, bg, fg) R.cells, R.overlaps = {}, {}; return orig_clear(self, bg, fg) end
  Screen.text = function(self, x, y, str, fg, bg)
    str = tostring(str)
    if y >= 1 and y <= self.h and #str > 0 and (x < 1 or x + #str - 1 > self.w) then R.clipped[#R.clipped + 1] = string.format("'%s' at %d,%d (width %d)", str, x, y, self.w) end
    for i = 1, #str do
      local ch, cx = str:sub(i, i), x + i - 1
      if ch ~= " " and cx >= 1 and cx <= self.w and y >= 1 and y <= self.h then
        local k = y * 1000 + cx
        if R.cells[k] and R.cells[k] ~= ch then R.overlaps[#R.overlaps + 1] = string.format("text '%s' over '%s' at %d,%d", str, R.cells[k], cx, y) end
        R.cells[k] = ch
      end
    end
    return orig_text(self, x, y, str, fg, bg)
  end
  Screen.fill = function(self, x, y, w, h, bg, ch, fg)
    for row = y, y + h - 1 do
      for c = x, x + w - 1 do
        local k = row * 1000 + c
        if ch and ch ~= " " then R.cells[k] = ch
        elseif R.cells[k] then R.overlaps[#R.overlaps + 1] = string.format("fill over '%s' at %d,%d", R.cells[k], c, row); R.cells[k] = nil end
      end
    end
    return orig_fill(self, x, y, w, h, bg, ch, fg)
  end
  R.inject = {}
  local orig_call = Client.call
  Client.call = function(self, method, params, o)
    local r
    if R.inject[method] then
      r = R.inject[method]
      R.inject[method] = nil
    else
      r = orig_call(self, method, params, o)
    end
    R.calls[#R.calls + 1] = { m = method, p = params, r = r }
    return r
  end

  function R.screen() return (R.mon or C.term)._dump() end
  function R.has(text) return R.screen():find(text, 1, true) ~= nil end
  function R.settle(sec) world:run({ seconds = sec or 0.5 }) end
  function R.last(method)
    for i = #R.calls, 1, -1 do if R.calls[i].m == method then return R.calls[i] end end
  end
  function R.count(method)
    local n = 0
    for _, c in ipairs(R.calls) do if method == nil or c.m == method then n = n + 1 end end
    return n
  end

  function R.problems()
    local s = R.app and R.app.s
    local bad = {}
    for _, c in ipairs(R.clipped) do bad[#bad + 1] = "cut off: " .. c end
    R.clipped = {}
    if s and not R.app.toast then
      for _, o in ipairs(R.overlaps) do bad[#bad + 1] = "overlap: " .. o end
      for i, r in ipairs(s.regions) do
        if r.x < 1 or r.y < 1 or r.x + r.w - 1 > s.w or r.y + r.h - 1 > s.h then bad[#bad + 1] = string.format("region %s outside screen", tostring(r.id)) end
        for j = i + 1, #s.regions do
          local q = s.regions[j]
          if r.x < q.x + q.w and q.x < r.x + r.w and r.y < q.y + q.h and q.y < r.y + r.h then bad[#bad + 1] = string.format("regions %s and %s overlap", tostring(r.id), tostring(q.id)) end
        end
      end
    end
    return bad
  end

  function R.audit(tag)
    R.audited = R.audited + 1
    local where = string.format("%s after %s", name, tag)
    local bad = R.problems()
    if #bad > 0 then
      print("LAYOUT " .. where .. ":\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 6)) .. "\n" .. R.screen())
      T.failed = T.failed + 1
    else
      T.passed = T.passed + 1
    end
    if DUMP then print("---- " .. where .. "\n" .. R.screen()) end
  end

  function R.region(id)
    for _, r in ipairs(R.app.s.regions) do if r.id == id then return r end end
  end

  function R.touch(x, y)
    if R.mon then C.queue[#C.queue + 1] = { "monitor_touch", R.mon.__name, x, y }
    else C.queue[#C.queue + 1] = { "mouse_click", 1, x, y } end
  end

  function R.after(tag)
    R.settle()
    R.audit(tag)
  end

  function R.tap_id(id)
    local r = R.region(id)
    if not T.check(r ~= nil, name .. ": no region " .. tostring(id) .. "\n" .. R.screen()) then return false end
    R.touch(r.x + math.floor(r.w / 2), r.y)
    R.after("tap " .. tostring(id))
    return true
  end

  function R.find(label)
    local y = 0
    for line in (R.screen() .. "\n"):gmatch("(.-)\n") do
      y = y + 1
      local init = 1
      while true do
        local a, b = line:find(label, init, true)
        if not a then break end
        if not line:sub(a - 1, a - 1):match("%w") and not line:sub(b + 1, b + 1):match("%w") then
          local x = a + math.floor((b - a) / 2)
          if R.app.s:hit(x, y) then return x, y end
        end
        init = a + 1
      end
    end
  end

  function R.tap(label)
    local x, y = R.find(label)
    if not T.check(x ~= nil, name .. ": nothing to touch labelled '" .. label .. "'\n" .. R.screen()) then return false end
    R.touch(x, y)
    R.after("tap " .. label)
    return true
  end

  function R.type(text)
    for ch in text:gmatch(".") do C.queue[#C.queue + 1] = { "char", ch } end
    R.after("type " .. text)
  end

  function R.keys(text)
    for ch in text:gmatch(".") do
      if ch:match("%u") then R.tap_id("shift") end
      R.tap_id("k:" .. ch)
      if ch:match("%u") then R.tap_id("shift") end
    end
  end

  function R.digits(text)
    for ch in text:gmatch("%d") do R.tap_id("key:" .. ch) end
  end

  function R.key(k)
    local code = ({ enter = 257, escape = 256, backspace = 259, down = 264, up = 265 })[k]
    C.queue[#C.queue + 1] = { "key", code, false }
    R.after("key " .. k)
  end

  function R.expect(text, msg)
    local ok = T.check(R.has(text), name .. ": " .. (msg or ("expected '" .. text .. "'")) .. "\n" .. R.screen())
    if not ok then R.errors() end
    return ok
  end

  function R.refuse(text, msg)
    return T.check(not R.has(text), name .. ": " .. (msg or ("did not expect '" .. text .. "'")) .. "\n" .. R.screen())
  end

  function R.start()
    local fn = function() require("roles.atm").run() end
    T.setenv(fn, C.env)
    world:start(C, function()
      local ok, err = xpcall(fn, debug.traceback)
      R.exit = { ok = ok, err = err }
      print("ATM STOPPED: " .. tostring(err))
      T.failed = T.failed + 1
    end)
    R.settle(1)
    R.audit("start")
  end

  function R.errors(quiet)
    local n = 0
    for _, line in ipairs(C.printed) do
      if line:find("ATM error", 1, true) then
        n = n + 1
        if not quiet then print(name .. ": " .. line) end
      end
    end
    return n
  end

  function R.click(label)
    local x, y = R.find(label)
    if not T.check(x ~= nil, name .. ": nothing to click labelled '" .. label .. "'\n" .. R.screen()) then return false end
    C.queue[#C.queue + 1] = { "mouse_click", 1, x, y }
    R.after("click " .. label)
    return true
  end

  return R
end

local seed = rpc(function(call)
  local a = call("open_account", { owner = "alice", pin = "1234" })
  local b = call("open_account", { owner = "bob", pin = "4321" })
  T.check(a.ok and b.ok, "seed accounts")
  call("admin_issue", { account_id = a.checking_id, amount = 100000, reason = "seed funds" }, true)
  call("admin_issue", { account_id = b.checking_id, amount = 5000, reason = "seed funds" }, true)
  return { a = a, b = b }
end)

local big_pc = N.client_pc(world, 3, nil, { monitors = { { w = 57, h = 38, scale = 0.5 } }, w = 51, h = 19 })
local speaker, printer, drive = fake_speaker(), fake_printer(), fake_drive("disk")
local chests = {}
local drop = fake_inventory(chests, "chest_drop", { [1] = { name = "minecraft:diamond", count = 3 }, [2] = { name = "minecraft:dirt", count = 9 } })
local bank_chest = fake_inventory(chests, "chest_bank", { [1] = { name = "minecraft:diamond", count = 10 } })
big_pc.add_peripheral("speaker_0", "speaker", speaker)
big_pc.add_peripheral("printer_0", "printer", printer)
big_pc.add_peripheral("drive_0", "drive", drive)
big_pc.add_peripheral("chest_drop", "inventory", drop)
big_pc.add_peripheral("chest_bank", "inventory", bank_chest)
big_pc.env.settings.get = function(k, d)
  return ({ ["vrb.atm.drop"] = "chest_drop", ["vrb.atm.bank"] = "chest_bank" })[k] or d
end
local A = rig(big_pc, "big", big_pc.monitors[1])
A.start()

do
  local scr = A.app.s
  scr:text(scr.w - 2, 10, "abcdef")
  scr:text(5, 12, "hello")
  scr:text(7, 12, "XY")
  scr:region(3, 20, 6, 2, "ghost1")
  scr:region(5, 21, 6, 2, "ghost2")
  local bad = A.problems()
  T.check(#bad >= 3, "the layout audit catches cut off text, overlapping text and overlapping buttons (" .. #bad .. ")")
  A.app:refresh()
  T.eq(#A.problems(), 0, "a fresh render is clean again")
end

A.expect("SIGN IN")
A.expect("OPEN ACCOUNT")
A.expect("REWARDS")
A.expect("WORK ORDERS")
A.expect("RATES")
A.expect("FIND A PLAYER")
do
  local writes, netcalls = A.mon._T.calls, #A.calls
  world:run({ seconds = 120 })
  T.eq(A.mon._T.calls, writes, "idle home screen writes nothing for 120 seconds")
  T.eq(#A.calls, netcalls, "idle home screen sends no requests")
end

section("open an account")
A.tap("OPEN ACCOUNT")
A.type("carol")
A.key("enter")
A.digits("5555")
A.digits("5556")
A.expect("did not match", "mismatched PINs are refused")
A.tap("OK")
A.digits("5555")
A.digits("5555")
A.expect("Account opened")
A.expect("ACC-")
A.refuse("5555", "the PIN is never shown")
local carol = rpc(function(call) return call("lookup", { owner = "carol" }) end)
T.check(carol.ok and #carol.accounts == 1, "carol has a payable account on the server")
T.eq(A.last("open_account").p.pin, "5555", "open_account got the PIN once")
A.tap("CONTINUE")
A.expect("Welcome, carol", "new account signs in by itself")
A.tap("SIGN OUT")
A.expect("SIGN IN")
local out = A.last("signout")
T.check(out and out.p.session, "sign out tells the bank")

section("a wrong PIN shows the server's words and stays signed out")
A.tap("SIGN IN")
A.tap("USERNAME")
A.type("alice")
A.key("enter")
A.digits("9999")
A.expect("Invalid credentials", "wrong PIN shows the server message")
A.tap("OK")
A.expect("SIGN IN")
A.expect("OPEN ACCOUNT")

local function sign_in(R, owner, pin)
  R.tap("SIGN IN")
  R.tap("USERNAME")
  R.type(owner)
  R.key("enter")
  R.digits(pin)
  R.expect("Welcome, " .. owner, owner .. " signs in")
end

sign_in(A, "alice", "1234")
A.expect("$1,000.00")
A.expect("Checking")
A.expect("Savings")
T.check(A.last("auth_by_owner").p.branch == "client3", "sign in carries the branch name")
T.check(A.last("profile") and A.last("ping"), "dashboard loads profile and rates")

section("pay bob with a note")
A.tap("PAY")
A.expect("bob")
A.expect("carol")
T.check(A.region(seed.b.checking_id) ~= nil, "bob is in the payee list")
T.check(A.region(seed.a.checking_id) == nil, "you are not in your own payee list")
local lp = A.last("list_payable_accounts")
T.check(lp.p.offset == 0 and lp.p.limit >= 3 and lp.p.limit <= 100, "payee list is paged from the server")
A.tap("FIND")
A.type("bo")
A.key("enter")
T.eq(A.last("list_payable_accounts").p.q, "bo", "search sends the typed name")
A.expect("bob")
A.refuse("carol", "search narrows the list")
A.tap("bob")
A.type("20")
A.key("enter")
A.tap("ADD A NOTE")
A.type("lunch money")
A.key("enter")
A.expect("Tax: $1.00 (5%)")
A.expect("bob gets: $19.00")
A.expect("Note: lunch money")
A.tap("SEND")
A.expect("Payment sent")
A.expect("$980.00")
A.tap("PRINT RECEIPT")
T.check(#printer.pages == 1 and printer.pages[1].lines[5] and printer.pages[1].lines[5]:find("Paid: bob"), "receipt printed with the payee")
T.check(#speaker.notes > 0, "speaker played a note")
A.tap("DONE")
local p = profile("alice", "1234")
T.eq(p.checking.balance, 98000, "alice paid $20.00")
T.eq(profile("bob", "4321").checking.balance, 6900, "bob received $19.00 after tax")
T.eq(A.last("transfer").p.memo, "lunch money", "memo went to the server")

section("bills: alice bills bob from the ATM")
A.tap("BILLS")
A.expect("BILL A PLAYER")
A.expect("BILLS TO YOU")
A.expect("BILLS YOU SENT")
A.tap("BILL A PLAYER")
A.tap("bob")
A.type("5")
A.key("enter")
A.tap("NO NOTE")
A.expect("Amount: $5.00")
A.tap("SEND BILL")
A.expect("Bill sent")
A.tap("OK")
A.tap("BILLS YOU SENT")
A.expect("bob")
A.expect("$5.00")
A.tap("BACK")
A.tap("BACK")
A.tap("SIGN OUT")
A.expect("SIGN IN")

local sent = rpc(function(call)
  local s = login(call, "alice", "1234")
  local r1 = call("request_payment", { session = s, target_owner = "bob", amount = 100000, memo = "rent" })
  local r2 = call("request_payment", { session = s, target_owner = "bob", amount = 300, memo = "snack" })
  call("signout", { session = s })
  return { rent = r1.request_id, snack = r2.request_id }
end)

local function bills_of(owner, pin)
  return rpc(function(call)
    local s = login(call, owner, pin)
    local r = call("list_payment_requests", { session = s })
    call("signout", { session = s })
    local by = {}
    for _, b in ipairs(r.requests) do by[b.amount] = b end
    return by
  end)
end

sign_in(A, "bob", "4321")
A.tap("BILLS")
A.tap("BILLS TO YOU")
A.expect("$1,000.00")
A.expect("$3.00")
A.expect("$5.00")
A.tap("$1,000.00")
A.tap("PAY WHEN FUNDED")
A.expect("Auto-pay is on")
A.tap("OK")
T.eq(bills_of("bob", "4321")[100000].status, "auto_pending", "bill armed to pay when funded")
A.tap("$3.00")
A.tap("DECLINE")
A.tap("DECLINE")
T.check(bills_of("bob", "4321")[300] == nil, "declined bill is gone from the inbox")
A.tap("$1,000.00")
A.tap("STOP AUTO-PAY")
T.eq(bills_of("bob", "4321")[100000].status, "pending", "auto-pay stopped")
A.tap("$5.00")
A.tap("PAY NOW")
A.expect("Pay alice $5.00?")
A.tap("PAY")
A.expect("Bill paid")
A.expect("$64.00")
A.tap("OK")
T.eq(profile("bob", "4321").checking.balance, 6400, "bob paid the bill")
T.eq(profile("alice", "1234").checking.balance, 98475, "alice got the bill after tax")
A.tap("BACK")
A.tap("BACK")
A.tap("SIGN OUT")

sign_in(A, "alice", "1234")
A.tap("BILLS")
A.tap("BILLS YOU SENT")
A.expect("$1,000.00")
A.tap("$1,000.00")
A.expect("Cancel your bill to bob")
A.tap("CANCEL BILL")
A.expect("No open bills")
T.eq(next(bills_of("bob", "4321")), nil, "alice cancelled her bill")
A.tap("BACK")
A.tap("BACK")

section("move money, with the early savings tax")
A.tap("MOVE MONEY")
A.tap("CHECKING TO SAVINGS")
A.type("100")
A.key("enter")
A.expect("Move $100.00")
A.tap("MOVE")
A.expect("Money moved")
A.tap("OK")
T.eq(profile("alice", "1234").savings.balance, 10000, "moved $100.00 to savings")
A.tap("MOVE MONEY")
A.tap("SAVINGS TO CHECKING")
A.type("50")
A.key("enter")
A.expect("30 days old")
A.expect("up to $25.00")
A.tap("MOVE")
A.expect("Early tax taken: $25.00")
A.tap("OK")
p = profile("alice", "1234")
T.eq(p.checking.balance, 98475 - 10000 + 5000 - 2500, "early savings tax came out of the move")
T.eq(p.savings.balance, 5000, "savings after the move")
A.expect("under 30 days old", "dashboard warns about young savings")

section("history")
A.tap("HISTORY")
A.expect("Payment sent")
A.expect("Bill received")
A.expect("Moved out")
A.expect("-$20.00")
A.expect("+$4.75")
local function color_of(R, text)
  local y = 0
  for line in (R.screen() .. "\n"):gmatch("(.-)\n") do
    y = y + 1
    local a = line:find(text, 1, true)
    if a then return R.mon._T.fgs[y]:sub(a, a) end
  end
end
T.eq(color_of(A, "-$20.00"), A.C.env.colors.toBlit(A.C.env.colors.red), "payments out show in red")
T.eq(color_of(A, "+$4.75"), A.C.env.colors.toBlit(A.C.env.colors.lime), "money in shows in green")
A.tap("BACK")

section("idle timeout signs out")
local sid = A.last("auth_by_owner").r.session
world:run({ seconds = 55 })
A.expect("Welcome, alice", "still signed in before 60 seconds")
world:run({ seconds = 10 })
A.audit("idle sign out")
A.expect("SIGN IN", "idle timeout returns home")
T.eq(A.last("signout").p.session, sid, "idle timeout calls signout")
T.eq(rpc(function(call) return call("profile", { session = sid }).code end), "no_session", "server dropped the idle session")
do
  local writes, netcalls = A.mon._T.calls, #A.calls
  world:run({ seconds = 300 })
  T.eq(A.mon._T.calls, writes, "home writes nothing after the idle sign out")
  T.eq(#A.calls, netcalls, "home sends nothing after the idle sign out")
end

section("the bank stops answering, then the session disappears")
sign_in(A, "alice", "1234")
local link = server.modems.back
local cfgmod = A.C.env.require("lib.cfg")
local channel = cfgmod.channel(cfgmod.load())
link.closeAll()
A.touch(1, 1)
local x, y = A.find("HISTORY")
A.touch(x, y)
world:run({ seconds = 16 })
A.audit("bank not answering")
A.expect("not responding", "a timeout shows a clear error")
A.tap("OK")
A.expect("Welcome, alice", "a timeout keeps you on the same screen")
link.open(channel)
sid = A.last("auth_by_owner").r.session
rpc(function(call) return call("signout", { session = sid }) end)
A.tap("HISTORY")
A.expect("Your session ended", "a dead session returns to the start")
A.tap("OK")
A.expect("SIGN IN")

section("the rest of the screens")
local function to_dashboard(R)
  for _ = 1, 8 do
    if R.has("Welcome,") then return end
    R.key("escape")
  end
end

local function chk_balance(owner, pin) return profile(owner, pin).checking.balance end

local extra = rpc(function(call)
  call("admin_issue", { account_id = "FUND-000000", amount = 500000, reason = "fund the works" }, true)
  local w = call("admin_post_work_order", { title = "Fix the bridge", bounty = 2500, description = "Replace the broken planks on the north bridge." }, true)
  local j = call("admin_create_job", { title = "Mayor", annual_cents = 5000000 }, true)
  local rk = call("admin_set_rank", { account_id = seed.b.checking_id, rank_id = "E3" }, true)
  T.check(w.ok and j.ok and rk.ok, "seed work order, job and rank")
  return { order = w.order_id, job = j.job_id }
end)

sign_in(A, "alice", "1234")

section("CDs")
local before = chk_balance("alice", "1234")
A.tap("CDS AND LOANS")
A.tap("CDS")
A.expect("No CDs yet")
A.tap("NEW CD")
A.type("100")
A.key("enter")
A.expect("90 DAYS")
A.expect("3.5% a month")
A.tap("30 DAYS")
A.expect("Lock $100.00")
A.expect("5%")
A.tap("OPEN CD")
A.expect("Your CD number is CD-")
A.tap("OK")
A.expect("$100.00")
T.eq(chk_balance("alice", "1234"), before - 10000, "CD took $100.00 from checking")
A.tap("$100.00")
A.expect("Not ready yet")
A.expect("$95.00")
A.tap("CASH IN EARLY")
A.expect("You received $95.00")
A.tap("OK")
A.expect("No CDs yet")
T.eq(chk_balance("alice", "1234"), before - 500, "early CD redeem paid back 95%")

section("loans")
A.tap("BACK")
A.tap("LOANS")
A.expect("No loans")
A.tap("NEW LOAN")
A.type("100")
A.key("enter")
A.expect("Keep $25.00 in checking")
A.tap("BORROW")
A.expect("Loan number LOAN-")
A.tap("OK")
A.expect("Your loans")
A.expect("$100.00")
A.tap("$100.00")
A.expect("Owed: $100.00")
A.tap("ENTER AN AMOUNT")
A.type("30")
A.key("enter")
A.expect("Still owed: $70.00")
A.tap("OK")
A.tap("$70.00")
A.tap("PAY $70.00")
A.expect("The loan is paid off")
A.tap("OK")
A.expect("No loans")
T.eq(rpc(function(call) return #call("list_loans", { session = login(call, "alice", "1234") }).loans end), 0, "loan repaid")
to_dashboard(A)

section("earn: earnings, insurance, rewards, work orders, civic jobs, rank")
A.tap("EARN")
A.tap("MY EARNINGS")
A.expect("Streak")
A.expect("No payout yet")
A.tap("HISTORY")
A.expect("No payouts yet")
A.tap("BACK")
A.tap("INSURANCE")
A.expect("Cost for 30 days")
A.expect("$500.00")
A.tap("BUY")
A.expect("Pay $500.00 for 30 days")
A.tap("BUY")
A.expect("Insured")
A.tap("OK")
A.expect("Active")
A.expect("CANCEL POLICY")
T.eq(rpc(function(call) return call("my_earnings", { session = login(call, "alice", "1234") }).insurance_active end), true, "insurance bought")
A.tap("CANCEL POLICY")
A.tap("CANCEL POLICY")
T.eq(rpc(function(call) return call("my_earnings", { session = login(call, "alice", "1234") }).insurance_active end), false, "insurance cancelled")
to_dashboard(A)
A.tap("EARN")
A.tap("REWARDS")
A.expect("First diamond mined")
A.tap("First diamond mined")
A.type("mined_a_diamond")
A.key("enter")
A.expect("Claim sent")
A.tap("OK")
A.expect("Waiting for staff")
local claims = rpc(function(call) return call("my_claims", { session = login(call, "alice", "1234") }).claims end)
T.check(#claims == 1 and claims[1].pending, "reward claim is waiting for staff")
A.tap("BACK")
A.tap("WORK ORDERS")
A.expect("Fix the bridge")
A.tap("Fix the bridge")
A.expect("Replace the broken planks")
A.tap("TAKE THIS JOB")
A.expect("Work order taken")
A.tap("OK")
local function order_owner()
  return rpc(function(call)
    for _, o in ipairs(call("list_work_orders", {}).orders) do if o.title == "Fix the bridge" then return o.claimed_by end end
  end)
end
T.eq(order_owner(), seed.a.checking_id, "alice took the work order")
A.tap("Fix the bridge")
A.tap("GIVE BACK")
T.eq(order_owner(), nil, "alice gave the work order back")
A.tap("BACK")
A.tap("CIVIC JOBS")
A.expect("Mayor")
A.tap("Mayor")
A.expect("Apply to be Mayor?")
A.tap("APPLY")
A.expect("Application sent")
A.tap("OK")
A.expect("waiting for staff")
A.tap("MY JOB")
A.expect("No civic job")
A.tap("BACK")
A.tap("CANCEL APPLICATION")
A.refuse("waiting for staff", "application cancelled")
A.tap("BACK")
A.tap("VANGUARD RANK")
A.expect("not in the Vanguard")
A.tap("ALL RANKS")
A.expect("Lance Corporal")
to_dashboard(A)

section("settings")
A.tap("SETTINGS")
A.tap("NOTIFICATIONS")
A.expect("Daily payout summary")
A.expect("OFF")
A.tap("Daily payout summary")
A.expect("ON")
local subs = rpc(function(call) return call("my_notif_subs", { session = login(call, "alice", "1234") }).channels end)
T.check(subs[1].id == "daily" and subs[1].subscribed, "notification switched on")
A.tap("BACK")
A.tap("ACCOUNT CHECK")
A.expect("matches every entry")
A.tap("OK")
to_dashboard(A)

section("factions")
A.tap("FACTIONS")
A.expect("No factions yet")
A.tap("NEW")
A.type("Builders")
A.key("enter")
A.type("2")
A.key("enter")
A.type("2")
A.key("enter")
A.expect("2 of 2 members must approve")
A.tap("CREATE")
A.expect("Faction created")
A.tap("OK")
A.expect("Builders")
local fac = rpc(function(call)
  local s = login(call, "alice", "1234")
  local f = call("list_factions", { session = s }).factions[1]
  call("transfer", { session = s, target_id = f.treasury, amount = 20000 })
  return f
end)
T.eq(fac.name, "Builders", "faction chartered")
to_dashboard(A)
A.tap("BILLS")
A.tap("BILL A PLAYER")
A.tap_id(fac.treasury)
A.expect("You can only bill players")
A.tap("OK")
to_dashboard(A)
A.tap("FACTIONS")
A.tap("Builders")
A.expect("founder")
A.expect(fac.treasury)
A.tap("ADD")
A.type("bob")
A.key("enter")
A.expect("bob added")
T.eq(#rpc(function(call) return call("list_factions", { session = login(call, "alice", "1234") }).factions[1].members end), 2, "bob joined the faction")
A.tap("Builders")
A.tap("PAY OUT")
A.tap("bob")
A.type("10")
A.key("enter")
A.tap("NO NOTE")
A.expect("Needs 2 approvals")
A.tap("PROPOSE")
A.expect("Waiting for approval")
A.tap("OK")
A.tap("BACK")
A.tap("BACK")
A.tap("FACTIONS")
A.tap("PENDING")
A.expect("1 of 2 approved, including you")
A.tap("Builders")
A.expect("You already approved this one")
A.expect("CANCEL PAYMENT")
to_dashboard(A)
A.tap("SIGN OUT")

section("bob approves, checks his rank and refunds an escrow")
sign_in(A, "bob", "4321")
local bob_before = chk_balance("bob", "4321")
A.tap("FACTIONS")
A.tap("PENDING")
A.tap("Builders")
A.tap("APPROVE")
A.expect("The payment went through")
A.tap("OK")
T.eq(chk_balance("bob", "4321"), bob_before + 950, "bob's approval released the faction payment")
to_dashboard(A)
A.tap("EARN")
A.tap("VANGUARD RANK")
A.expect("Lance Corporal")
A.expect("Enlisted")
to_dashboard(A)
rpc(function(call)
  local s = login(call, "alice", "1234")
  T.check(call("create_escrow", { session = s, counterparty = seed.b.checking_id, amount = 1500, memo = "deal" }).ok, "escrow created for refund")
end)
local alice_before = chk_balance("alice", "1234")
A.tap("ESCROW")
A.expect("From " .. seed.a.checking_id)
A.tap("$15.00")
A.expect("Return $15.00")
A.tap("SEND BACK")
A.expect("Sent back")
A.tap("OK")
T.eq(chk_balance("alice", "1234"), alice_before + 1500, "refund returned the escrow")
to_dashboard(A)
A.tap("SIGN OUT")

section("alice: scheduled payments, escrow, shops")
sign_in(A, "alice", "1234")
section("founder cancels a pending payment and removes a member")
A.tap("FACTIONS")
A.tap("Builders")
A.tap("PAY OUT")
A.tap("bob")
A.type("5")
A.key("enter")
A.tap("NO NOTE")
A.tap("PROPOSE")
A.tap("OK")
A.tap("BACK")
A.tap("PENDING")
A.tap("Builders")
A.tap("CANCEL PAYMENT")
A.expect("Nothing waiting")
A.tap("BACK")
A.tap("Builders")
A.tap("REMOVE")
A.tap("bob")
A.expect("Remove bob from Builders?")
A.tap("REMOVE")
A.expect("Builders")
T.eq(#rpc(function(call) return call("list_factions", { session = login(call, "alice", "1234") }).factions[1].members end), 1, "founder removed bob")
to_dashboard(A)
section("scheduled payments")
A.tap("SCHEDULED")
A.expect("Nothing scheduled")
A.tap("NEW")
A.tap("bob")
A.type("1")
A.key("enter")
A.tap("EVERY FEW DAYS")
A.type("3")
A.key("enter")
A.type("5")
A.key("enter")
A.tap("NO NOTE")
A.expect("every 3 days, 5 times")
A.tap("SCHEDULE")
A.expect("Scheduled")
A.tap("OK")
local rec = rpc(function(call) return call("list_my_recurring", { session = login(call, "alice", "1234") }).recurring end)
T.check(#rec == 1 and rec[1].interval_sec == 259200 and rec[1].remaining == 5 and rec[1].amount == 100, "recurring payment set up")
A.tap("To " .. seed.b.checking_id)
A.expect("every 3 days")
A.tap("STOP")
A.expect("Nothing scheduled")
T.eq(#rpc(function(call) return call("list_my_recurring", { session = login(call, "alice", "1234") }).recurring end), 0, "recurring payment cancelled")
to_dashboard(A)
bob_before = chk_balance("bob", "4321")
A.tap("ESCROW")
A.expect("No escrows")
A.tap("NEW")
A.tap("bob")
A.type("10")
A.key("enter")
A.tap("NO NOTE")
A.tap("HOLD")
A.expect("Escrow started")
A.tap("OK")
A.tap("To " .. seed.b.checking_id)
A.expect("Tax applies")
A.tap("RELEASE")
A.expect("Released")
A.tap("OK")
T.eq(chk_balance("bob", "4321"), bob_before + 950, "released escrow paid bob after tax")
to_dashboard(A)

A.tap("SHOPS")
A.expect("No shops yet")
A.tap("NEW SHOP")
A.type("Gem Stall")
A.key("enter")
A.expect("Shop created")
A.tap("OK")
A.tap("Gem Stall")
A.expect("No items listed")
A.tap("ADD ITEM")
A.type("DIA1")
A.key("enter")
A.type("Diamond")
A.key("enter")
A.type("64")
A.key("enter")
A.type("5")
A.key("enter")
A.tap("ENTER ITEM ID")
A.type("minecraft:diamond")
A.key("enter")
A.expect("$64.00")
local shops = rpc(function(call) return call("list_my_shops", { session = login(call, "alice", "1234") }).shops end)
local item = shops[1] and shops[1].items[1]
T.check(item and item.sku == "DIA1" and item.price == 6400 and item.stock == 5 and item.item_id == "minecraft:diamond", "shop listing saved with its item id")
A.tap("Diamond")
A.tap("CHANGE PRICE AND STOCK")
A.type("70")
A.key("enter")
A.type("4")
A.key("enter")
A.tap("KEEP ITEM ID")
shops = rpc(function(call) return call("list_my_shops", { session = login(call, "alice", "1234") }).shops end)
item = shops[1] and shops[1].items[1]
T.check(item and item.price == 7000 and item.stock == 4 and item.item_id == "minecraft:diamond", "listing updated and kept its item id")
A.tap("Diamond")
A.tap("REMOVE FROM SHOP")
A.tap("REMOVE")
A.expect("No items listed")
to_dashboard(A)

section("notes and item deposits")
alice_before = chk_balance("alice", "1234")
local note = rpc(function(call)
  local r = call("admin_issue_note", { account_id = seed.a.checking_id, denomination = 25 }, true)
  T.check(r.ok, "note issued")
  return r.note
end)
T.eq(chk_balance("alice", "1234"), alice_before - 2500, "issuing the note took $25.00")
local note_text = A.C.env.textutils.serialize(note)
local function write_note()
  if not A.C.fs.exists("disk") then A.C.fs.makeDir("disk") end
  local f = A.C.fs.open("disk/note.vrb", "w")
  f.write(note_text)
  f.close()
end
A.tap("NOTES AND ITEMS")
A.expect("REDEEM NOTE")
A.expect("DEPOSIT ITEMS")
drive.present = false
A.tap("REDEEM NOTE")
A.expect("Put your note disk")
A.tap("OK")
drive.present = true
A.tap("REDEEM NOTE")
A.expect("no note on this disk")
A.tap("OK")
write_note()
A.tap("REDEEM NOTE")
A.expect("Worth $25.00")
A.tap("REDEEM")
A.expect("Note redeemed")
A.tap("OK")
T.eq(chk_balance("alice", "1234"), alice_before, "redeeming the note paid $25.00")
T.check(not A.C.fs.exists("disk/note.vrb"), "note file deleted after redeeming")
write_note()
A.tap("REDEEM NOTE")
A.tap("REDEEM")
A.expect("already redeemed")
A.tap("OK")
T.check(A.C.fs.exists("disk/note.vrb"), "note file kept when the bank refuses it")
alice_before = chk_balance("alice", "1234")
A.tap("DEPOSIT ITEMS")
A.expect("3 x Diamond")
A.expect("$192.00")
A.refuse("Dirt", "unbacked items are not offered")
A.inject.item_deposit = { ok = false, err = "Item backing is off", code = "x" }
A.tap("DEPOSIT")
A.expect("Item backing is off")
A.tap("OK")
T.check(drop.slots[1] and drop.slots[1].count == 3 and bank_chest.slots[1].count == 10, "items go back to the player when the bank refuses the deposit")
A.expect("3 x Diamond")
A.tap("DEPOSIT")
A.expect("Items deposited")
A.expect("Credited: $192.00")
A.tap("OK")
T.eq(chk_balance("alice", "1234"), alice_before + 19200, "item deposit credited three diamonds")
T.check(drop.slots[1] == nil and drop.slots[2] and drop.slots[2].count == 9, "diamonds left the drop chest, dirt stayed")
T.eq(bank_chest.slots[1].count, 13, "diamonds sit in the bank chest")
to_dashboard(A)
A.tap("SIGN OUT")

section("carol changes her PIN")
sign_in(A, "carol", "5555")
A.tap("SETTINGS")
A.tap("CHANGE PIN")
A.digits("5555")
A.digits("2468")
A.digits("2468")
A.expect("PIN changed")
A.tap("OK")
to_dashboard(A)
A.tap("SIGN OUT")
T.check(rpc(function(call) return call("auth_by_owner", { owner = "carol", pin = "2468" }).ok end), "new PIN works")
T.check(not rpc(function(call) return call("auth_by_owner", { owner = "carol", pin = "5555" }).ok end), "old PIN stopped working")

section("sign in by account number")
A.tap("SIGN IN")
A.tap("ACCOUNT NUMBER")
A.type(seed.b.savings_id:sub(5))
A.key("enter")
A.digits("4321")
A.expect("Welcome, bob", "a savings number signs in to the checking account")
T.eq(A.last("auth").p.account_id, seed.b.savings_id, "sign in by number uses the account number")
A.tap("SIGN OUT")

section("duplicate username and a locked account")
A.tap("OPEN ACCOUNT")
A.type("alice")
A.key("enter")
A.digits("1111")
A.digits("1111")
A.expect("already has an account")
A.tap("OK")
A.expect("SIGN IN")
rpc(function(call)
  call("open_account", { owner = "locky", pin = "1357" })
  for _ = 1, 5 do call("auth_by_owner", { owner = "locky", pin = "0000" }) end
end)
A.tap("SIGN IN")
A.tap("USERNAME")
A.type("locky")
A.key("enter")
A.digits("1357")
A.expect("locked")
A.tap("OK")

section("a matured CD")
rpc(function(call)
  local sid = login(call, "alice", "1234")
  T.check(call("open_cd", { session = sid, amount = 10000, days = 30 }).ok, "CD opened for the maturity test")
end)
world.time = world.time + 31 * 86400
world:run({ seconds = 130 })
local before_cd = chk_balance("alice", "1234")
sign_in(A, "alice", "1234")
A.tap("CDS AND LOANS")
A.tap("CDS")
A.expect("Ready")
A.tap("$100.00")
A.expect("This CD is ready")
A.tap("CASH IN")
A.expect("CD cashed in")
A.tap("OK")
T.check(chk_balance("alice", "1234") >= before_cd + 10000, "a matured CD pays back at least the principal")
to_dashboard(A)
A.tap("SIGN OUT")

section("public screens")
A.tap("RATES")
A.tap("INTEREST AND FEES")
A.expect("Savings")
A.expect("2%")
A.expect("Early savings tax")
A.tap("BACK")
A.tap("INCOME TAX")
A.expect("From $0.00 a year")
A.tap("BACK")
A.tap("ITEM VALUES")
A.expect("$64.00 each")
A.tap("BACK")
A.tap("BANK NUMBERS")
A.expect("Accounts")
A.tap("BACK")
A.tap("RECENT ACTIVITY")
A.expect("Names are hidden")
A.tap("BACK")
A.tap("BACK")
A.tap("FIND A PLAYER")
A.type("bob")
A.key("enter")
A.expect(seed.b.checking_id)
A.tap("BACK")
A.tap("REWARDS")
A.expect("Sign in to claim")
A.tap("BACK")
A.tap("WORK ORDERS")
A.tap("Fix the bridge")
A.expect("Replace the broken planks")
A.refuse("TAKE THIS JOB", "signed out players cannot take a work order")
A.tap("BACK")
A.tap("BACK")
A.expect("SIGN IN")

T.check(A.errors() == 0, "no ATM errors were printed")

section("a small 2 by 1 monitor with no extras")
local small_pc = N.client_pc(world, 4, nil, { monitors = { { w = 29, h = 19, scale = 0.5 } }, w = 51, h = 19 })
local S = rig(small_pc, "small", small_pc.monitors[1])
S.start()
S.expect("SIGN IN")
S.expect("FIND A PLAYER")
S.tap("SIGN IN")
S.tap("USERNAME")
S.keys("alice")
S.tap_id("ok")
S.digits("1234")
S.expect("Welcome, alice")

local function open_item(R, label)
  for _ = 1, 8 do
    if R.find(label) then return R.tap(label) end
    if R.region("more") then R.tap_id("more") else break end
  end
  return T.check(false, R.name .. ": cannot find dashboard item " .. label .. "\n" .. R.screen())
end

local function peek(R, label, ...)
  open_item(R, label)
  for _, sub in ipairs({ ... }) do
    R.tap(sub)
    R.key("escape")
  end
  to_dashboard(R)
end

local function walk_menus(R)
  peek(R, "BILLS", "BILL A PLAYER", "BILLS TO YOU", "BILLS YOU SENT")
  peek(R, "HISTORY")
  peek(R, "CDS AND LOANS", "CDS", "LOANS")
  peek(R, "EARN", "MY EARNINGS", "INSURANCE", "REWARDS", "WORK ORDERS", "CIVIC JOBS", "VANGUARD RANK")
  peek(R, "FACTIONS", "PENDING")
  peek(R, "SCHEDULED")
  peek(R, "ESCROW")
  peek(R, "SHOPS")
  peek(R, "SETTINGS", "CHANGE PIN", "ACCOUNT CHECK", "NOTIFICATIONS")
end

local bob_small = chk_balance("bob", "4321")
open_item(S, "PAY")
S.expect("bob")
S.tap("FIND")
S.keys("bo")
S.tap_id("ok")
S.tap("bob")
S.digits("")
S.tap_id("key:2")
S.tap_id("key:0")
S.tap_id("ok")
S.tap("ADD A NOTE")
S.keys("lunch")
S.tap_id("space")
S.keys("money")
S.tap_id("ok")
S.expect("Note: lunch money")
S.tap("SEND")
S.expect("Payment sent")
S.refuse("PRINT RECEIPT", "no printer, no print button")
S.tap("DONE")
T.eq(chk_balance("bob", "4321"), bob_small + 1900, "payment from the small monitor arrived")
to_dashboard(S)
walk_menus(S)
S.refuse("NOTES AND ITEMS", "no disk drive or chest, no notes button")
open_item(S, "SHOPS")
S.tap("Gem Stall")
S.tap("BACK")
S.tap("BACK")
open_item(S, "FACTIONS")
S.tap("Builders")
S.tap("BACK")
S.tap("BACK")

local function line_of(R, n)
  local i = 0
  for l in (R.screen() .. "\n"):gmatch("(.-)\n") do
    i = i + 1
    if i == n then return l end
  end
end

open_item(S, "HISTORY")
local top = line_of(S, 5)
S.tap_id("down")
T.check(line_of(S, 5) ~= top, "history scrolls down on a small screen")
S.tap_id("up")
T.eq(line_of(S, 5), top, "history scrolls back up")
S.key("escape")

section("long player lists are paged by the server")
for batch = 0, 1 do
  rpc(function(call)
    for i = 1, 7 do call("open_account", { owner = string.format("player%02d", batch * 7 + i), pin = "1111" }) end
  end)
end
open_item(S, "PAY")
S.expect("player")
local first = S.last("list_payable_accounts").p
T.eq(first.offset, 0, "first page starts at the top")
S.tap("NEXT")
T.eq(S.last("list_payable_accounts").p.offset, first.limit, "NEXT asks the server for the following page")
S.tap("PREV")
T.eq(S.last("list_payable_accounts").p.offset, 0, "PREV goes back a page")
S.tap("FIND")
S.keys("player1")
S.tap_id("ok")
T.eq(S.last("list_payable_accounts").p.q, "player1", "search is sent to the server")
S.expect("player10")
S.refuse("player02")
S.key("escape")
to_dashboard(S)

section("idle in the middle of a payment signs out")
local sid2 = S.last("auth_by_owner").r.session
open_item(S, "PAY")
S.tap("bob")
S.expect("Dollars and cents")
world:run({ seconds = 65 })
S.audit("idle in the middle of a payment")
S.expect("SIGN IN")
T.eq(S.last("signout").p.session, sid2, "idle at the amount screen signs out")

section("open an account with capitals and an underscore on the small keyboard")
S.tap("OPEN ACCOUNT")
S.keys("Dave_1")
S.tap_id("ok")
S.digits("7777")
S.digits("7777")
S.expect("Account opened")
S.tap("CONTINUE")
S.expect("Welcome, Dave_1")
local dave = rpc(function(call) return call("lookup", { owner = "dave_1" }) end)
T.check(dave.ok and dave.accounts[1] and dave.accounts[1].owner == "Dave_1", "capitals and the underscore reach the server")
S.tap("SIGN OUT")

section("a bug inside a screen signs the player out instead of freezing the kiosk")
sign_in(S, "alice", "1234")
local sid3 = S.last("auth_by_owner").r.session
S.inject.history = { ok = true, history = { false } }
open_item(S, "HISTORY")
S.expect("Something went wrong")
T.eq(S.errors(true), 1, "the unexpected error was printed for the owner")
S.tap("OK")
S.expect("SIGN IN")
T.eq(S.last("signout").p.session, sid3, "an unexpected error signs the player out")
sign_in(S, "alice", "1234")
S.tap("SIGN OUT")

T.eq(S.errors(true), 1, "only the injected error showed up on the small monitor")

section("no monitor: the computer terminal works with the keyboard and the mouse")
local kb_pc = N.client_pc(world, 5, nil, { w = 51, h = 19 })
local K = rig(kb_pc, "terminal", nil)
K.start()
K.expect("1 SIGN IN")
K.type("1")
K.type("1")
K.type("alice")
K.key("enter")
K.type("1234")
K.expect("Welcome, alice")
K.type("4")
K.expect("History")
K.key("escape")
K.expect("Welcome, alice")
K.click("SIGN OUT")
K.expect("1 SIGN IN")
T.eq(K.errors(), 0, "no ATM errors on the terminal")

section("a pocket computer")
local pocket_pc = N.client_pc(world, 6, nil, { w = 26, h = 20 })
local P = rig(pocket_pc, "pocket", nil)
P.start()
P.tap("SIGN IN")
P.tap("USERNAME")
P.keys("alice")
P.tap_id("ok")
P.digits("1234")
P.expect("Welcome, alice")
walk_menus(P)
open_item(P, "PAY")
P.tap("bob")
P.tap_id("key:1")
P.tap_id("ok")
P.tap("ADD A NOTE")
P.keys("hi")
P.tap_id("space")
P.keys("bob")
P.tap_id("ok")
P.expect("Note: hi bob")
P.tap("SEND")
P.expect("Payment sent")
P.tap("DONE")
T.eq(P.errors(), 0, "no ATM errors on the pocket computer")

T.check(A.errors() == 0, "no ATM errors on the large monitor")
T.done()
