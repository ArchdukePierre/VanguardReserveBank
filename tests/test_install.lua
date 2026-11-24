local T = dofile(HERE .. "/lib.lua")
local cc = T.cc
local N = dofile(HERE .. "/net.lua")

local function slurp(p) local f = assert(io.open(REPO .. "/" .. p, "rb")); local s = f:read("*a"); f:close(); return s end

local BASE = "https://raw.githubusercontent.com/ArchdukePierre/VanguardReserveBank/main/"
local http = {}
for rel, data in pairs(REPO_FILES) do http[BASE .. rel] = data end
http[BASE .. "install.lua"] = slurp("install.lua")
http[BASE .. "manifest.lua"] = slurp("manifest.lua")

local manifest = assert(load(http[BASE .. "manifest.lua"], "m", "t", {}))()
local stale = 0
for _, e in ipairs(manifest.files) do
  local body = http[BASE .. e.path]
  if not body or #body ~= e.size then stale = stale + 1; print("manifest out of date: " .. e.path) end
end
T.eq(stale, 0, "manifest.lua matches the files (run tools/make_manifest.py)")
for rel in pairs(REPO_FILES) do
  if rel:match("%.lua$") then
    local listed = false
    for _, e in ipairs(manifest.files) do if e.path == rel then listed = true end end
    T.check(listed, rel .. " is listed in the manifest")
  end
end

local world = cc.new()
world.http = http
local function answers_for(C, list)
  C.env.read = function() return table.remove(list, 1) end
end

local A = world:computer({ id = 1, label = "bank", files = {} })
answers_for(A, { "1", "keyboard mash", "testbank" })
world:start(A, T.setenv(function() shell.run("/install.lua") end, A.env))
A.fs.F = nil
cc.load_tree(A, { ["install.lua"] = http[BASE .. "install.lua"] }, "/")
world:run({ seconds = 30, stop = function() return A.rebooted or A.crash end })
T.check(not A.crash, "installer did not crash: " .. tostring(A.crash))
T.check(A.rebooted, "installer ends with a reboot")
T.check(A.fs.exists("/vrb/boot.lua") and A.fs.exists("/vrb/server/init.lua"), "server files installed")
T.check(not A.fs.exists("/vrb/roles/atm.lua"), "server does not get the ATM program")
T.check(not A.fs.exists("/vrb/ui/app.lua"), "server does not get the UI toolkit")
T.eq(A.fs.open("/.vrb/role", "r").readAll(), "server", "role recorded")
local k1 = A.fs.open("/.vrb/keys/server.secret", "r").readAll()
local k2 = A.fs.open("/.vrb/keys/admin.key", "r").readAll()
T.check(#k1 == 64 and k1:match("^%x+$") and #k2 == 64 and k1 ~= k2, "keys generated")
T.check(A.fs.exists("/startup.lua") and A.fs.exists("/vrb.lua"), "startup files written")
T.check(A.fs.open("/.vrb/config", "r").readAll():find("testbank"), "network name saved")

A.running, A.rebooted = true, false
world:start(A, T.setenv(function() shell.run("/startup.lua") end, A.env))
world:run({ seconds = 2 })
T.check(A.term._dump():find("VANGUARD RESERVE BANK"), "installed server boots to its dashboard")
cc.key(A, "p")
world:run({ seconds = 1 })
local code
for i = #A.term._T.text, 1, -1 do
  local c = A.term._T.text[i]:match("code: ([%u%d]+%-[%u%d]+%-[%u%d]+)")
  if c then code = c end
end
T.check(code ~= nil, "pairing code on the server screen")

local B = world:computer({ id = 2, label = "atm1", files = {}, monitors = { { w = 57, h = 38 } } })
cc.load_tree(B, { ["install.lua"] = http[BASE .. "install.lua"] }, "/")
answers_for(B, { "2", code })
world:start(B, T.setenv(function() shell.run("/install.lua") end, B.env))
world:run({ seconds = 60, stop = function() return B.rebooted or B.crash end })
T.check(not B.crash, "node installer did not crash: " .. tostring(B.crash))
T.check(B.rebooted, "node installer reboots")
T.check(B.fs.exists("/vrb/ui/app.lua"), "atm gets the UI toolkit")
T.check(not B.fs.exists("/vrb/server/init.lua"), "atm does not get the server")
T.eq(B.fs.open("/.vrb/keys/server.secret", "r").readAll(), k1, "node paired and holds the server secret")
T.check(not B.fs.exists("/.vrb/keys/admin.key"), "atm has no admin key")

local out = {}
B.running = true
world:start(B, T.setenv(function() shell.run("/vrb.lua", "status"); out.done = true end, B.env))
world:run({ seconds = 20, stop = function() return out.done end })
local printed = table.concat(B.printed, "\n")
T.check(printed:find("Bank      : online"), "vrb status reaches the bank: " .. printed:gsub("\n", " | "):sub(1, 300))
T.done()
