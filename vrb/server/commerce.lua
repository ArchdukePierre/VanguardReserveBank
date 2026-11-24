local util = require("lib.util")
local crypto = require("lib.crypto")
local ser = require("lib.ser")
local common = require("server.common")

local fail, memo = common.fail, common.memo
local floor = math.floor
local M = {}

function M.register(rpc, bank, jobs)
  local cfg = bank.cfg
  local pol = bank.policy
  local shops = bank.db:coll("shops")
  local notes = bank.db:coll("notes")

  rpc:method("create_shop", { write = true, auth = "session", p = { label = "text" } }, function(ctx, p)
    if #p.label < 3 or #p.label > 40 then return fail("Shop name must be 3 to 40 characters") end
    local sid = bank:id("SHP", 8, true)
    shops:put(sid, { id = sid, owner_account = ctx.acct.id, owner = ctx.acct.owner, label = p.label, listings = {}, active = true, created = util.now() })
    bank:log("shop_create", { shop = sid, owner = ctx.acct.id, label = p.label })
    return { ok = true, shop_id = sid }
  end)

  rpc:method("set_shop_listing", { write = true, auth = "session", p = { shop_id = "id", sku = "str", item = "str", price = "cents+", stock = "cents", note = "text?", item_id = "str?" }, doc = "Add or update a listing" }, function(ctx, p)
    local shop = shops:get(p.shop_id)
    if not shop or shop.owner_account ~= ctx.acct.id then return fail("That is not your shop") end
    shop.listings[p.sku] = { item = p.item, price = p.price, stock = p.stock, note = memo(p.note) or "", item_id = p.item_id }
    shops:touch(shop.id)
    bank:log("shop_listing", { shop = shop.id, sku = p.sku, price = p.price, stock = p.stock })
    return { ok = true }
  end)

  rpc:method("remove_shop_listing", { write = true, auth = "session", p = { shop_id = "id", sku = "str" } }, function(ctx, p)
    local shop = shops:get(p.shop_id)
    if not shop or shop.owner_account ~= ctx.acct.id then return fail("That is not your shop") end
    shop.listings[p.sku] = nil
    shops:touch(shop.id)
    return { ok = true }
  end)

  rpc:method("get_shop", { p = { shop_id = "id" }, doc = "Public shop listing" }, function(ctx, p)
    local shop = shops:get(p.shop_id)
    if not shop or not shop.active then return fail("Shop not found") end
    local listings = {}
    for sku, l in pairs(shop.listings) do listings[#listings + 1] = { sku = sku, item = l.item, price = l.price, stock = l.stock, note = l.note, item_id = l.item_id } end
    table.sort(listings, function(x, y) return x.sku < y.sku end)
    return { ok = true, shop = { id = shop.id, label = shop.label, owner = shop.owner, listings = listings } }
  end)

  rpc:method("buy_from_shop", { write = true, auth = "session", p = { shop_id = "id", sku = "str", qty = "int+?" } }, function(ctx, p)
    local a = ctx.acct
    local shop = shops:get(p.shop_id)
    if not shop or not shop.active then return fail("Shop unavailable") end
    local l = shop.listings[p.sku]
    if not l then return fail("That item is not listed") end
    local qty = p.qty or 1
    if l.stock < qty then return fail("Out of stock") end
    local cost = l.price * qty
    if a.balance < cost then return fail("Insufficient funds") end
    local dst = bank.accounts:get(shop.owner_account)
    if not dst or dst.frozen then return fail("The shop owner is unavailable") end
    if dst.id == a.id then return fail("You cannot buy from your own shop") end
    local tax = floor(cost * (pol.shop_tax_rate or 0))
    bank:post(a, -cost, "shop_buy", string.format("%s x%d @ %s", l.item, qty, shop.label), dst.id)
    bank:post(dst, cost - tax, "shop_sale", string.format("%s x%d to %s", l.item, qty, a.owner), a.id)
    bank:fund_credit(tax, "shop_tax: " .. shop.label)
    l.stock = l.stock - qty
    shops:touch(shop.id)
    bank:count_tx()
    bank:mark(a)
    bank:mark(dst)
    bank:log("shop_sale", { shop = shop.id, buyer = a.id, seller = dst.id, sku = p.sku, qty = qty, cost = cost, tax = tax })
    return { ok = true, cost = cost, balance = a.balance, dispensed = { item = l.item, item_id = l.item_id, qty = qty } }
  end)

  rpc:method("list_my_shops", { auth = "session" }, function(ctx)
    local out = {}
    for id, s in shops:pairs() do
      if s.owner_account == ctx.acct.id then
        local listings = {}
        for sku, l in pairs(s.listings) do listings[#listings + 1] = { sku = sku, item = l.item, price = l.price, stock = l.stock, item_id = l.item_id } end
        table.sort(listings, function(x, y) return x.sku < y.sku end)
        out[#out + 1] = { id = id, label = s.label, active = s.active, listings = #listings, items = listings }
      end
    end
    table.sort(out, function(x, y) return x.label < y.label end)
    return { ok = true, shops = out }
  end)

  rpc:method("item_deposit", { write = true, auth = "session", p = { item = "str", count = "int+" }, doc = "Credit backed items to checking" }, function(ctx, p)
    if not pol.item_backing_enabled then return fail("Item backing is off") end
    if p.count > 4096 then return fail("At most 4096 items per deposit") end
    local rate = pol.item_backing_map[p.item]
    if not rate then return fail("That item is not backed") end
    local value = floor(rate * p.count)
    if value <= 0 then return fail("That item is not backed") end
    local a = ctx.acct
    bank:post(a, value, "item_deposit", string.format("%s x%d", p.item, p.count))
    bank:supply(value)
    bank:count_tx()
    bank:mark(a)
    bank:log("item_deposit", { account = a.id, item = p.item, count = p.count, value = value })
    return { ok = true, balance = a.balance, credited = value }
  end)

  rpc:method("item_rates", { doc = "Items that back the currency" }, function()
    if not pol.item_backing_enabled then return { ok = true, enabled = false, rates = {} } end
    local out = {}
    for item, rate in pairs(pol.item_backing_map) do out[#out + 1] = { item = item, rate = rate } end
    table.sort(out, function(x, y) return x.item < y.item end)
    return { ok = true, enabled = true, rates = out }
  end)

  local function note_sig(note)
    return crypto.hmac(bank.meta.key, "note|" .. note.serial .. "|" .. note.denom .. "|" .. note.issued .. "|" .. note.account)
  end

  local function legacy_sig(note)
    local ok, s = pcall(textutils.serialize, { serial = note.serial, denom = note.denom, issued = note.issued, account = note.account })
    if not ok then return nil end
    return crypto.hmac(bank.meta.key, s)
  end

  rpc:method("admin_issue_note", { write = true, auth = "admin", p = { account_id = "acct", denomination = "num" }, doc = "Turn account funds into a physical Reserve Note" }, function(ctx, p)
    local a = bank.accounts:get(p.account_id)
    if not a then return fail("Account not found") end
    local cents = floor(p.denomination * 100)
    if cents <= 0 or a.balance < cents then return fail("Insufficient funds") end
    local serial = "VRN-" .. crypto.random_hex(12):upper()
    local note = { serial = serial, denom = p.denomination, issued = util.now(), account = a.id, v = 10 }
    note.sig = note_sig(note)
    notes:put(serial, { kind = "note", denom = p.denomination, issued = note.issued, redeemed = false })
    bank:post(a, -cents, "note_issue", "Note " .. serial)
    bank:log("note_issue", { account = a.id, serial = serial, denom = p.denomination })
    return { ok = true, note = note, balance = a.balance }
  end)

  rpc:method("redeem_note", { write = true, auth = "session", p = { note = "tbl" }, doc = "Redeem a Reserve Note into checking" }, function(ctx, p)
    local note = p.note
    if type(note.serial) ~= "string" or type(note.sig) ~= "string" or type(note.denom) ~= "number" or type(note.account) ~= "string" or type(note.issued) ~= "number" then return fail("That note is damaged") end
    if note.denom <= 0 or note.denom > 1e9 then return fail("Bad note denomination") end
    local good = crypto.equal(note_sig(note), note.sig)
    if not good and note.v ~= 10 then
      local ls = legacy_sig(note)
      good = ls ~= nil and crypto.equal(ls, note.sig)
    end
    if not good then return fail("Forged note (signature mismatch)") end
    local rec = notes:get(note.serial)
    if not rec then return fail("Note is not in the registry. Contact Reserve staff.") end
    if rec.redeemed then return fail("Note already redeemed") end
    rec.redeemed, rec.redeemed_at, rec.redeemed_by = true, util.now(), ctx.acct.id
    notes:touch(note.serial)
    local cents = floor(note.denom * 100)
    bank:post(ctx.acct, cents, "note_redeem", "Note " .. note.serial)
    bank:log("note_redeem", { account = ctx.acct.id, serial = note.serial, denom = note.denom })
    return { ok = true, balance = ctx.acct.balance }
  end)
end

return M
