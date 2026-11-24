local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")
local cc = T.cc

local world, server = N.world()
world:run({ seconds = 1 })
local node = world:computer({ id = 7, label = "newnode", files = {} })
T.mount(node)
local staff = world:computer({ id = 8, label = "newstaff", files = {} })
T.mount(staff)

cc.key(server, "p")
world:run({ seconds = 0.5 })
local code
for i = #server.term._T.text, 1, -1 do
  local c = server.term._T.text[i]:match("code: ([%u%d]+%-[%u%d]+%-[%u%d]+)")
  if c then code = c; break end
end
T.check(code ~= nil, "server shows a pairing code")

local result = {}
local function join(pc, entered, want_staff)
  local fn = T.setenv(function()
    local pair = require("tools.pair")
    local orig_read = read
    local ok = pair.join(want_staff)
    result.ok = ok
    result.done = true
  end, pc.env)
  pc.env.read = function() return entered end
  result.done = false
  world:start(pc, function() local ok, e = xpcall(fn, debug.traceback); if not ok then print(e); T.failed = T.failed + 1 end end)
  world:run({ seconds = 60, stop = function() return result.done end })
end

join(node, "AAAA-AAAA-AAAA", false)
T.check(result.ok == false, "wrong code does not pair")
T.check(not node.fs.exists("/.vrb/keys/server.secret"), "no key written after a wrong code")

join(node, code:lower(), false)
T.check(result.ok == true, "right code pairs (lowercase accepted)")
T.eq(node.fs.open("/.vrb/keys/server.secret", "r").readAll(), N.SECRET, "node received the server secret")
T.check(not node.fs.exists("/.vrb/keys/admin.key"), "a normal code does not hand out the admin key")

join(node, code, false)
T.check(result.ok == false, "a code works once")

cc.key(server, "s")
world:run({ seconds = 0.5 })
local scode
for i = #server.term._T.text, 1, -1 do
  local c = server.term._T.text[i]:match("STAFF code: ([%u%d]+%-[%u%d]+%-[%u%d]+)")
  if c then scode = c; break end
end
T.check(scode ~= nil, "staff code shown")
join(staff, scode, true)
T.check(result.ok == true, "staff code pairs")
T.eq(staff.fs.open("/.vrb/keys/admin.key", "r").readAll(), N.ADMIN, "staff computer received the admin key")

local r2
N.run_client(world, node, function()
  local c = assert(require("lib.client").new({}))
  r2 = c:call("ping", {})
end)
T.check(r2 and r2.ok, "paired node reaches the bank")
T.done()
