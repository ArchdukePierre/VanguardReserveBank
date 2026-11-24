local T = dofile(HERE .. "/lib.lua")
local N = dofile(HERE .. "/net.lua")

local world, server = N.world()
local client = N.client_pc(world, 2)
N.run_client(world, client, function()
  local c = assert(require("lib.client").new({}))
  for i = 1, 20 do c:call("open_account", { owner = "user" .. i, pin = "1234" }) end
end)
world:run({ seconds = 30 })
local i0, w0, o0, t0 = server.instr, server.F.bytes_written, server.F.opens, server.term._T.calls
world:run({ seconds = 600 })
local di = server.instr - i0
T.check(di < 20000000, "an idle server runs under 20M VM instructions in 10 minutes (" .. string.format("%.2fM", di / 1e6) .. ")")
T.check(server.F.bytes_written - w0 < 6000, "an idle server writes almost nothing in 10 minutes (" .. (server.F.bytes_written - w0) .. " bytes)")
print(string.format("idle 600 s: %.2fM instructions, %d bytes written, %d file opens, %d terminal calls", di / 1e6, server.F.bytes_written - w0, server.F.opens - o0, server.term._T.calls - t0))
T.done()
