local T = dofile(HERE .. "/lib.lua")
local cc = T.cc
local N = {}

N.SECRET = string.rep("ab", 32)
N.ADMIN = string.rep("cd", 32)

function N.keys() return { ["/.vrb/keys/server.secret"] = N.SECRET, ["/.vrb/keys/admin.key"] = N.ADMIN } end

function N.snapshot(C, skip)
  local out = {}
  for path, f in pairs(C.F.files) do
    if path:sub(1, 4) ~= "vrb/" and not path:find(skip or "^$") then out[path] = f.data end
  end
  return out
end

function N.world(opts)
  opts = opts or {}
  local world = cc.new({ latency = opts.latency or 0.02 })
  local server = world:computer({ id = 1, label = "bank", files = opts.files or N.keys(), capacity = opts.capacity })
  T.mount(server)
  if opts.config then
    cc.load_tree(server, { [".vrb/config"] = opts.config }, "/")
  end
  world:start(server, T.setenv(function() require("server.init").run() end, server.env))
  return world, server
end

function N.client_pc(world, id, files, opts)
  local C = world:computer({ id = id, label = "client" .. id, files = files or N.keys(), monitors = opts and opts.monitors, w = opts and opts.w, h = opts and opts.h })
  T.mount(C)
  return C
end

function N.run_client(world, C, fn, seconds)
  local result = { done = false }
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    result.ok, result.err, result.done = ok, err, true
  end)
  world:run({ seconds = seconds or 300, stop = function() return result.done or C.crash end, max_steps = 5e7 })
  if C.crash then print("CLIENT CRASH: " .. C.crash); T.failed = T.failed + 1 end
  if result.done and not result.ok then print("CLIENT ERROR: " .. tostring(result.err)); T.failed = T.failed + 1 end
  return result
end

return N
