local crypto = require("lib.crypto")
local util = require("lib.util")

local floor, type = math.floor, type

local Rpc = {}
Rpc.__index = Rpc

local function is_int(n) return type(n) == "number" and n == floor(n) end

local V = {
  acct = function(v, rpc) return type(v) == "string" and (v:match("^ACC%-%d%d%d%d%d%d$") ~= nil or v == rpc.fund_id) end,
  cents = function(v) return is_int(v) and v >= 0 and v <= 1e12 end,
  ["cents+"] = function(v) return is_int(v) and v > 0 and v <= 1e12 end,
  pin = function(v) return type(v) == "string" and v:match("^%d%d%d%d$") ~= nil end,
  user = function(v) return type(v) == "string" and #v >= 2 and #v <= 32 and v:match("^[A-Za-z0-9_]+$") ~= nil end,
  text = function(v) return type(v) == "string" and #v <= 200 end,
  str = function(v) return type(v) == "string" and #v <= 64 end,
  id = function(v) return type(v) == "string" and #v >= 1 and #v <= 48 and v:match("^[%w_%-]+$") ~= nil end,
  int = function(v) return is_int(v) and v > -1e12 and v < 1e12 end,
  ["int+"] = function(v) return is_int(v) and v > 0 and v < 1e12 end,
  num = function(v) return type(v) == "number" and v == v and v > -1e15 and v < 1e15 end,
  bool = function(v) return type(v) == "boolean" end,
  tbl = function(v) return type(v) == "table" end,
  any = function(v) return true end,
  days = function(v) return is_int(v) and v >= 1 and v <= 3650 end,
  sess = function(v) return type(v) == "string" and #v == 32 and v:match("^%x+$") ~= nil end,
}

function Rpc.new(bank, cfg, admin_key)
  return setmetatable({ bank = bank, cfg = cfg, admin_key = admin_key, methods = {}, order = {}, fund_id = cfg.server.fund_account }, Rpc)
end

function Rpc:method(name, spec, fn)
  spec.name = name
  spec.fn = fn
  spec.auth = spec.auth or "public"
  spec.p = spec.p or {}
  local parsed, order = {}, {}
  for field, t in pairs(spec.p) do
    local optional = false
    local tname = t
    if type(t) == "string" and t:sub(-1) == "?" then optional = true; tname = t:sub(1, -2) end
    parsed[field] = { t = tname, optional = optional }
    order[#order + 1] = field
  end
  table.sort(order)
  spec.parsed, spec.fields = parsed, order
  self.methods[name] = spec
  self.order[#self.order + 1] = name
end

local function check(v, rule, rpc)
  local t = rule.t
  if type(t) == "table" then
    for _, x in ipairs(t) do if x == v then return true end end
    return false
  end
  local f = V[t]
  if not f then error("unknown validator " .. tostring(t)) end
  return f(v, rpc)
end

function Rpc:validate(spec, p)
  for field, rule in pairs(spec.parsed) do
    local v = p[field]
    if v == nil then
      if not rule.optional then return "Missing " .. field end
    elseif not check(v, rule, self) then
      return "Invalid " .. field
    end
  end
end

function Rpc:admin_ok(req)
  if not self.admin_key then return false end
  if type(req.a) ~= "string" or type(req.ts) ~= "number" then return false end
  if math.abs(util.now() - req.ts) > 30 then return false end
  return crypto.equal(req.a, crypto.hmac(self.admin_key, req.i .. ":" .. req.m .. ":" .. req.ts))
end

function Rpc:dispatch(req, chan)
  local spec = self.methods[req.m]
  if not spec then return { ok = false, err = "Unknown request", code = "unknown" } end
  local p = req.p
  if type(p) ~= "table" then return { ok = false, err = "Malformed request", code = "malformed" } end
  local ctx = { chan = chan, req = req, bank = self.bank, rpc = self }
  if spec.auth == "admin" then
    if not self:admin_ok(req) then return { ok = false, err = "Unauthorized", code = "unauthorized" } end
    ctx.admin = true
  elseif spec.auth == "session" then
    local sid = p.session
    if not V.sess(sid) then return { ok = false, err = "Sign in first", code = "no_session" } end
    local s, err = self.bank:resolve_session(sid, chan)
    if not s then return { ok = false, err = err, code = "no_session" } end
    local a = self.bank.accounts:get(s.account)
    if not a then return { ok = false, err = "Account closed", code = "no_session" } end
    if a.treasury then return { ok = false, err = "Treasury account is admin only", code = "forbidden" } end
    if a.frozen then return { ok = false, err = "Account frozen", code = "frozen" } end
    ctx.acct, ctx.sess, ctx.sid = a, s, sid
  end
  local bad = self:validate(spec, p)
  if bad then return { ok = false, err = bad, code = "invalid" } end
  if spec.write and not self.bank.db:writable() then
    return { ok = false, err = "Bank storage is full. Contact the Reserve staff.", code = "disk_full" }
  end
  local ok, res = pcall(spec.fn, ctx, p)
  if not ok then
    self.last_error = { method = req.m, err = tostring(res), t = util.now() }
    self.errors = (self.errors or 0) + 1
    return { ok = false, err = "Server error", code = "server_error" }
  end
  if type(res) ~= "table" then return { ok = false, err = "Server error", code = "server_error" } end
  return res
end

function Rpc:describe()
  local out = {}
  for _, name in ipairs(self.order) do
    local s = self.methods[name]
    local fields = {}
    for _, f in ipairs(s.fields) do
      local r = s.parsed[f]
      local t = type(r.t) == "table" and table.concat(r.t, "|") or r.t
      fields[#fields + 1] = f .. ":" .. t .. (r.optional and "?" or "")
    end
    out[#out + 1] = { name = name, auth = s.auth, write = s.write and true or false, fields = fields, doc = s.doc }
  end
  return out
end

return Rpc
