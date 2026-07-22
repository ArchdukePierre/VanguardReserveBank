-- ============================================================================
-- VRB POCKET POS  (v5)
-- ----------------------------------------------------------------------------
-- A pocket-computer point-of-sale terminal for shopkeepers. Runs on an
-- Advanced Ender Pocket Computer. Lets you open tabs for customers, add
-- line items as they order, then BILL the customer (which sends a payment
-- request via the bank's existing handler).
--
-- TABS ARE LOCAL: stored on this pocket computer's disk under /.vrb/tabs.dat.
-- Survives reboots. If the pocket dies/dies, tabs are lost; sorry.
--
-- USAGE:
--   tab steve           -- switch to Steve's tab (creates if doesn't exist)
--   add burger 8        -- add "burger" $8.00 to current tab
--   + fries 4           -- shorthand for add
--   void burger         -- remove "burger" from current tab
--   tabs                -- list all open tabs
--   close               -- finish current tab; sends one BILL to customer
--   reload              -- re-fetch session if signed out
--   help                -- show command help
--   quit                -- exit (tabs persist on disk)
--   delete steve        -- delete a tab without billing
--
-- SCROLL WHEEL: scrolls the line items in long tabs.
-- ============================================================================

local CFG = {
    PROTOCOL        = "VRB_V2",
    HOSTNAME_SERVER = "vrb.reserve",
    PAIR_PROTOCOL   = "VRB_POCKET_PAIR",
    DATA_DIR        = "/.vrb",
    KEY_DIR         = "/.vrb/keys",
    SECRET_PATH     = "/.vrb/keys/server.secret",
    TABS_PATH       = "/.vrb/tabs.dat",
    SESSION_PATH    = "/.vrb/pos_session.dat",
    SHOP_PATH       = "/.vrb/pos_shop.dat",
    RPC_WINDOW_SEC  = 30,
    RPC_TIMEOUT     = 5,
}

-- ============================================================================
-- CRYPTO  (copied from vrb.lua so we share the same wire format)
-- ============================================================================
local crypto = {}
local band, bor, bxor = bit32.band, bit32.bor, bit32.bxor
local lshift, rshift  = bit32.lshift, bit32.rshift
local rrotate         = bit32.rrotate

local K256 = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local function shaPad(msg)
    local L = #msg
    local pad = "\128"
    local rem = (L + 1) % 64
    local zeros = (rem <= 56) and (56 - rem) or (120 - rem)
    pad = pad .. string.rep("\0", zeros)
    local bits = L * 8
    local high = math.floor(bits / 4294967296)
    local low  = bits % 4294967296
    pad = pad .. string.char(
        band(rshift(high, 24), 0xff), band(rshift(high, 16), 0xff),
        band(rshift(high, 8),  0xff), band(high, 0xff),
        band(rshift(low,  24), 0xff), band(rshift(low,  16), 0xff),
        band(rshift(low,   8), 0xff), band(low,  0xff))
    return msg .. pad
end

local function shaBlock(h, blk, off)
    local w = {}
    for i = 0, 15 do
        local b1 = string.byte(blk, off + i*4 + 1)
        local b2 = string.byte(blk, off + i*4 + 2)
        local b3 = string.byte(blk, off + i*4 + 3)
        local b4 = string.byte(blk, off + i*4 + 4)
        w[i] = bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4)
    end
    for i = 16, 63 do
        local s0 = bxor(rrotate(w[i-15], 7), rrotate(w[i-15], 18), rshift(w[i-15], 3))
        local s1 = bxor(rrotate(w[i-2], 17), rrotate(w[i-2], 19), rshift(w[i-2], 10))
        w[i] = (w[i-16] + s0 + w[i-7] + s1) % 4294967296
    end
    local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
    for i = 0, 63 do
        local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
        local ch = bxor(band(e, f), band(bxor(0xffffffff, e), g))
        local t1 = (hh + S1 + ch + K256[i+1] + w[i]) % 4294967296
        local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
        local mj = bxor(band(a, b), band(a, c), band(b, c))
        local t2 = (S0 + mj) % 4294967296
        hh = g; g = f; f = e
        e = (d + t1) % 4294967296
        d = c; c = b; b = a
        a = (t1 + t2) % 4294967296
    end
    h[1] = (h[1] + a) % 4294967296; h[2] = (h[2] + b) % 4294967296
    h[3] = (h[3] + c) % 4294967296; h[4] = (h[4] + d) % 4294967296
    h[5] = (h[5] + e) % 4294967296; h[6] = (h[6] + f) % 4294967296
    h[7] = (h[7] + g) % 4294967296; h[8] = (h[8] + hh) % 4294967296
