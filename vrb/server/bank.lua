local crypto = require("lib.crypto")
local util = require("lib.util")

local floor = math.floor

local Bank = {}
Bank.__index = Bank

function Bank.new(db, cfg, secret)
  local self = setmetatable({ db = db, cfg = cfg, secret = secret, meta = db.meta, sessions = {}, by_owner = {}, sys = db:coll("sys") }, Bank)
  self.accounts = db:coll("accounts")
  self.scfg = cfg.server
  self.hist_max = cfg.server.history_depth
  self.fund_id = cfg.server.fund_account
  local m = self.meta
  m.money_supply = m.money_supply or 0
  m.loans_out = m.loans_out or 0
  m.tx_count = m.tx_count or 0
  m.last_interest = m.last_interest or util.now()
  m.last_ubi = m.last_ubi or 0
  m.last_mc_day = m.last_mc_day or 0
  m.last_earnings = m.last_earnings or 0
  m.last_backup = m.last_backup or 0
  m.earnings_enabled = m.earnings_enabled
  if m.earnings_enabled == nil then m.earnings_enabled = cfg.earnings.enabled end
  if m.pvp_enabled == nil then m.pvp_enabled = cfg.earnings.pvp_enabled end
  if m.vanguard_enabled == nil then m.vanguard_enabled = cfg.vanguard.enabled end
  m.key = m.key or secret
  m.schema = 10
  local pol = self.sys:get("policy")
  if not pol then
    pol = util.deepcopy(cfg.policy)
    self.sys:put("policy", pol)
  else
    for k, v in pairs(cfg.policy) do
      if pol[k] == nil then pol[k] = util.deepcopy(v) end
    end
  end
  self.policy = pol
  local cat = db:coll("catalog")
  if cat:count() == 0 then
    for _, item in ipairs(cfg.catalog) do cat:put(item.id, { label = item.label, bounty = item.bounty, once = item.once }) end
  end
  self.rank_by_id = {}
  for _, r in ipairs(cfg.vanguard.ranks) do self.rank_by_id[r.id] = r end
  self:reindex()
  if not self.accounts:get(self.fund_id) then
    self.accounts:put(self.fund_id, {
      id = self.fund_id, owner = cfg.server.fund_owner, kind = "treasury", balance = 0, sum = 0, pin = "TREASURY_NO_PIN",
      created = util.now(), hist = {}, joint = {}, treasury = true,
    })
    self:reindex()
  end
  return self
end

