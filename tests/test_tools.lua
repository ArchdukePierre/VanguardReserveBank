local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local world, server = N.world()
local pc = N.client_pc(world, 2)
N.run_client(world, pc, function()
  local c = assert(require("lib.client").new({ admin = require("lib.cfg").read_key("admin.key") }))
  for i = 1, 8 do
    local r = c:call("open_account", { owner = "user" .. i, pin = "1234" })
    c:call("admin_issue", { account_id = r.account_id, amount = 10000 * i, reason = "seed funds" }, { admin = true })
  end
end)
world:run({ seconds = 5 })
local files = N.snapshot(server)
files["/.vrb/role"] = "server"

local world2 = T.cc.new()
local C = world2:computer({ id = 1, files = files })
T.mount(C)
local out = {}
local answers = {}
C.env.read = function() return table.remove(answers, 1) end
local function run(fn)
  out.done = false
  T.setenv(fn, C.env)
  world2:start(C, function() local ok, e = xpcall(fn, debug.traceback); if not ok then print(e); T.failed = T.failed + 1 end; out.done = true end)
  world2:run({ seconds = 60, stop = function() return out.done end })
end
local function printed() return table.concat(C.printed, "\n") end
local function clear() for i = #C.printed, 1, -1 do table.remove(C.printed, i) end end

run(function()
  package.path = "/vrb/?.lua;" .. package.path
  require("tools.doctor").main()
end)
local p = printed()
T.check(not p:find("%[FAIL%]"), "doctor finds nothing wrong on a healthy server: " .. p:gsub("\n", " | "):sub(1, 400))
T.check(p:find("17 accounts"), "doctor counts the accounts")
T.check(p:find("Ledger chain intact"), "doctor verifies the ledger")
T.check(p:find("matches its posted entries"), "doctor audits the accounts")

clear()
run(function() require("tools.config").main("config", { "set", "net.network", "myserver" }) end)
T.check(C.fs.open("/.vrb/config", "r").readAll():find("myserver"), "config set writes the override")
clear()
run(function() require("tools.config").main("config", { "set", "server.history_depth", "abc" }) end)
T.check(printed():find("needs a number"), "config rejects a wrong type")
clear()
run(function() require("tools.config").main("config", { "set", "nonsense.key", "1" }) end)
T.check(printed():find("Unknown"), "config rejects an unknown name")
run(function() require("tools.config").main("config", { "unset", "net.network" }) end)

clear()
run(function() require("tools.backup").main("backup", {}) end)
T.check(printed():find("Backup saved as"), "backup tool saves a snapshot: " .. printed():sub(1, 200))
local name = C.fs.list("/.vrb/backups")[1]
run(function()
  local DB = require("lib.db")
  local db = DB.open("/.vrb/data", {})
  db:coll("accounts"):del(db:coll("accounts"):ids()[2])
  db:commit()
  db:compact()
end)
answers[1] = "RESTORE"
run(function() require("tools.backup").main("restore", { name }) end)
run(function()
  local DB = require("lib.db")
  local db = DB.open("/.vrb/data", {})
  T.eq(db:coll("accounts"):count(), 17, "restore brings the deleted account back")
end)

answers[1] = "RESET"
run(function() require("tools.reset").main("reset") end)
T.check(not C.fs.exists("/.vrb"), "reset removes the data folder")
T.done()
