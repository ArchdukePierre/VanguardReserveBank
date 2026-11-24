local cc = dofile(HERE .. "/cc.lua")
local T = { cc = cc, passed = 0, failed = 0 }

function T.check(cond, msg)
  if cond then T.passed = T.passed + 1 else T.failed = T.failed + 1; print("FAIL: " .. tostring(msg)) end
  return cond
end

function T.eq(a, b, msg)
  local ok = a == b
  if not ok then print(string.format("FAIL: %s (got %s, want %s)", tostring(msg), tostring(a), tostring(b))) end
  T.check(ok, msg)
  return ok
end

function T.done()
  print(string.format("%d passed, %d failed", T.passed, T.failed))
  if T.failed > 0 then os.exit(1) end
end

function T.mount(C)
  local files = {}
  for rel, data in pairs(REPO_FILES) do files[rel] = data end
  cc.load_tree(C, files, "/")
  C.F.bytes_written, C.F.writes, C.F.opens = 0, 0, 0
  C.env.package.path = "/vrb/?.lua;/vrb/?/init.lua;" .. C.env.package.path
end

function T.setenv(fn, env)
  local holder
  do local e = env; holder = function() return e end end
  local i = 1
  while true do
    local name = debug.getupvalue(fn, i)
    if not name then return fn end
    if name == "_ENV" then debug.upvaluejoin(fn, i, holder, 1); return fn end
    i = i + 1
  end
end

function T.solo(opts, fn)
  local world = cc.new(opts)
  local C = world:computer(opts)
  T.mount(C)
  local result = {}
  T.setenv(fn, C.env)
  world:start(C, function()
    local ok, err = xpcall(fn, debug.traceback)
    result.ok, result.err = ok, err
    result.done = true
  end)
  world:run({ seconds = (opts and opts.seconds) or 600, stop = function() return result.done or C.crash end, max_steps = 5e7 })
  if C.crash then print("CRASH: " .. C.crash) T.failed = T.failed + 1 end
  if result.done and not result.ok then print("ERROR: " .. tostring(result.err)) T.failed = T.failed + 1 end
  return world, C
end

return T
