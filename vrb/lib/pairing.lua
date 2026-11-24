local crypto = require("lib.crypto")
local ser = require("lib.ser")
local util = require("lib.util")

local P = {}

P.CHANNEL = 6999
local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

function P.new_code()
  local hex = crypto.random_hex(24)
  local out = {}
  for i = 1, 12 do
    local n = tonumber(hex:sub(i * 2 - 1, i * 2), 16) % #ALPHABET + 1
    out[i] = ALPHABET:sub(n, n)
  end
  local s = table.concat(out)
  return s:sub(1, 4) .. "-" .. s:sub(5, 8) .. "-" .. s:sub(9, 12)
end

function P.normalize(code)
  return (tostring(code or ""):upper():gsub("[^%w]", ""):gsub("0", "O"):gsub("1", "I"))
end

local function key_for(code)
  return crypto.sha256_raw(P.normalize(code) .. "|vrb-pair-v1")
end

function P.request(code, reply)
  local key = key_for(code)
  local n = crypto.random_hex(16)
  return { v = 3, kind = "pair", n = n, r = reply, m = crypto.hmac_raw(key, "req" .. n .. "|" .. reply) }
end

function P.open_reply(code, msg, n)
  if type(msg) ~= "table" or msg.kind ~= "pairok" or type(msg.n) ~= "string" or type(msg.c) ~= "string" or type(msg.m) ~= "string" then return nil end
  local key = key_for(code)
  if not crypto.equal(crypto.hmac_raw(key, "ok" .. msg.n .. n .. msg.c), msg.m) then return nil end
  local body = ser.decode(crypto.stream(key, msg.n, msg.c))
  if type(body) ~= "table" or type(body.secret) ~= "string" then return nil end
  return body
end

local Server = {}
Server.__index = Server

function P.server(secret, admin, network)
  return setmetatable({ secret = secret, admin = admin, network = network, active = nil, bad = 0 }, Server)
end

function Server:start(staff, seconds)
  self.active = { code = P.new_code(), staff = staff and true or false, expires = util.now() + (seconds or 180), used = 0 }
  self.bad = 0
  return self.active
end

function Server:stop() self.active = nil end

function Server:state()
  local a = self.active
  if a and util.now() >= a.expires then self.active = nil; return nil end
  return a
end

function Server:handle(msg)
  local a = self:state()
  if not a then return nil, "closed" end
  if type(msg) ~= "table" or msg.kind ~= "pair" or type(msg.n) ~= "string" or #msg.n > 40 or type(msg.m) ~= "string" or type(msg.r) ~= "number" then return nil, "bad" end
  local key = key_for(a.code)
  if not crypto.equal(crypto.hmac_raw(key, "req" .. msg.n .. "|" .. msg.r), msg.m) then
    self.bad = self.bad + 1
    if self.bad >= 8 then self.active = nil end
    return nil, "wrong code"
  end
  local body = { secret = self.secret, network = self.network }
  if a.staff then body.admin = self.admin end
  local n2 = crypto.random_hex(16)
  local c = crypto.stream(key, n2, ser.encode(body))
  a.used = a.used + 1
  self.active = nil
  return { v = 3, kind = "pairok", n = n2, c = c, m = crypto.hmac_raw(key, "ok" .. n2 .. msg.n .. c) }, a.staff and "staff" or "node"
end

return P
