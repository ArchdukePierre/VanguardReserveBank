local cc = dofile(HERE .. "/cc.lua")
local OLD = ARGS[1]
local N = tonumber(ARGS[2]) or 60
local M = tonumber(ARGS[3]) or 200

local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local src = slurp(OLD)
src = src:gsub('elseif ROLE == "keygen" then runKeygen%(%)', 'elseif ROLE == "bench" then return BENCH_FN(newClient, loadClientKeys)\nelseif ROLE == "keygen" then runKeygen()', 1)

local world = cc.new()
local SECRET = string.rep("ab", 32)
local ADMIN = string.rep("cd", 32)
local keys = { ["/.vrb/keys/server.secret"] = SECRET, ["/.vrb/keys/admin.key"] = ADMIN }

local server = world:computer({ id = 1, label = "bank", files = keys })
local client = world:computer({ id = 2, label = "bench", files = keys })
cc.load_tree(server, { ["vrb"] = src }, "/")
cc.load_tree(client, { ["vrb"] = src }, "/")

local result = { ok = 0, fail = 0, errs = {} }
local done = false
client.env.BENCH_FN = function(newClient, loadClientKeys)
  local secret, admin = loadClientKeys(true)
  local C = newClient(secret, admin)
  local t0 = client.env.os.epoch("utc")
  local ids, sess = {}, {}
  for i = 1, N do
    local r = C:call("open_account", { owner = "user" .. i, pin = "1234" })
    if r.ok then ids[i] = r.account_id else result.errs[#result.errs + 1] = r.err end
  end
  for i = 1, N do
    if ids[i] then
      C:call("admin_issue", { account_id = ids[i], amount = 5000000, reason = "seed funds" }, true)
      local a = C:call("auth", { account_id = ids[i], pin = "1234", branch = "bench" })
      if a.ok then sess[i] = a.session end
    end
  end
  result.setup_done = server.F.bytes_written
  result.setup_instr = server.instr
  math.randomseed(7)
  local tx0_instr, tx0_bytes, tx0_opens, tx0_time = server.instr, server.F.bytes_written, server.F.opens, world.time
  for k = 1, M do
    local a, b = math.random(1, N), math.random(1, N)
    if a ~= b and sess[a] and ids[b] then
      local r = C:call("transfer", { session = sess[a], target_id = ids[b], amount = 100 + k, memo = "bench" })
      if r.ok then result.ok = result.ok + 1 else result.fail = result.fail + 1; result.errs[#result.errs + 1] = r.err end
    end
  end
  result.tx_instr = server.instr - tx0_instr
  result.tx_bytes = server.F.bytes_written - tx0_bytes
  result.tx_opens = server.F.opens - tx0_opens
  result.tx_time = world.time - tx0_time
  done = true
end

world:start(server, function() return server.env.shell.run("/vrb", "server") end)
world:start(client, function() return client.env.shell.run("/vrb", "bench") end)
world:run({ seconds = 3600, stop = function() return done or client.crash or server.crash end, max_steps = 5e7 })

print("server crash:", server.crash)
print("client crash:", client.crash)
print(string.format("accounts=%d transfers ok=%d fail=%d", N, result.ok, result.fail))
print(string.format("errs: %s", table.concat(result.errs, "; "):sub(1, 300)))
print(string.format("setup: server instr=%.1fM bytes_written=%d", (result.setup_instr or 0) / 1e6, result.setup_done or 0))
if result.tx_instr then
  print(string.format("per transfer: server instr=%.2fM  bytes_written=%d  file_opens=%.1f", result.tx_instr / M / 1e6, result.tx_bytes / M, result.tx_opens / M))
end
local dbsize = server.fs.exists("/.vrb/bank.db") and server.fs.getSize("/.vrb/bank.db") or 0
print(string.format("db size=%d bytes, ledger=%d bytes, disk free=%d", dbsize, server.fs.exists("/.vrb/ledger.log") and server.fs.getSize("/.vrb/ledger.log") or 0, server.fs.getFreeSpace("/")))
print(string.format("virtual time %.1fs", world.time))
