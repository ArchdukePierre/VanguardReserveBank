local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local util = require("lib.util")

local I = {}

local function inventories()
  if not settings or not settings.get then return nil end
  local drop_name, bank_name = settings.get("vrb.atm.drop"), settings.get("vrb.atm.bank")
  if type(drop_name) ~= "string" or type(bank_name) ~= "string" or drop_name == bank_name then return nil end
  if not peripheral.isPresent(drop_name) or not peripheral.isPresent(bank_name) then return nil end
  local drop, bank = peripheral.wrap(drop_name), peripheral.wrap(bank_name)
  if not drop or not bank or type(drop.list) ~= "function" or type(drop.pushItems) ~= "function" or type(bank.list) ~= "function" then return nil end
  return { drop = drop, bank = bank, drop_name = drop_name, bank_name = bank_name }
end

function I.available(ctx)
  return ctx:find("drive") ~= nil or inventories() ~= nil
end

function I.redeem(ctx)
  local drive = ctx:find("drive")
  if not drive then return ctx:say("Redeem note", { "No disk drive is attached." }, "warn") end
  local mount = drive.isDiskPresent and drive.isDiskPresent() and drive.getMountPath and drive.getMountPath()
  if not mount then return ctx:say("Redeem note", { "Put your note disk in the drive,", "then try again." }, "warn") end
  local path = fs.combine(mount, "note.vrb")
  local raw = util.read_file(path)
  if not raw then return ctx:say("Redeem note", { "There is no note on this disk." }, "warn") end
  local note = textutils.unserialize(raw)
  if type(note) ~= "table" then return ctx:say("Redeem note", { "That note is damaged." }, "error") end
  local worth = type(note.denom) == "number" and util.money(math.floor(note.denom * 100)) or "unknown value"
  local serial = type(note.serial) == "string" and note.serial or "note"
  if not ui.confirm(ctx, "Redeem note", { serial, "Worth " .. worth, "It goes into your checking account." }, "REDEEM") then return end
  local res = ctx:call("redeem_note", { note = note })
  if not res.ok then return ctx:fail(res, "Note not redeemed", true) end
  local removed = pcall(fs.delete, path)
  local lines = { "Added to checking.", "Checking: " .. util.money(res.balance or 0) }
  if not removed or fs.exists(path) then lines[#lines + 1] = "Remove note.vrb from the disk by hand." end
  ctx:say("Note redeemed", lines, "ok")
end

local function scan(inv, values)
  local ok, listing = pcall(inv.drop.list)
  if not ok or type(listing) ~= "table" then return {} end
  local by_item, order = {}, {}
  for slot, stack in pairs(listing) do
    if values[stack.name] then
      local e = by_item[stack.name]
      if not e then e = { item = stack.name, count = 0, slots = {} }; by_item[stack.name] = e; order[#order + 1] = e end
      e.count = e.count + stack.count
      e.slots[#e.slots + 1] = { slot = slot, count = stack.count }
    end
  end
  table.sort(order, function(a, b) return a.item < b.item end)
  return order
end

local function give_back(inv, item, count)
  local ok, listing = pcall(inv.bank.list)
  if not ok or type(listing) ~= "table" then return end
  for slot, stack in pairs(listing) do
    if count <= 0 then return end
    if stack.name == item then
      local ok2, n = pcall(inv.bank.pushItems, inv.drop_name, slot, math.min(count, stack.count))
      count = count - (ok2 and tonumber(n) or 0)
    end
  end
end

local function move_all(ctx, inv, found, values)
  local lines, total = {}, 0
  for _, e in ipairs(found) do
    local moved = 0
    for _, s in ipairs(e.slots) do
      local ok, n = pcall(inv.drop.pushItems, inv.bank_name, s.slot, s.count)
      if ok then moved = moved + (tonumber(n) or 0) end
    end
    if moved > 0 then
      local res = ctx:call("item_deposit", { item = e.item, count = moved })
      if res.ok then
        total = total + (res.credited or 0)
        lines[#lines + 1] = string.format("%.0f %s", moved, fmt.item_name(e.item))
      else
        give_back(inv, e.item, moved)
        ctx:fail(res, "Not credited", true)
      end
    end
  end
  if #lines == 0 then return false end
  lines[#lines + 1] = "Credited: " .. util.money(total)
  ctx:say("Items deposited", lines, "ok")
  return true
end

function I.deposit(ctx)
  local inv = inventories()
  if not inv then return ctx:say("Deposit items", { "The item chest is not set up." }, "warn") end
  local rates = ctx:pub("item_rates", {})
  if not rates.ok then return ctx:fail(rates) end
  if not rates.enabled or #rates.rates == 0 then return ctx:say("Deposit items", { "Item deposits are off right now." }, "warn") end
  local values = {}
  for _, r in ipairs(rates.rates) do values[r.item] = r.rate end
  while true do
    local found = scan(inv, values)
    local rows = {}
    for _, e in ipairs(found) do
      rows[#rows + 1] = { left = string.format("%.0f x %s", e.count, fmt.item_name(e.item)), right = util.money(math.floor(values[e.item] * e.count)) }
    end
    local kind, id = ui.list(ctx, { title = "Deposit items", sub = "Fill the chest, tap DEPOSIT", rows = rows, empty = "No items found", hint = "Items must be on the list",
      buttons = { { label = "DEPOSIT", id = "go", kind = "success", disabled = #found == 0 }, { label = "REFRESH", id = "refresh" } } })
    if kind ~= "btn" then return end
    if id == "go" and move_all(ctx, inv, found, values) then return end
  end
end

function I.menu(ctx)
  while true do
    local items = {}
    if ctx:find("drive") then items[#items + 1] = { label = "REDEEM NOTE", id = "note", kind = "primary", sub = "From a note disk" } end
    if inventories() then items[#items + 1] = { label = "DEPOSIT ITEMS", id = "items", kind = "success", sub = "Turn items into money" } end
    if #items == 0 then return ctx:say("Notes and items", { "Nothing is set up on this ATM." }, "warn") end
    local id = ui.menu(ctx, { title = "Notes and items", sub = "Cash in what you carry", items = items })
    if not id then return end
    if id == "note" then I.redeem(ctx) else I.deposit(ctx) end
  end
end

return I
