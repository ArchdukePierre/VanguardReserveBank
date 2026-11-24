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

local TABS_PATH = "/.vrb/tabs.dat"
local IDLE_SEC = 600
local MAX_PRICE = 100000000
local MAX_MEMO = 200
local HELP = { "tab <name>", "add <item> <price>", "+ <item> <price>", "void <item>", "tabs", "bill  (or close)", "delete <name>", "scroll u|d", "out  sign out", "q  quit" }

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function total(tab)
  local sum = 0
  for _, l in ipairs(tab.lines) do sum = sum + l.qty * l.price end
  return sum
end

local function count_text(n)
  return n .. (n == 1 and " line" or " lines")
end

local function line_text(l)
  return l.name .. (l.qty > 1 and (" x" .. l.qty) or "")
end

function M.build_memo(tab)
  local parts = {}
  for i, l in ipairs(tab.lines) do parts[i] = line_text(l) .. " " .. util.money(l.qty * l.price) end
  local tail = " = " .. util.money(total(tab))
  local full = table.concat(parts, ", ") .. tail
  if #full <= MAX_MEMO then return full end
  local best
  for i = 1, #parts do
    local more = #parts - i
    local suffix = (more > 0 and (", +" .. more .. " more") or "") .. tail
    local head = table.concat(parts, ", ", 1, i)
    if #head + #suffix > MAX_MEMO then break end
    best = head .. suffix
  end
  if best then return best end
  return parts[1]:sub(1, MAX_MEMO - #tail - 3) .. "..." .. tail
end

function M.parse_add(rest)
  local words = {}
  for w in trim(rest):gmatch("%S+") do words[#words + 1] = w end
  if #words < 2 then return nil, "Use: add <item> <price>" end
  local price = util.parse_money(words[#words])
  local name = table.concat(words, " ", 1, #words - 1)
  if not price then
    price = util.parse_money(words[1])
    name = table.concat(words, " ", 2)
  end
  if not price or price <= 0 then return nil, "Price must be above zero" end
  if price > MAX_PRICE then return nil, "Price is too high" end
  return name:sub(1, 30), price
end

local function load_state()
  local t = ser.decode(util.read_file(TABS_PATH) or "")
  local state = { tabs = {} }
  if type(t) ~= "table" or type(t.tabs) ~= "table" then return state end
  for key, tab in pairs(t.tabs) do
    if type(key) == "string" and type(tab) == "table" and type(tab.owner) == "string" and type(tab.lines) == "table" then
      local lines = {}
      for _, l in ipairs(tab.lines) do
        if type(l) == "table" and type(l.name) == "string" and type(l.price) == "number" and type(l.qty) == "number" then lines[#lines + 1] = l end
      end
      state.tabs[key] = { owner = tab.owner, lines = lines, opened = tab.opened }
    end
  end
  if type(t.current) == "string" and state.tabs[t.current] then state.current = t.current end
  if type(t.owner) == "string" then state.owner = t.owner end
  return state
end

local function fatal(lines)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  for _, l in ipairs(lines) do print(l) end
end

function M.run()
  local secret = cfgmod.read_key("server.secret")
  if not secret then
    return fatal({ "POS: no bank key", "", "server.secret is missing.", "Copy it to /.vrb/keys", "or run: vrb join" })
  end
  local client, why = Client.new({})
  if not client then return fatal({ "POS: network problem", "", tostring(why) }) end

  local S = load_state()
  S.buf = ""
  S.list = { offset = 0 }
  local app = App.new({})

  local function save()
    util.write_atomic(TABS_PATH, ser.encode({ tabs = S.tabs, current = S.current, owner = S.owner }))
  end

  local function current_tab() return S.current and S.tabs[S.current] or nil end
  local function status(text, kind) S.status = { text = text, kind = kind or "info" } end

  local function draw(s)
    s:fill(1, 1, s.w, 1, T.panel)
    s:text(2, 1, "VRB POS", T.accent, T.panel)
    local who = util.ellipsis(S.session and S.owner or "signed out", s.w - 11)
    s:text(s.w - #who, 1, who, S.session and T.good or T.warn, T.panel)
    local tab = current_tab()
    local bh = s.h >= 18 and 2 or 1
    local by = s.h - 1 - bh
    local top, rows_h = 3, by - 3
    if tab then
      local t = util.money(total(tab))
      s:text(2, 2, util.ellipsis("Tab " .. tab.owner, s.w - #t - 3), T.accent)
      s:text(s.w - #t, 2, t, T.ink)
      if #tab.lines == 0 then
        kit.empty(s, 1, top, s.w, rows_h, "Tab is empty", "add <item> <price>")
        S.per = rows_h
      else
        local rows = {}
        for i, l in ipairs(tab.lines) do rows[i] = { left = line_text(l), right = util.money(l.qty * l.price) } end
        S.per = kit.list(s, 1, top, s.w, rows_h, rows, S.list)
      end
    else
      kit.empty(s, 1, top, s.w, rows_h, "No tab open", "type: tab <name>")
      S.per = rows_h
    end
    if s.w >= 24 then
      local short = s.w < 40
      kit.grid(s, 1, by, s.w, bh, 4, {
        { label = "BILL", id = "bill", kind = "success", disabled = not tab or #tab.lines == 0 },
        { label = short and "VOID" or "VOID LAST", id = "void", kind = "secondary", disabled = not tab or #tab.lines == 0 },
        { label = "TABS", id = "tabs", kind = "secondary" },
        { label = "HELP", id = "help", kind = "secondary" },
      }, 1)
    end
    if S.status then
      local color = ({ ok = T.good, error = T.bad, warn = T.warn })[S.status.kind] or T.muted
      s:text(2, s.h - 1, util.ellipsis(S.status.text, s.w - 2), color)
    elseif S.buf == "" then
      s:text(2, s.h - 1, "help for commands", T.dim)
    end
    local shown = S.buf .. "_"
    if #shown > s.w - 3 then shown = shown:sub(-(s.w - 3)) end
    s:text(1, s.h, ">", T.accent)
    s:text(3, s.h, shown, T.ink)
    s:region(1, 2, s.w, 1, "tabs")
  end

  local function sign_out_quiet()
    if S.session then client:call("signout", { session = S.session }, { timeout = 1, retries = 1 }) end
    S.session = nil
    app.idle = nil
  end

  local function sign_in()
    local user = flows.text(app, { title = "Sign in", label = "Username", max = 32, initial = S.owner })
    if not user or #user < 2 then return false end
    local pin = flows.pin(app, "PIN for " .. user)
    if not pin then return false end
    local r = client:call("auth_by_owner", { owner = user, pin = pin, branch = "POS" })
    if not r.ok then
      flows.message(app, "Sign in failed", { r.err or "Try again" }, "error")
      return false
    end
    S.session = r.session
    app.idle = IDLE_SEC
    if S.owner ~= r.account.owner then
      S.owner = r.account.owner
      save()
    end
    return true
  end

  local function ensure_session()
    if S.session then return true end
    local ok = sign_in()
    app:show(draw)
    return ok
  end

  local function bill()
    local tab = current_tab()
    if not tab then return status("No tab open", "error") end
    local sum = total(tab)
    if sum <= 0 then return status("Tab is empty", "error") end
    if not ensure_session() then return status("Sign in to bill", "warn") end
    local memo = M.build_memo(tab)
    local yes = flows.confirm(app, "Bill " .. tab.owner, { "Total " .. util.money(sum), count_text(#tab.lines), util.ellipsis(memo, 54) }, { yes = "SEND", no = "CANCEL" })
    app:show(draw)
    if not yes then return status("Cancelled", "warn") end
    local params = { session = S.session, target_owner = tab.owner, amount = sum, memo = memo }
    local r = client:call("request_payment", params)
    if not r.ok and r.code == "no_session" then
      S.session = nil
      if sign_in() then
        params.session = S.session
        r = client:call("request_payment", params)
      end
      app:show(draw)
    end
    if r.ok then
      S.tabs[S.current] = nil
      S.current = nil
      save()
      status("Bill sent to " .. tab.owner, "ok")
    else
      status(r.err or "Bill failed", "error")
    end
  end

  local function void_last_or(name)
    local tab = current_tab()
    if not tab then return status("No tab open", "error") end
    local idx
    for i = #tab.lines, 1, -1 do
      if not name or tab.lines[i].name:lower() == name:lower() then idx = i; break end
    end
    if not idx then return status("Not on the tab: " .. name, "error") end
    local l = tab.lines[idx]
    if l.qty > 1 then l.qty = l.qty - 1 else table.remove(tab.lines, idx) end
    save()
    status("Removed " .. l.name, "ok")
  end

  local function pick_tab()
    local keys = util.sorted_keys(S.tabs)
    local rows = {}
    for i, key in ipairs(keys) do
      local tab = S.tabs[key]
      rows[i] = { left = tab.owner, right = util.money(total(tab)), id = "tab:" .. key, selected = key == S.current }
    end
    local id = flows.pick_list(app, "Open tabs", rows, { empty = "No open tabs", hint = "tab <name>" })
    app:show(draw)
    if type(id) == "string" and id:sub(1, 4) == "tab:" and S.tabs[id:sub(5)] and S.current ~= id:sub(5) then
      S.current = id:sub(5)
      S.list.offset = 0
      save()
    end
  end

  local function help()
    app:show(function(s)
      s:fill(1, 1, s.w, 1, T.panel)
      s:text(2, 1, "VRB POS commands", T.accent, T.panel)
      for i, l in ipairs(HELP) do s:text(2, 2 + i, util.ellipsis(l, s.w - 2), T.ink) end
      s:text(2, s.h, "touch or press a key", T.dim)
      s:region(1, 1, s.w, s.h, "back")
    end)
    while true do
      local kind, a = app:wait({ timeout = 60 })
      if kind == "tap" or kind == "char" or kind == "timeout" or (kind == "key" and (a == "enter" or a == "escape")) then break end
    end
    app:show(draw)
  end

  local function delete(arg)
    local key = trim(arg):lower()
    if key == "" then key = S.current end
    local tab = key and S.tabs[key]
    if not tab then return status("No such tab", "error") end
    if #tab.lines > 0 then
      local yes = flows.confirm(app, "Delete tab", { tab.owner .. " has " .. count_text(#tab.lines) .. ".", "They will be lost." }, { yes = "DELETE", no = "KEEP", danger = true })
      app:show(draw)
      if not yes then return status("Kept " .. tab.owner, "warn") end
    end
    S.tabs[key] = nil
    if S.current == key then S.current = nil end
    save()
    status("Deleted " .. tab.owner, "warn")
  end

  local function scroll(delta)
    S.list.offset = math.max(0, (S.list.offset or 0) + delta)
  end

  local function command(line)
    line = trim(line)
    if line == "" then return end
    local cmd, rest = line:match("^(%S+)%s*(.*)$")
    cmd = cmd:lower()
    if cmd == "q" or cmd == "quit" or cmd == "exit" then return "quit" end
    if cmd == "help" or cmd == "?" then return help() end
    if cmd == "tabs" then return pick_tab() end
    if cmd == "tab" then
      local name = trim(rest)
      if #name < 2 or #name > 32 or not name:match("^[%w_]+$") then return status("Use a player name", "error") end
      local key = name:lower()
      if not S.tabs[key] then
        S.tabs[key] = { owner = name, lines = {}, opened = util.now() }
        S.current = key
        S.list.offset = 0
        save()
        return status("Opened " .. name, "ok")
      end
      if S.current ~= key then
        S.current = key
        S.list.offset = 0
        save()
      end
      return status("Tab " .. S.tabs[key].owner, "ok")
    end
    if cmd == "add" or cmd == "+" then
      local tab = current_tab()
      if not tab then return status("Open a tab first", "error") end
      local name, price = M.parse_add(rest)
      if not name then return status(price, "error") end
      local found
      for _, l in ipairs(tab.lines) do
        if l.name:lower() == name:lower() and l.price == price then found = l end
      end
      if found then found.qty = found.qty + 1 else tab.lines[#tab.lines + 1] = { name = name, price = price, qty = 1 } end
      S.list.offset = 1e9
      save()
      return status("Added " .. name, "ok")
    end
    if cmd == "void" or cmd == "remove" then
      local name = trim(rest)
      if name == "" then return status("Use: void <item>", "error") end
      return void_last_or(name)
    end
    if cmd == "delete" or cmd == "del" then return delete(rest) end
    if cmd == "close" or cmd == "bill" then return bill() end
    if cmd == "scroll" then
      local dir = trim(rest):lower()
      if dir == "u" or dir == "up" then scroll(-(S.per or 5)) elseif dir == "d" or dir == "down" then scroll(S.per or 5) else return status("Use: scroll u or d", "error") end
      return
    end
    if cmd == "out" or cmd == "signout" then
      sign_out_quiet()
      status("Signed out", "warn")
      app:show(draw)
      sign_in()
      return
    end
    status("Unknown: " .. util.ellipsis(cmd, 12) .. ". Type help", "error")
  end

  app:show(draw)
  sign_in()
  app:show(draw)

  while true do
    local kind, a = app:wait()
    local result
    if kind == "char" then
      S.status = nil
      if #S.buf < 120 then S.buf = S.buf .. a end
    elseif kind == "paste" then
      S.status = nil
      S.buf = (S.buf .. a:gsub("[\r\n]", " ")):sub(1, 120)
    elseif kind == "key" then
      if a == "backspace" then
        S.buf = S.buf:sub(1, -2)
      elseif a == "enter" then
        local line = S.buf
        S.buf, S.status = "", nil
        result = command(line)
      elseif a == "escape" then
        S.buf = ""
      elseif a == "up" then scroll(-1)
      elseif a == "down" then scroll(1)
      elseif a == "pageUp" then scroll(-(S.per or 5))
      elseif a == "pageDown" then scroll(S.per or 5) end
    elseif kind == "scroll" then
      scroll(a)
    elseif kind == "tap" then
      S.status = nil
      if a.id == "bill" then bill()
      elseif a.id == "void" then void_last_or(nil)
      elseif a.id == "tabs" then pick_tab()
      elseif a.id == "help" then help() end
    elseif kind == "timeout" then
      sign_out_quiet()
      status("Signed out after idle time", "warn")
    end
    if result == "quit" then break end
    app:show(draw)
  end
  sign_out_quiet()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
end

return M
