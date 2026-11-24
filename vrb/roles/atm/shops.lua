local ui = require("roles.atm.ui")
local util = require("lib.util")
local theme = require("ui.theme")

local S = {}

local function new_shop(ctx)
  local name = ui.text(ctx, { title = "New shop", label = "Shop name (3 to 40)", max = 40, free = true })
  if not name then return end
  if #name < 3 then return ctx:say("New shop", { "The name needs at least 3 letters." }, "error") end
  local res = ctx:call("create_shop", { label = name })
  if not res.ok then return ctx:fail(res, "Shop not created", true) end
  ctx:say("Shop created", { name, "Shop number " .. res.shop_id }, "ok")
end

local function edit_listing(ctx, shop, item)
  local sku, name = item and item.sku, item and item.item
  if not item then
    sku = ui.text(ctx, { title = "Item code", label = "Short code, like DIA1", max = 20, allowed = "^[%w_%-]$" })
    if not sku then return end
    name = ui.text(ctx, { title = "Item name", label = "What are you selling?", max = 40, free = true })
    if not name then return end
  end
  local price = ui.amount(ctx, "Price each")
  if not price then return end
  local stock = ui.number(ctx, "Stock", 6, "How many are in stock?")
  if not stock then return end
  local item_id = item and item.item_id
  local options = {
    { label = "NO ITEM ID", id = "skip", kind = "primary", sub = "Just a name" },
    { label = "ENTER ITEM ID", id = "enter", kind = "panel", sub = "Like minecraft:diamond" },
  }
  if item_id then table.insert(options, 1, { label = "KEEP ITEM ID", id = "keep", kind = "success", sub = item_id }) end
  local pick = ui.choose(ctx, "Game item id?", options)
  if not pick then return end
  if pick == "enter" then
    item_id = ui.text(ctx, { title = "Item id", label = "Like minecraft:diamond", max = 60, allowed = "^[%w_:%./%-]$" })
    if not item_id then return end
  elseif pick == "skip" then
    item_id = nil
  end
  local res = ctx:call("set_shop_listing", { shop_id = shop.id, sku = sku, item = name, price = price, stock = tonumber(stock), item_id = item_id })
  if not res.ok then return ctx:fail(res, "Not saved", true) end
  ctx:toast("Saved " .. name, "ok")
end

local function shop_page(ctx, shop_id)
  while true do
    local res = ctx:call("list_my_shops", {})
    if not res.ok then return ctx:fail(res) end
    local shop
    for _, s in ipairs(res.shops) do if s.id == shop_id then shop = s end end
    if not shop then return end
    local rows = {}
    for _, it in ipairs(shop.items or {}) do
      local sub = string.format("Code %s, stock %.0f", it.sku, it.stock or 0)
      if it.item_id then sub = sub .. ", " .. it.item_id end
      rows[#rows + 1] = { left = it.item, right = util.money(it.price or 0), sub = sub, id = it.sku, data = it }
    end
    local kind, _, data = ui.list(ctx, { title = shop.label, sub = "Touch an item to change it", rows = rows, empty = "No items listed", hint = "Add one with ADD ITEM",
      buttons = { { label = "ADD ITEM", id = "add", kind = "success" } } })
    if not kind then return end
    if kind == "btn" then
      edit_listing(ctx, shop, nil)
    else
      local pick = ui.choose(ctx, data.item, {
        { label = "CHANGE PRICE AND STOCK", id = "edit", kind = "primary" },
        { label = "REMOVE FROM SHOP", id = "remove", kind = "danger" },
      }, "Code " .. data.sku)
      if pick == "edit" then
        edit_listing(ctx, shop, data)
      elseif pick == "remove" and ui.confirm(ctx, "Remove item", { "Remove " .. data.item .. " from the shop?" }, "REMOVE", true) then
        local r = ctx:call("remove_shop_listing", { shop_id = shop.id, sku = data.sku })
        if not r.ok then ctx:fail(r, "Not removed", true) else ctx:toast("Item removed", "ok") end
      end
    end
  end
end

function S.run(ctx)
  while true do
    local res = ctx:call("list_my_shops", {})
    if not res.ok then return ctx:fail(res) end
    local rows = {}
    for _, s in ipairs(res.shops) do
      rows[#rows + 1] = { left = s.label, right = string.format("%.0f items", s.listings or 0), rcolor = theme.accent, sub = (s.active and "Open" or "Closed by staff") .. ", " .. s.id, id = s.id, data = s }
    end
    local kind, _, data = ui.list(ctx, { title = "Your shops", sub = "Touch a shop to manage it", rows = rows, empty = "No shops yet", hint = "Open one with NEW SHOP",
      buttons = { { label = "NEW SHOP", id = "new", kind = "success" } } })
    if not kind then return end
    if kind == "btn" then new_shop(ctx) else shop_page(ctx, data.id) end
  end
end

return S
