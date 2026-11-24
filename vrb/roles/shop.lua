local App = require("ui.app")
local kit = require("ui.kit")
local flows = require("ui.flows")
local theme = require("ui.theme")
local Client = require("lib.client")
local cfgmod = require("lib.cfg")
local util = require("lib.util")
local ser = require("lib.ser")

local M = {}
local T = theme

local CFG_PATH = "/.vrb/shop.cfg"
local IDLE_SEC = 60

local function valid_id(s)
  return type(s) == "string" and #s >= 1 and #s <= 48 and s:match("^[%w_%-]+$") ~= nil
end

local function load_config()
  local t = ser.decode(util.read_file(CFG_PATH) or "")
  if type(t) == "table" and valid_id(t.shop_id) then return t end
end

local function ask_shop_id()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("VRB shop kiosk setup")
  print("")
  print("Enter the shop id from the")
  print("owner (like SHP-1A2B3C4D).")
  while true do
    write("Shop id: ")
    local id = read()
    id = id and util.trim(id) or ""
    if valid_id(id) then
      local cfg = { shop_id = id }
      util.write_atomic(CFG_PATH, ser.encode(cfg))
      return cfg
    end
    print("Letters, digits, - and _ only.")
  end
end

local function find_monitor()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then return peripheral.wrap(name), name end
  end
end

local function fatal(lines)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  for _, l in ipairs(lines) do print(l) end
end

local function stock_count(inv, item_id)
  local ok, list = pcall(inv.list)
  if not ok or type(list) ~= "table" then return nil end
  local n = 0
  for _, it in pairs(list) do
    if it.name == item_id then n = n + (it.count or 0) end
  end
  return n
end

