local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")
local N_ACC = tonumber(ARGS[1]) or 60
local M_TX = tonumber(ARGS[2]) or 200

local world, server = N.world()
local client = N.client_pc(world, 2)
local crypto
local result = { ok = 0, fail = 0, errs = {} }
local before

N.run_client(world, client, function()
  local Client = require("lib.client")
  local cm = require("lib.cfg")
  local c = assert(Client.new({ admin = cm.read_key("admin.key") }))
  local ids, sess = {}, {}
  for i = 1, N_ACC do
    local r = c:call("open_account", { owner = "user" .. i, pin = "1234" })
    if r.ok then ids[i] = r.account_id else result.errs[#result.errs + 1] = r.err end
  end
  for i = 1, N_ACC do
    if ids[i] then
      c:call("admin_issue", { account_id = ids[i], amount = 5000000, reason = "seed funds" }, { admin = true })
      local a = c:call("auth", { account_id = ids[i], pin = "1234", branch = "bench" })
      if a.ok then sess[i] = a.session end
    end
  end
  result.setup_instr, result.setup_bytes = server.instr, server.F.bytes_written
  math.randomseed(7)
  local i0, b0, o0, t0 = server.instr, server.F.bytes_written, server.F.opens, world.time
  for k = 1, M_TX do
    local a, b = math.random(1, N_ACC), math.random(1, N_ACC)
    if a ~= b and sess[a] and ids[b] then
      local r = c:call("transfer", { session = sess[a], target_id = ids[b], amount = 100 + k, memo = "bench" })
      if r.ok then result.ok = result.ok + 1 else result.fail = result.fail + 1; result.errs[#result.errs + 1] = r.err end
    end
  end
  result.tx_instr, result.tx_bytes, result.tx_opens, result.tx_time = server.instr - i0, server.F.bytes_written - b0, server.F.opens - o0, world.time - t0
end, 3600)

local function size(p) return server.fs.exists(p) and util_size and 0 or 0 end
print(string.format("accounts=%d transfers ok=%d fail=%d  errs=%s", N_ACC, result.ok, result.fail, table.concat(result.errs, ";"):sub(1, 200)))
print(string.format("setup: server instr=%.1fM bytes_written=%d", (result.setup_instr or 0) / 1e6, result.setup_bytes or 0))
if result.tx_instr then
  print(string.format("per transfer: server instr=%.2fM  bytes_written=%d  file_opens=%.1f", result.tx_instr / M_TX / 1e6, result.tx_bytes / M_TX, result.tx_opens / M_TX))
end
print(string.format("disk free=%d, virtual time %.1fs", server.fs.getFreeSpace("/"), world.time))
local function dsize(p)
  if not server.fs.exists(p) then return 0 end
  if not server.fs.isDir(p) then return server.fs.getSize(p) end
  local n = 0
  for _, name in ipairs(server.fs.list(p)) do n = n + dsize(p .. "/" .. name) end
  return n
end
print(string.format("data on disk: snapshots %d B, journal+ledger %d B, total /.vrb %d B (%d accounts incl. savings)", dsize("/.vrb/data/snap"), dsize("/.vrb/data") - dsize("/.vrb/data/snap"), dsize("/.vrb"), N_ACC * 2 + 1))
print("server crash:", server.crash)