function Bank:reindex()
  self.index_version = (self.index_version or 0) + 1
  local idx = {}
  for id, a in self.accounts:pairs() do
    local k = a.owner:lower()
    local l = idx[k]
    if not l then l = {}; idx[k] = l end
    l[#l + 1] = id
  end
  for _, l in pairs(idx) do table.sort(l) end
  self.by_owner = idx
end

function Bank:index_add(a)
  self.index_version = (self.index_version or 0) + 1
  local k = a.owner:lower()
  local l = self.by_owner[k]
  if not l then l = {}; self.by_owner[k] = l end
  l[#l + 1] = a.id
  table.sort(l)
end

function Bank:index_remove(a)
  self.index_version = (self.index_version or 0) + 1
  local k = a.owner:lower()
  local l = self.by_owner[k]
  if not l then return end
  for i, id in ipairs(l) do if id == a.id then table.remove(l, i); break end end
  if #l == 0 then self.by_owner[k] = nil end
end

function Bank:save_policy() self.sys:touch("policy") end
function Bank:meta_touch() self.db.store.meta_dirty = true end
function Bank:log(kind, fields) return self.db:log(kind, fields) end
function Bank:now() return util.now() end

function Bank:account(id) return self.accounts:get(id) end
function Bank:touch(a) self.accounts:touch(a.id) end

function Bank:owner_accounts(owner)
  local out = {}
  for _, id in ipairs(self.by_owner[owner:lower()] or {}) do
    local a = self.accounts:get(id)
    if a then out[#out + 1] = a end
  end
  return out
end

function Bank:checking_of(owner)
  for _, a in ipairs(self:owner_accounts(owner)) do
    if a.kind == "checking" and not a.treasury then return a end
  end
end

function Bank:primary(owner)
  local c = self:checking_of(owner)
  if c then return c end
  return self:owner_accounts(owner)[1]
end

function Bank:pair_of(a)
  if a.paired then return self.accounts:get(a.paired) end
end

function Bank:checking_for(a)
  if a.kind == "savings" then return self:pair_of(a) end
  return a
end

function Bank:new_account_id()
  while true do
    local id = "ACC-" .. string.format("%06d", crypto.random_int(100000, 999999))
    if not self.accounts:get(id) then return id end
  end
end

function Bank:id(prefix, nhex, upper)
  local h = crypto.random_hex(nhex)
  if upper then h = h:upper() end
  return prefix .. "-" .. h
end

function Bank:hash_pin(pin, id)
  return crypto.hmac(self.meta.key, "pin:" .. id .. ":" .. pin)
end

function Bank:history(a, kind, amount, note, party)
  self.accounts:append(a.id, "hist", { t = util.now(), y = kind, a = amount, n = note, p = party }, self.hist_max)
end

function Bank.expand(h)
  return { t = h.t, type = h.y, amount = h.a, note = h.n, party = h.p }
end

function Bank:post(a, delta, kind, note, party)
  a.balance = a.balance + delta
  a.sum = (a.sum or 0) + delta
  self:history(a, kind, delta, note, party)
  self.accounts:touch(a.id)
  return a.balance
end

function Bank:mark(a)
  a.act = util.now()
end

function Bank:supply(delta)
  self.meta.money_supply = self.meta.money_supply + delta
  self.db.store.meta_dirty = true
end

function Bank:count_tx(n)
  self.meta.tx_count = self.meta.tx_count + (n or 1)
  self.db.store.meta_dirty = true
end

function Bank:fund()
  return self.accounts:get(self.fund_id)
end

function Bank:fund_credit(cents, note)
  if not cents or cents <= 0 then return end
  self:post(self:fund(), cents, "tax_in", note or "tax")
end

function Bank:tax_for(amount, from_id, to_id)
  if from_id == self.fund_id or to_id == self.fund_id then return 0, 0 end
  local rate = self.policy.tx_tax_rate or 0
  return floor(amount * rate), rate
end

function Bank:income_tax_rate(annual)
  local rate = 0
  for _, b in ipairs(self.policy.income_tax_brackets or {}) do
    if (annual or 0) >= (b.above or 0) then rate = b.rate or 0 end
  end
  if rate > 0.10 then rate = 0.10 end
  return rate
end

function Bank:move(src, dst, amount, tax, out_kind, in_kind, memo, extra)
  self:post(src, -amount, out_kind, memo, dst.id)
  self:post(dst, amount - tax, in_kind, memo, src.id)
  if tax > 0 then self:fund_credit(tax, "tx_tax: " .. src.owner .. " -> " .. dst.owner) end
  self:count_tx()
  self:mark(src)
  self:mark(dst)
end

function Bank:is_frozen(a) return a.frozen == true end

function Bank:is_locked(a)
  local l = a.lock
  if not l then return false end
  if l.untl and util.now() < l.untl then return true, l.untl end
  if l.untl and util.now() >= l.untl then a.lock = nil; self:touch(a) end
  return false
end

function Bank:register_fail(a)
  local l = a.lock or { fails = 0 }
  l.fails = l.fails + 1
  if l.fails >= self.scfg.pin_fails then
    l.untl = util.now() + self.scfg.pin_lock_sec
    self:log("lockout", { account = a.id, untl = l.untl })
  end
  a.lock = l
  self:touch(a)
end

function Bank:clear_fails(a)
  if a.lock then a.lock = nil; self:touch(a) end
end

function Bank:create_session(a, chan)
  local sid = crypto.random_hex(32)
  self.sessions[sid] = { account = a.id, expires = util.now() + self.scfg.session_ttl, chan = chan }
  return sid
end

function Bank:resolve_session(sid, chan)
  local s = self.sessions[sid]
  if not s then return nil, "Session expired. Sign in again." end
  local t = util.now()
  if t >= s.expires or (s.chan and chan and s.chan ~= chan) then
    self.sessions[sid] = nil
    return nil, "Session expired. Sign in again."
  end
  s.expires = t + self.scfg.session_ttl
  return s
end

function Bank:gc_sessions()
  local t = util.now()
  for sid, s in pairs(self.sessions) do if t >= s.expires then self.sessions[sid] = nil end end
end

function Bank:drop_sessions_of(account_id)
  for sid, s in pairs(self.sessions) do if s.account == account_id then self.sessions[sid] = nil end end
end

function Bank:rank(id) return self.rank_by_id[id] end

function Bank:count_vanguard()
  local n = 0
  for _, a in self.accounts:pairs() do if a.vg then n = n + 1 end end
  return n
end

function Bank:audit_account(a)
  return a.balance == (a.base or 0) + (a.sum or 0)
end

function Bank:audit()
  local bad, total, n = {}, 0, 0
  for id, a in self.accounts:pairs() do
    n = n + 1
    total = total + a.balance
    if not self:audit_account(a) then bad[#bad + 1] = id end
  end
  return { accounts = n, total = total, mismatched = bad }
end

return Bank