end

function crypto.sha256(msg)
    local h = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
               0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}
    local padded = shaPad(msg)
    for off = 0, #padded - 1, 64 do shaBlock(h, padded, off) end
    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x",
        h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8])
end

local function sha256_raw(msg)
    local hex = crypto.sha256(msg)
    local out = {}
    for i = 1, 64, 2 do
        out[#out+1] = string.char(tonumber(hex:sub(i, i+1), 16))
    end
    return table.concat(out)
end

function crypto.hmac(key, msg)
    local k
    if #key == 64 and key:match("^[0-9a-f]+$") then
        local out = {}
        for i = 1, 64, 2 do
            out[#out+1] = string.char(tonumber(key:sub(i, i+1), 16))
        end
        k = table.concat(out)
    else
        k = key
    end
    if #k > 64 then k = sha256_raw(k) end
    if #k < 64 then k = k .. string.rep("\0", 64 - #k) end
    local kip, kop = {}, {}
    for i = 1, 64 do
        local c = string.byte(k, i)
        kip[i] = string.char(bxor(c, 0x36))
        kop[i] = string.char(bxor(c, 0x5c))
    end
    kip = table.concat(kip); kop = table.concat(kop)
    local inner = sha256_raw(kip .. msg)
    return crypto.sha256(kop .. inner)
end

function crypto.stream_xor(key, nonce, plaintext)
    local out = {}
    local block = 0
    local stream_raw = ""
    for i = 1, #plaintext do
        if #stream_raw == 0 then
            stream_raw = sha256_raw(key .. nonce .. tostring(block))
            block = block + 1
        end
        local kb = string.byte(stream_raw, 1)
        stream_raw = stream_raw:sub(2)
        out[i] = string.char(bxor(string.byte(plaintext, i), kb))
    end
    return table.concat(out)
end

local _rand_state, _rand_counter = nil, 0
local function _seedRand()
    local epoch_us = os.epoch and os.epoch("utc") or (os.time() * 1000)
    local cid = os.getComputerID and os.getComputerID() or 0
    local jitter = tostring(os.clock and os.clock() or 0)
    local seed_str = tostring(epoch_us) .. ":" .. tostring(cid) .. ":" .. jitter
    local hex = crypto.sha256(seed_str)
    math.randomseed(tonumber(hex:sub(1, 8), 16) or 1)
    _rand_state = sha256_raw(hex); _rand_counter = 0
end

function crypto.random_bytes(n)
    if not _rand_state then _seedRand() end
    local out = {}
    while #out < n do
        _rand_counter = _rand_counter + 1
        local mix = sha256_raw(_rand_state .. tostring(_rand_counter)
                                .. tostring(os.epoch and os.epoch("utc") or 0))
        _rand_state = sha256_raw(_rand_state .. mix)
        for i = 1, math.min(32, n - #out) do
            out[#out+1] = string.format("%02x", string.byte(mix, i))
        end
    end
    return table.concat(out, "", 1, n)
end

function crypto.random_id() return crypto.random_bytes(16) end

local function seal(key, payload)
    local nonce  = crypto.random_id()
    local ts     = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
    local body   = textutils.serialize(payload)
    local cipher = crypto.stream_xor(key, nonce, body)
    local mac    = crypto.hmac(key, nonce .. tostring(ts) .. cipher)
    return {v=2, nonce=nonce, ts=ts, cipher=cipher, mac=mac}
end

local function unseal(key, envelope, window)
    if type(envelope) ~= "table" or envelope.v ~= 2 then return nil, "Bad envelope" end
    local now_ts = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
    if math.abs(now_ts - (envelope.ts or 0)) > (window or CFG.RPC_WINDOW_SEC) then
        return nil, "Stale packet"
    end
    local expect = crypto.hmac(key, envelope.nonce .. tostring(envelope.ts) .. envelope.cipher)
    if expect ~= envelope.mac then return nil, "Bad MAC" end
    local body = crypto.stream_xor(key, envelope.nonce, envelope.cipher)
    local ok, payload = pcall(textutils.unserialize, body)
    if not ok or type(payload) ~= "table" then return nil, "Bad payload" end
    return payload
end

-- ============================================================================
-- UTIL
-- ============================================================================
local function fmtMoney(cents)
    cents = cents or 0
    local neg = cents < 0
    if neg then cents = -cents end
    local d = math.floor(cents / 100)
    local c = cents % 100
    return (neg and "-$" or "$") .. d .. string.format(".%02d", c)
end

local function ensureDir(p)
    if not fs.exists(p) then fs.makeDir(p) end
end

local function readFile(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r"); if not f then return nil end
    local s = f.readAll(); f.close()
    return s
end

local function writeFile(path, content)
    ensureDir(CFG.DATA_DIR)
    local f = fs.open(path, "w"); if not f then return false end
    f.write(content); f.close()
    return true
end

local function readTable(path)
    local s = readFile(path); if not s then return nil end
    local ok, t = pcall(textutils.unserialize, s)
    if ok and type(t) == "table" then return t end
    return nil
end

local function writeTable(path, t)
    return writeFile(path, textutils.serialize(t))
end

-- ============================================================================
-- HARDWARE
-- ============================================================================
local function openModem()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            if not rednet.isOpen(name) then rednet.open(name) end
            return name
        end
    end
    return nil
end

-- ============================================================================
-- PAIRING (first-time setup: receive server.secret from admin terminal)
-- ============================================================================
-- The admin terminal runs a small "pair" command that broadcasts the secret
-- on a private channel after the user enters a 6-digit code. The pocket
-- listens for the same code over the pair channel and saves the secret.

local function pairWithAdmin()
    term.clear(); term.setCursorPos(1, 1)
    print("VRB Pocket POS")
    print("First-time setup")
    print("")
    print("On your admin terminal,")
    print("run the pair tool, OR")
    print("paste the server.secret")
    print("here directly.")
    print("")
    print("Choose:")
    print(" 1) Wait for admin pair")
    print(" 2) Paste secret manually")
    print("")
    write("> ")
    local choice = read()
    if choice == "1" or choice:lower() == "pair" then
        -- Pairing flow over rednet
        local mod = openModem()
        if not mod then
            print("No modem; cannot pair.")
            print("Press any key to exit.")
            os.pullEvent("key")
            return false
        end
        -- Generate a 6-digit code on this side, show it; admin terminal
        -- types the same code; we accept whichever broadcast matches.
        local code = string.format("%06d", math.random(0, 999999))
        term.clear(); term.setCursorPos(1, 1)
        print("Pair code:")
        term.setTextColor(colors.yellow)
        print("")
        print("    "..code)
        term.setTextColor(colors.white)
        print("")
        print("On admin terminal:")
        print("'pair pocket "..code.."'")
        print("")
        print("Waiting...")
        print("(any key cancels)")
        local timeout_at = os.clock() + 120
        while os.clock() < timeout_at do
            local timeout = timeout_at - os.clock()
            local ev, p1, p2, p3 = os.pullEvent()
            if ev == "key" then
                return false
            elseif ev == "rednet_message" then
                local sender, msg, proto = p1, p2, p3
                if proto == CFG.PAIR_PROTOCOL
                   and type(msg) == "table"
                   and msg.code == code
                   and type(msg.secret) == "string"
                   and #msg.secret >= 32 then
                    ensureDir(CFG.KEY_DIR)
                    if writeFile(CFG.SECRET_PATH, msg.secret) then
                        print("")
                        term.setTextColor(colors.lime)
                        print("Paired!")
                        term.setTextColor(colors.white)
                        sleep(1)
                        return true
                    end
                end
            end
        end
        print("Pairing timed out.")
        sleep(1)
        return false
    elseif choice == "2" or choice:lower() == "paste" then
        term.clear(); term.setCursorPos(1, 1)
        print("Paste the server.secret")
        print("contents (hex string):")
        write("> ")
        local s = read()
        if s and #s >= 32 then
            ensureDir(CFG.KEY_DIR)
            if writeFile(CFG.SECRET_PATH, s) then
                print("Saved.")
                sleep(1)
                return true
            end
        end
        print("Invalid; need 32+ chars.")
        sleep(2)
        return false
    end
    return false
end

local SECRET = nil
local function loadSecret()
    if not fs.exists(CFG.SECRET_PATH) then return false end
    local s = readFile(CFG.SECRET_PATH)
    if not s or #s < 32 then return false end
    SECRET = s
    return true
end

-- ============================================================================
-- RPC
-- ============================================================================
local SERVER_ID = nil

local function findServer(force)
    if SERVER_ID and not force then return SERVER_ID end
    SERVER_ID = rednet.lookup(CFG.PROTOCOL, CFG.HOSTNAME_SERVER)
    return SERVER_ID
end

local function call(method, params)
    params = params or {}
    local sid = findServer()
    if not sid then
        sid = findServer(true)
        if not sid then return {ok=false, err="Bank not online"} end
    end
    local rpc_id = crypto.random_id()
    local payload = {rpc_id=rpc_id, method=method, params=params}
    for attempt = 1, 3 do
        pcall(rednet.send, sid, seal(SECRET, payload), CFG.PROTOCOL)
        local deadline = os.clock() + CFG.RPC_TIMEOUT
        while os.clock() < deadline do
            local id, envelope = rednet.receive(CFG.PROTOCOL, deadline - os.clock())
            if id == sid then
                local res = unseal(SECRET, envelope, CFG.RPC_WINDOW_SEC)
                if res and res.rpc_id == rpc_id then return res end
            end
        end
        sid = findServer(true) or sid
    end
    return {ok=false, err="Bank timeout"}
end

-- ============================================================================
-- SHOPKEEPER SESSION
-- ============================================================================
local SESSION = nil          -- session token from auth_by_owner
local OWNER   = nil          -- shopkeeper's username
local SHOP_LABEL = nil       -- "Steve's Diner"

local function loadSession()
    local t = readTable(CFG.SESSION_PATH)
    if t and t.session and t.owner then
        SESSION = t.session
        OWNER = t.owner
        return true
    end
    return false
end

local function saveSession()
    if SESSION and OWNER then
        writeTable(CFG.SESSION_PATH, {session=SESSION, owner=OWNER, t=os.epoch("utc")})
    end
end

local function clearSession()
    SESSION = nil; OWNER = nil
    if fs.exists(CFG.SESSION_PATH) then fs.delete(CFG.SESSION_PATH) end
end

local function loadShop()
    local t = readTable(CFG.SHOP_PATH)
    if t and t.label then SHOP_LABEL = t.label end
end

local function saveShop()
    writeTable(CFG.SHOP_PATH, {label=SHOP_LABEL})
end

local function shopkeeperSignIn()
    term.clear(); term.setCursorPos(1, 1)
    print("VRB Pocket POS")
    print("Sign in (shopkeeper)")
    print("")
    write("Username: ")
    local user = read()
    if not user or #user < 2 then return false end
    write("PIN:      ")
    local pin = read("*")
    if not pin or #pin ~= 4 then
        print("PIN must be 4 digits.")
        sleep(2); return false
    end
    print("Authenticating...")
    local r = call("auth_by_owner",
        {owner=user, pin=pin, branch="POCKET"})
    if not r.ok then
        print("Failed: " .. (r.err or "?"))
        sleep(2); return false
    end
    if r.account.kind ~= "checking" then
        print("Need a checking account.")
        sleep(2); return false
    end
    SESSION = r.session
    OWNER = r.account.owner
    saveSession()
    if not SHOP_LABEL then
        print("")
        write("Shop name: ")
        local label = read()
        if label and #label >= 1 then
            SHOP_LABEL = label:sub(1, 22)
            saveShop()
        else
            SHOP_LABEL = OWNER .. "'s Shop"
            saveShop()
        end
    end
    print("Signed in.")
    sleep(0.5)
    return true
end

-- ============================================================================
-- TABS  (local state)
-- ============================================================================
-- Schema:
--   TABS = {
--     [owner_lower] = {
--       owner = "Steve",     -- canonical case
--       lines = {
--         {qty=1, name="burger", price=800},
--         {qty=2, name="fries", price=400},
--       },
--       opened_at = epoch,
--     },
--     ...
--   }
local TABS = {}
local CURRENT_TAB = nil  -- owner_lower of currently selected tab

local function loadTabs()
    local t = readTable(CFG.TABS_PATH)
    if t and type(t.tabs) == "table" then
        TABS = t.tabs
        CURRENT_TAB = t.current
    end
end

local function saveTabs()
    writeTable(CFG.TABS_PATH, {tabs=TABS, current=CURRENT_TAB})
end

local function tabTotal(tab)
    if not tab or not tab.lines then return 0 end
    local total = 0
    for _, ln in ipairs(tab.lines) do
        total = total + (ln.qty or 1) * (ln.price or 0)
    end
    return total
end

local function findOrCreateTab(owner)
    local k = owner:lower()
    if not TABS[k] then
        TABS[k] = {owner = owner, lines = {}, opened_at = os.epoch("utc")}
    end
    return TABS[k], k
end

local function findExistingLine(tab, name)
    local target = name:lower()
    for i, ln in ipairs(tab.lines) do
        if ln.name:lower() == target then return i, ln end
    end
    return nil
end

local function addToTab(tab, name, price)
    -- Consolidate by name
    local idx, existing = findExistingLine(tab, name)
    if existing and existing.price == price then
        existing.qty = (existing.qty or 1) + 1
    elseif existing then
        -- Same name, different price -- treat as new line
        table.insert(tab.lines, {qty=1, name=name, price=price})
    else
        table.insert(tab.lines, {qty=1, name=name, price=price})
    end
end

local function voidFromTab(tab, name)
    local idx, existing = findExistingLine(tab, name)
    if not existing then return false end
    if (existing.qty or 1) > 1 then
        existing.qty = existing.qty - 1
    else
        table.remove(tab.lines, idx)
    end
    return true
end

-- ============================================================================
-- UI  (26 cols x 20 rows on Advanced Pocket Computer)
-- ============================================================================
local SCROLL = 0      -- offset into the lines display
local STATUS_MSG = nil
local STATUS_COLOR = colors.white
local STATUS_UNTIL = 0

local function setStatus(msg, color, secs)
    STATUS_MSG = msg
    STATUS_COLOR = color or colors.white
    STATUS_UNTIL = os.clock() + (secs or 4)
end

local function clearStatusIfExpired()
    if STATUS_MSG and os.clock() > STATUS_UNTIL then
        STATUS_MSG = nil
    end
end

local function drawHeader()
    local W = ({term.getSize()})[1]
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.yellow)
    term.setCursorPos(1, 1)
    term.clearLine()
    local title = "VRB POS"
    term.write(title)
    if SHOP_LABEL then
        local s = SHOP_LABEL:sub(1, W - #title - 2)
        term.setCursorPos(W - #s + 1, 1)
        term.write(s)
    end
end

local function drawTabBar()
    local W = ({term.getSize()})[1]
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.setCursorPos(1, 2)
    term.clearLine()
    if CURRENT_TAB and TABS[CURRENT_TAB] then
        local tab = TABS[CURRENT_TAB]
        local label = "Tab: " .. tab.owner:sub(1, 12)
        term.setCursorPos(1, 2)
        term.write(label)
        local total = fmtMoney(tabTotal(tab))
        term.setCursorPos(W - #total + 1, 2)
        term.write(total)
    else
        term.setCursorPos(1, 2)
        term.write("(no tab open -- type 'tab <name>')")
    end
end

local function drawLines()
    local W, H = term.getSize()
    -- Lines area: rows 3 to H-3
    local first_row = 3
    local last_row = H - 3
    local rows_avail = last_row - first_row + 1
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    for r = first_row, last_row do
        term.setCursorPos(1, r); term.clearLine()
    end
    if not CURRENT_TAB or not TABS[CURRENT_TAB] then return end
    local lines = TABS[CURRENT_TAB].lines or {}
    local total_lines = #lines
    if total_lines == 0 then
        term.setCursorPos(2, first_row)
        term.setTextColor(colors.lightGray)
        term.write("(empty)")
        return
    end
    -- Clamp scroll
    if SCROLL > total_lines - rows_avail then
        SCROLL = math.max(0, total_lines - rows_avail)
    end
    if SCROLL < 0 then SCROLL = 0 end
    local visible_count = math.min(rows_avail, total_lines - SCROLL)
    for i = 1, visible_count do
        local idx = i + SCROLL
        local ln = lines[idx]
        if ln then
            local r = first_row + (i - 1)
            term.setCursorPos(1, r)
            local qty = ln.qty or 1
            local name = ln.name or "?"
            local subtotal = qty * (ln.price or 0)
            local left
            if qty > 1 then
                left = " " .. name .. " x" .. qty
            else
                left = " " .. name
            end
            local price_text = fmtMoney(subtotal)
            local max_left = W - #price_text - 1
            if #left > max_left then left = left:sub(1, max_left - 1) .. ">" end
            term.setTextColor(colors.white)
            term.write(left)
            term.setCursorPos(W - #price_text + 1, r)
            term.setTextColor(colors.yellow)
            term.write(price_text)
        end
    end
    -- Scroll indicator
    if SCROLL > 0 then
        term.setCursorPos(W, first_row)
        term.setTextColor(colors.lightGray)
        term.write("^")
    end
    if SCROLL + rows_avail < total_lines then
        term.setCursorPos(W, last_row)
        term.setTextColor(colors.lightGray)
        term.write("v")
    end
end

local function drawHints()
    local W, H = term.getSize()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(1, H - 2)
    term.clearLine()
    if STATUS_MSG and os.clock() <= STATUS_UNTIL then
        term.setTextColor(STATUS_COLOR)
        local s = STATUS_MSG:sub(1, W)
        term.setCursorPos(1, H - 2)
        term.write(s)
    else
        term.write(" ?=help  c=close  q=quit")
    end
end

local function drawInput(buf)
    local W, H = term.getSize()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, H - 1); term.clearLine()
    term.setCursorPos(1, H); term.clearLine()
    term.setCursorPos(1, H)
    term.setTextColor(colors.yellow)
    term.write("> ")
    term.setTextColor(colors.white)
    term.write(buf or "")
end

local function drawAll(input_buf)
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()
    drawTabBar()
    drawLines()
    drawHints()
    drawInput(input_buf or "")
    -- Cursor at end of input line
    local W, H = term.getSize()
    term.setCursorPos(3 + #(input_buf or ""), H)
    term.setCursorBlink(true)
end

-- ============================================================================
-- COMMAND PARSER
-- ============================================================================
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

-- Parse "add burger 8" / "add Diamond Block 50" / "+ fries 4" / "8 burger"
-- Last numeric token is the price (in dollars). Everything before is name.
-- Numeric tokens may be int or decimal.
local function parseAdd(rest)
    rest = trim(rest)
    if rest == "" then return nil, "Need: <name> <price>" end
    -- Split into words
    local words = {}
    for w in rest:gmatch("%S+") do table.insert(words, w) end
    if #words < 2 then return nil, "Need: <name> <price>" end
    -- If first word is a number, "price-first" form: "8 burger"
    -- gsub returns (string, count); wrap in parens so tonumber only sees
    -- the string (otherwise the count gets passed as the base argument).
    local first_num = tonumber((words[1]:gsub("^%$", "")))
    local last_num = tonumber((words[#words]:gsub("^%$", "")))
    local price_dollars, name
    if last_num and last_num > 0 then
        price_dollars = last_num
        name = table.concat(words, " ", 1, #words - 1)
    elseif first_num and first_num > 0 then
        price_dollars = first_num
        name = table.concat(words, " ", 2)
    else
        return nil, "Need a positive price"
    end
    if not name or #name == 0 then return nil, "Need a name" end
    if price_dollars > 1e6 then return nil, "Price too large" end
    local price_cents = math.floor(price_dollars * 100 + 0.5)
    return name, price_cents
end

local function cmdHelp()
    local lines = {
        "tab <name>   switch/create",
        "add <n> <p>  add line",
        "+ <n> <p>    same as add",
        "void <name>  remove 1",
        "tabs         list all",
        "close        bill customer",
        "delete <n>   drop tab",
        "scroll u/d   page lines",
        "out          sign out",
        "q | quit     exit",
    }
    term.setBackgroundColor(colors.black); term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow); print("VRB POS commands"); print("")
    term.setTextColor(colors.white)
    for _, l in ipairs(lines) do print(l) end
    print("")
    term.setTextColor(colors.lightGray)
    print("(any key returns)")
    os.pullEvent("key")
end

local function cmdTabs()
    term.setBackgroundColor(colors.black); term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow); print("Open tabs:"); print("")
    term.setTextColor(colors.white)
    local count = 0
    for k, t in pairs(TABS) do
        count = count + 1
        local total = tabTotal(t)
        local cur = (k == CURRENT_TAB) and "* " or "  "
        print(string.format("%s%-12s %s", cur,
            t.owner:sub(1, 12), fmtMoney(total)))
    end
    if count == 0 then
        term.setTextColor(colors.lightGray)
        print("(no tabs)")
    end
    print("")
    term.setTextColor(colors.lightGray)
    print("(any key returns)")
    os.pullEvent("key")
end

-- Returns true if the input was a known command.
-- Returns false (and sets a status) if not.
local function dispatchCommand(line)
    line = trim(line)
    if line == "" then return true end
    local lower = line:lower()
    -- Quick aliases
    if lower == "?" or lower == "help" then
        cmdHelp(); return true
    end
    if lower == "q" or lower == "quit" or lower == "exit" then
        return "quit"
    end
    if lower == "out" or lower == "signout" then
        if SESSION then pcall(call, "signout", {session=SESSION}) end
        clearSession()
        setStatus("Signed out", colors.orange, 3)
        return "signed_out"
    end
    if lower == "tabs" then
        cmdTabs(); return true
    end
    -- Multi-word commands
    local cmd, rest = line:match("^(%S+)%s*(.*)$")
    cmd = cmd:lower()
    if cmd == "tab" then
        local name = trim(rest)
        if #name < 2 then
            setStatus("Need: tab <name>", colors.red); return true
        end
        local tab, key = findOrCreateTab(name)
        CURRENT_TAB = key
        SCROLL = 0
        saveTabs()
        setStatus("Tab: " .. tab.owner, colors.lime, 2)
        return true
    end
    if cmd == "add" or cmd == "+" then
        if not CURRENT_TAB or not TABS[CURRENT_TAB] then
            setStatus("Open a tab first", colors.red); return true
        end
        local name, price = parseAdd(rest)
        if not name then
            setStatus(price or "Bad input", colors.red); return true
        end
        addToTab(TABS[CURRENT_TAB], name, price)
        saveTabs()
        setStatus(name .. " " .. fmtMoney(price), colors.lime, 2)
        return true
    end
    if cmd == "void" or cmd == "remove" or cmd == "rm" or cmd == "-" then
        if not CURRENT_TAB or not TABS[CURRENT_TAB] then
            setStatus("Open a tab first", colors.red); return true
        end
        local name = trim(rest)
        if name == "" then
            setStatus("Need: void <name>", colors.red); return true
        end
        if voidFromTab(TABS[CURRENT_TAB], name) then
            saveTabs()
            setStatus("Removed " .. name, colors.lime, 2)
        else
            setStatus("Not in tab: " .. name, colors.red)
        end
        return true
    end
    if cmd == "delete" or cmd == "del" then
        local key = trim(rest):lower()
        if key == "" then key = CURRENT_TAB end
        if not key or not TABS[key] then
            setStatus("Not a tab", colors.red); return true
        end
        local owner = TABS[key].owner
        TABS[key] = nil
        if CURRENT_TAB == key then CURRENT_TAB = nil end
        saveTabs()
        setStatus("Dropped " .. owner, colors.orange, 2)
        return true
    end
    if cmd == "close" or cmd == "bill" then
        if not CURRENT_TAB or not TABS[CURRENT_TAB] then
            setStatus("No tab to close", colors.red); return true
        end
        local tab = TABS[CURRENT_TAB]
        local total = tabTotal(tab)
        if total <= 0 then
            setStatus("Tab is empty", colors.red); return true
        end
        if not SESSION then
            setStatus("Sign in first", colors.red); return true
        end
        -- Build memo: "burger x1, fries x2, cola x1"
        local parts = {}
        for _, ln in ipairs(tab.lines) do
            local qty = ln.qty or 1
            if qty > 1 then
                table.insert(parts, ln.name .. " x" .. qty)
            else
                table.insert(parts, ln.name)
            end
        end
        local memo = table.concat(parts, ", "):sub(1, 60)
        -- Confirm prompt
        term.setBackgroundColor(colors.black); term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.yellow)
        print("BILL CUSTOMER")
        print("")
        term.setTextColor(colors.white)
        print("Customer: " .. tab.owner)
        print("Total:    " .. fmtMoney(total))
        print("Items:    " .. #tab.lines)
        print("")
        term.setTextColor(colors.lightGray)
        print("Memo: " .. memo:sub(1, 22))
        print("")
        term.setTextColor(colors.white)
        write("Send bill? (y/N): ")
        local ans = read()
        if not ans or ans:lower() ~= "y" and ans:lower() ~= "yes" then
            setStatus("Cancelled", colors.orange, 2)
            return true
        end
        local r = call("request_payment", {
            session=SESSION,
            target_owner=tab.owner,
            amount=total,
            memo=memo,
        })
        if r.ok then
            -- Clear the tab
            TABS[CURRENT_TAB] = nil
            CURRENT_TAB = nil
            saveTabs()
            setStatus("Bill sent: " .. (r.request_id or "?"), colors.lime, 4)
        else
            setStatus("Failed: " .. (r.err or "?"), colors.red, 4)
        end
        return true
    end
    if cmd == "scroll" then
        local dir = trim(rest):lower()
        if dir == "u" or dir == "up" then SCROLL = math.max(0, SCROLL - 5)
        elseif dir == "d" or dir == "down" then SCROLL = SCROLL + 5
        end
        return true
    end
    setStatus("Unknown: " .. cmd .. " (?=help)", colors.red)
    return true
end

-- ============================================================================
-- INPUT LOOP
-- ============================================================================
local function inputLoop()
    local buf = ""
    while true do
        clearStatusIfExpired()
        drawAll(buf)
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "char" then
            if #buf < 80 then buf = buf .. p1 end
        elseif ev == "key" then
            if p1 == keys.enter then
                local cmd = buf
                buf = ""
                local r = dispatchCommand(cmd)
                if r == "quit" then return "quit" end
                if r == "signed_out" then return "signed_out" end
            elseif p1 == keys.backspace then
                buf = buf:sub(1, -2)
            elseif p1 == keys.up then
                -- Scroll lines
                SCROLL = math.max(0, SCROLL - 1)
            elseif p1 == keys.down then
                SCROLL = SCROLL + 1
            elseif p1 == keys.pageUp then
                SCROLL = math.max(0, SCROLL - 5)
            elseif p1 == keys.pageDown then
                SCROLL = SCROLL + 5
            end
        elseif ev == "mouse_scroll" then
            local dir = p1   -- -1 up, 1 down
            if dir < 0 then SCROLL = math.max(0, SCROLL - 1)
            else SCROLL = SCROLL + 1 end
        elseif ev == "term_resize" then
            -- redraw on next loop
        end
    end
end

-- ============================================================================
-- MAIN
-- ============================================================================
local function main()
    ensureDir(CFG.DATA_DIR)
    ensureDir(CFG.KEY_DIR)

    -- Modem
    if not openModem() then
        term.clear(); term.setCursorPos(1, 1)
        print("VRB POS: no modem found.")
        print("Attach a wireless or ender")
        print("modem and reboot.")
        while true do os.pullEvent() end
    end

    -- Secret
    if not loadSecret() then
        if not pairWithAdmin() then
            term.clear(); term.setCursorPos(1, 1)
            print("Setup incomplete.")
            print("Reboot to retry.")
            while true do os.pullEvent() end
        end
        loadSecret()
    end

    -- Shop label
    loadShop()
    loadTabs()

    -- Sign in (or restore)
    while true do
        if not loadSession() then
            if not shopkeeperSignIn() then
                -- retry
            end
        else
            -- Probe session is still valid
            local probe = call("balance", {session=SESSION})
            if not probe.ok then
                clearSession()
            else
                break
            end
        end
        if SESSION then break end
    end

    -- Main loop
    while true do
        local r = inputLoop()
        if r == "quit" then
            term.clear(); term.setCursorPos(1, 1)
            print("Goodbye.")
            return
        elseif r == "signed_out" then
            -- Re-signin
            while not loadSession() do
                if not shopkeeperSignIn() then sleep(1) end
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.clear()
    term.setCursorPos(1, 1)
    print("CRASHED:")
    print(tostring(err):sub(1, 200))
    print("")
    print("Press any key to reboot.")
    os.pullEvent("key")
    os.reboot()
end