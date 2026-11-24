local crypto = require("lib.crypto")
local ser = require("lib.ser")
local util = require("lib.util")

local net = {}

local format = string.format

local prefix = nil
local counter = 0

function net.nonce()
  if not prefix then prefix = crypto.random_hex(8) end
  counter = counter + 1
  return prefix .. format("%08x", counter % 4294967296)
end

function net.reply_channel()
  return 20000 + (os.getComputerID() % 40000)
end

function net.find_modem(prefer)
  local best
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      local m = peripheral.wrap(name)
      if prefer and name == prefer then return m, name end
      if m.isWireless and m.isWireless() then return m, name end
      best = best or { m, name }
    end
  end
  if best then return best[1], best[2] end
  return nil
end

function net.seal(key, payload, encrypt)
  local body = ser.encode(payload)
  local n = net.nonce()
  local t = util.now()
  local e = encrypt and 1 or 0
  if e == 1 then body = crypto.stream(key, n, body) end
  local mac = crypto.hmac_raw(key, n .. t .. e .. body)
  return { v = 3, n = n, t = t, e = e, c = body, m = mac }
end

function net.open_env(key, env, window, seen)
  if type(env) ~= "table" or env.v ~= 3 then return nil, "bad envelope" end
  local n, t, e, c, m = env.n, env.t, env.e, env.c, env.m
  if type(n) ~= "string" or #n ~= 16 or type(t) ~= "number" or type(c) ~= "string" or type(m) ~= "string" or #m ~= 32 then return nil, "bad envelope" end
  if #c > 65536 then return nil, "too large" end
  if math.abs(util.now() - t) > (window or 30) then return nil, "stale" end
  if seen and seen[n] then return nil, "replay" end
  if not crypto.equal(crypto.hmac_raw(key, n .. t .. e .. c), m) then return nil, "bad mac" end
  if seen then seen[n] = t end
  local body = c
  if e == 1 then body = crypto.stream(key, n, c) end
  local payload = ser.decode(body)
  if type(payload) ~= "table" then return nil, "bad payload" end
  return payload
end

function net.prune_seen(seen, window)
  local cutoff = util.now() - (window or 30) * 2
  for n, t in pairs(seen) do if t < cutoff then seen[n] = nil end end
end

return net