local function dispense(inv, output, item_id, qty)
  local ok, list = pcall(inv.list)
  if not ok or type(list) ~= "table" then return 0 end
  local slots = {}
  for slot, it in pairs(list) do
    if it.name == item_id then slots[#slots + 1] = slot end
  end
  table.sort(slots)
  local moved = 0
  for _, slot in ipairs(slots) do
    if moved >= qty then break end
    local pushed, n = pcall(inv.pushItems, output, slot, qty - moved)
    n = pushed and tonumber(n) or 0
    if n <= 0 then break end
    moved = moved + n
  end
  return moved
end

function M.run()
  if not cfgmod.read_key("server.secret") then
    return fatal({ "SHOP: no bank key", "", "server.secret is missing.", "Copy it to /.vrb/keys and", "start this computer again." })
  end
  local client, why = Client.new({})
  if not client then return fatal({ "SHOP: network problem", "", tostring(why) }) end
  local cfg = load_config() or ask_shop_id()
  local mon, name = find_monitor()
  local app = App.new({ surface = mon, name = name, idle = IDLE_SEC })
  local S = { offset = 0, per = 1 }

  local function physical(l)
    return cfg.stock and cfg.output and l.item_id
  end

  local function fetch()
    local r = client:call("get_shop", { shop_id = cfg.shop_id })
    if r.ok then
      S.shop, S.err = r.shop, nil
    else
      S.shop, S.err = nil, r.err or "The bank is not responding"
    end
  end

  local function draw(s)
    local shop = S.shop
    kit.header(s, shop and shop.label or "Shop", shop and ("Run by " .. shop.owner) or cfg.shop_id)
    local top, bottom = 5, s.h - 2
    local listings = shop and shop.listings or {}
    S.per = math.max(1, math.floor((bottom - top + 1) / 2))
    S.offset = util.clamp(S.offset, 0, math.max(0, #listings - S.per))
    if not shop then
      kit.empty(s, 2, top, s.w - 2, bottom - top + 1, "Shop unavailable", S.err)
    elseif #listings == 0 then
      kit.empty(s, 2, top, s.w - 2, bottom - top + 1, "Nothing for sale yet", "Check back soon")
    else
      for i = 1, S.per do
        local l = listings[S.offset + i]
        if l then
          local y = top + (i - 1) * 2
          local bg = (i % 2 == 1) and T.panel or T.bg
          local sold = l.stock <= 0
          s:fill(2, y, s.w - 2, 2, bg)
          local price = util.money(l.price)
          s:text(3, y, util.ellipsis(l.item, s.w - #price - 6), sold and T.muted or T.ink, bg)
          s:text(s.w - #price - 1, y, price, sold and T.muted or T.accent, bg)
          s:text(3, y + 1, util.ellipsis(l.note or "", s.w - 18), T.muted, bg)
          local right = sold and "SOLD OUT" or l.stock .. " in stock"
          s:text(s.w - #right - 1, y + 1, right, sold and T.bad or T.muted, bg)
          if not sold then s:region(2, y, s.w - 2, 2, "item:" .. (S.offset + i)) end
        end
      end
    end
    local bw = math.min(12, math.floor((s.w - 4) / 3))
    kit.button(s, 2, s.h - 1, bw, "\30 UP", "up", { kind = "secondary", disabled = S.offset == 0 })
    kit.button(s, 3 + bw, s.h - 1, bw, "\31 DOWN", "down", { kind = "secondary", disabled = S.offset + S.per >= #listings })
    kit.button(s, s.w - bw - 1, s.h - 1, bw, "REFRESH", "refresh", { kind = "ghost" })
    kit.footer(s, util.ellipsis("Touch an item to buy", s.w - #cfg.shop_id - 5), cfg.shop_id)
  end

  local function sign_in()
    local user = flows.text(app, { title = "Sign in", label = "Minecraft username", max = 32 })
    if not user or #user < 2 then return nil end
    local pin = flows.pin(app, "PIN for " .. user)
    if not pin then return nil end
    local r = client:call("auth_by_owner", { owner = user, pin = pin, branch = "SHOP:" .. cfg.shop_id })
    if not r.ok then
      flows.message(app, "Could not sign in", { r.err or "Try again" }, "error")
      return nil
    end
    return r
  end

  local function checkout(l, qty, auth, release)
    local total = l.price * qty
    local yes = flows.confirm(app, "Confirm purchase", { qty .. " x " .. l.item, "Total " .. util.money(total), "Your balance " .. util.money(auth.account.balance) }, { yes = "BUY", no = "CANCEL" })
    if not yes then return end
    local inv
    if physical(l) then
      inv = peripheral.wrap(cfg.stock)
      if not inv or not peripheral.isPresent(cfg.output) then
        release()
        return flows.message(app, "Not available", { "This shop cannot hand out items right now.", "Nothing was charged." }, "warn")
      end
      local have = stock_count(inv, l.item_id)
      if not have or have < qty then
        release()
        return flows.message(app, "Not enough in the chest", { "Ask " .. S.shop.owner .. " to restock.", "Nothing was charged." }, "warn")
      end
    end
    local r = client:call("buy_from_shop", { session = auth.session, shop_id = cfg.shop_id, sku = l.sku, qty = qty })
    release()
    if not r.ok then return flows.message(app, "Purchase failed", { r.err or "Try again" }, "error") end
    if inv then
      local moved = dispense(inv, cfg.output, l.item_id, qty)
      if moved < qty then
        flows.message(app, "Contact the owner", { string.format("You paid %s for %d x %s.", util.money(r.cost), qty, l.item), string.format("Only %d came out.", moved), "Tell " .. S.shop.owner .. " before you leave." }, "error")
        return true
      end
    end
    flows.message(app, "Thank you", { qty .. " x " .. l.item, "Paid " .. util.money(r.cost), "Balance " .. util.money(r.balance) }, "ok")
    return true
  end

  local function purchase(l)
    local qty = 1
    if l.stock > 1 then
      local text = flows.number(app, util.ellipsis(l.item, 24) .. ": how many?", { max = 3 })
      if not text then return end
      qty = math.max(1, tonumber(text) or 1)
    end
    if qty > l.stock then return flows.message(app, "Not enough stock", { "Only " .. l.stock .. " left." }, "warn") end
    local auth = sign_in()
    if not auth then return end
    local function release()
      if auth.session then
        client:call("signout", { session = auth.session }, { timeout = 2, retries = 1 })
        auth.session = nil
      end
    end
    local ok, bought = pcall(checkout, l, qty, auth, release)
    release()
    if not ok then error(bought, 0) end
    if bought then fetch() end
  end

  app:show(draw)
  fetch()
  while true do
    app:show(draw)
    local kind, a = app:wait()
    if kind == "tap" then
      if a.id == "up" then S.offset = S.offset - S.per
      elseif a.id == "down" then S.offset = S.offset + S.per
      elseif a.id == "refresh" then fetch()
      elseif a.id:sub(1, 5) == "item:" and S.shop then
        local l = S.shop.listings[tonumber(a.id:sub(6))]
        if l then purchase(l) end
      end
    elseif kind == "scroll" then
      S.offset = S.offset + a
    elseif kind == "timeout" then
      S.offset = 0
    end
  end
end

return M
