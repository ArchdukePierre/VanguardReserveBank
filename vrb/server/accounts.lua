local util = require("lib.util")
local crypto = require("lib.crypto")
local common = require("server.common")

local fail = common.fail
local M = {}

function M.register(rpc, bank)
  local cfg = bank.cfg
  local fund_owner = cfg.server.fund_owner
  local sorted_cache

  local function sorted_accounts()
    if sorted_cache and sorted_cache.v == bank.index_version then return sorted_cache.list end
    local list = {}
    for id, a in bank.accounts:pairs() do
      if a.kind ~= "savings" and not a.treasury then list[#list + 1] = { lower = a.owner:lower(), id = id } end
    end
    table.sort(list, function(x, y)
      if x.lower == y.lower then return x.id < y.id end
      return x.lower < y.lower
    end)
    sorted_cache = { v = bank.index_version, list = list }
    return list
  end

  rpc:method("ping", { doc = "Server status and public rates" }, function(ctx, p)
    local pol = bank.policy
    return { ok = true, version = cfg.VERSION, time = util.now(), supply = bank.meta.money_supply, month_sec = cfg.server.month_sec,
      policy = { sav_mpr = pol.sav_mpr, chk_mpr = pol.chk_mpr, cd_mpr_30 = pol.cd_mpr_30, cd_mpr_90 = pol.cd_mpr_90, cd_mpr_180 = pol.cd_mpr_180,
        loan_mpr = pol.loan_mpr, tx_tax_rate = pol.tx_tax_rate, min_loan_col = pol.min_loan_col },
      early_days = cfg.server.early_savings_days, early_rate = cfg.server.early_savings_rate, writable = bank.db:writable() }
  end)

  local function begin_session(a, branch, chan, via_owner)
    local sa = bank:checking_for(a) or a
    if sa.frozen then return fail("Account frozen") end
    bank:clear_fails(a)
    local sid = bank:create_session(sa, chan)
    sa.last_login = util.now()
    bank:touch(sa)
    return { ok = true, session = sid, account = { id = sa.id, owner = sa.owner, kind = sa.kind, balance = sa.balance, joint = sa.joint } }
  end

  rpc:method("auth", { write = true, p = { account_id = "acct", pin = "pin", branch = "str?" }, doc = "Sign in with an account number and PIN" }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a or a.treasury then
      bank:hash_pin(p.pin, p.account_id)
      return fail("Invalid credentials")
    end
    local locked, untl = bank:is_locked(a)
    if locked then return fail("Account locked until " .. os.date("%H:%M", untl)) end
    if a.frozen then return fail("Account frozen") end
    if a.pin ~= bank:hash_pin(p.pin, a.id) then
      bank:register_fail(a)
      bank:log("pin_fail", { account = a.id, branch = p.branch })
      return fail("Invalid credentials")
    end
    return begin_session(a, p.branch, ctx.chan)
  end)

  rpc:method("auth_by_owner", { write = true, p = { owner = "user", pin = "pin", branch = "str?" }, doc = "Sign in with a username and PIN" }, function(ctx, p)
    local ids = bank.by_owner[p.owner:lower()] or {}
    if #ids == 0 then bank:hash_pin(p.pin, "ACC-000000"); return fail("Invalid credentials") end
    local matched, any = nil, false
    local accts = {}
    for _, id in ipairs(ids) do
      local a = bank.accounts:get(id)
      if a and not a.treasury and not a.frozen then accts[#accts + 1] = a end
    end
    for _, a in ipairs(accts) do
      if not bank:is_locked(a) then
        any = true
        if not matched and a.pin == bank:hash_pin(p.pin, a.id) then matched = a end
      end
    end
    if not any then return fail("Your accounts are locked. Try again later.") end
    if not matched then
      for _, a in ipairs(accts) do if not bank:is_locked(a) then bank:register_fail(a) end end
      bank:log("pin_fail", { owner = p.owner, branch = p.branch })
      return fail("Invalid credentials")
    end
    return begin_session(matched, p.branch, ctx.chan)
  end)

  rpc:method("signout", { p = { session = "str?" } }, function(ctx, p)
    if type(p.session) == "string" then bank.sessions[p.session] = nil end
    return { ok = true }
  end)

  rpc:method("open_account", { write = true, p = { owner = "user", pin = "pin" }, doc = "Open a checking and savings pair" }, function(ctx, p)
    if p.owner:lower() == fund_owner:lower() then return fail("That username is reserved") end
    if #(bank.by_owner[p.owner:lower()] or {}) > 0 then return fail("That username already has an account") end
    local cid = bank:new_account_id()
    local sid = bank:new_account_id()
    while sid == cid do sid = bank:new_account_id() end
    local t = util.now()
    local chk = { id = cid, owner = p.owner, kind = "checking", balance = 0, sum = 0, pin = bank:hash_pin(p.pin, cid), created = t, hist = {}, joint = {}, paired = sid }
    local sav = { id = sid, owner = p.owner, kind = "savings", balance = 0, sum = 0, pin = bank:hash_pin(p.pin, sid), created = t, hist = {}, joint = {}, paired = cid, lots = {} }
    bank.accounts:put(cid, chk)
    bank.accounts:put(sid, sav)
    bank:index_add(chk)
    bank:index_add(sav)
    bank:log("open_pair", { owner = p.owner, checking = cid, savings = sid })
    return { ok = true, account_id = cid, checking_id = cid, savings_id = sid }
  end)

  rpc:method("change_pin", { write = true, auth = "session", p = { old_pin = "pin", new_pin = "pin" }, doc = "Change the PIN on both accounts" }, function(ctx, p)
    local a = ctx.acct
    if a.pin ~= bank:hash_pin(p.old_pin, a.id) then
      bank:register_fail(a)
      return fail("Current PIN is wrong")
    end
    for _, acc in ipairs(bank:owner_accounts(a.owner)) do
      if not acc.treasury and acc.kind ~= "faction" then
        acc.pin = bank:hash_pin(p.new_pin, acc.id)
        bank:touch(acc)
      end
    end
    bank:log("pin_change", { account = a.id })
    return { ok = true }
  end)

  rpc:method("balance", { auth = "session" }, function(ctx)
    local a = ctx.acct
    return { ok = true, balance = a.balance, kind = a.kind, owner = a.owner, id = a.id }
  end)

  rpc:method("profile", { auth = "session", doc = "Checking and savings summary" }, function(ctx)
    local a = ctx.acct
    local chk, sav = bank:checking_for(a), nil
    if a.kind == "checking" then sav = bank:pair_of(a) else sav = a end
    local out = { owner = a.owner }
    if chk then out.checking = { id = chk.id, balance = chk.balance, kind = "checking" } end
    if sav then
      local young, cutoff = 0, util.now() - cfg.server.early_savings_days * 86400
      for _, lot in ipairs(sav.lots or {}) do if (lot.t or 0) >= cutoff then young = young + (lot.amount or 0) end end
      out.savings = { id = sav.id, balance = sav.balance, kind = "savings", young_cents = young }
    end
    out.vanguard = a.vg
    return { ok = true, profile = out }
  end)

  rpc:method("history", { auth = "session", p = { limit = "int+?" }, doc = "Recent activity across checking and savings" }, function(ctx, p)
    local a = ctx.acct
    local limit = util.clamp(p.limit or 25, 1, 100)
    local rows = {}
    local function add(acc)
      if not acc then return end
      for _, h in ipairs(acc.hist) do
        rows[#rows + 1] = { t = h.t, type = h.y, amount = h.a, note = h.n, party = h.p, _account = acc.id, _kind = acc.kind }
      end
    end
    add(a)
    add(bank:pair_of(a))
    table.sort(rows, function(x, y) return (x.t or 0) < (y.t or 0) end)
    local out = {}
    for i = math.max(1, #rows - limit + 1), #rows do out[#out + 1] = rows[i] end
    return { ok = true, history = out }
  end)

  rpc:method("lookup", { p = { owner = "user" }, doc = "Find a player's payable account" }, function(ctx, p)
    local out = {}
    for _, a in ipairs(bank:owner_accounts(p.owner)) do
      if not a.treasury and a.kind ~= "savings" then out[#out + 1] = { id = a.id, kind = a.kind, owner = a.owner } end
    end
    return { ok = true, accounts = out }
  end)

  rpc:method("list_payable_accounts", { auth = "session", p = { q = "str?", offset = "int?", limit = "int+?" }, doc = "Payable accounts, filtered and paged" }, function(ctx, p)
    local list = sorted_accounts()
    local q = (p.q or ""):lower()
    local offset, limit = math.max(0, p.offset or 0), util.clamp(p.limit or 40, 1, 100)
    local mine = ctx.acct.owner:lower()
    local out, seen, total = {}, 0, 0
    for _, e in ipairs(list) do
      if e.lower ~= mine and (q == "" or e.lower:find(q, 1, true)) then
        local a = bank.accounts:get(e.id)
        if a and not a.frozen then
          total = total + 1
          if total > offset and #out < limit then out[#out + 1] = { id = a.id, kind = a.kind, owner = a.owner } end
        end
      end
    end
    return { ok = true, accounts = out, total = total, offset = offset }
  end)

  rpc:method("self_audit", { auth = "session", doc = "Check that this account balance matches its posted entries" }, function(ctx)
    local a = ctx.acct
    local tracked = (a.base or 0) + (a.sum or 0)
    local pair = bank:pair_of(a)
    local pair_ok = pair == nil or bank:audit_account(pair)
    return { ok = true, balance = a.balance, computed = tracked, ok_match = a.balance == tracked and pair_ok, ledger_head = bank.meta.ledger_head, entries = bank.meta.ledger_seq }
  end)
end

return M
