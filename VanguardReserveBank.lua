-- VANGUARD RESERVE BANK -- single-file CC:Tweaked banking system.
local ROLE = ...
local VERSION = "9.0.0"
local CFG = {
PROTOCOL = "VRB_V2",
HOSTNAME_SERVER = "vrb.reserve",
DATA_DIR = "/.vrb",
KEY_DIR = "/.vrb/keys",
MC_MONTH_SEC = 30 * 24 * 3600,
INTEREST_TICK_SEC = 3600,
SESSION_TTL_SEC = 15 * 60,
PIN_LOCKOUT_FAILS = 5,
PIN_LOCKOUT_SEC = 15 * 60,
RPC_WINDOW_SEC = 30,
RPC_TIMEOUT = 5,
RPC_RETRIES = 2,
POLICY_DEFAULTS = {
sav_mpr = 0.02,
chk_mpr = 0.003,
cd_mpr_30 = 0.03,
cd_mpr_90 = 0.035,
cd_mpr_180 = 0.04,
loan_mpr = 0.05,
frozen = {},
locked_pins = {},
min_loan_col = 0.25,
issue_enabled = true,
income_tax_brackets = {
{above=0, rate=0.00},
{above=50000 * 100, rate=0.00},
{above=100000 * 100, rate=0.02},
{above=200000 * 100, rate=0.04},
{above=400000 * 100, rate=0.05},
{above=750000 * 100, rate=0.06},
{above=1500000 * 100, rate=0.07},
{above=3000000 * 100, rate=0.08},
{above=6000000 * 100, rate=0.09},
{above=10000000 * 100, rate=0.10},
},
tx_tax_rate = 0.05,
tx_tax = 0.0,
tax_brackets = {},
ubi_enabled = false,
ubi_weekly = 5000,
ubi_active_within_sec = 7 * 24 * 3600,
supply_target_enabled = false,
supply_target_low = 0,
supply_target_high = 1e12,
item_backing_enabled = true,
item_backing_map = {
["minecraft:diamond"] = 6400,
["minecraft:netherite_ingot"]= 76800,
["minecraft:gold_ingot"] = 800,
["minecraft:emerald"] = 1600,
},
multisig_threshold = 100000,
},
FUND_OWNER = "VanguardFed",
FUND_ACCOUNT_ID = "FUND-000000",
NOTE_DENOMINATIONS = {1, 5, 10, 50, 100, 500, 1000},
PROGRESS_CATALOG_DEFAULT = {
{id="first_diamond", label="First diamond mined", bounty=500, once=true },
{id="first_nether", label="First Nether entry", bounty=300, once=true },
{id="first_end", label="First End entry", bounty=1500, once=true },
{id="kill_dragon", label="Killed the Ender Dragon", bounty=10000, once=true },
{id="kill_wither", label="Killed a Wither", bounty=5000, once=false},
{id="days_survived_7", label="Survived 7 in-game days", bounty=200, once=true },
{id="days_survived_30", label="Survived 30 in-game days", bounty=1000, once=true },
{id="base_built", label="Registered a base with Vanguard", bounty=2000, once=true },
{id="winery_visit", label="Visited the Vanguard Winery", bounty=50, once=true },
{id="faction_founded", label="Founded a chartered faction", bounty=5000, once=true },
{id="pvp_tourney_win", label="Won a Vanguard PvP tournament", bounty=10000, once=false},
{id="public_works", label="Completed a Public Works order", bounty=0, once=false},
},
EARNINGS_ENABLED = true,
EARNINGS_DAILY_TICK_HOUR = 4,
EARNINGS_MIN_SESSION_SEC = 20 * 60,
EARNINGS_PVP_ENABLED = false,
EARNINGS_PVP_COOLDOWN_SEC = 6 * 3600,
EARNINGS_SURVIVAL_WAGE = 800,
EARNINGS_COMBAT_TIER = {
["minecraft:zombie"] = 1,
["minecraft:skeleton"] = 1,
["minecraft:spider"] = 1,
["minecraft:creeper"] = 1,
["minecraft:drowned"] = 1,
["minecraft:husk"] = 1,
["minecraft:stray"] = 1,
["minecraft:cave_spider"] = 1,
["minecraft:zombie_villager"]= 1,
["minecraft:silverfish"] = 1,
["minecraft:slime"] = 1,
["minecraft:magma_cube"] = 1,
["minecraft:witch"] = 3,
["minecraft:pillager"] = 3,
["minecraft:vindicator"] = 3,
["minecraft:ravager"] = 3,
["minecraft:blaze"] = 3,
["minecraft:ghast"] = 3,
["minecraft:piglin_brute"] = 3,
["minecraft:hoglin"] = 3,
["minecraft:zoglin"] = 3,
["minecraft:guardian"] = 3,
["minecraft:warden"] = 8,
["minecraft:elder_guardian"] = 8,
["minecraft:evoker"] = 8,
["minecraft:shulker"] = 8,
},
EARNINGS_COMBAT_UNIT_CENTS = 50,
EARNINGS_COMBAT_DAILY_CAP = 15000,
EARNINGS_COMBAT_VELOCITY_LIMIT= 500,
EARNINGS_BOSS_BOUNTY = {
["minecraft:ender_dragon"] = 50000,
["minecraft:wither"] = 25000,
},
EARNINGS_EXPLORE_TIERS = {
{blocks = 5000, pay = 1000},
{blocks = 15000, pay = 2500},
{blocks = 40000, pay = 5000},
{blocks = 80000, pay = 8000},
},
EARNINGS_EXPLORE_STATS = {
"minecraft.custom:minecraft.walk_one_cm",
"minecraft.custom:minecraft.sprint_one_cm",
"minecraft.custom:minecraft.swim_one_cm",
"minecraft.custom:minecraft.walk_under_water_one_cm",
"minecraft.custom:minecraft.walk_on_water_one_cm",
"minecraft.custom:minecraft.climb_one_cm",
"minecraft.custom:minecraft.fly_one_cm",
"minecraft.custom:minecraft.boat_one_cm",
"minecraft.custom:minecraft.minecart_one_cm",
"minecraft.custom:minecraft.horse_one_cm",
"minecraft.custom:minecraft.pig_one_cm",
"minecraft.custom:minecraft.strider_one_cm",
},
EARNINGS_EXPLORE_NETHER_END_BONUS = 0.5,
EARNINGS_BUILD_TIERS = {
{count = 100, pay = 1500},
{count = 500, pay = 4000},
{count = 2000, pay = 8000},
{count = 5000, pay = 15000},
},
EARNINGS_BUILD_STREAK_PAY = 20000,
EARNINGS_BUILD_MATERIALS = {
["minecraft:cobblestone"]=1.0, ["minecraft:stone"]=1.0, ["minecraft:stone_bricks"]=1.0,
["minecraft:oak_planks"]=1.0, ["minecraft:spruce_planks"]=1.0, ["minecraft:birch_planks"]=1.0,
["minecraft:jungle_planks"]=1.0, ["minecraft:acacia_planks"]=1.0, ["minecraft:dark_oak_planks"]=1.0,
["minecraft:oak_log"]=1.0, ["minecraft:spruce_log"]=1.0, ["minecraft:birch_log"]=1.0,
["minecraft:bricks"]=1.0, ["minecraft:glass"]=1.0, ["minecraft:smooth_stone"]=1.0,
["minecraft:polished_andesite"]=1.0, ["minecraft:polished_diorite"]=1.0,
["minecraft:polished_granite"]=1.0, ["minecraft:quartz_block"]=1.0,
["minecraft:nether_bricks"]=1.0, ["minecraft:end_stone_bricks"]=1.0,
["minecraft:deepslate_bricks"]=1.0, ["minecraft:mud_bricks"]=1.0,
["minecraft:prismarine"]=1.0, ["minecraft:copper_block"]=1.0,
["minecraft:dirt"]=0.25, ["minecraft:sand"]=0.25, ["minecraft:gravel"]=0.25,
["minecraft:cobbled_deepslate"]=0.25, ["minecraft:netherrack"]=0.25,
},
EARNINGS_DANGER_TIERS = {
{damage = 40, pay = 800},
{damage = 100, pay = 2000},
{damage = 200, pay = 4000},
{damage = 400, pay = 6500},
},
EARNINGS_STREAK_TIERS = {
{day = 0, mult = 1.00, label = "New"},
{day = 7, mult = 1.25, label = "Week"},
{day = 30, mult = 1.50, label = "Month"},
{day = 100, mult = 2.00, label = "Dedicated"},
{day = 365, mult = 2.50, label = "Veteran"},
},
EARNINGS_STREAK_GRACE_DAYS = 2,
EARNINGS_STREAK_DROP_TIERS = 1,
EARNINGS_INSURANCE_COST = 50000,
EARNINGS_INSURANCE_DURATION = 30 * 86400,
NOTIF_CHANNELS = {
{"daily", false, "Daily payout summary", "+/- after each daily tick"},
{"streak", false, "Streak warnings", "When your streak is about to lapse"},
{"death", false, "Death penalty notice", "When dying drops your streak"},
{"multisig", false, "Faction approvals", "When a multisig proposal needs you"},
{"insurance",false, "Insurance reminders", "When your policy is about to expire"},
},
NOTIF_OUTBOX_MAX = 200,
NOTIF_STREAK_WARN_HOURS = 12,
NOTIF_INSURANCE_WARN_DAYS = 3,
EARNINGS_HISTORY_DEPTH = 30,
VANGUARD_ENABLED = true,
VANGUARD_MAX_MEMBERS = 10,
VANGUARD_MIN_SESSION_SEC = 20 * 60,
VANGUARD_RANKS = {
{id="E1", grade="E-1", group="Enlisted",
label="Private", weekly_cents=120000},
{id="E2", grade="E-2", group="Enlisted",
label="Private First Class", weekly_cents=140000},
{id="E3", grade="E-3", group="Enlisted",
label="Lance Corporal", weekly_cents=165000},
{id="E4", grade="E-4", group="Enlisted",
label="Corporal", weekly_cents=195000},
{id="E5", grade="E-5", group="Enlisted",
label="Sergeant", weekly_cents=230000},
{id="E6", grade="E-6", group="Enlisted",
label="Staff Sergeant", weekly_cents=275000},
{id="E7", grade="E-7", group="Enlisted",
label="Gunnery Sergeant", weekly_cents=330000},
{id="E8a", grade="E-8", group="Enlisted",
label="Master Sergeant", weekly_cents=400000},
{id="E8b", grade="E-8", group="Enlisted",
label="First Sergeant", weekly_cents=400000},
{id="E9a", grade="E-9", group="Enlisted",
label="Master Gunnery Sergeant", weekly_cents=480000},
{id="E9b", grade="E-9", group="Enlisted",
label="Sergeant Major", weekly_cents=500000},
{id="E9c", grade="E-9", group="Enlisted",
label="Sergeant Major of the Marine Corps", weekly_cents=580000},
{id="W1", grade="W-1", group="Warrant",
label="Warrant Officer", weekly_cents=450000},
{id="W2", grade="W-2", group="Warrant",
label="Chief Warrant Officer 2", weekly_cents=550000},
{id="W3", grade="W-3", group="Warrant",
label="Chief Warrant Officer 3", weekly_cents=680000},
{id="W4", grade="W-4", group="Warrant",
label="Chief Warrant Officer 4", weekly_cents=840000},
{id="W5", grade="W-5", group="Warrant",
label="Chief Warrant Officer 5", weekly_cents=1020000},
{id="O1", grade="O-1", group="Officer",
label="Second Lieutenant", weekly_cents=1100000},
{id="O2", grade="O-2", group="Officer",
label="First Lieutenant", weekly_cents=1350000},
{id="O3", grade="O-3", group="Officer",
label="Captain", weekly_cents=1650000},
{id="O4", grade="O-4", group="Officer",
label="Major", weekly_cents=2050000},
{id="O5", grade="O-5", group="Officer",
label="Lieutenant Colonel", weekly_cents=2550000},
{id="O6", grade="O-6", group="Officer",
label="Colonel", weekly_cents=3150000},
{id="O7", grade="O-7", group="Officer",
label="Brigadier General", weekly_cents=4000000},
{id="O8", grade="O-8", group="Officer",
label="Major General", weekly_cents=5000000},
{id="O9", grade="O-9", group="Officer",
label="Lieutenant General", weekly_cents=6250000},
{id="O10", grade="O-10", group="Officer",
label="General", weekly_cents=8000000},
},
}
local EARNINGS_CFG_OK = true
local T = {
bg=colors.black, panel=colors.gray, panelAlt=colors.lightGray,
ink=colors.white, muted=colors.lightGray, accent=colors.yellow,
credit=colors.lime, debit=colors.red, warn=colors.orange,
rule=colors.gray, btn=colors.yellow, btnInk=colors.black,
btnAlt=colors.lightGray, btnAltInk=colors.black,
}
local crypto = {}
local band, bor, bxor = bit32.band, bit32.bor, bit32.bxor
local lshift, rshift = bit32.lshift, bit32.rshift
local rrotate = bit32.rrotate
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
local low = bits % 4294967296
pad = pad .. string.char(
band(rshift(high, 24), 0xff), band(rshift(high, 16), 0xff),
band(rshift(high, 8), 0xff), band(high, 0xff),
band(rshift(low, 24), 0xff), band(rshift(low, 16), 0xff),
band(rshift(low, 8), 0xff), band(low, 0xff))
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
h[1] = (h[1] + a) % 4294967296
h[2] = (h[2] + b) % 4294967296
h[3] = (h[3] + c) % 4294967296
h[4] = (h[4] + d) % 4294967296
h[5] = (h[5] + e) % 4294967296
h[6] = (h[6] + f) % 4294967296
h[7] = (h[7] + g) % 4294967296
h[8] = (h[8] + hh) % 4294967296
end
function crypto.sha256(msg)
local h = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}
local padded = shaPad(msg)
for off = 0, #padded - 1, 64 do
shaBlock(h, padded, off)
end
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
function crypto.hash(s) return crypto.sha256(s) end
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
kip = table.concat(kip)
kop = table.concat(kop)
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
local _rand_state = nil
local _rand_counter = 0
local function _seedRand()
local epoch_us = os.epoch and os.epoch("utc") or (os.time() * 1000)
local cid = os.getComputerID and os.getComputerID() or 0
local jitter = tostring(os.clock and os.clock() or 0)
local seed_str = tostring(epoch_us) .. ":" .. tostring(cid) .. ":" .. jitter
local hex = crypto.sha256(seed_str)
local seed = tonumber(hex:sub(1, 8), 16) or 1
math.randomseed(seed)
_rand_state = sha256_raw(hex)
_rand_counter = 0
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
function crypto.selfTest()
local expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
local got = crypto.sha256("abc")
if got ~= expected then
error("SHA-256 self-test failed: got "..got.." expected "..expected)
end
local k = string.rep(string.char(0x0b), 20)
local hmac_got = crypto.hmac(k, "Hi There")
local hmac_expected = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
if hmac_got ~= hmac_expected then
error("HMAC-SHA256 self-test failed: got "..hmac_got
.." expected "..hmac_expected)
end
return true
end
local function seal(key, payload)
local nonce = crypto.random_id()
local ts = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
local body = textutils.serialize(payload)
local cipher = crypto.stream_xor(key, nonce, body)
local mac = crypto.hmac(key, nonce .. tostring(ts) .. cipher)
return {v=2, nonce=nonce, ts=ts, cipher=cipher, mac=mac}
end
local function unseal(key, envelope, window, seen_nonces)
if type(envelope) ~= "table" or envelope.v ~= 2 then return nil, "Bad envelope" end
local now_ts = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
if math.abs(now_ts - (envelope.ts or 0)) > (window or CFG.RPC_WINDOW_SEC) then
return nil, "Stale packet"
end
if seen_nonces and seen_nonces[envelope.nonce] then return nil, "Replay detected" end
local expect = crypto.hmac(key, envelope.nonce .. tostring(envelope.ts) .. envelope.cipher)
if expect ~= envelope.mac then return nil, "Bad MAC" end
local body = crypto.stream_xor(key, envelope.nonce, envelope.cipher)
local ok, payload = pcall(textutils.unserialize, body)
if not ok or type(payload) ~= "table" then return nil, "Bad payload" end
if seen_nonces then seen_nonces[envelope.nonce] = now_ts end
return payload
end
local function now() return os.epoch and math.floor(os.epoch("utc") / 1000) or os.time() end
local function fmtMoney(c)
c = math.floor(c or 0)
local sign = c < 0 and "-" or ""
c = math.abs(c)
local whole = math.floor(c / 100); local cents = c % 100
local s = tostring(whole); local out = ""
while #s > 3 do out = "," .. s:sub(-3) .. out; s = s:sub(1, -4) end
out = s .. out
return string.format("%s$%s.%02d", sign, out, cents)
end
local function ensureDir(p) if not fs.exists(p) then fs.makeDir(p) end end
local function writeAtomic(path, data)
local ok_dir, dir_err = pcall(ensureDir, fs.getDir(path))
if not ok_dir then return false, "cannot create dir: "..tostring(dir_err) end
local tmp = path .. ".tmp"
local f, oerr = fs.open(tmp, "w")
if not f then return false, "open failed: "..tostring(oerr or "unknown") end
local ok_w, werr = pcall(function() f.write(data); f.close() end)
if not ok_w then
pcall(function() if f then f.close() end end)
if fs.exists(tmp) then pcall(fs.delete, tmp) end
return false, "write failed: "..tostring(werr)
end
if fs.exists(path) then
local ok_d = pcall(fs.delete, path)
if not ok_d then return false, "delete-old failed" end
end
local ok_m, merr = pcall(fs.move, tmp, path)
if not ok_m then return false, "move failed: "..tostring(merr) end
return true
end
local function writeJSON(path, data)
local ok_s, ser = pcall(textutils.serialize, data)
if not ok_s then return false, "serialize failed: "..tostring(ser) end
return writeAtomic(path, ser)
end
local DIAG = {last_db_error = nil, last_persist_error = nil,
persist_failures = 0, ledger_write_failures = 0,
rejected_packets = 0, server_errors = 0}
local function readJSON(path, default)
if not fs.exists(path) then return default end
local f, oerr = fs.open(path, "r")
if not f then
DIAG.last_db_error = "open: "..tostring(oerr or "unknown")
return default
end
local ok_r, s = pcall(function() local x = f.readAll(); f.close(); return x end)
if not ok_r then
DIAG.last_db_error = "read: "..tostring(s)
pcall(function() f.close() end)
return default
end
local ok, v = pcall(textutils.unserialize, s)
if not ok or type(v) ~= "table" then
DIAG.last_db_error = "parse: serialized data corrupted"
return default
end
DIAG.last_db_error = nil
return v
end
local function findPeripheral(kind)
for _, name in ipairs(peripheral.getNames()) do
if peripheral.getType(name) == kind then return peripheral.wrap(name), name end
end
return nil
end
local function findAdvancedMonitor()
for _, name in ipairs(peripheral.getNames()) do
if peripheral.getType(name) == "monitor" then
local p = peripheral.wrap(name)
if p and p.isColor and p.isColor() then
return p, name
end
end
end
return findPeripheral("monitor")
end
local function showStartupError(role, reason, detail, fix_lines)
term.setBackgroundColor(colors.black); term.setTextColor(colors.red); term.clear()
term.setCursorPos(1, 1)
print("============================================================")
print(string.format("  VRB %s  -  STARTUP FAILED", role:upper()))
print("============================================================")
term.setTextColor(colors.white)
print("")
print("Reason:")
term.setTextColor(colors.yellow)
print("  "..reason)
if detail then
term.setTextColor(colors.lightGray)
print("  detail: "..tostring(detail))
end
term.setTextColor(colors.white)
print("")
if fix_lines and #fix_lines > 0 then
term.setTextColor(colors.lime)
print("How to fix:")
term.setTextColor(colors.white)
for i, line in ipairs(fix_lines) do
print("  "..i..". "..line)
end
print("")
end
term.setTextColor(colors.lightGray)
print("Press R to retry (reboot), or any other key to exit.")
term.setTextColor(colors.white)
while true do
local _, key = os.pullEvent("key")
if key == keys.r then os.reboot() end
return
end
end
local function findAndOpenModem()
local candidates = {}
local names = peripheral.getNames()
for _, name in ipairs(names) do
if peripheral.getType(name) == "modem" then
local p = peripheral.wrap(name)
local is_wireless = p and p.isWireless and p.isWireless()
if is_wireless then
table.insert(candidates, name)
end
end
end
if #candidates == 0 then
return nil, "no_wireless_modem"
end
for _, name in ipairs(candidates) do
local ok = pcall(function()
if not rednet.isOpen(name) then rednet.open(name) end
end)
if ok then return name end
end
return nil, "open_failed"
end
local function openModem()
local side, err = findAndOpenModem()
if not side then
if err == "no_wireless_modem" then
error("No wireless modem attached. Place an Ender Modem or "
.."Wireless Modem on top of this computer and right-click "
.."to enable it (red ring = active).", 2)
else
error("Modem found but couldn't open it. Try removing and "
.."replacing it, then reboot.", 2)
end
end
return side
end
local V = {}
function V.account_id(s)
if type(s) ~= "string" then return false end
return s:match("^ACC%-%d%d%d%d%d%d$") ~= nil
or s == "FUND-000000"
end
function V.loan_id(s) return type(s)=="string" and s:match("^LOAN%-%d%d%d%d%d%d$") ~= nil end
function V.cd_id(s) return type(s)=="string" and s:match("^CD%-%d%d%d%d%d%d$") ~= nil end
function V.pin(s) return type(s)=="string" and s:match("^%d%d%d%d$") ~= nil end
function V.username(s) return type(s)=="string" and #s>=2 and #s<=32 and s:match("^[A-Za-z0-9_]+$") ~= nil end
function V.amount(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=1e12 end
function V.days(n) return type(n)=="number" and n==math.floor(n) and n>=1 and n<=3650 end
function V.kind(s) return s == "checking" or s == "savings" end
function V.progress_id(s)return type(s)=="string" and #s<=48 and s:match("^[a-z0-9_]+$") ~= nil end
function V.short_text(s) return type(s)=="string" and #s<=200 end
function V.session(s) return type(s)=="string" and #s == 64 and s:match("^[0-9a-f]+$") ~= nil end
function V.faction_id(s) return type(s)=="string" and s:match("^FAC%-[A-Z0-9]+$") ~= nil end
function V.escrow_id(s) return type(s)=="string" and s:match("^ESC%-[a-f0-9]+$") ~= nil end
function V.shop_id(s) return type(s)=="string" and s:match("^SHP%-[A-Z0-9]+$") ~= nil end
function V.order_id(s) return type(s)=="string" and s:match("^WO%-[a-f0-9]+$") ~= nil end
function V.pending_id(s) return type(s)=="string" and s:match("^PND%-[a-f0-9]+$") ~= nil end
function V.recur_id(s) return type(s)=="string" and s:match("^REC%-[a-f0-9]+$") ~= nil end
function V.positive_int(n) return type(n)=="number" and n==math.floor(n) and n>0 end
function V.bool(b) return type(b)=="boolean" end
local function runServer()
local PATHS = {
db = fs.combine(CFG.DATA_DIR, "bank.db"),
ledger = fs.combine(CFG.DATA_DIR, "ledger.log"),
secret = fs.combine(CFG.KEY_DIR, "server.secret"),
admin_key = fs.combine(CFG.KEY_DIR, "admin.key"),
boot_log = fs.combine(CFG.DATA_DIR, "boot.log"),
backups = fs.combine(CFG.DATA_DIR, "backups"),
}
ensureDir(CFG.DATA_DIR); ensureDir(CFG.KEY_DIR); ensureDir(PATHS.backups)
local DISK_LIMITS = {
BACKUPS_KEEP = 3,
LEDGER_MAX_BYTES = 200 * 1024,
LEDGER_ARCHIVE_DAYS = 7,
ERRORS_MAX_BYTES = 50 * 1024,
FREE_SPACE_LOW_KB = 100,
FREE_SPACE_PANIC_KB = 30,
}
local function getFreeKB()
if fs.getFreeSpace then
local ok, n = pcall(fs.getFreeSpace, "/")
if ok and n then return math.floor(n / 1024) end
end
return nil
end
local function truncateLog(path, size_max)
if not fs.exists(path) then return end
local sz = fs.getSize(path) or 0
if sz <= size_max then return end
local f = fs.open(path, "r"); if not f then return end
local content = f.readAll(); f.close()
local cut = math.floor(#content / 2)
local tail = content:sub(cut)
local nl = tail:find("\n")
if nl then tail = tail:sub(nl + 1) end
local fw = fs.open(path, "w"); if not fw then return end
fw.write("# truncated by janitor at "..os.date("%Y-%m-%d %H:%M:%S").."\n")
fw.write(tail); fw.close()
end
local function rotateLedgerIfBig()
if not fs.exists(PATHS.ledger) then return false end
local sz = fs.getSize(PATHS.ledger) or 0
if sz <= DISK_LIMITS.LEDGER_MAX_BYTES then return false end
local stamp = os.date("%Y%m%d-%H%M%S")
local archive = PATHS.ledger .. ".archive-" .. stamp
local ok = pcall(fs.move, PATHS.ledger, archive)
return ok
end
local function pruneOldArchives()
if not fs.exists(CFG.DATA_DIR) then return 0 end
local now_t = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
local cutoff = now_t - DISK_LIMITS.LEDGER_ARCHIVE_DAYS * 86400
local deleted = 0
for _, name in ipairs(fs.list(CFG.DATA_DIR) or {}) do
local y, mo, d, h, mi, s = name:match(
"^ledger%.log%.archive%-(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)(%d%d)$")
if y then
local archive_t = os.time({
year=tonumber(y), month=tonumber(mo), day=tonumber(d),
hour=tonumber(h), min=tonumber(mi), sec=tonumber(s),
})
if archive_t and archive_t < cutoff then
if pcall(fs.delete, fs.combine(CFG.DATA_DIR, name)) then
deleted = deleted + 1
end
end
end
end
return deleted
end
local function emergencyCleanup()
if fs.exists(fs.combine(CFG.DATA_DIR, "errors.log")) then
pcall(fs.delete, fs.combine(CFG.DATA_DIR, "errors.log"))
end
if fs.exists(PATHS.backups) then
local snaps = {}
for _, n in ipairs(fs.list(PATHS.backups) or {}) do
if n:sub(1, 4) == "vrb-" then table.insert(snaps, n) end
end
table.sort(snaps)
while #snaps > 1 do
pcall(fs.delete, fs.combine(PATHS.backups,
table.remove(snaps, 1)))
end
end
for _, name in ipairs(fs.list(CFG.DATA_DIR) or {}) do
if name:match("^ledger%.log%.archive%-") then
pcall(fs.delete, fs.combine(CFG.DATA_DIR, name))
end
end
rotateLedgerIfBig()
end
local function rollingBackup()
local free_kb = getFreeKB()
if free_kb and free_kb < DISK_LIMITS.FREE_SPACE_LOW_KB then
DIAG.last_backup_skipped_reason = "low_disk_"..free_kb.."KB"
return
end
local stamp = os.date("%Y%m%d-%H%M%S")
local snap_dir = fs.combine(PATHS.backups, "vrb-"..stamp)
ensureDir(snap_dir)
if fs.exists(PATHS.db) then
pcall(fs.copy, PATHS.db, fs.combine(snap_dir, "bank.db"))
end
if fs.exists(PATHS.ledger) then
pcall(fs.copy, PATHS.ledger, fs.combine(snap_dir, "ledger.log"))
end
local snaps = {}
for _, n in ipairs(fs.list(PATHS.backups) or {}) do
if n:sub(1, 4) == "vrb-" then table.insert(snaps, n) end
end
table.sort(snaps)
while #snaps > DISK_LIMITS.BACKUPS_KEEP do
local old = table.remove(snaps, 1)
pcall(fs.delete, fs.combine(PATHS.backups, old))
end
end
local function janitorSweep()
truncateLog(fs.combine(CFG.DATA_DIR, "errors.log"),
DISK_LIMITS.ERRORS_MAX_BYTES)
rotateLedgerIfBig()
pruneOldArchives()
if fs.exists(PATHS.backups) then
local snaps = {}
for _, n in ipairs(fs.list(PATHS.backups) or {}) do
if n:sub(1, 4) == "vrb-" then table.insert(snaps, n) end
end
table.sort(snaps)
while #snaps > DISK_LIMITS.BACKUPS_KEEP do
pcall(fs.delete, fs.combine(PATHS.backups,
table.remove(snaps, 1)))
end
end
end
local function loadOrCreateKey(path)
if fs.exists(path) then
local f = fs.open(path, "r")
if f then
local s = f.readAll(); f.close()
if s and #s >= 32 then return s end
end
end
local s = crypto.random_bytes(32); writeAtomic(path, s); return s
end
local SERVER_SECRET = loadOrCreateKey(PATHS.secret)
local ADMIN_KEY = loadOrCreateKey(PATHS.admin_key)
local function isAdmin(p)
if type(p._admin_sig) ~= "string" or type(p._admin_nonce) ~= "string" then return false end
local expect = crypto.hmac(ADMIN_KEY, p._admin_nonce)
return expect == p._admin_sig
end
local DB = {
accounts={}, byOwner={}, loans={}, certs={}, cards={},
sessions={}, progress={}, work_orders={},
factions={},
escrows={},
shops={},
recurring={},
pending_tx={},
activity={},
last_ubi_run=0,
earnings_state={},
earnings_last={},
last_earnings_run=0,
earnings_enabled=true,
earnings_pvp_enabled=false,
earnings_history={},
earnings_subs={},
farm_flags={},
notif_state={},
notif_outbox={},
civic_jobs={},
last_mc_day_tick=0,
civic_requests={},
payment_requests={},
policy=nil, catalog=nil,
meta={money_supply=0, loans_out=0, tx_count=0, last_interest=now(),
ledger_head="0000000000000000", version=VERSION},
}
do
local saved = readJSON(PATHS.db, nil)
if saved then for k, v in pairs(saved) do DB[k] = v end end
DB.policy = DB.policy or {}
for k, v in pairs(CFG.POLICY_DEFAULTS) do
if DB.policy[k] == nil then DB.policy[k] = (type(v) == "table") and {} or v end
end
DB.catalog = DB.catalog or {}
if next(DB.catalog) == nil then
for _, item in ipairs(CFG.PROGRESS_CATALOG_DEFAULT) do
DB.catalog[item.id] = {label=item.label, bounty=item.bounty, once=item.once}
end
end
DB.civic_requests = DB.civic_requests or {}
DB.payment_requests = DB.payment_requests or {}
if not DB.accounts[CFG.FUND_ACCOUNT_ID] then
DB.accounts[CFG.FUND_ACCOUNT_ID] = {
id = CFG.FUND_ACCOUNT_ID,
owner = CFG.FUND_OWNER,
kind = "treasury",
balance = 0,
pin_hash = "TREASURY_NO_PIN",
created = now(),
history = {},
joint = {},
is_treasury = true,
}
local k = CFG.FUND_OWNER:lower()
DB.byOwner[k] = DB.byOwner[k] or {}
end
DB.meta.boot_time = now()
end
local seenNonces = {}
local function persist()
local ok, err = writeJSON(PATHS.db, DB)
if not ok then
DIAG.persist_failures = DIAG.persist_failures + 1
DIAG.last_persist_error = tostring(err)
DIAG.last_persist_failure_time = now()
term.setTextColor(T.debit)
print(string.format("[%s] PERSIST FAILED: %s",
os.date("%H:%M:%S"), tostring(err)))
term.setTextColor(T.ink)
local err_str = tostring(err or ""):lower()
local out_of_space = err_str:find("out of space")
or err_str:find("no space")
or err_str:find("disk full")
if out_of_space then
term.setTextColor(T.warn)
print(string.format("[%s] persist: running emergency cleanup",
os.date("%H:%M:%S")))
term.setTextColor(T.ink)
pcall(emergencyCleanup)
else
pcall(janitorSweep)
end
sleep(0.5)
local ok2, err2 = writeJSON(PATHS.db, DB)
if ok2 then
term.setTextColor(T.credit)
print(string.format("[%s] persist: retry succeeded",
os.date("%H:%M:%S")))
term.setTextColor(T.ink)
DIAG.last_persist_error = nil
else
pcall(appendLedger, {type="persist_failed",
err=tostring(err2):sub(1, 100)})
end
end
end
local function canon(v)
local t = type(v)
if t == "string" then
return string.format("%q", v)
elseif t == "number" then
if v == math.floor(v) and v > -1e15 and v < 1e15 then
return string.format("%d", v)
end
return string.format("%.17g", v)
elseif t == "boolean" then
return v and "true" or "false"
elseif t == "nil" then
return "nil"
elseif t == "table" then
local keys = {}
for k in pairs(v) do keys[#keys+1] = k end
table.sort(keys, function(a, b)
local ta, tb = type(a), type(b)
if ta == tb then return tostring(a) < tostring(b) end
return ta < tb
end)
local parts = {}
for i = 1, #keys do
local k = keys[i]
local ks
if type(k) == "string" and k:match("^[%a_][%w_]*$") then
ks = k
else
ks = "[" .. canon(k) .. "]"
end
parts[#parts+1] = ks .. "=" .. canon(v[k])
end
return "{" .. table.concat(parts, ",") .. "}"
end
return "nil"
end
local function serializeLine(t) return canon(t) end
local function appendLedger(entry)
entry.t = entry.t or now()
entry.prev_hash = DB.meta.ledger_head
entry.hash = crypto.hash(canon(entry))
DB.meta.ledger_head = entry.hash
local ok_dir = pcall(ensureDir, CFG.DATA_DIR)
if not ok_dir then
DIAG.ledger_write_failures = DIAG.ledger_write_failures + 1
DIAG.last_ledger_error = "ensureDir failed"
return entry
end
local f, oerr = fs.open(PATHS.ledger,
fs.exists(PATHS.ledger) and "a" or "w")
if not f then
DIAG.ledger_write_failures = DIAG.ledger_write_failures + 1
DIAG.last_ledger_error = "open: "..tostring(oerr or "unknown")
return entry
end
local ok_w, werr = pcall(function()
f.writeLine(canon(entry)); f.close()
end)
if not ok_w then
DIAG.ledger_write_failures = DIAG.ledger_write_failures + 1
DIAG.last_ledger_error = "write: "..tostring(werr)
pcall(function() f.close() end)
end
return entry
end
local function verifyLedgerChain()
if not fs.exists(PATHS.ledger) then return true, 0 end
local f = fs.open(PATHS.ledger, "r")
if not f then return false, "Ledger file unreadable" end
local prev = "0000000000000000"; local count = 0
while true do
local line = f.readLine()
if not line then break end
count = count + 1
local ok, entry = pcall(textutils.unserialize, line)
if not ok or type(entry) ~= "table" then
f.close(); return false, "Ledger entry "..count.." unreadable"
end
if entry.prev_hash ~= prev then
f.close(); return false, "Chain break at entry "..count
end
local given = entry.hash; entry.hash = nil
local expect = crypto.hash(canon(entry))
if expect ~= given then
f.close(); return false, "Hash mismatch at entry "..count
end
prev = given
end
f.close()
if prev ~= DB.meta.ledger_head then
return false, "Head mismatch: db="..DB.meta.ledger_head.." chain="..prev
end
return true, count
end
local function hashPin(pin, account_id)
return crypto.hmac(SERVER_SECRET, "pin:"..account_id..":"..pin)
end
local function isLocked(account_id)
local lock = DB.policy.locked_pins[account_id]
if not lock then return false end
if lock["until"] and now() < lock["until"] then return true, lock["until"] end
if lock["until"] and now() >= lock["until"] then
DB.policy.locked_pins[account_id] = nil; return false
end
return false
end
local function registerFail(account_id)
local lock = DB.policy.locked_pins[account_id] or {fails=0}
lock.fails = lock.fails + 1
if lock.fails >= CFG.PIN_LOCKOUT_FAILS then
lock["until"] = now() + CFG.PIN_LOCKOUT_SEC
appendLedger{type="lockout", account=account_id, until_ts=lock["until"]}
end
DB.policy.locked_pins[account_id] = lock
end
local function clearFails(id) DB.policy.locked_pins[id] = nil end
local function newAccountId()
while true do
local id = "ACC-" .. string.format("%06d", math.random(100000, 999999))
if not DB.accounts[id] then return id end
end
end
local function migratePairAccounts()
local migrated = 0
for owner_lower, ids in pairs(DB.byOwner) do
if owner_lower ~= CFG.FUND_OWNER:lower() then
local has_checking, has_savings
local checking_id, savings_id
for _, id in ipairs(ids) do
local a = DB.accounts[id]
if a and not a.is_treasury then
if a.kind == "checking" then
has_checking = a; checking_id = id
elseif a.kind == "savings" then
has_savings = a; savings_id = id
end
end
end
if has_checking and not has_savings then
local sid = newAccountId()
DB.accounts[sid] = {
id=sid, owner=has_checking.owner, kind="savings",
balance=0,
pin_hash=hashPin("0000", sid),
created=now(), history={}, joint={},
paired_checking=checking_id,
lots={},
}
has_checking.paired_savings = sid
table.insert(ids, sid)
appendLedger{type="migrate_pair", owner=has_checking.owner,
added=sid, paired_with=checking_id, kind="savings"}
migrated = migrated + 1
elseif has_savings and not has_checking then
local cid = newAccountId()
DB.accounts[cid] = {
id=cid, owner=has_savings.owner, kind="checking",
balance=0,
pin_hash=hashPin("0000", cid),
created=now(), history={}, joint={},
paired_savings=savings_id,
}
has_savings.paired_checking = cid
has_savings.lots = has_savings.lots or {}
table.insert(ids, cid)
appendLedger{type="migrate_pair", owner=has_savings.owner,
added=cid, paired_with=savings_id, kind="checking"}
migrated = migrated + 1
elseif has_checking and has_savings then
if not has_checking.paired_savings then
has_checking.paired_savings = savings_id
migrated = migrated + 1
end
if not has_savings.paired_checking then
has_savings.paired_checking = checking_id
migrated = migrated + 1
end
if not has_savings.lots then
has_savings.lots = {}
end
end
end
end
return migrated
end
local function createSession(account_id, branch)
local sid = crypto.random_id() .. crypto.random_id()
DB.sessions[sid] = {account_id=account_id, expires=now() + CFG.SESSION_TTL_SEC, branch=branch}
return sid
end
local function resolveSession(sid)
local s = DB.sessions[sid]
if not s then return nil, "No session" end
if now() >= s.expires then DB.sessions[sid] = nil; return nil, "Session expired" end
s.expires = now() + CFG.SESSION_TTL_SEC
return s
end
local function gcSessions()
for sid, s in pairs(DB.sessions) do
if now() >= s.expires then DB.sessions[sid] = nil end
end
end
local function accrueInterest()
local dt = now() - (DB.meta.last_interest or now())
if dt < CFG.INTEREST_TICK_SEC then return end
local months = dt / CFG.MC_MONTH_SEC
local function growth(mpr) return (1 + mpr) ^ months - 1 end
for id, a in pairs(DB.accounts) do
if not DB.policy.frozen[id] and a.balance > 0 then
local mpr = (a.kind == "savings") and DB.policy.sav_mpr or DB.policy.chk_mpr
if mpr > 0 then
local earned = math.floor(a.balance * growth(mpr))
if earned > 0 then
a.balance = a.balance + earned
DB.meta.money_supply = DB.meta.money_supply + earned
table.insert(a.history, {t=now(), type="interest", amount=earned, note="Monthly accrual"})
if #a.history > 200 then table.remove(a.history, 1) end
appendLedger{type="interest", account=id, amount=earned}
end
end
end
end
for id, l in pairs(DB.loans) do
if not l.closed then
local add = math.floor(l.balance * growth(DB.policy.loan_mpr))
if add > 0 then
l.balance = l.balance + add
l.interest_accrued = (l.interest_accrued or 0) + add
appendLedger{type="loan_interest", loan=id, amount=add}
end
end
end
DB.meta.last_interest = now()
persist()
end
local function markActivity(account_id)
DB.activity[account_id] = now()
end
local function computeTax(amount, from_id, to_id)
if from_id == CFG.FUND_ACCOUNT_ID or to_id == CFG.FUND_ACCOUNT_ID then
return 0, 0
end
local rate = DB.policy.tx_tax_rate or 0
return math.floor(amount * rate), rate
end
local function incomeTaxRate(annual_cents)
local brackets = DB.policy.income_tax_brackets or {}
local rate = 0
for _, b in ipairs(brackets) do
if (annual_cents or 0) >= (b.above or 0) then
rate = b.rate or 0
end
end
if rate > 0.10 then rate = 0.10 end
return rate
end
local function creditFund(cents, reason)
if not cents or cents <= 0 then return end
local fund = DB.accounts[CFG.FUND_ACCOUNT_ID]
if not fund then return end
fund.balance = fund.balance + cents
table.insert(fund.history, {
t=now(), type="tax_in", amount=cents, note=reason or "tax",
})
if #fund.history > 500 then table.remove(fund.history, 1) end
end
local function itemValue(item_name, count)
if not DB.policy.item_backing_enabled then return 0 end
local rate = DB.policy.item_backing_map[item_name]
if not rate then return 0 end
return math.floor(rate * (count or 0))
end
local function distributeUBI()
if not DB.policy.ubi_enabled then return end
if DB.policy.ubi_weekly <= 0 then return end
local week = 7 * 24 * 3600
if now() - (DB.last_ubi_run or 0) < week then return end
local cutoff = now() - (DB.policy.ubi_active_within_sec or week)
local paid = 0
local count = 0
for id, a in pairs(DB.accounts) do
local last = DB.activity[id] or a.created or 0
if not DB.policy.frozen[id] and last >= cutoff then
a.balance = a.balance + DB.policy.ubi_weekly
DB.meta.money_supply = DB.meta.money_supply + DB.policy.ubi_weekly
table.insert(a.history, {t=now(), type="ubi", amount=DB.policy.ubi_weekly,
note="Citizen's dividend"})
if #a.history > 200 then table.remove(a.history, 1) end
paid = paid + DB.policy.ubi_weekly
count = count + 1
end
end
if count > 0 then
appendLedger{type="ubi_payout", recipients=count, total=paid,
per_account=DB.policy.ubi_weekly}
end
DB.last_ubi_run = now()
end
local function supplyTargetAdjust()
if not DB.policy.supply_target_enabled then return end
local s = DB.meta.money_supply
local changed = false
if s > (DB.policy.supply_target_high or 0) then
for _, b in ipairs(DB.policy.tax_brackets or {}) do
if b.above >= 1000000 and b.rate < 0.10 then
b.rate = math.min(0.10, b.rate + 0.001)
changed = true
end
end
elseif s < (DB.policy.supply_target_low or 0) then
for _, b in ipairs(DB.policy.tax_brackets or {}) do
if b.above >= 1000000 and b.rate > 0 then
b.rate = math.max(0, b.rate - 0.001)
changed = true
end
end
end
if changed then
appendLedger{type="auto_policy", supply=s, brackets=DB.policy.tax_brackets}
end
end
local function streakTierFor(days)
local tier = CFG.EARNINGS_STREAK_TIERS[1]
local idx = 1
for i, t in ipairs(CFG.EARNINGS_STREAK_TIERS) do
if days >= t.day then tier = t; idx = i end
end
return tier, idx
end
local function thresholdPay(value, tiers)
local pay = 0
for _, t in ipairs(tiers) do
if value >= (t.blocks or t.count or t.damage or 0) then pay = t.pay end
end
return pay
end
local function applyDeathPenalty(st)
local days = st.streak_days or 0
local insured = st.insurance_until and (st.insurance_until > now())
local drop_tiers = CFG.EARNINGS_STREAK_DROP_TIERS
if insured then drop_tiers = math.max(0, math.floor(drop_tiers * 0.5)) end
local _, idx = streakTierFor(days)
local new_idx = math.max(1, idx - drop_tiers)
local new_day = CFG.EARNINGS_STREAK_TIERS[new_idx].day
st.streak_days = new_day
st.last_death_penalty = now()
st.last_death_penalty_from = days
return new_day
end
local function earningsStateFor(owner_lower)
local s = DB.earnings_state[owner_lower]
if not s then
s = {
scoreboard = {},
streak_days = 0,
last_active_day = nil,
grace_used = 0,
last_snapshot_ts = 0,
insurance_until = nil,
build_streak = 0,
boss_claimed = {},
last_death_ts = nil,
last_death_penalty = nil,
last_death_penalty_from = nil,
flags = {},
}
DB.earnings_state[owner_lower] = s
end
return s
end
local function primaryAccountFor(owner)
local ids = DB.byOwner[owner:lower()]
if not ids or #ids == 0 then return nil end
table.sort(ids)
return DB.accounts[ids[1]]
end
local function statDelta(prev, curr)
if type(prev) ~= "number" then return curr or 0, false end
if type(curr) ~= "number" then return 0, false end
if curr < prev then return 0, true end
return curr - prev, false
end
local function computeEarnings(owner, snapshot, session_sec)
local st = earningsStateFor(owner:lower())
local prev = st.scoreboard or {}
local date_key = tonumber(os.date("%Y%m%d"))
if st.last_active_day == date_key then
return {skipped="already_ran_today"}
end
local breakdown = {
owner = owner, date = date_key,
survival_wage = 0, combat_pay = 0, explorer_bonus = 0,
builder_bonus = 0, danger_pay = 0, boss_bounty = 0,
build_streak_bonus = 0, insurance_cost = 0,
base = 0, streak_mult = 1.0, dimension_mult = 1.0,
total = 0, flagged = {}, components = {},
streak_before = st.streak_days,
died_today = false,
}
local tsd_prev = prev["minecraft.custom:minecraft.time_since_last_death"] or 0
local tsd_curr = snapshot["minecraft.custom:minecraft.time_since_last_death"] or 0
if tsd_curr < tsd_prev or (tsd_curr < 1200 and st.last_snapshot_ts > 0) then
breakdown.died_today = true
st.last_death_ts = now()
end
local play_prev = prev["minecraft.custom:minecraft.play_time"]
or prev["minecraft.custom:minecraft.play_one_minute"] or 0
local play_curr = snapshot["minecraft.custom:minecraft.play_time"]
or snapshot["minecraft.custom:minecraft.play_one_minute"] or 0
local play_delta_ticks = math.max(0, play_curr - play_prev)
local play_delta_sec = play_delta_ticks / 20
if session_sec then play_delta_sec = math.max(play_delta_sec, session_sec) end
breakdown.play_sec = play_delta_sec
if play_delta_sec < CFG.EARNINGS_MIN_SESSION_SEC then
breakdown.skipped = "below_session_threshold"
return breakdown
end
breakdown.survival_wage = CFG.EARNINGS_SURVIVAL_WAGE
local combat_score = 0
for entity, weight in pairs(CFG.EARNINGS_COMBAT_TIER) do
local key = "minecraft.killed:"..entity
local delta, reset = statDelta(prev[key], snapshot[key])
if delta > CFG.EARNINGS_COMBAT_VELOCITY_LIMIT then
breakdown.flagged[entity] = delta
local flag_id = "FLG-" .. crypto.random_bytes(6)
DB.farm_flags[flag_id] = {
id = flag_id, owner = owner, entity = entity,
count = delta, weight = weight,
estimated_pay = delta * weight * CFG.EARNINGS_COMBAT_UNIT_CENTS,
ts = now(), status = "pending",
}
appendLedger{type="farm_flag", flag=flag_id, owner=owner,
entity=entity, count=delta}
delta = 0
end
if delta > 0 then
combat_score = combat_score + (delta * weight)
breakdown.components[entity] = (breakdown.components[entity] or 0) + (delta * weight)
end
end
if DB.earnings_pvp_enabled then
local key = "minecraft.killed:minecraft.player"
local delta = statDelta(prev[key], snapshot[key])
combat_score = combat_score + (delta * 2)
end
breakdown.combat_pay = math.min(
combat_score * CFG.EARNINGS_COMBAT_UNIT_CENTS,
CFG.EARNINGS_COMBAT_DAILY_CAP)
for entity, bounty in pairs(CFG.EARNINGS_BOSS_BOUNTY) do
local key = "minecraft.killed:"..entity
local delta = statDelta(prev[key], snapshot[key])
if delta > 0 then
if entity == "minecraft:ender_dragon" then
if not st.boss_claimed.ender_dragon then
breakdown.boss_bounty = breakdown.boss_bounty + bounty
st.boss_claimed.ender_dragon = true
end
else
breakdown.boss_bounty = breakdown.boss_bounty + bounty * delta
end
end
end
local total_cm = 0
for _, stat in ipairs(CFG.EARNINGS_EXPLORE_STATS) do
local delta = statDelta(prev[stat], snapshot[stat])
total_cm = total_cm + delta
end
local blocks = math.floor(total_cm / 100)
local explore_pay = thresholdPay(blocks, CFG.EARNINGS_EXPLORE_TIERS)
local dim = snapshot["_dimension"]
if dim == "minecraft:the_nether" or dim == "minecraft:the_end" then
breakdown.dimension_mult = 1 + CFG.EARNINGS_EXPLORE_NETHER_END_BONUS
explore_pay = math.floor(explore_pay * breakdown.dimension_mult)
end
breakdown.explorer_bonus = explore_pay
breakdown.blocks_traveled = blocks
local build_score = 0
for block, weight in pairs(CFG.EARNINGS_BUILD_MATERIALS) do
local placed_key = "minecraft.used:"..block
local mined_key = "minecraft.mined:"..block
local placed = statDelta(prev[placed_key], snapshot[placed_key])
local mined = statDelta(prev[mined_key], snapshot[mined_key])
local net = math.max(0, placed - mined)
build_score = build_score + (net * weight)
end
build_score = math.floor(build_score)
breakdown.blocks_built = build_score
breakdown.builder_bonus = thresholdPay(build_score, CFG.EARNINGS_BUILD_TIERS)
if build_score >= 2000 then
st.build_streak = (st.build_streak or 0) + 1
if st.build_streak == 3 then
breakdown.build_streak_bonus = CFG.EARNINGS_BUILD_STREAK_PAY
end
else
st.build_streak = 0
end
if not breakdown.died_today then
local dmg_delta = statDelta(
prev["minecraft.custom:minecraft.damage_taken"],
snapshot["minecraft.custom:minecraft.damage_taken"])
breakdown.damage_taken = dmg_delta
breakdown.danger_pay = thresholdPay(dmg_delta, CFG.EARNINGS_DANGER_TIERS)
end
breakdown.base = breakdown.survival_wage
+ breakdown.combat_pay
+ breakdown.explorer_bonus
+ breakdown.builder_bonus
+ breakdown.danger_pay
+ breakdown.boss_bounty
+ breakdown.build_streak_bonus
if breakdown.died_today then
applyDeathPenalty(st)
else
local gap = 0
if st.last_active_day then
local last = tostring(st.last_active_day)
local y = tonumber(last:sub(1,4)); local m = tonumber(last:sub(5,6)); local d = tonumber(last:sub(7,8))
local last_ts = os.time{year=y, month=m, day=d, hour=12}
local now_ts = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
gap = math.floor((now_ts - last_ts) / 86400)
end
if gap == 0 and st.last_active_day ~= nil then
elseif gap <= (1 + CFG.EARNINGS_STREAK_GRACE_DAYS) then
st.streak_days = (st.streak_days or 0) + 1
st.grace_used = math.max(0, gap - 1)
else
st.streak_days = 1
st.grace_used = 0
end
end
local tier = streakTierFor(st.streak_days)
breakdown.streak_mult = tier.mult
breakdown.streak_label = tier.label
breakdown.streak_after = st.streak_days
local multiplied = math.floor(breakdown.base * breakdown.streak_mult)
if st.insurance_until and st.insurance_until > now() then
breakdown.insurance_active = true
end
breakdown.total = multiplied
breakdown.multiplied = multiplied
st.scoreboard = snapshot
st.last_active_day = date_key
st.last_snapshot_ts = now()
return breakdown
end
local function payEarnings(owner, breakdown)
if not breakdown or breakdown.skipped then
DB.earnings_last[owner:lower()] = breakdown
return breakdown
end
local a = primaryAccountFor(owner)
if not a then
breakdown.error = "no_account"
DB.earnings_last[owner:lower()] = breakdown
return breakdown
end
if DB.policy.frozen[a.id] then
breakdown.error = "account_frozen"
DB.earnings_last[owner:lower()] = breakdown
return breakdown
end
local amt = breakdown.total or 0
if amt > 0 then
a.balance = a.balance + amt
DB.meta.money_supply = DB.meta.money_supply + amt
DB.meta.tx_count = DB.meta.tx_count + 1
table.insert(a.history, {
t=now(), type="earnings", amount=amt,
note=string.format("Daily earnings (streak day %d, %.2fx)",
breakdown.streak_after or 0, breakdown.streak_mult or 1),
})
if #a.history > 200 then table.remove(a.history, 1) end
appendLedger{
type="earnings", account=a.id, owner=owner, amount=amt,
survival_wage = breakdown.survival_wage,
combat_pay = breakdown.combat_pay,
explorer_bonus= breakdown.explorer_bonus,
builder_bonus = breakdown.builder_bonus,
danger_pay = breakdown.danger_pay,
boss_bounty = breakdown.boss_bounty,
build_streak_bonus = breakdown.build_streak_bonus,
base = breakdown.base,
streak_days = breakdown.streak_after,
streak_mult = breakdown.streak_mult,
dim_mult = breakdown.dimension_mult,
died = breakdown.died_today,
}
elseif breakdown.died_today then
appendLedger{
type="death_penalty", account=a.id, owner=owner,
streak_before = breakdown.streak_before,
streak_after = breakdown.streak_after,
}
end
DB.earnings_last[owner:lower()] = breakdown
local hist = DB.earnings_history[owner:lower()]
if not hist then hist = {}; DB.earnings_history[owner:lower()] = hist end
local compact = {
t = now(),
date = breakdown.date,
total = breakdown.total or 0,
survival_wage = breakdown.survival_wage or 0,
combat_pay = breakdown.combat_pay or 0,
explorer_bonus = breakdown.explorer_bonus or 0,
builder_bonus = breakdown.builder_bonus or 0,
danger_pay = breakdown.danger_pay or 0,
boss_bounty = breakdown.boss_bounty or 0,
build_streak_bonus = breakdown.build_streak_bonus or 0,
streak_days = breakdown.streak_after,
streak_mult = breakdown.streak_mult,
died = breakdown.died_today and true or false,
skipped = breakdown.skipped,
}
table.insert(hist, compact)
while #hist > CFG.EARNINGS_HISTORY_DEPTH do table.remove(hist, 1) end
persist()
return breakdown
end
local function chargeInsuranceIfDue(owner)
local st = earningsStateFor(owner:lower())
if not st.insurance_until or st.insurance_until <= now() then return end
if not st.insurance_last_charge or st.insurance_last_charge + CFG.EARNINGS_INSURANCE_DURATION <= now() then
local a = primaryAccountFor(owner)
if a and a.balance >= CFG.EARNINGS_INSURANCE_COST then
a.balance = a.balance - CFG.EARNINGS_INSURANCE_COST
DB.meta.money_supply = DB.meta.money_supply - CFG.EARNINGS_INSURANCE_COST
st.insurance_last_charge = now()
st.insurance_until = now() + CFG.EARNINGS_INSURANCE_DURATION
table.insert(a.history, {
t=now(), type="insurance",
amount=-CFG.EARNINGS_INSURANCE_COST,
note="Death Insurance renewal",
})
appendLedger{type="insurance_charge", account=a.id, amount=CFG.EARNINGS_INSURANCE_COST}
else
st.insurance_until = now()
appendLedger{type="insurance_lapse", account=a and a.id, owner=owner}
end
end
end
local RANK_BY_ID = {}
for _, r in ipairs(CFG.VANGUARD_RANKS) do RANK_BY_ID[r.id] = r end
local function rankFor(rank_id)
if not rank_id then return nil end
return RANK_BY_ID[rank_id]
end
local function vanguardCount()
local n = 0
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then n = n + 1 end
end
return n
end
local function dailySalaryCents(rank)
if not rank then return 0 end
return math.floor(rank.weekly_cents / 7)
end
local function paySalary(account)
if not CFG.VANGUARD_ENABLED then return 0 end
if not account or not account.vanguard_rank then return 0 end
if account.is_treasury then return 0 end
local rank = rankFor(account.vanguard_rank)
if not rank then return 0 end
if DB.policy.frozen[account.id] then return 0 end
local gross = dailySalaryCents(rank)
if gross <= 0 then return 0 end
local annual = (rank.weekly_cents or 0) * 52
local rate = incomeTaxRate(annual)
local tax = math.floor(gross * rate)
local net = gross - tax
account.balance = account.balance + net
DB.meta.money_supply = DB.meta.money_supply + gross
DB.meta.tx_count = DB.meta.tx_count + 1
creditFund(tax, "income_tax: VG "..rank.grade.." "..account.owner)
table.insert(account.history, {
t=now(), type="salary", amount=net,
note=string.format("%s salary (gross %s, tax %s @ %.0f%%)",
rank.grade, fmtMoney(gross), fmtMoney(tax), rate * 100),
})
if #account.history > 200 then table.remove(account.history, 1) end
appendLedger{
type="salary", account=account.id, owner=account.owner,
rank=rank.id, grade=rank.grade,
gross=gross, tax=tax, rate=rate, amount=net,
weekly=rank.weekly_cents,
}
account.vanguard_week_paid = (account.vanguard_week_paid or 0) + net
account.vanguard_week_days = (account.vanguard_week_days or 0) + 1
return net
end
local function sendWeeklyDigests()
for _, a in pairs(DB.accounts) do
if a.vanguard_rank and (a.vanguard_week_paid or 0) > 0 then
local rank = rankFor(a.vanguard_rank)
local rank_label = rank and rank.label or a.vanguard_rank
notify(a.owner, "daily", "gold", string.format(
"Weekly salary digest: %s paid for %d days as %s",
fmtMoney(a.vanguard_week_paid),
a.vanguard_week_days or 0,
rank_label))
a.vanguard_week_paid = 0
a.vanguard_week_days = 0
end
end
end
local function runPayroll()
if not CFG.VANGUARD_ENABLED then return 0, 0 end
local total = 0
local paid = 0
local errors = 0
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then
local ok_pay, p = pcall(paySalary, a)
if not ok_pay then
errors = errors + 1
DIAG.last_error_time = now()
DIAG.last_error_method = "paySalary"
DIAG.last_error_detail = (a.id or "?")..": "..tostring(p):sub(1, 160)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
elseif type(p) == "number" and p > 0 then
total = total + p; paid = paid + 1
end
end
end
if paid > 0 then
pcall(appendLedger, {type="payroll_tick", paid=paid, total=total,
errors=errors > 0 and errors or nil})
end
if tonumber(os.date("%w")) == 1 then
pcall(sendWeeklyDigests)
pcall(sendCivicWeeklyDigests)
end
return total, paid
end
local function dailyJobCents(annual_cents)
if not annual_cents or annual_cents <= 0 then return 0 end
return math.floor(annual_cents / 365)
end
local function payJob(account, job)
if not account or not job then return 0 end
if account.is_treasury then return 0 end
if DB.policy.frozen[account.id] then return 0 end
local holder = account.civic_jobs and account.civic_jobs[job.id]
if not holder then return 0 end
local gross = dailyJobCents(job.annual_cents)
if gross <= 0 then return 0 end
local rate = incomeTaxRate(job.annual_cents or 0)
local tax = math.floor(gross * rate)
local net = gross - tax
account.balance = account.balance + net
DB.meta.money_supply = DB.meta.money_supply + gross
DB.meta.tx_count = DB.meta.tx_count + 1
creditFund(tax, "income_tax: civic "..job.title.." "..account.owner)
table.insert(account.history, {
t=now(), type="civic_pay", amount=net,
note=string.format("%s salary (gross %s, tax %s @ %.0f%%)",
job.title, fmtMoney(gross), fmtMoney(tax), rate * 100),
})
if #account.history > 200 then table.remove(account.history, 1) end
appendLedger{
type="civic_pay", account=account.id, owner=account.owner,
job_id=job.id, title=job.title,
gross=gross, tax=tax, rate=rate, amount=net,
annual=job.annual_cents,
}
account.civic_week_paid = (account.civic_week_paid or 0) + net
holder.week_paid = (holder.week_paid or 0) + net
holder.week_days = (holder.week_days or 0) + 1
return net
end
local function runCivicPayroll()
local total = 0
local paid_records = 0
local errors = 0
for _, account in pairs(DB.accounts) do
if account.civic_jobs and next(account.civic_jobs) then
for job_id, _ in pairs(account.civic_jobs) do
local job = DB.civic_jobs[job_id]
if job then
local ok_pay, p = pcall(payJob, account, job)
if not ok_pay then
errors = errors + 1
DIAG.last_error_time = now()
DIAG.last_error_method = "payJob"
DIAG.last_error_detail = (account.id or "?").."/"..(job_id or "?")..": "..tostring(p):sub(1, 140)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
elseif type(p) == "number" and p > 0 then
total = total + p; paid_records = paid_records + 1
end
end
end
end
end
if paid_records > 0 then
pcall(appendLedger, {type="civic_payroll_tick", paid=paid_records,
total=total, errors=errors > 0 and errors or nil})
end
return total, paid_records
end
local function sendCivicWeeklyDigests()
for _, a in pairs(DB.accounts) do
if a.civic_jobs and (a.civic_week_paid or 0) > 0 then
local parts = {}
for job_id, holder in pairs(a.civic_jobs) do
local job = DB.civic_jobs[job_id]
if job and (holder.week_paid or 0) > 0 then
table.insert(parts, string.format("%s as %s",
fmtMoney(holder.week_paid), job.title))
holder.week_paid = 0
holder.week_days = 0
end
end
if #parts > 0 then
notify(a.owner, "daily", "gold",
"Civic pay this week: "..table.concat(parts, ", ")
.." (total "..fmtMoney(a.civic_week_paid)..")")
end
a.civic_week_paid = 0
end
end
end
local function subsFor(owner_lower)
local s = DB.earnings_subs[owner_lower]
if not s then
s = {}
for _, ch in ipairs(CFG.NOTIF_CHANNELS) do s[ch[1]] = ch[2] and true or false end
DB.earnings_subs[owner_lower] = s
end
return s
end
local function notifStateFor(owner_lower)
local s = DB.notif_state[owner_lower]
if not s then s = {}; DB.notif_state[owner_lower] = s end
return s
end
local function notify(owner, channel, color, message)
local subs = subsFor(owner:lower())
if not subs[channel] then return false end
if #DB.notif_outbox >= CFG.NOTIF_OUTBOX_MAX then
table.remove(DB.notif_outbox, 1)
end
table.insert(DB.notif_outbox, {
owner = owner, channel = channel,
color = color or "white",
message = message,
t = now(),
})
return true
end
local function checkStreakWarnings()
for owner_lower, st in pairs(DB.earnings_state) do
if st.streak_days and st.streak_days > 0 and st.last_active_day then
local last = tostring(st.last_active_day)
local y = tonumber(last:sub(1,4)); local m = tonumber(last:sub(5,6)); local d = tonumber(last:sub(7,8))
if y and m and d then
local last_ts = os.time{year=y, month=m, day=d, hour=12}
local now_ts = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
local gap_days = math.floor((now_ts - last_ts) / 86400)
if gap_days >= 1 and gap_days <= (1 + CFG.EARNINGS_STREAK_GRACE_DAYS) then
local ns = notifStateFor(owner_lower)
local cooldown = CFG.NOTIF_STREAK_WARN_HOURS * 3600
if not ns.last_streak_warn or now() - ns.last_streak_warn > cooldown then
local owner = owner_lower
local ids = DB.byOwner[owner_lower]
if ids and ids[1] and DB.accounts[ids[1]] then
owner = DB.accounts[ids[1]].owner
end
local hours_left = (1 + CFG.EARNINGS_STREAK_GRACE_DAYS - gap_days) * 24
notify(owner, "streak", "yellow", string.format(
"Streak warning: day %d streak expires in ~%dh. " ..
"Play 20+ minutes today to keep it.",
st.streak_days, hours_left))
ns.last_streak_warn = now()
end
end
end
end
end
end
local H = {}
function H.ping(p)
return {ok=true, version=VERSION, policy={
sav_mpr=DB.policy.sav_mpr, chk_mpr=DB.policy.chk_mpr,
cd_mpr_30=DB.policy.cd_mpr_30, cd_mpr_90=DB.policy.cd_mpr_90,
cd_mpr_180=DB.policy.cd_mpr_180, loan_mpr=DB.policy.loan_mpr,
tx_tax=DB.policy.tx_tax, min_loan_col=DB.policy.min_loan_col,
}, supply=DB.meta.money_supply, mc_month_sec=CFG.MC_MONTH_SEC}
end
function H.admin_diagnostics(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local accts = 0; local frozen = 0
for id, a in pairs(DB.accounts) do
accts = accts + 1
if DB.policy.frozen[id] then frozen = frozen + 1 end
end
local sessions = 0
for _ in pairs(DB.sessions) do sessions = sessions + 1 end
local pending_factions = 0
for _, t in pairs(DB.pending_tx or {}) do pending_factions = pending_factions + 1 end
local jobs = 0
for _ in pairs(DB.civic_jobs or {}) do jobs = jobs + 1 end
local vanguard = 0
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then vanguard = vanguard + 1 end
end
local farm_flags_pending = 0
for _, fl in pairs(DB.farm_flags or {}) do
if fl.status == "pending" then farm_flags_pending = farm_flags_pending + 1 end
end
local ledger_size = 0
if fs.exists(PATHS.ledger) then ledger_size = fs.getSize(PATHS.ledger) end
local db_size = 0
if fs.exists(PATHS.db) then db_size = fs.getSize(PATHS.db) end
local free_space = nil
if fs.getFreeSpace then
local ok_g, fs_n = pcall(fs.getFreeSpace, "/")
if ok_g then free_space = fs_n end
end
return {
ok = true,
version = VERSION,
uptime_sec = now() - (DB.meta.boot_time or now()),
accounts = accts,
accounts_frozen = frozen,
active_sessions = sessions,
pending_factions = pending_factions,
civic_jobs = jobs,
vanguard_members = vanguard,
vanguard_max = CFG.VANGUARD_MAX_MEMBERS,
farm_flags_pending = farm_flags_pending,
money_supply = DB.meta.money_supply,
tx_count = DB.meta.tx_count or 0,
ledger_head = DB.meta.ledger_head,
ledger_size_bytes = ledger_size,
db_size_bytes = db_size,
free_space_bytes = free_space,
persist_failures = DIAG.persist_failures or 0,
last_persist_error = DIAG.last_persist_error,
last_persist_failure_time = DIAG.last_persist_failure_time,
ledger_write_failures = DIAG.ledger_write_failures or 0,
last_ledger_error = DIAG.last_ledger_error,
rejected_packets = DIAG.rejected_packets or 0,
last_reject_time = DIAG.last_reject_time,
last_reject_reason = DIAG.last_reject_reason,
last_reject_sender = DIAG.last_reject_sender,
server_errors = DIAG.server_errors or 0,
last_error_time = DIAG.last_error_time,
last_error_method = DIAG.last_error_method,
last_error_detail = DIAG.last_error_detail,
last_db_error = DIAG.last_db_error,
last_earnings_run = DB.last_earnings_run or 0,
earnings_enabled = DB.earnings_enabled,
vanguard_enabled = CFG.VANGUARD_ENABLED,
}
end
function H.auth(p)
if not V.account_id(p.account_id) then return {ok=false, err="Invalid account ID"} end
if not V.pin(p.pin) then return {ok=false, err="Invalid PIN format"} end
local locked, until_ts = isLocked(p.account_id)
if locked then return {ok=false, err="Account locked until "..os.date("%H:%M", until_ts)} end
local a = DB.accounts[p.account_id]
if not a then
hashPin(p.pin, p.account_id)
return {ok=false, err="Invalid credentials"}
end
if DB.policy.frozen[p.account_id] then return {ok=false, err="Account frozen"} end
if a.is_treasury then return {ok=false, err="Treasury account; admin-only"} end
if a.pin_hash ~= hashPin(p.pin, p.account_id) then
registerFail(p.account_id)
appendLedger{type="pin_fail", account=p.account_id, branch=p.branch}
return {ok=false, err="Invalid credentials"}
end
clearFails(p.account_id)
local sid = createSession(p.account_id, p.branch)
appendLedger{type="signin", account=p.account_id, branch=p.branch}
return {ok=true, session=sid, account={
id=a.id, owner=a.owner, kind=a.kind, balance=a.balance, joint=a.joint,
}}
end
function H.signout(p)
if V.session(p.session) then DB.sessions[p.session] = nil end
return {ok=true}
end
function H.auth_by_owner(p)
if not V.username(p.owner or "") then
return {ok=false, err="Invalid username"}
end
if not V.pin(p.pin) then return {ok=false, err="Invalid PIN format"} end
local k = (p.owner or ""):lower()
local ids = DB.byOwner[k] or {}
if #ids == 0 then
hashPin(p.pin, "ACC-000000")
return {ok=false, err="Invalid credentials"}
end
local matched
local any_unlocked = false
local sorted = {}
for _, id in ipairs(ids) do table.insert(sorted, id) end
table.sort(sorted, function(x, y)
local ax = DB.accounts[x]; local ay = DB.accounts[y]
local kx = (ax and ax.kind) or ""
local ky = (ay and ay.kind) or ""
if kx == ky then return x < y end
return kx == "checking"
end)
for _, id in ipairs(sorted) do
local a = DB.accounts[id]
if a and not a.is_treasury and not DB.policy.frozen[id] then
local locked, _ = isLocked(id)
if not locked then
any_unlocked = true
if a.pin_hash == hashPin(p.pin, id) then
matched = a; break
end
end
end
end
if not any_unlocked then
return {ok=false, err="All your accounts are locked. Try later."}
end
if not matched then
for _, id in ipairs(sorted) do
local a = DB.accounts[id]
if a and not a.is_treasury and not DB.policy.frozen[id] then
local locked, _ = isLocked(id)
if not locked then registerFail(id) end
end
end
appendLedger{type="pin_fail_owner", owner=p.owner, branch=p.branch}
return {ok=false, err="Invalid credentials"}
end
clearFails(matched.id)
local session_account = matched
if matched.kind == "savings" and matched.paired_checking then
local chk = DB.accounts[matched.paired_checking]
if chk and not chk.is_treasury and not DB.policy.frozen[chk.id] then
session_account = chk
end
end
local sid = createSession(session_account.id, p.branch)
appendLedger{type="signin", account=session_account.id,
owner=session_account.owner, via_owner=true, branch=p.branch,
matched_account=matched.id ~= session_account.id and matched.id or nil}
return {ok=true, session=sid, account={
id=session_account.id, owner=session_account.owner,
kind=session_account.kind, balance=session_account.balance,
joint=session_account.joint,
}}
end
local function withSession(p)
if not V.session(p.session) then return nil, "No session" end
local s, err = resolveSession(p.session)
if not s then return nil, err end
local a = DB.accounts[s.account_id]
if not a then return nil, "Account gone" end
if a.is_treasury then return nil, "Treasury account; admin-only" end
if DB.policy.frozen[a.id] then return nil, "Account frozen" end
return a, nil, s
end
function H.balance(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
return {ok=true, balance=a.balance, kind=a.kind, owner=a.owner, id=a.id}
end
function H.history(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local limit = math.min(math.max(tonumber(p.limit) or 25, 1), 100)
local combined = {}
for _, h in ipairs(a.history or {}) do
local copy = {}
for k, v in pairs(h) do copy[k] = v end
copy._account = a.id; copy._kind = a.kind
table.insert(combined, copy)
end
if a.paired_savings then
local sav = DB.accounts[a.paired_savings]
if sav and sav.history then
for _, h in ipairs(sav.history) do
local copy = {}
for k, v in pairs(h) do copy[k] = v end
copy._account = sav.id; copy._kind = sav.kind
table.insert(combined, copy)
end
end
elseif a.paired_checking then
local chk = DB.accounts[a.paired_checking]
if chk and chk.history then
for _, h in ipairs(chk.history) do
local copy = {}
for k, v in pairs(h) do copy[k] = v end
copy._account = chk.id; copy._kind = chk.kind
table.insert(combined, copy)
end
end
end
table.sort(combined, function(x, y) return (x.t or 0) < (y.t or 0) end)
local n = math.min(#combined, limit)
local slice = {}
for i = #combined - n + 1, #combined do
if combined[i] then table.insert(slice, combined[i]) end
end
return {ok=true, history=slice}
end
local function postHistory(a, entry)
table.insert(a.history, entry)
if #a.history > 200 then table.remove(a.history, 1) end
end
function H.open_account(p)
if not V.username(p.owner) then return {ok=false, err="Invalid username (2-32, a-z0-9_)"} end
if p.owner:lower() == CFG.FUND_OWNER:lower() then
return {ok=false, err="That username is reserved"}
end
if not V.pin(p.pin) then return {ok=false, err="PIN must be 4 digits"} end
local k = p.owner:lower()
local existing = DB.byOwner[k] or {}
if #existing > 0 then
return {ok=false, err="You already have an account under this username"}
end
local checking_id = newAccountId()
local savings_id = newAccountId()
while savings_id == checking_id do savings_id = newAccountId() end
local pin_hash_chk = hashPin(p.pin, checking_id)
local pin_hash_sav = hashPin(p.pin, savings_id)
local now_ts = now()
DB.accounts[checking_id] = {
id=checking_id, owner=p.owner, kind="checking", balance=0,
pin_hash=pin_hash_chk, created=now_ts,
history={}, joint=(type(p.joint) == "table") and p.joint or {},
paired_savings = savings_id,
}
DB.accounts[savings_id] = {
id=savings_id, owner=p.owner, kind="savings", balance=0,
pin_hash=pin_hash_sav, created=now_ts,
history={}, joint={},
paired_checking = checking_id,
lots = {},
}
DB.byOwner[k] = DB.byOwner[k] or {}
table.insert(DB.byOwner[k], checking_id)
table.insert(DB.byOwner[k], savings_id)
appendLedger{type="open_pair", owner=p.owner,
checking=checking_id, savings=savings_id}
persist()
return {ok=true, account_id=checking_id,
checking_id=checking_id, savings_id=savings_id}
end
function H.deposit(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
local is_admin_call = isAdmin(p)
if not is_admin_call and not DB.policy.allow_player_deposit then
return {ok=false,
err="Direct deposits are disabled. Earn through play, claim progress rewards, "
.."or redeem a Reserve Note instead."}
end
a.balance = a.balance + p.amount
DB.meta.money_supply = DB.meta.money_supply + p.amount
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(a.id)
postHistory(a, {t=now(), type="deposit", amount=p.amount,
note=V.short_text(p.note) and p.note or
(is_admin_call and "Admin deposit" or "Cash deposit")})
appendLedger{type="deposit", account=a.id, amount=p.amount,
branch=p.branch, by_admin=is_admin_call}
persist()
return {ok=true, balance=a.balance}
end
function H.withdraw(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
if a.balance < p.amount then return {ok=false, err="Insufficient funds"} end
a.balance = a.balance - p.amount
DB.meta.money_supply = DB.meta.money_supply - p.amount
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(a.id)
postHistory(a, {t=now(), type="withdraw", amount=-p.amount, note=V.short_text(p.note) and p.note or "Cash withdrawal"})
appendLedger{type="withdraw", account=a.id, amount=p.amount, branch=p.branch}
persist()
return {ok=true, balance=a.balance}
end
function H.transfer(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.account_id(p.target_id) then return {ok=false, err="Invalid target"} end
local b = DB.accounts[p.target_id]
if not b then return {ok=false, err="Target account not found"} end
if a.id == b.id then return {ok=false, err="Cannot transfer to your own account"} end
if DB.policy.frozen[b.id] then return {ok=false, err="Target frozen"} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
local memo = V.short_text(p.memo) and p.memo or nil
if b.kind == "savings" then
if b.paired_checking and DB.accounts[b.paired_checking] then
b = DB.accounts[b.paired_checking]
if a.id == b.id then return {ok=false, err="Cannot transfer to your own account"} end
if DB.policy.frozen[b.id] then return {ok=false, err="Target frozen"} end
else
return {ok=false, err="Cannot pay to savings; target has no checking"}
end
end
if not p.from_faction and a.kind == "savings" then
return {ok=false, err="Use MOVE to bring funds into checking first"}
end
if p.from_faction then
if not V.faction_id(p.from_faction) then return {ok=false, err="Bad faction id"} end
local fac = DB.factions[p.from_faction]
if not fac then return {ok=false, err="Faction not found"} end
if not fac.members[a.owner] then return {ok=false, err="Not a faction member"} end
local treasury = DB.accounts[fac.treasury_account]
if not treasury then return {ok=false, err="Treasury missing"} end
if treasury.balance < p.amount then return {ok=false, err="Treasury insufficient"} end
if p.amount <= (DB.policy.multisig_threshold or 0) and fac.threshold_n <= 1 then
local tax, rate = computeTax(p.amount, treasury.id, b.id)
treasury.balance = treasury.balance - p.amount
b.balance = b.balance + (p.amount - tax)
creditFund(tax, "tx_tax: faction "..fac.name.." -> "..b.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(b.id)
postHistory(treasury, {t=now(), type="faction_out", amount=-p.amount, note=memo, party=b.id})
postHistory(b, {t=now(), type="faction_in", amount=(p.amount-tax), note=memo, party=treasury.id})
appendLedger{type="faction_transfer", faction=p.from_faction, from=treasury.id,
to=b.id, amount=p.amount, tax=tax, rate=rate, by=a.owner, memo=memo}
persist()
return {ok=true, executed=true}
end
local pid = "PND-" .. crypto.random_bytes(6)
DB.pending_tx[pid] = {
id=pid, faction_id=p.from_faction, from=treasury.id, to=b.id,
amount=p.amount, memo=memo, approvals={[a.owner]=true},
created=now(),
}
appendLedger{type="multisig_propose", pending=pid, from=treasury.id, to=b.id,
amount=p.amount, proposer=a.owner, faction=p.from_faction}
for member, _ in pairs(fac.members) do
if member ~= a.owner then
notify(member, "multisig", "yellow", string.format(
"[%s] %s proposed %s -- needs your approval (%s)",
fac.name, a.owner, fmtMoney(p.amount), pid))
end
end
persist()
return {ok=true, pending=pid, needs_approvals=fac.threshold_n - 1}
end
if a.balance < p.amount then return {ok=false, err="Insufficient funds"} end
local tax, rate = computeTax(p.amount, a.id, b.id)
a.balance = a.balance - p.amount
b.balance = b.balance + (p.amount - tax)
creditFund(tax, "tx_tax: "..a.owner.." -> "..b.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(a.id); markActivity(b.id)
postHistory(a, {t=now(), type="transfer_out", amount=-p.amount, note=memo, party=b.id})
postHistory(b, {t=now(), type="transfer_in", amount=(p.amount - tax), note=memo, party=a.id})
appendLedger{type="transfer", from=a.id, to=b.id, amount=p.amount, tax=tax, rate=rate, memo=memo}
persist()
return {ok=true, balance=a.balance, tax=tax}
end
function H.move_internal(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if a.kind ~= "checking" then
return {ok=false, err="Sign in as your checking account"}
end
if not a.paired_savings then
return {ok=false, err="No paired savings on this account"}
end
local sav = DB.accounts[a.paired_savings]
if not sav then return {ok=false, err="Savings missing"} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
if DB.policy.frozen[a.id] or DB.policy.frozen[sav.id] then
return {ok=false, err="One of your accounts is frozen"}
end
local dir = p.direction
if dir ~= "chk_to_sav" and dir ~= "sav_to_chk" then
return {ok=false, err="Direction must be chk_to_sav or sav_to_chk"}
end
local EARLY_DAYS = 30
local EARLY_RATE = 0.50
local early_window_sec = EARLY_DAYS * 24 * 60 * 60
if dir == "chk_to_sav" then
if a.balance < p.amount then return {ok=false, err="Insufficient checking balance"} end
a.balance = a.balance - p.amount
sav.balance = sav.balance + p.amount
sav.lots = sav.lots or {}
table.insert(sav.lots, {amount=p.amount, t=now()})
postHistory(a, {t=now(), type="move_out", amount=-p.amount,
note="To savings", party=sav.id})
postHistory(sav, {t=now(), type="move_in", amount=p.amount,
note="From checking", party=a.id})
appendLedger{type="move", direction="chk_to_sav",
from=a.id, to=sav.id, amount=p.amount, owner=a.owner}
persist()
return {ok=true, checking=a.balance, savings=sav.balance, tax=0}
end
if sav.balance < p.amount then return {ok=false, err="Insufficient savings balance"} end
sav.lots = sav.lots or {}
local remaining = p.amount
local now_ts = now()
local total_tax = 0
local i = 1
while remaining > 0 and i <= #sav.lots do
local lot = sav.lots[i]
if not lot or not lot.amount or lot.amount <= 0 then
table.remove(sav.lots, i)
else
local take = math.min(remaining, lot.amount)
local age = now_ts - (lot.t or 0)
if age < early_window_sec then
total_tax = total_tax + math.floor(take * EARLY_RATE)
end
lot.amount = lot.amount - take
remaining = remaining - take
if lot.amount <= 0 then
table.remove(sav.lots, i)
else
i = i + 1
end
end
end
local uncovered = remaining
if uncovered > 0 then
remaining = 0
end
sav.balance = sav.balance - p.amount
local credited = p.amount - total_tax
a.balance = a.balance + credited
creditFund(total_tax, "early_savings_tax: "..a.owner)
postHistory(sav, {t=now(), type="move_out", amount=-p.amount,
note=string.format("To checking (early-tax %s)",
fmtMoney(total_tax)),
party=a.id})
postHistory(a, {t=now(), type="move_in", amount=credited,
note=string.format("From savings (after %s tax)",
fmtMoney(total_tax)),
party=sav.id})
appendLedger{type="move", direction="sav_to_chk",
from=sav.id, to=a.id, amount=p.amount,
tax=total_tax, owner=a.owner,
uncovered=uncovered > 0 and uncovered or nil}
persist()
return {ok=true, checking=a.balance, savings=sav.balance,
tax=total_tax, credited=credited}
end
function H.profile(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {
owner = a.owner,
checking = nil,
savings = nil,
}
local chk, sav
if a.kind == "checking" then
chk = a
if a.paired_savings then sav = DB.accounts[a.paired_savings] end
elseif a.kind == "savings" then
sav = a
if a.paired_checking then chk = DB.accounts[a.paired_checking] end
end
if chk then
out.checking = {id=chk.id, balance=chk.balance, kind="checking"}
end
if sav then
local young = 0
local cutoff = now() - (30 * 24 * 60 * 60)
for _, lot in ipairs(sav.lots or {}) do
if (lot.t or 0) >= cutoff then young = young + (lot.amount or 0) end
end
out.savings = {id=sav.id, balance=sav.balance, kind="savings",
young_cents=young}
end
return {ok=true, profile=out}
end
function H.lookup(p)
if not V.username(p.owner or "") then return {ok=false, err="Invalid username"} end
local ids = DB.byOwner[p.owner:lower()] or {}
local out = {}
for _, id in ipairs(ids) do
local a = DB.accounts[id]
if a and not a.is_treasury and a.kind ~= "savings" then
table.insert(out, {id=id, kind=a.kind, owner=a.owner})
end
end
return {ok=true, accounts=out}
end
function H.list_payable_accounts(p)
local me, err = withSession(p)
if not me then return {ok=false, err=err} end
local out = {}
local mine = {}
for _, id in ipairs(DB.byOwner[me.owner:lower()] or {}) do
mine[id] = true
end
for id, a in pairs(DB.accounts) do
if not mine[id]
and not a.is_treasury
and a.kind ~= "savings"
and not (DB.policy.frozen and DB.policy.frozen[id]) then
table.insert(out, {id=id, kind=a.kind, owner=a.owner})
end
end
table.sort(out, function(x, y)
if x.owner:lower() == y.owner:lower() then return x.id < y.id end
return x.owner:lower() < y.owner:lower()
end)
return {ok=true, accounts=out}
end
function H.open_cd(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
if not V.days(p.days) then return {ok=false, err="Invalid term"} end
if a.balance < p.amount then return {ok=false, err="Insufficient funds"} end
local mpr
if p.days >= 180 then mpr = DB.policy.cd_mpr_180
elseif p.days >= 90 then mpr = DB.policy.cd_mpr_90
elseif p.days >= 30 then mpr = DB.policy.cd_mpr_30
else return {ok=false, err="Minimum CD term is 30 days"} end
a.balance = a.balance - p.amount
local id = "CD-" .. string.format("%06d", math.random(100000,999999))
DB.certs[id] = {
id=id, owner=a.owner, source=a.id, principal=p.amount,
opened=now(), matures=now() + p.days * 86400,
mpr=mpr, redeemed=false,
}
postHistory(a, {t=now(), type="cd_open", amount=-p.amount, note="CD "..id})
appendLedger{type="cd_open", account=a.id, cd=id, amount=p.amount, days=p.days, mpr=mpr}
persist()
return {ok=true, cd_id=id, balance=a.balance, mpr=mpr}
end
function H.redeem_cd(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.cd_id(p.cd_id) then return {ok=false, err="Invalid CD id"} end
local cd = DB.certs[p.cd_id]
if not cd or cd.redeemed or cd.source ~= a.id then return {ok=false, err="CD not found"} end
local mature = now() >= cd.matures
local months = (now() - cd.opened) / CFG.MC_MONTH_SEC
local payout
if mature then payout = math.floor(cd.principal * ((1 + cd.mpr) ^ months))
else payout = math.max(0, math.floor(cd.principal * 0.95)) end
cd.redeemed = true
a.balance = a.balance + payout
DB.meta.money_supply = DB.meta.money_supply + (payout - cd.principal)
postHistory(a, {t=now(), type="cd_redeem", amount=payout, note=p.cd_id..(mature and " (matured)" or " (early)")})
appendLedger{type="cd_redeem", account=a.id, cd=cd.id, payout=payout, mature=mature}
persist()
return {ok=true, balance=a.balance, payout=payout, mature=mature}
end
function H.list_cds(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
for _, c in pairs(DB.certs) do
if c.source == a.id and not c.redeemed then
table.insert(out, {id=c.id, principal=c.principal, matures=c.matures, mpr=c.mpr})
end
end
return {ok=true, cds=out}
end
function H.request_loan(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
local col = math.floor(p.amount * DB.policy.min_loan_col)
if a.balance < col then
return {ok=false, err=string.format("Need %s on deposit as collateral", fmtMoney(col))}
end
a.balance = a.balance + p.amount
local id = "LOAN-" .. string.format("%06d", math.random(100000,999999))
DB.loans[id] = {
id=id, owner=a.owner, account=a.id, principal=p.amount, balance=p.amount,
mpr=DB.policy.loan_mpr, opened=now(), closed=false,
collateral=col, interest_accrued=0,
}
DB.meta.money_supply = DB.meta.money_supply + p.amount
DB.meta.loans_out = DB.meta.loans_out + p.amount
postHistory(a, {t=now(), type="loan_origin", amount=p.amount, note="Loan "..id})
appendLedger{type="loan_origin", account=a.id, loan=id, amount=p.amount, mpr=DB.policy.loan_mpr}
persist()
return {ok=true, loan_id=id, balance=a.balance}
end
function H.repay_loan(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.loan_id(p.loan_id) then return {ok=false, err="Invalid loan id"} end
local l = DB.loans[p.loan_id]
if not l or l.closed or l.account ~= a.id then return {ok=false, err="Loan not found"} end
if not V.amount(p.amount) then return {ok=false, err="Invalid amount"} end
local amt = math.min(p.amount, l.balance)
if amt <= 0 or a.balance < amt then return {ok=false, err="Insufficient funds"} end
a.balance = a.balance - amt
l.balance = l.balance - amt
DB.meta.money_supply = DB.meta.money_supply - amt
DB.meta.loans_out = DB.meta.loans_out - amt
if l.balance <= 0 then l.closed = true end
postHistory(a, {t=now(), type="loan_repay", amount=-amt, note="Loan "..l.id})
appendLedger{type="loan_repay", account=a.id, loan=l.id, amount=amt}
persist()
return {ok=true, balance=a.balance, loan_balance=l.balance, closed=l.closed}
end
function H.list_loans(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
for _, l in pairs(DB.loans) do
if l.account == a.id and not l.closed then
table.insert(out, {id=l.id, balance=l.balance, mpr=l.mpr, opened=l.opened})
end
end
return {ok=true, loans=out}
end
function H.list_catalog(p)
local out = {}
for id, item in pairs(DB.catalog) do
table.insert(out, {id=id, label=item.label, bounty=item.bounty, once=item.once})
end
return {ok=true, catalog=out}
end
function H.list_work_orders(p)
local out = {}
for id, wo in pairs(DB.work_orders) do
if not wo.completed then
table.insert(out, {id=id, title=wo.title, bounty=wo.bounty, posted_by=wo.posted_by,
claimed_by=wo.claimed_by, posted_at=wo.posted_at})
end
end
return {ok=true, orders=out}
end
function H.submit_claim(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.progress_id(p.progress_id) then return {ok=false, err="Invalid progress id"} end
if not DB.catalog[p.progress_id] then return {ok=false, err="Unknown achievement"} end
if not V.short_text(p.evidence) then return {ok=false, err="Evidence required"} end
DB.progress[a.id] = DB.progress[a.id] or {}
local item = DB.catalog[p.progress_id]
local prior = DB.progress[a.id][p.progress_id]
if prior and item.once and prior.approved then return {ok=false, err="Already awarded"} end
local claim_id = "CLM-" .. crypto.random_bytes(4)
DB.progress[a.id][p.progress_id] = {
submitted_at=now(), evidence=p.evidence, approved=false,
count=(prior and prior.count or 0), pending_claim=claim_id,
}
appendLedger{type="claim_submit", account=a.id, progress=p.progress_id, claim=claim_id}
persist()
return {ok=true, claim_id=claim_id}
end
function H.claim_work_order(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if type(p.order_id) ~= "string" then return {ok=false, err="Invalid order"} end
local wo = DB.work_orders[p.order_id]
if not wo or wo.completed then return {ok=false, err="Order not available"} end
if wo.claimed_by and wo.claimed_by ~= a.id then return {ok=false, err="Already claimed"} end
wo.claimed_by = a.id
wo.claimed_at = now()
appendLedger{type="wo_claim", order=p.order_id, account=a.id}
persist()
return {ok=true}
end
function H.create_faction(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if type(p.name) ~= "string" or #p.name < 3 or #p.name > 40 then
return {ok=false, err="Faction name 3-40 chars"} end
if not V.positive_int(p.threshold_n) or not V.positive_int(p.threshold_m) then
return {ok=false, err="Thresholds must be positive integers"} end
if p.threshold_n > p.threshold_m then
return {ok=false, err="N cannot exceed M"} end
local fid = "FAC-" .. crypto.random_bytes(4):upper()
local tid = newAccountId()
DB.accounts[tid] = {
id=tid, owner="@"..fid, kind="checking", balance=0,
pin_hash="", created=now(), history={}, joint={},
faction_id=fid,
}
DB.factions[fid] = {
id=fid, name=p.name, treasury_account=tid,
members={[a.owner]="founder"},
threshold_n=p.threshold_n, threshold_m=p.threshold_m,
created=now(),
}
appendLedger{type="faction_create", faction=fid, name=p.name, founder=a.owner, treasury=tid}
persist()
return {ok=true, faction_id=fid, treasury_id=tid}
end
function H.faction_add_member(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.faction_id(p.faction_id) then return {ok=false, err="Bad faction id"} end
if not V.username(p.member) then return {ok=false, err="Bad username"} end
local fac = DB.factions[p.faction_id]
if not fac then return {ok=false, err="Faction not found"} end
if fac.members[a.owner] ~= "founder" then return {ok=false, err="Only founder can add members"} end
fac.members[p.member] = "member"
appendLedger{type="faction_add", faction=p.faction_id, member=p.member, by=a.owner}
persist()
return {ok=true}
end
function H.faction_remove_member(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.faction_id(p.faction_id) then return {ok=false, err="Bad faction id"} end
local fac = DB.factions[p.faction_id]
if not fac then return {ok=false, err="Faction not found"} end
if fac.members[a.owner] ~= "founder" then return {ok=false, err="Only founder"} end
if p.member == a.owner then return {ok=false, err="Founder cannot remove self"} end
fac.members[p.member] = nil
appendLedger{type="faction_remove", faction=p.faction_id, member=p.member, by=a.owner}
persist()
return {ok=true}
end
function H.list_pending_tx(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
for pid, pt in pairs(DB.pending_tx) do
local fac = DB.factions[pt.faction_id]
if fac and fac.members[a.owner] then
local n_approve = 0
for _ in pairs(pt.approvals) do n_approve = n_approve + 1 end
table.insert(out, {
id=pid, faction_id=pt.faction_id, from=pt.from, to=pt.to,
amount=pt.amount, memo=pt.memo, approvals=n_approve,
required=fac.threshold_n, you_approved=(pt.approvals[a.owner] == true),
created=pt.created,
})
end
end
return {ok=true, pending=out}
end
function H.approve_pending_tx(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.pending_id(p.pending_id) then return {ok=false, err="Bad pending id"} end
local pt = DB.pending_tx[p.pending_id]
if not pt then return {ok=false, err="Not found"} end
local PENDING_TTL = 7 * 86400
if (now() - (pt.created or 0)) > PENDING_TTL then
DB.pending_tx[p.pending_id] = nil
appendLedger{type="multisig_expired", pending=p.pending_id,
created=pt.created, expired_at=now()}
persist()
return {ok=false, err="Proposal expired (7+ days old). Re-propose."}
end
local fac = DB.factions[pt.faction_id]
if not fac or not fac.members[a.owner] then return {ok=false, err="Not a member"} end
pt.approvals[a.owner] = true
local n = 0
for _ in pairs(pt.approvals) do n = n + 1 end
if n >= fac.threshold_n then
local src = DB.accounts[pt.from]
local dst = DB.accounts[pt.to]
if not src or not dst then
DB.pending_tx[p.pending_id] = nil
return {ok=false, err="Account gone"}
end
if src.balance < pt.amount then
DB.pending_tx[p.pending_id] = nil
appendLedger{type="multisig_fail", pending=p.pending_id, reason="insufficient"}
persist()
return {ok=false, err="Source now has insufficient funds"}
end
local tax, rate = computeTax(pt.amount, src.id, dst.id)
src.balance = src.balance - pt.amount
dst.balance = dst.balance + (pt.amount - tax)
creditFund(tax, "tx_tax: multisig "..src.owner.." -> "..dst.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(src.id); markActivity(dst.id)
postHistory(src, {t=now(), type="multisig_out", amount=-pt.amount, note=pt.memo, party=dst.id})
postHistory(dst, {t=now(), type="multisig_in", amount=(pt.amount-tax), note=pt.memo, party=src.id})
local approvers = {}
for k in pairs(pt.approvals) do table.insert(approvers, k) end
appendLedger{type="multisig_execute", pending=p.pending_id, from=src.id, to=dst.id,
amount=pt.amount, tax=tax, rate=rate, approvers=approvers, memo=pt.memo}
DB.pending_tx[p.pending_id] = nil
persist()
return {ok=true, executed=true, approvals=n}
end
appendLedger{type="multisig_approve", pending=p.pending_id, by=a.owner, approvals=n,
required=fac.threshold_n}
persist()
return {ok=true, executed=false, approvals=n, required=fac.threshold_n}
end
function H.cancel_pending_tx(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.pending_id(p.pending_id) then return {ok=false, err="Bad pending id"} end
local pt = DB.pending_tx[p.pending_id]
if not pt then return {ok=false, err="Not found"} end
local fac = DB.factions[pt.faction_id]
if not fac or fac.members[a.owner] ~= "founder" then
return {ok=false, err="Only founder can cancel"} end
DB.pending_tx[p.pending_id] = nil
appendLedger{type="multisig_cancel", pending=p.pending_id, by=a.owner}
persist()
return {ok=true}
end
function H.create_escrow(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.account_id(p.counterparty) then return {ok=false, err="Bad counterparty"} end
if p.counterparty == a.id then return {ok=false, err="Cannot escrow to self"} end
if not DB.accounts[p.counterparty] then return {ok=false, err="Counterparty not found"} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
if a.balance < p.amount then return {ok=false, err="Insufficient funds"} end
if not V.short_text(p.memo or "") then return {ok=false, err="Memo too long"} end
a.balance = a.balance - p.amount
local eid = "ESC-" .. crypto.random_bytes(6)
DB.escrows[eid] = {
id=eid, from=a.id, to=p.counterparty, amount=p.amount, memo=p.memo or "",
status="held", created=now(), from_owner=a.owner,
}
markActivity(a.id)
postHistory(a, {t=now(), type="escrow_hold", amount=-p.amount, note="Escrow "..eid})
appendLedger{type="escrow_create", escrow=eid, from=a.id, to=p.counterparty, amount=p.amount}
persist()
return {ok=true, escrow_id=eid}
end
function H.release_escrow(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.escrow_id(p.escrow_id) then return {ok=false, err="Bad escrow id"} end
local e = DB.escrows[p.escrow_id]
if not e or e.status ~= "held" then return {ok=false, err="Escrow not active"} end
if e.from ~= a.id then return {ok=false, err="Only sender can release"} end
local dst = DB.accounts[e.to]
if not dst then e.status = "void"; return {ok=false, err="Recipient gone"} end
local tax, rate = computeTax(e.amount, e.from, e.to)
dst.balance = dst.balance + (e.amount - tax)
creditFund(tax, "tx_tax: escrow "..e.id)
e.status = "released"; e.resolved = now()
markActivity(dst.id)
postHistory(dst, {t=now(), type="escrow_payout", amount=(e.amount-tax), note="Escrow "..e.id})
appendLedger{type="escrow_release", escrow=e.id, amount=e.amount, tax=tax, rate=rate}
persist()
return {ok=true}
end
function H.refund_escrow(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.escrow_id(p.escrow_id) then return {ok=false, err="Bad escrow id"} end
local e = DB.escrows[p.escrow_id]
if not e or e.status ~= "held" then return {ok=false, err="Escrow not active"} end
if e.to ~= a.id then return {ok=false, err="Only recipient can refund"} end
local src = DB.accounts[e.from]
if not src then e.status = "void"; return {ok=false, err="Sender gone"} end
src.balance = src.balance + e.amount
e.status = "refunded"; e.resolved = now()
postHistory(src, {t=now(), type="escrow_refund", amount=e.amount, note="Escrow "..e.id})
appendLedger{type="escrow_refund", escrow=e.id, amount=e.amount}
persist()
return {ok=true}
end
function H.list_my_escrows(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
for id, e in pairs(DB.escrows) do
if e.from == a.id or e.to == a.id then
table.insert(out, {
id=id, from=e.from, to=e.to, amount=e.amount, memo=e.memo,
status=e.status, you_are=(e.from == a.id) and "sender" or "recipient",
created=e.created,
})
end
end
return {ok=true, escrows=out}
end
function H.create_recurring(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.account_id(p.target_id) then return {ok=false, err="Bad target"} end
if not DB.accounts[p.target_id] then return {ok=false, err="Target not found"} end
if not V.amount(p.amount) or p.amount <= 0 then return {ok=false, err="Invalid amount"} end
if not V.positive_int(p.interval_sec) or p.interval_sec < 3600 then
return {ok=false, err="Interval must be >= 1 hour"} end
if not V.positive_int(p.remaining) or p.remaining > 365 then
return {ok=false, err="Remaining must be 1-365"} end
local rid = "REC-" .. crypto.random_bytes(6)
DB.recurring[rid] = {
id=rid, from=a.id, to=p.target_id, amount=p.amount,
memo=V.short_text(p.memo or "") and p.memo or "Recurring",
interval_sec=p.interval_sec, next_run=now() + p.interval_sec,
remaining=p.remaining, created_by=a.owner, created=now(), active=true,
}
appendLedger{type="recurring_create", recur=rid, from=a.id, to=p.target_id,
amount=p.amount, interval=p.interval_sec, count=p.remaining}
persist()
return {ok=true, recur_id=rid}
end
function H.cancel_recurring(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.recur_id(p.recur_id) then return {ok=false, err="Bad id"} end
local r = DB.recurring[p.recur_id]
if not r or not r.active then return {ok=false, err="Not found"} end
if r.from ~= a.id then return {ok=false, err="Not your recurring"} end
r.active = false
appendLedger{type="recurring_cancel", recur=p.recur_id, by=a.owner}
persist()
return {ok=true}
end
function H.list_my_recurring(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
for id, r in pairs(DB.recurring) do
if r.from == a.id and r.active then
table.insert(out, {
id=id, to=r.to, amount=r.amount, memo=r.memo,
interval_sec=r.interval_sec, next_run=r.next_run,
remaining=r.remaining,
})
end
end
return {ok=true, recurring=out}
end
local function processRecurring()
local fired = 0
for id, r in pairs(DB.recurring) do
if r.active and r.remaining > 0 and now() >= r.next_run then
local src = DB.accounts[r.from]
local dst = DB.accounts[r.to]
if src and dst and not DB.policy.frozen[src.id] and not DB.policy.frozen[dst.id]
and src.balance >= r.amount then
local tax, rate = computeTax(r.amount, src.id, dst.id)
src.balance = src.balance - r.amount
dst.balance = dst.balance + (r.amount - tax)
creditFund(tax, "tx_tax: recurring "..src.owner.." -> "..dst.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
postHistory(src, {t=now(), type="recur_out", amount=-r.amount, note=r.memo, party=dst.id})
postHistory(dst, {t=now(), type="recur_in", amount=(r.amount-tax), note=r.memo, party=src.id})
appendLedger{type="recurring_fire", recur=id, amount=r.amount, tax=tax}
r.remaining = r.remaining - 1
r.next_run = r.next_run + r.interval_sec
if r.remaining <= 0 then r.active = false end
fired = fired + 1
else
appendLedger{type="recurring_skip", recur=id, reason="insufficient_or_frozen"}
r.next_run = r.next_run + r.interval_sec
end
end
end
if fired > 0 then persist() end
end
function H.create_shop(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if type(p.label) ~= "string" or #p.label < 3 or #p.label > 40 then
return {ok=false, err="Label 3-40 chars"} end
local sid = "SHP-" .. crypto.random_bytes(4):upper()
DB.shops[sid] = {
id=sid, owner_account=a.id, owner=a.owner, label=p.label,
listings={}, active=true, created=now(),
}
appendLedger{type="shop_create", shop=sid, owner=a.id, label=p.label}
persist()
return {ok=true, shop_id=sid}
end
function H.set_shop_listing(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.shop_id(p.shop_id) then return {ok=false, err="Bad shop id"} end
local shop = DB.shops[p.shop_id]
if not shop or shop.owner_account ~= a.id then return {ok=false, err="Not your shop"} end
if type(p.sku) ~= "string" or #p.sku < 1 or #p.sku > 40 then return {ok=false, err="Bad sku"} end
if type(p.item) ~= "string" or #p.item > 80 then return {ok=false, err="Bad item"} end
if not V.amount(p.price) or p.price <= 0 then return {ok=false, err="Bad price"} end
if type(p.stock) ~= "number" or p.stock < 0 or p.stock ~= math.floor(p.stock) then
return {ok=false, err="Bad stock"} end
shop.listings[p.sku] = {
item=p.item, price=p.price, stock=p.stock,
note=V.short_text(p.note or "") and p.note or "",
}
appendLedger{type="shop_listing", shop=p.shop_id, sku=p.sku, price=p.price, stock=p.stock}
persist()
return {ok=true}
end
function H.get_shop(p)
if not V.shop_id(p.shop_id) then return {ok=false, err="Bad shop id"} end
local shop = DB.shops[p.shop_id]
if not shop or not shop.active then return {ok=false, err="Shop not found"} end
local listings = {}
for sku, l in pairs(shop.listings) do
table.insert(listings, {sku=sku, item=l.item, price=l.price, stock=l.stock, note=l.note})
end
return {ok=true, shop={id=shop.id, label=shop.label, owner=shop.owner, listings=listings}}
end
function H.buy_from_shop(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not V.shop_id(p.shop_id) then return {ok=false, err="Bad shop id"} end
local shop = DB.shops[p.shop_id]
if not shop or not shop.active then return {ok=false, err="Shop unavailable"} end
local l = shop.listings[p.sku]
if not l then return {ok=false, err="Item not listed"} end
local qty = tonumber(p.qty) or 1
if qty < 1 or qty ~= math.floor(qty) then return {ok=false, err="Bad quantity"} end
if l.stock < qty then return {ok=false, err="Out of stock"} end
local cost = l.price * qty
if a.balance < cost then return {ok=false, err="Insufficient funds"} end
local dst = DB.accounts[shop.owner_account]
if not dst or DB.policy.frozen[dst.id] then return {ok=false, err="Shop owner unavailable"} end
local tax = math.floor(cost * 0.01)
a.balance = a.balance - cost
dst.balance = dst.balance + (cost - tax)
DB.meta.money_supply = DB.meta.money_supply - tax
DB.meta.tx_count = DB.meta.tx_count + 1
l.stock = l.stock - qty
markActivity(a.id); markActivity(dst.id)
postHistory(a, {t=now(), type="shop_buy", amount=-cost,
note=string.format("%s x%d @ %s", l.item, qty, shop.label)})
postHistory(dst, {t=now(), type="shop_sale", amount=(cost-tax),
note=string.format("%s x%d to %s", l.item, qty, a.owner)})
appendLedger{type="shop_sale", shop=shop.id, buyer=a.id, seller=dst.id,
sku=p.sku, qty=qty, cost=cost, tax=tax}
persist()
return {ok=true, cost=cost, balance=a.balance, dispensed={item=l.item, qty=qty}}
end
function H.list_my_shops(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
for id, s in pairs(DB.shops) do
if s.owner_account == a.id then
local n_sku = 0; for _ in pairs(s.listings) do n_sku = n_sku + 1 end
table.insert(out, {id=id, label=s.label, active=s.active, listings=n_sku})
end
end
return {ok=true, shops=out}
end
function H.item_deposit(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if type(p.item) ~= "string" then return {ok=false, err="Bad item"} end
if not V.positive_int(p.count) then return {ok=false, err="Bad count"} end
if not DB.policy.item_backing_enabled then return {ok=false, err="Item backing disabled"} end
local value = itemValue(p.item, p.count)
if value <= 0 then return {ok=false, err="Item not backed"} end
a.balance = a.balance + value
DB.meta.money_supply = DB.meta.money_supply + value
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(a.id)
postHistory(a, {t=now(), type="item_deposit", amount=value,
note=string.format("%s x%d", p.item, p.count)})
appendLedger{type="item_deposit", account=a.id, item=p.item, count=p.count, value=value}
persist()
return {ok=true, balance=a.balance, credited=value}
end
function H.item_rates(p)
if not DB.policy.item_backing_enabled then return {ok=true, enabled=false, rates={}} end
local out = {}
for item, rate in pairs(DB.policy.item_backing_map) do
table.insert(out, {item=item, rate=rate})
end
return {ok=true, enabled=true, rates=out}
end
function H.public_stats(p)
local n_acc, n_loan, n_shop, n_fac, n_active = 0, 0, 0, 0, 0
local recent_cutoff = now() - 7*24*3600
for id, a in pairs(DB.accounts) do
n_acc = n_acc + 1
if (DB.activity[id] or 0) >= recent_cutoff then n_active = n_active + 1 end
end
for _, l in pairs(DB.loans) do if not l.closed then n_loan = n_loan + 1 end end
for _, s in pairs(DB.shops) do if s.active then n_shop = n_shop + 1 end end
for _ in pairs(DB.factions) do n_fac = n_fac + 1 end
return {ok=true, stats={
accounts=n_acc, active_last_week=n_active, active_loans=n_loan,
active_shops=n_shop, factions=n_fac,
supply=DB.meta.money_supply, loans_out=DB.meta.loans_out,
tx_count=DB.meta.tx_count, ledger_head=DB.meta.ledger_head,
policy={
sav_mpr=DB.policy.sav_mpr, chk_mpr=DB.policy.chk_mpr,
loan_mpr=DB.policy.loan_mpr, ubi_enabled=DB.policy.ubi_enabled,
ubi_weekly=DB.policy.ubi_weekly, tax_brackets=DB.policy.tax_brackets,
},
}}
end
function H.public_ledger_tail(p)
local limit = math.min(tonumber(p.limit) or 30, 100)
if not fs.exists(PATHS.ledger) then return {ok=true, entries={}} end
local function anon(id)
if not id or type(id) ~= "string" then return id end
if id:sub(1,4) == "ACC-" then return "acct#"..crypto.hash(id):sub(1,6) end
return id
end
local f = fs.open(PATHS.ledger, "r")
if not f then return {ok=true, entries={}} end
local lines = {}
while true do
local line = f.readLine()
if not line then break end
table.insert(lines, line)
if #lines > limit * 3 then table.remove(lines, 1) end
end
f.close()
local out = {}
for _, l in ipairs(lines) do
local ok, e = pcall(textutils.unserialize, l)
if ok and e then
local publishable = {
transfer=true, deposit=true, withdraw=true, loan_origin=true,
loan_repay=true, cd_open=true, cd_redeem=true, interest=true,
ubi_payout=true, policy_change=true, auto_policy=true,
wo_post=true, wo_complete=true, progress_approve=true,
note_issue=true, note_redeem=true, faction_create=true,
shop_sale=true, item_deposit=true, issue=true, admin_adjust=true,
multisig_execute=true,
earnings=true, earnings_tick=true, death_penalty=true,
insurance_charge=true, insurance_lapse=true,
salary=true, payroll_tick=true, rank_assign=true,
rank_change=true, rank_remove=true,
civic_pay=true, civic_payroll_tick=true,
job_create=true, job_assign=true, job_remove=true,
}
if publishable[e.type] then
local sanitized = {t=e.t, type=e.type}
for k, v in pairs(e) do
if k == "account" or k == "from" or k == "to" then sanitized[k] = anon(v)
elseif k == "amount" or k == "tax" or k == "bounty" or k == "delta"
or k == "payout" or k == "total" or k == "recipients" then
sanitized[k] = v
end
end
table.insert(out, sanitized)
end
end
end
while #out > limit do table.remove(out, 1) end
return {ok=true, entries=out, head=DB.meta.ledger_head}
end
function H.self_audit(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not fs.exists(PATHS.ledger) then return {ok=true, balance=a.balance, computed=0, ok_match=(a.balance == 0)} end
local f = fs.open(PATHS.ledger, "r")
if not f then return {ok=false, err="Ledger unreadable"} end
local running = 0
local touched = 0
while true do
local line = f.readLine()
if not line then break end
local okp, e = pcall(textutils.unserialize, line)
if okp and e then
local delta = 0
if e.account == a.id then
if e.type == "deposit" then delta = e.amount or 0
elseif e.type == "withdraw" then delta = -(e.amount or 0)
elseif e.type == "interest" then delta = e.amount or 0
elseif e.type == "ubi_payout" then
elseif e.type == "cd_open" then delta = -(e.amount or 0)
elseif e.type == "cd_redeem" then delta = e.payout or 0
elseif e.type == "loan_origin" then delta = e.amount or 0
elseif e.type == "loan_repay" then delta = -(e.amount or 0)
elseif e.type == "progress_approve" then delta = e.bounty or 0
elseif e.type == "wo_complete" then delta = e.bounty or 0
elseif e.type == "note_issue" then delta = -(math.floor((e.denom or 0)*100))
elseif e.type == "note_redeem" then delta = math.floor((e.denom or 0)*100)
elseif e.type == "issue" then delta = e.amount or 0
elseif e.type == "admin_adjust" then delta = e.delta or 0
elseif e.type == "item_deposit" then delta = e.value or 0
elseif e.type == "escrow_create" then delta = -(e.amount or 0)
elseif e.type == "escrow_refund" then delta = e.amount or 0
end
running = running + delta
if delta ~= 0 then touched = touched + 1 end
end
if e.type == "transfer" or e.type == "multisig_execute" then
if e.from == a.id then running = running - (e.amount or 0); touched = touched + 1 end
if e.to == a.id then running = running + ((e.amount or 0) - (e.tax or 0)); touched = touched + 1 end
end
if e.type == "shop_sale" then
if e.buyer == a.id then running = running - (e.cost or 0); touched = touched + 1 end
if e.seller == a.id then running = running + ((e.cost or 0) - (e.tax or 0)); touched = touched + 1 end
end
if e.type == "escrow_release" then
end
end
end
f.close()
for _, h in ipairs(a.history) do
if h.type == "ubi" then running = running + (h.amount or 0); touched = touched + 1 end
end
return {ok=true, balance=a.balance, computed=running, ok_match=(a.balance == running),
entries_touched=touched, ledger_head=DB.meta.ledger_head}
end
function H.admin_stats(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local n_acc, n_loan, n_cd, n_frozen = 0, 0, 0, 0
for _ in pairs(DB.accounts) do n_acc = n_acc + 1 end
for _, l in pairs(DB.loans) do if not l.closed then n_loan = n_loan + 1 end end
for _, c in pairs(DB.certs) do if not c.redeemed then n_cd = n_cd + 1 end end
for _ in pairs(DB.policy.frozen) do n_frozen = n_frozen + 1 end
return {ok=true, stats={
accounts=n_acc, active_loans=n_loan, active_cds=n_cd, frozen=n_frozen,
supply=DB.meta.money_supply, loans_out=DB.meta.loans_out,
tx_count=DB.meta.tx_count, policy=DB.policy,
ledger_head=DB.meta.ledger_head, version=VERSION,
mc_month_sec=CFG.MC_MONTH_SEC,
}}
end
function H.admin_list_accounts(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
local filter = type(p.filter) == "string" and p.filter:lower() or ""
for id, a in pairs(DB.accounts) do
if filter == ""
or (a.owner and a.owner:lower():find(filter, 1, true))
or (id:lower():find(filter, 1, true)) then
table.insert(out, {
id=id, owner=a.owner, kind=a.kind, balance=a.balance,
frozen=DB.policy.frozen[id] and true or false,
vanguard_rank=a.vanguard_rank,
civic_jobs=a.civic_jobs,
on_leave=a.on_leave and true or false,
is_treasury=a.is_treasury and true or false,
paired_checking=a.paired_checking,
paired_savings=a.paired_savings,
})
end
end
table.sort(out, function(x, y) return x.id < y.id end)
return {ok=true, accounts=out}
end
function H.admin_account_detail(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
local rank_label = nil
if a.vanguard_rank then
for _, rk in ipairs(CFG.VANGUARD_RANKS or {}) do
if rk.id == a.vanguard_rank then
rank_label = (rk.grade or rk.id) .. "  " .. (rk.label or "")
break
end
end
end
return {ok=true, account={
id=a.id, owner=a.owner, kind=a.kind, balance=a.balance,
created=a.created, history=a.history, joint=a.joint,
frozen=DB.policy.frozen[a.id] and true or false,
locked=DB.policy.locked_pins[a.id],
progress=DB.progress[a.id] or {},
vanguard_rank=a.vanguard_rank,
vanguard_label=rank_label,
civic_jobs=a.civic_jobs,
on_leave=a.on_leave and true or false,
is_treasury=a.is_treasury and true or false,
paired_checking=a.paired_checking,
paired_savings=a.paired_savings,
lots=a.lots,
}}
end
function H.admin_account_history(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
local limit = math.min(math.max(tonumber(p.limit) or 50, 1), 200)
local hist = a.history or {}
local out = {}
local start = math.max(1, #hist - limit + 1)
for i = #hist, start, -1 do
table.insert(out, hist[i])
end
return {ok=true, entries=out}
end
function H.admin_set_pin(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
if not V.pin(p.new_pin) then return {ok=false, err="PIN must be 4 digits"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
a.pin_hash = hashPin(p.new_pin, p.account_id)
DB.policy.locked_pins[p.account_id] = nil
appendLedger{type="admin_set_pin", account=a.id, by_admin=true}
persist()
return {ok=true}
end
function H.vanguard_summary(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local total = 0
local weekly = 0
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then
total = total + 1
for _, rk in ipairs(CFG.VANGUARD_RANKS or {}) do
if rk.id == a.vanguard_rank then
weekly = weekly + (rk.weekly_cents or 0)
break
end
end
end
end
return {ok=true, total=total, weekly_cents=weekly,
max=CFG.VANGUARD_MAX_MEMBERS or 10}
end
function H.vanguard_roster(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then
local label = a.vanguard_rank
local grade = a.vanguard_rank
local weekly = 0
for _, rk in ipairs(CFG.VANGUARD_RANKS or {}) do
if rk.id == a.vanguard_rank then
label = rk.label or rk.id
grade = rk.grade or rk.id
weekly = rk.weekly_cents or 0
break
end
end
table.insert(out, {
account_id=a.id, owner=a.owner,
rank_code=grade, rank_title=label,
weekly_cents=weekly,
on_leave=a.on_leave and true or false,
})
end
end
local rank_order = {}
for i, rk in ipairs(CFG.VANGUARD_RANKS or {}) do
rank_order[rk.id] = i
end
table.sort(out, function(x, y)
local function key(grade)
local first = (grade or ""):sub(1, 1)
if first == "O" then return 1000 + (tonumber(grade:match("%d+")) or 0) end
if first == "W" then return 500 + (tonumber(grade:match("%d+")) or 0) end
if first == "E" then return 0 + (tonumber(grade:match("%d+")) or 0) end
return -1
end
return key(x.rank_code) > key(y.rank_code)
end)
return {ok=true, members=out}
end
function H.admin_set_job_salary(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if type(p.job_id) ~= "string" then return {ok=false, err="Bad job id"} end
if type(p.annual_cents) ~= "number" or p.annual_cents <= 0 then
return {ok=false, err="Bad annual amount"}
end
local job = DB.civic_jobs[p.job_id]
if not job then return {ok=false, err="Job not found"} end
local old = job.annual_cents
job.annual_cents = math.floor(p.annual_cents)
appendLedger{type="job_salary_change", job_id=p.job_id,
title=job.title, old=old, new=job.annual_cents}
persist()
return {ok=true, new_annual=job.annual_cents}
end
function H.admin_set_balance(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
if type(p.new_balance) ~= "number" or p.new_balance ~= math.floor(p.new_balance) then
return {ok=false, err="Balance must be integer cents"} end
local SANE_MIN = -100000000000
local SANE_MAX = 100000000000
if (p.new_balance < SANE_MIN or p.new_balance > SANE_MAX) and not p.confirm_extreme then
return {ok=false, err="Balance outside sane range. If intentional, "
.."pass confirm_extreme=true. (limit: "
..fmtMoney(SANE_MAX)..")"}
end
if not V.short_text(p.reason) or #p.reason < 5 then
return {ok=false, err="Reason required (5-200 chars)"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
local delta = p.new_balance - a.balance
a.balance = p.new_balance
DB.meta.money_supply = DB.meta.money_supply + delta
postHistory(a, {t=now(), type="admin_adjust", amount=delta, note="ADMIN: "..p.reason})
appendLedger{type="admin_adjust", account=a.id, delta=delta, new_balance=p.new_balance, reason=p.reason}
persist()
return {ok=true, new_balance=a.balance}
end
function H.admin_set_policy(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local changed = {}
for k, v in pairs(p.policy or {}) do
if DB.policy[k] ~= nil and type(DB.policy[k]) ~= "table" and type(v) == type(DB.policy[k]) then
DB.policy[k] = v; changed[k] = v
end
end
appendLedger{type="policy_change", changes=changed}
persist()
return {ok=true, policy=DB.policy}
end
function H.admin_delete_account(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
if a.is_treasury then return {ok=false, err="Cannot delete treasury"} end
if a.balance and a.balance > 0 then
local fund = DB.accounts[CFG.FUND_ACCOUNT_ID]
if fund then
fund.balance = fund.balance + a.balance
table.insert(fund.history, {t=now(), type="account_close",
amount=a.balance, note="Closed: "..a.owner.." ("..a.id..")"})
end
end
local k = (a.owner or ""):lower()
if DB.byOwner[k] then
for i, id in ipairs(DB.byOwner[k]) do
if id == a.id then table.remove(DB.byOwner[k], i); break end
end
if #DB.byOwner[k] == 0 then DB.byOwner[k] = nil end
end
if a.civic_jobs then
for jid, _ in pairs(a.civic_jobs) do
local job = DB.civic_jobs[jid]
if job and job.holders then job.holders[a.id] = nil end
end
end
for rid, r in pairs(DB.civic_requests or {}) do
if r.account_id == a.id and r.status == "pending" then
DB.civic_requests[rid] = nil
end
end
for sid, s in pairs(DB.sessions) do
if s.account_id == a.id then DB.sessions[sid] = nil end
end
DB.policy.frozen[a.id] = nil
DB.policy.locked_pins[a.id] = nil
DB.progress[a.id] = nil
DB.activity[a.id] = nil
DB.accounts[a.id] = nil
appendLedger{type="account_delete", account=a.id, owner=a.owner,
balance_refunded=a.balance or 0,
had_rank=(a.vanguard_rank or false),
had_civic_job=(a.civic_jobs and next(a.civic_jobs)) and true or false}
persist()
return {ok=true, refunded=a.balance or 0}
end
function H.admin_freeze(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
DB.policy.frozen[p.account_id] = p.frozen and true or nil
appendLedger{type="freeze", account=p.account_id, frozen=p.frozen}
persist()
return {ok=true}
end
function H.admin_unlock(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
DB.policy.locked_pins[p.account_id] = nil
appendLedger{type="unlock", account=p.account_id}
persist()
return {ok=true}
end
function H.admin_reset_pin(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
if not V.pin(p.new_pin) then return {ok=false, err="PIN must be 4 digits"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
a.pin_hash = hashPin(p.new_pin, a.id)
DB.policy.locked_pins[p.account_id] = nil
appendLedger{type="pin_reset", account=p.account_id}
persist()
return {ok=true}
end
function H.admin_issue(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not DB.policy.issue_enabled then return {ok=false, err="Issuance disabled"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
if type(p.amount) ~= "number" or p.amount ~= math.floor(p.amount) then
return {ok=false, err="Amount must be integer"} end
if not V.short_text(p.reason) or #p.reason < 3 then return {ok=false, err="Reason required"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
a.balance = a.balance + p.amount
DB.meta.money_supply = DB.meta.money_supply + p.amount
postHistory(a, {t=now(), type="issue", amount=p.amount, note="Treasury: "..p.reason})
appendLedger{type="issue", account=a.id, amount=p.amount, reason=p.reason}
persist()
return {ok=true, balance=a.balance}
end
function H.admin_approve_claim(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
if not V.progress_id(p.progress_id) then return {ok=false, err="Bad progress id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Account not found"} end
local item = DB.catalog[p.progress_id]
if not item then return {ok=false, err="Unknown achievement"} end
DB.progress[a.id] = DB.progress[a.id] or {}
local rec = DB.progress[a.id][p.progress_id] or {count=0}
if item.once and rec.approved then return {ok=false, err="Already approved"} end
local bounty = tonumber(p.override_bounty) or item.bounty
if type(bounty) ~= "number" or bounty < 0 then return {ok=false, err="Bad bounty"} end
rec.approved = true
rec.approved_at = now()
rec.count = (rec.count or 0) + 1
rec.last_bounty = bounty
rec.pending_claim = nil
DB.progress[a.id][p.progress_id] = rec
a.balance = a.balance + bounty
DB.meta.money_supply = DB.meta.money_supply + bounty
postHistory(a, {t=now(), type="progress_reward", amount=bounty, note=item.label})
appendLedger{type="progress_approve", account=a.id, progress=p.progress_id, bounty=bounty}
persist()
return {ok=true, balance=a.balance, bounty=bounty}
end
function H.admin_reject_claim(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
if not V.progress_id(p.progress_id) then return {ok=false, err="Bad progress id"} end
DB.progress[p.account_id] = DB.progress[p.account_id] or {}
DB.progress[p.account_id][p.progress_id] = nil
appendLedger{type="progress_reject", account=p.account_id, progress=p.progress_id, reason=p.reason}
persist()
return {ok=true}
end
function H.admin_pending_claims(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for acct, by_prog in pairs(DB.progress) do
for pid, rec in pairs(by_prog) do
if rec.pending_claim and not rec.approved then
local a = DB.accounts[acct]
table.insert(out, {
account=acct, owner=a and a.owner or "?", progress=pid,
label=DB.catalog[pid] and DB.catalog[pid].label or pid,
evidence=rec.evidence, submitted_at=rec.submitted_at,
bounty=DB.catalog[pid] and DB.catalog[pid].bounty or 0,
})
end
end
end
return {ok=true, claims=out}
end
function H.admin_post_work_order(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.short_text(p.title) or #p.title < 3 then return {ok=false, err="Title required"} end
if type(p.bounty) ~= "number" or p.bounty <= 0 then return {ok=false, err="Bounty required"} end
local fund = DB.accounts[CFG.FUND_ACCOUNT_ID]
if not fund then return {ok=false, err="Fund missing"} end
if fund.balance < p.bounty then
return {ok=false, err=string.format(
"Fund balance %s < bounty %s",
fmtMoney(fund.balance), fmtMoney(p.bounty))}
end
fund.balance = fund.balance - p.bounty
local id = "WO-" .. crypto.random_bytes(4)
DB.work_orders[id] = {
id=id, title=p.title, bounty=p.bounty, posted_by="Vanguard Reserve",
posted_at=now(), claimed_by=nil, completed=false,
description=V.short_text(p.description) and p.description or nil,
}
table.insert(fund.history, {t=now(), type="wo_reserve",
amount=-p.bounty, note="Work Order posted: "..p.title})
appendLedger{type="wo_post", order=id, title=p.title, bounty=p.bounty,
from_fund=true}
persist()
return {ok=true, order_id=id}
end
function H.admin_complete_work_order(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local wo = DB.work_orders[p.order_id]
if not wo or wo.completed then return {ok=false, err="Order not open"} end
if not wo.claimed_by then
return {ok=false, err="No worker has accepted this order yet"}
end
local a = DB.accounts[wo.claimed_by]
if not a then return {ok=false, err="Worker account gone"} end
wo.completed = true
wo.completed_at = now()
wo.paid_to = a.id
a.balance = a.balance + wo.bounty
postHistory(a, {t=now(), type="wo_payout", amount=wo.bounty,
note="Work Order: "..wo.title})
appendLedger{type="wo_complete", order=wo.id, account=a.id, bounty=wo.bounty,
owner=a.owner}
persist()
return {ok=true, balance=a.balance, paid_to=a.id, owner=a.owner}
end
function H.admin_delete_work_order(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local wo = DB.work_orders[p.order_id]
if not wo then return {ok=false, err="Not found"} end
if wo.completed then return {ok=false, err="Already completed; can't delete"} end
local fund = DB.accounts[CFG.FUND_ACCOUNT_ID]
if fund then
fund.balance = fund.balance + wo.bounty
table.insert(fund.history, {t=now(), type="wo_refund",
amount=wo.bounty, note="Work Order deleted: "..wo.title})
end
DB.work_orders[wo.id] = nil
appendLedger{type="wo_delete", order=wo.id, title=wo.title, bounty=wo.bounty,
refund_to_fund=fund ~= nil}
persist()
return {ok=true}
end
function H.cancel_work_order_claim(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local wo = DB.work_orders[p.order_id]
if not wo then return {ok=false, err="Order not found"} end
if wo.completed then return {ok=false, err="Already completed"} end
if wo.claimed_by ~= a.id then return {ok=false, err="Not your claim"} end
wo.claimed_by = nil
wo.claimed_at = nil
appendLedger{type="wo_unclaim", order=wo.id, account=a.id, owner=a.owner}
persist()
return {ok=true}
end
function H.admin_ledger_tail(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local limit = math.min(tonumber(p.limit) or 50, 500)
if not fs.exists(PATHS.ledger) then return {ok=true, entries={}} end
local f = fs.open(PATHS.ledger, "r")
if not f then return {ok=false, err="Ledger unreadable"} end
local lines = {}
while true do
local line = f.readLine()
if not line then break end
table.insert(lines, line)
if #lines > limit then table.remove(lines, 1) end
end
f.close()
local entries = {}
for _, l in ipairs(lines) do
local ok, e = pcall(textutils.unserialize, l)
if ok then table.insert(entries, e) end
end
return {ok=true, entries=entries, head=DB.meta.ledger_head}
end
function H.admin_verify_ledger(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local ok, result = verifyLedgerChain()
return {ok=true, chain_ok=ok, result=result}
end
function H.admin_rotate_secret(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
SERVER_SECRET = crypto.random_bytes(32)
writeAtomic(PATHS.secret, SERVER_SECRET)
DB.sessions = {}
appendLedger{type="rotate_secret"}
persist()
return {ok=true}
end
function H.admin_set_item_rate(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if type(p.item) ~= "string" or #p.item > 80 then return {ok=false, err="Bad item"} end
if p.rate ~= nil and (type(p.rate) ~= "number" or p.rate < 0) then return {ok=false, err="Bad rate"} end
if p.rate == nil then
DB.policy.item_backing_map[p.item] = nil
else
DB.policy.item_backing_map[p.item] = math.floor(p.rate)
end
appendLedger{type="item_rate_change", item=p.item, rate=p.rate}
persist()
return {ok=true, rates=DB.policy.item_backing_map}
end
function H.admin_deactivate_shop(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.shop_id(p.shop_id) then return {ok=false, err="Bad shop"} end
local shop = DB.shops[p.shop_id]
if not shop then return {ok=false, err="Not found"} end
shop.active = false
appendLedger{type="shop_deactivate", shop=p.shop_id, reason=p.reason}
persist()
return {ok=true}
end
function H.admin_list_factions(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for id, fac in pairs(DB.factions) do
local n_members = 0
for _ in pairs(fac.members) do n_members = n_members + 1 end
local treasury = DB.accounts[fac.treasury_account]
table.insert(out, {
id=id, name=fac.name, members=n_members,
threshold=fac.threshold_n.."/"..fac.threshold_m,
treasury=fac.treasury_account,
treasury_balance=treasury and treasury.balance or 0,
})
end
return {ok=true, factions=out}
end
function H.admin_set_tax_bracket(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if type(p.brackets) ~= "table" then return {ok=false, err="Bad brackets"} end
for _, b in ipairs(p.brackets) do
if type(b.above) ~= "number" or type(b.rate) ~= "number" or b.rate < 0 or b.rate > 0.5 then
return {ok=false, err="Each bracket needs {above=N, rate=R} with 0<=R<=0.5"}
end
end
table.sort(p.brackets, function(a,b) return a.above < b.above end)
DB.policy.tax_brackets = p.brackets
appendLedger{type="tax_brackets", brackets=p.brackets}
persist()
return {ok=true}
end
function H.admin_set_ubi(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if p.enabled ~= nil then DB.policy.ubi_enabled = p.enabled and true or false end
if type(p.weekly) == "number" and p.weekly >= 0 then
DB.policy.ubi_weekly = math.floor(p.weekly)
end
appendLedger{type="ubi_set", enabled=DB.policy.ubi_enabled, weekly=DB.policy.ubi_weekly}
persist()
return {ok=true, ubi_enabled=DB.policy.ubi_enabled, ubi_weekly=DB.policy.ubi_weekly}
end
function H.admin_set_supply_target(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if p.enabled ~= nil then DB.policy.supply_target_enabled = p.enabled and true or false end
if type(p.low) == "number" and p.low >= 0 then DB.policy.supply_target_low = p.low end
if type(p.high) == "number" and p.high >= 0 then DB.policy.supply_target_high = p.high end
appendLedger{type="supply_target", enabled=DB.policy.supply_target_enabled,
low=DB.policy.supply_target_low, high=DB.policy.supply_target_high}
persist()
return {ok=true}
end
function H.admin_force_ubi(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
DB.last_ubi_run = 0
distributeUBI()
return {ok=true}
end
function H.admin_cancel_recurring(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.recur_id(p.recur_id) then return {ok=false, err="Bad id"} end
local r = DB.recurring[p.recur_id]
if not r then return {ok=false, err="Not found"} end
r.active = false
appendLedger{type="recurring_cancel_admin", recur=p.recur_id}
persist()
return {ok=true}
end
function H.admin_list_recurring(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for id, r in pairs(DB.recurring) do
if r.active then
table.insert(out, {
id=id, from=r.from, to=r.to, amount=r.amount, memo=r.memo,
interval_sec=r.interval_sec, next_run=r.next_run,
remaining=r.remaining,
})
end
end
return {ok=true, recurring=out}
end
function H.admin_issue_note(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
if type(p.denomination) ~= "number" then return {ok=false, err="Bad denomination"} end
local denom_cents = math.floor(p.denomination * 100)
if denom_cents <= 0 or a.balance < denom_cents then return {ok=false, err="Insufficient funds"} end
a.balance = a.balance - denom_cents
local serial = "VRN-" .. crypto.random_bytes(6):upper()
local issued = now()
local blob = {serial=serial, denom=p.denomination, issued=issued, account=a.id}
blob.sig = crypto.hmac(SERVER_SECRET, textutils.serialize(blob))
DB.cards[serial] = {kind="note", denom=p.denomination, issued=issued, redeemed=false}
postHistory(a, {t=now(), type="note_issue", amount=-denom_cents, note="Note "..serial})
appendLedger{type="note_issue", account=a.id, serial=serial, denom=p.denomination}
persist()
return {ok=true, note=blob, balance=a.balance}
end
function H.admin_submit_snapshot(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if type(p.snapshots) ~= "table" then return {ok=false, err="Bad snapshots"} end
if not DB.earnings_enabled then return {ok=false, err="Earnings disabled"} end
local results = {}
local total_paid = 0
local paid_count = 0
local active_owners = {}
for owner, snap in pairs(p.snapshots) do
if V.username(owner) and type(snap) == "table" then
local breakdown = computeEarnings(owner, snap, tonumber(p.session_sec))
payEarnings(owner, breakdown)
chargeInsuranceIfDue(owner)
if breakdown.skipped ~= "below_session_threshold" then
active_owners[owner:lower()] = true
end
results[owner] = {
total = breakdown.total or 0,
skipped = breakdown.skipped,
died = breakdown.died_today,
streak = breakdown.streak_after,
error = breakdown.error,
}
if breakdown.total and breakdown.total > 0 then
total_paid = total_paid + breakdown.total
paid_count = paid_count + 1
end
if breakdown.died_today then
notify(owner, "death", "red", string.format(
"You died yesterday. Streak dropped from %d to %d.",
breakdown.streak_before or 0, breakdown.streak_after or 0))
elseif breakdown.total and breakdown.total > 0 then
local streak_str = ""
if breakdown.streak_mult and breakdown.streak_mult > 1 then
streak_str = string.format(" (streak day %d, %.2fx)",
breakdown.streak_after or 0, breakdown.streak_mult or 1)
end
notify(owner, "daily", "green",
string.format("+%s earned today%s", fmtMoney(breakdown.total), streak_str))
local before = breakdown.streak_before or 0
local after = breakdown.streak_after or 0
for _, t in ipairs(CFG.EARNINGS_STREAK_TIERS) do
if before < t.day and after >= t.day and t.day > 0 then
notify(owner, "streak", "gold", string.format(
"Streak milestone: %s tier (%.2fx multiplier)",
t.label, t.mult))
end
end
end
local st = DB.earnings_state[owner:lower()]
if st and st.insurance_until then
local days_left = math.floor((st.insurance_until - now()) / 86400)
local ns = notifStateFor(owner:lower())
if days_left == CFG.NOTIF_INSURANCE_WARN_DAYS
and (not ns.last_insurance_warn or now() - ns.last_insurance_warn > 24*3600) then
notify(owner, "insurance", "yellow", string.format(
"Death Insurance policy expires in %d days.", days_left))
ns.last_insurance_warn = now()
end
end
end
end
DB.last_earnings_run = now()
appendLedger{type="earnings_tick", players=paid_count, total=total_paid}
persist()
return {ok=true, results=results, total_paid=total_paid, players=paid_count}
end
local processAutoPayments
function H.admin_run_minecraft_day_tick(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local mc_day = tonumber(p.mc_day)
if not mc_day then return {ok=false, err="Bad mc_day"} end
local already = DB.last_mc_day_tick and DB.last_mc_day_tick > 0
and mc_day <= DB.last_mc_day_tick
if not p.force and already then
return {ok=true, paid_already=true, mc_day=mc_day,
payroll_total=0, payroll_count=0,
civic_total=0, civic_count=0}
end
local payroll_total, payroll_count = 0, 0
local civic_total, civic_count = 0, 0
local ok_p, err_p = pcall(function()
payroll_total, payroll_count = runPayroll()
end)
if not ok_p then
DIAG.last_error_time = now()
DIAG.last_error_method = "runPayroll"
DIAG.last_error_detail = tostring(err_p):sub(1, 200)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
end
local ok_c, err_c = pcall(function()
civic_total, civic_count = runCivicPayroll()
end)
if not ok_c then
DIAG.last_error_time = now()
DIAG.last_error_method = "runCivicPayroll"
DIAG.last_error_detail = tostring(err_c):sub(1, 200)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
end
if not p.force then
DB.last_mc_day_tick = mc_day
end
local auto_count, auto_total = 0, 0
pcall(function()
auto_count, auto_total = processAutoPayments()
end)
pcall(persist)
return {ok=true, mc_day=mc_day,
payroll_total=payroll_total, payroll_count=payroll_count,
civic_total=civic_total, civic_count=civic_count,
auto_paid_count=auto_count, auto_paid_total=auto_total,
payroll_err=(not ok_p) and tostring(err_p):sub(1, 80) or nil,
civic_err=(not ok_c) and tostring(err_c):sub(1, 80) or nil}
end
function H.admin_set_earnings_enabled(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
DB.earnings_enabled = p.enabled and true or false
appendLedger{type="earnings_toggle", enabled=DB.earnings_enabled}
persist()
return {ok=true, enabled=DB.earnings_enabled}
end
function H.admin_set_pvp_enabled(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
DB.earnings_pvp_enabled = p.enabled and true or false
appendLedger{type="pvp_toggle", enabled=DB.earnings_pvp_enabled}
persist()
return {ok=true, enabled=DB.earnings_pvp_enabled}
end
function H.admin_earnings_state(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.username(p.owner or "") then return {ok=false, err="Bad owner"} end
local st = DB.earnings_state[p.owner:lower()]
local last = DB.earnings_last[p.owner:lower()]
if not st then return {ok=true, found=false} end
return {ok=true, found=true, state={
streak_days = st.streak_days,
last_active_day = st.last_active_day,
insurance_until = st.insurance_until,
build_streak = st.build_streak,
boss_claimed = st.boss_claimed,
last_death_ts = st.last_death_ts,
last_death_penalty_from = st.last_death_penalty_from,
flags = st.flags,
}, last_breakdown=last}
end
function H.admin_set_streak(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.username(p.owner or "") then return {ok=false, err="Bad owner"} end
if type(p.days) ~= "number" or p.days < 0 or p.days > 10000 then
return {ok=false, err="Bad days"} end
local st = earningsStateFor(p.owner:lower())
st.streak_days = math.floor(p.days)
appendLedger{type="streak_override", owner=p.owner, days=st.streak_days}
persist()
return {ok=true, streak_days=st.streak_days}
end
function H.my_earnings(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local breakdown = DB.earnings_last[a.owner:lower()]
local st = DB.earnings_state[a.owner:lower()]
return {ok=true,
breakdown = breakdown,
streak_days = st and st.streak_days or 0,
streak_mult = streakTierFor(st and st.streak_days or 0).mult,
streak_label = streakTierFor(st and st.streak_days or 0).label,
insurance_active = st and st.insurance_until and st.insurance_until > now(),
insurance_until = st and st.insurance_until,
enabled = DB.earnings_enabled,
}
end
function H.buy_insurance(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if a.balance < CFG.EARNINGS_INSURANCE_COST then
return {ok=false, err="Insufficient funds (need "..fmtMoney(CFG.EARNINGS_INSURANCE_COST)..")"}
end
local st = earningsStateFor(a.owner:lower())
a.balance = a.balance - CFG.EARNINGS_INSURANCE_COST
DB.meta.money_supply = DB.meta.money_supply - CFG.EARNINGS_INSURANCE_COST
local base_start = (st.insurance_until and st.insurance_until > now())
and st.insurance_until or now()
st.insurance_until = base_start + CFG.EARNINGS_INSURANCE_DURATION
st.insurance_last_charge = now()
postHistory(a, {t=now(), type="insurance", amount=-CFG.EARNINGS_INSURANCE_COST,
note="Death Insurance policy"})
appendLedger{type="insurance_charge", account=a.id, amount=CFG.EARNINGS_INSURANCE_COST}
persist()
return {ok=true, insurance_until=st.insurance_until, balance=a.balance}
end
function H.cancel_insurance(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local st = earningsStateFor(a.owner:lower())
st.insurance_until = now()
appendLedger{type="insurance_cancel", account=a.id}
persist()
return {ok=true}
end
function H.my_notif_subs(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local subs = subsFor(a.owner:lower())
local channels = {}
for _, ch in ipairs(CFG.NOTIF_CHANNELS) do
table.insert(channels, {
id = ch[1], default = ch[2], label = ch[3], description = ch[4],
subscribed = subs[ch[1]] and true or false,
})
end
return {ok=true, channels=channels}
end
function H.set_notif_subs(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if type(p.subs) ~= "table" then return {ok=false, err="Bad subs"} end
local subs = subsFor(a.owner:lower())
local valid_channels = {}
for _, ch in ipairs(CFG.NOTIF_CHANNELS) do valid_channels[ch[1]] = true end
for ch_id, val in pairs(p.subs) do
if valid_channels[ch_id] then
subs[ch_id] = val and true or false
end
end
appendLedger{type="notif_subs_set", account=a.id}
persist()
return {ok=true, subs=subs}
end
function H.my_earnings_history(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local hist = DB.earnings_history[a.owner:lower()] or {}
local limit = math.min(tonumber(p.limit) or 30, CFG.EARNINGS_HISTORY_DEPTH)
local out = {}
for i = #hist, math.max(1, #hist - limit + 1), -1 do
table.insert(out, hist[i])
end
local week = {}
local week_total = 0
local week_components = {survival_wage=0, combat_pay=0, explorer_bonus=0,
builder_bonus=0, danger_pay=0, boss_bounty=0,
build_streak_bonus=0}
local start_idx = math.max(1, #hist - 6)
for i = start_idx, #hist do
local e = hist[i]
table.insert(week, e)
week_total = week_total + (e.total or 0)
for k, _ in pairs(week_components) do
week_components[k] = week_components[k] + (e[k] or 0)
end
end
return {ok=true, history=out, week=week,
week_total=week_total, week_components=week_components}
end
function H.admin_pull_notifications(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local n = math.min(tonumber(p.limit) or 50, CFG.NOTIF_OUTBOX_MAX)
local out = {}
for i = 1, math.min(n, #DB.notif_outbox) do
table.insert(out, DB.notif_outbox[i])
end
if p.clear and #out > 0 then
for _ = 1, #out do table.remove(DB.notif_outbox, 1) end
persist()
end
return {ok=true, notifications=out, remaining=#DB.notif_outbox - (p.clear and 0 or #out)}
end
function H.admin_list_farm_flags(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local pending = {}
for id, fl in pairs(DB.farm_flags) do
if fl.status == "pending" then
table.insert(pending, {
id = id, owner = fl.owner, entity = fl.entity,
count = fl.count, estimated_pay = fl.estimated_pay,
ts = fl.ts,
})
end
end
table.sort(pending, function(a, b) return a.ts < b.ts end)
return {ok=true, flags=pending}
end
function H.admin_review_flag(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if type(p.flag_id) ~= "string" then return {ok=false, err="Bad flag id"} end
local fl = DB.farm_flags[p.flag_id]
if not fl or fl.status ~= "pending" then return {ok=false, err="Not pending"} end
if p.action == "confirm" then
fl.status = "confirmed"
fl.decided_ts = now()
appendLedger{type="farm_flag_confirm", flag=p.flag_id, owner=fl.owner}
elseif p.action == "override" then
fl.status = "override"
fl.decided_ts = now()
local acc = primaryAccountFor(fl.owner)
if acc and not DB.policy.frozen[acc.id] then
acc.balance = acc.balance + fl.estimated_pay
DB.meta.money_supply = DB.meta.money_supply + fl.estimated_pay
table.insert(acc.history, {
t=now(), type="farm_flag_override",
amount=fl.estimated_pay,
note="Admin override on flag "..p.flag_id,
})
if #acc.history > 200 then table.remove(acc.history, 1) end
appendLedger{type="farm_flag_override", flag=p.flag_id,
owner=fl.owner, paid=fl.estimated_pay, account=acc.id}
end
else
return {ok=false, err="action must be confirm or override"}
end
persist()
return {ok=true, status=fl.status}
end
function H.list_ranks(p)
local out = {}
for _, r in ipairs(CFG.VANGUARD_RANKS) do
table.insert(out, {
id = r.id, grade = r.grade, group = r.group, label = r.label,
weekly_cents = r.weekly_cents,
yearly_cents = r.weekly_cents * 52,
daily_cents = math.floor(r.weekly_cents / 7),
})
end
return {ok=true, ranks=out, max_members=CFG.VANGUARD_MAX_MEMBERS,
current_count=vanguardCount()}
end
function H.admin_set_rank(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
if a.is_treasury then return {ok=false, err="Cannot rank a treasury"} end
if a.kind == "savings" then
if a.paired_checking and DB.accounts[a.paired_checking] then
a = DB.accounts[a.paired_checking]
else
return {ok=false, err="Savings account; no paired checking"}
end
end
if p.rank_id == nil or p.rank_id == "" or p.rank_id == false then
if not a.vanguard_rank then return {ok=false, err="Not a Vanguard member"} end
local prev = a.vanguard_rank
a.vanguard_rank = nil
a.vanguard_on_leave = nil
a.vanguard_assigned_at = nil
a.vanguard_week_paid = nil
a.vanguard_week_days = nil
appendLedger{type="rank_remove", account=a.id, owner=a.owner, prev_rank=prev}
persist()
return {ok=true, removed=true}
end
local rank = rankFor(p.rank_id)
if not rank then return {ok=false, err="Bad rank id"} end
if not a.vanguard_rank then
if vanguardCount() >= CFG.VANGUARD_MAX_MEMBERS then
return {ok=false, err=string.format(
"Vanguard hard cap reached (%d/%d). Remove a member first.",
vanguardCount(), CFG.VANGUARD_MAX_MEMBERS)}
end
end
local prev = a.vanguard_rank
a.vanguard_rank = rank.id
a.vanguard_assigned_at = a.vanguard_assigned_at or now()
appendLedger{
type=prev and "rank_change" or "rank_assign",
account=a.id, owner=a.owner,
prev_rank=prev, new_rank=rank.id, weekly=rank.weekly_cents,
}
persist()
return {ok=true, rank={id=rank.id, grade=rank.grade, label=rank.label,
weekly_cents=rank.weekly_cents,
yearly_cents=rank.weekly_cents * 52}}
end
function H.admin_set_leave(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
if not a.vanguard_rank then return {ok=false, err="Not a Vanguard member"} end
a.vanguard_on_leave = p.on_leave and true or false
appendLedger{type="rank_leave", account=a.id, owner=a.owner,
on_leave=a.vanguard_on_leave}
persist()
return {ok=true, on_leave=a.vanguard_on_leave}
end
function H.admin_list_vanguard(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then
local rank = rankFor(a.vanguard_rank)
table.insert(out, {
account_id = a.id, owner = a.owner,
rank_id = a.vanguard_rank,
rank_grade = rank and rank.grade or "?",
rank_label = rank and rank.label or "?",
weekly_cents = rank and rank.weekly_cents or 0,
balance = a.balance,
on_leave = a.vanguard_on_leave and true or false,
week_paid = a.vanguard_week_paid or 0,
week_days = a.vanguard_week_days or 0,
assigned_at = a.vanguard_assigned_at,
})
end
end
local function rank_idx(rid)
for i, r in ipairs(CFG.VANGUARD_RANKS) do
if r.id == rid then return i end
end
return 0
end
table.sort(out, function(a, b)
return rank_idx(a.rank_id) > rank_idx(b.rank_id)
end)
return {ok=true, members=out,
count=#out, max=CFG.VANGUARD_MAX_MEMBERS}
end
function H.admin_set_vanguard_enabled(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
CFG.VANGUARD_ENABLED = p.enabled and true or false
appendLedger{type="vanguard_toggle", enabled=CFG.VANGUARD_ENABLED}
persist()
return {ok=true, enabled=CFG.VANGUARD_ENABLED}
end
function H.my_rank(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if not a.vanguard_rank then return {ok=true, vanguard=false} end
local r = rankFor(a.vanguard_rank)
return {ok=true, vanguard=true, rank={
id = r.id, grade = r.grade, label = r.label, group = r.group,
weekly_cents = r.weekly_cents,
yearly_cents = r.weekly_cents * 52,
daily_cents = math.floor(r.weekly_cents / 7),
}, on_leave = a.vanguard_on_leave and true or false,
assigned_at = a.vanguard_assigned_at,
week_paid = a.vanguard_week_paid or 0,
week_days = a.vanguard_week_days or 0}
end
function H.vanguard_payroll_summary(p)
local total_weekly = 0
local count = 0
local groups = {Officer=0, Warrant=0, Enlisted=0}
for _, a in pairs(DB.accounts) do
if a.vanguard_rank then
local r = rankFor(a.vanguard_rank)
if r then
total_weekly = total_weekly + r.weekly_cents
count = count + 1
groups[r.group] = (groups[r.group] or 0) + 1
end
end
end
return {ok=true, total_weekly=total_weekly,
total_yearly=total_weekly * 52,
total_daily=math.floor(total_weekly / 7),
count=count, groups=groups}
end
function H.admin_list_jobs(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for id, job in pairs(DB.civic_jobs) do
local holder_count = 0
for _ in pairs(job.holders or {}) do holder_count = holder_count + 1 end
table.insert(out, {
id=id, title=job.title, annual_cents=job.annual_cents,
weekly_cents=math.floor(job.annual_cents / 52),
daily_cents=dailyJobCents(job.annual_cents),
holder_count=holder_count,
created_at=job.created_at,
})
end
table.sort(out, function(a, b) return a.annual_cents > b.annual_cents end)
local total_annual = 0
for _, j in ipairs(out) do
total_annual = total_annual + j.annual_cents * j.holder_count
end
return {ok=true, jobs=out,
total_annual=total_annual,
total_weekly=math.floor(total_annual / 52),
total_daily=math.floor(total_annual / 365)}
end
function H.admin_list_work_orders(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for id, wo in pairs(DB.work_orders) do
if not wo.completed or p.include_completed then
local entry = {
id=wo.id, title=wo.title, bounty=wo.bounty,
posted_by=wo.posted_by, posted_at=wo.posted_at,
claimed_by=wo.claimed_by, claimed_at=wo.claimed_at,
completed=wo.completed, completed_at=wo.completed_at,
paid_to=wo.paid_to, description=wo.description,
}
if wo.claimed_by then
local a = DB.accounts[wo.claimed_by]
if a then entry.claimed_owner = a.owner end
end
table.insert(out, entry)
end
end
table.sort(out, function(a, b) return (a.posted_at or 0) > (b.posted_at or 0) end)
return {ok=true, orders=out}
end
function H.admin_create_job(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local title = (type(p.title) == "string") and p.title:gsub("^%s*(.-)%s*$", "%1") or ""
if #title < 2 or #title > 40 then
return {ok=false, err="Title must be 2-40 chars"} end
local annual = tonumber(p.annual_cents)
if not annual or annual <= 0 then
return {ok=false, err="Bad annual_cents"} end
if annual > 100 * 100 * 1000 * 1000 then
return {ok=false, err="Annual cap is $1B/yr"} end
for _, j in pairs(DB.civic_jobs) do
if j.title:lower() == title:lower() then
return {ok=false, err="Title already exists: "..j.title} end
end
local jid = "JOB-" .. crypto.random_bytes(6)
DB.civic_jobs[jid] = {
id=jid, title=title, annual_cents=annual,
holders={}, created_at=now(),
}
appendLedger{type="job_create", job_id=jid, title=title, annual=annual}
persist()
return {ok=true, job_id=jid, title=title, annual_cents=annual,
weekly_cents=math.floor(annual/52),
daily_cents=dailyJobCents(annual)}
end
function H.admin_edit_job(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local job = DB.civic_jobs[p.job_id]
if not job then return {ok=false, err="Job not found"} end
local prev_title = job.title
local prev_annual = job.annual_cents
if type(p.title) == "string" then
local t = p.title:gsub("^%s*(.-)%s*$", "%1")
if #t < 2 or #t > 40 then return {ok=false, err="Title 2-40 chars"} end
for jid2, j2 in pairs(DB.civic_jobs) do
if jid2 ~= p.job_id and j2.title:lower() == t:lower() then
return {ok=false, err="Title collides with "..j2.title} end
end
job.title = t
end
if p.annual_cents ~= nil then
local a = tonumber(p.annual_cents)
if not a or a <= 0 then return {ok=false, err="Bad annual_cents"} end
if a > 100 * 100 * 1000 * 1000 then
return {ok=false, err="Annual cap is $1B/yr"} end
job.annual_cents = a
end
appendLedger{type="job_edit", job_id=job.id,
prev_title=prev_title, new_title=job.title,
prev_annual=prev_annual, new_annual=job.annual_cents}
persist()
return {ok=true, job_id=job.id, title=job.title,
annual_cents=job.annual_cents}
end
function H.admin_delete_job(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local job = DB.civic_jobs[p.job_id]
if not job then return {ok=false, err="Job not found"} end
local removed = 0
for acct_id, _ in pairs(job.holders or {}) do
local a = DB.accounts[acct_id]
if a and a.civic_jobs then
a.civic_jobs[job.id] = nil
if not next(a.civic_jobs) then a.civic_jobs = nil end
removed = removed + 1
end
end
appendLedger{type="job_delete", job_id=job.id, title=job.title,
holders_removed=removed}
DB.civic_jobs[job.id] = nil
persist()
return {ok=true, holders_removed=removed}
end
function H.admin_assign_job(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a then return {ok=false, err="Not found"} end
if a.is_treasury then return {ok=false, err="Treasury cannot hold a job"} end
if a.kind == "savings" then
if a.paired_checking and DB.accounts[a.paired_checking] then
a = DB.accounts[a.paired_checking]
else
return {ok=false, err="Savings account; no paired checking"}
end
end
local job = DB.civic_jobs[p.job_id]
if not job then return {ok=false, err="Job not found"} end
a.civic_jobs = a.civic_jobs or {}
if next(a.civic_jobs) and not p.force then
local existing
for jid, _ in pairs(a.civic_jobs) do existing = jid; break end
local existing_title = (DB.civic_jobs[existing] or {}).title or existing
return {ok=false, err="Already holds: "..existing_title..". Clear it first."}
end
if a.civic_jobs[job.id] then
return {ok=false, err="Already holds this job"} end
a.civic_jobs[job.id] = {assigned_at=now(), on_leave=false,
week_paid=0, week_days=0}
job.holders[a.id] = true
appendLedger{type="job_assign", job_id=job.id, title=job.title,
account=a.id, owner=a.owner, annual=job.annual_cents}
persist()
return {ok=true, job_id=job.id}
end
function H.admin_unassign_job(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a or not a.civic_jobs or not a.civic_jobs[p.job_id] then
return {ok=false, err="Not a holder"} end
local job = DB.civic_jobs[p.job_id]
a.civic_jobs[p.job_id] = nil
if not next(a.civic_jobs) then a.civic_jobs = nil end
if job then job.holders[a.id] = nil end
appendLedger{type="job_remove", job_id=p.job_id,
title=job and job.title or "?",
account=a.id, owner=a.owner}
persist()
return {ok=true}
end
function H.admin_set_job_leave(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
if not V.account_id(p.account_id) then return {ok=false, err="Bad id"} end
local a = DB.accounts[p.account_id]
if not a or not a.civic_jobs or not a.civic_jobs[p.job_id] then
return {ok=false, err="Not a holder"} end
a.civic_jobs[p.job_id].on_leave = p.on_leave and true or false
appendLedger{type="job_leave", job_id=p.job_id,
account=a.id, owner=a.owner,
on_leave=a.civic_jobs[p.job_id].on_leave}
persist()
return {ok=true, on_leave=a.civic_jobs[p.job_id].on_leave}
end
function H.list_civic_jobs(p)
local jobs = {}
for id, j in pairs(DB.civic_jobs) do
local n_holders = 0
for _ in pairs(j.holders or {}) do n_holders = n_holders + 1 end
table.insert(jobs, {
id=j.id, title=j.title, annual_cents=j.annual_cents,
holders=n_holders,
})
end
table.sort(jobs, function(a, b) return a.title < b.title end)
local current_job
local pending_req
local me = nil
if V.session(p.session) then
local s, _ = resolveSession(p.session)
if s then
me = DB.accounts[s.account_id]
if me and me.civic_jobs then
for jid, _ in pairs(me.civic_jobs) do current_job = jid; break end
end
if me then
for _, r in pairs(DB.civic_requests or {}) do
if r.account_id == me.id and r.status == "pending" then
pending_req = r.id; break
end
end
end
end
end
return {ok=true, jobs=jobs, current_job=current_job,
pending_request=pending_req}
end
function H.request_civic_job(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if a.is_treasury then return {ok=false, err="Treasury cannot apply"} end
if not p.job_id or not DB.civic_jobs[p.job_id] then
return {ok=false, err="Unknown job"}
end
if a.civic_jobs and next(a.civic_jobs) then
return {ok=false, err="You already hold a civic job. Have an admin clear it first."}
end
for _, r in pairs(DB.civic_requests or {}) do
if r.account_id == a.id and r.status == "pending" then
return {ok=false, err="You already have a pending request: "..r.id}
end
end
local rid = "REQ-" .. crypto.random_bytes(4)
DB.civic_requests = DB.civic_requests or {}
DB.civic_requests[rid] = {
id=rid, account_id=a.id, owner=a.owner,
job_id=p.job_id, requested_at=now(), status="pending",
}
appendLedger{type="civic_request", request=rid,
account=a.id, owner=a.owner, job_id=p.job_id}
persist()
return {ok=true, request_id=rid}
end
function H.cancel_civic_request(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local rid = p.request_id
local r = DB.civic_requests and DB.civic_requests[rid]
if not r then return {ok=false, err="Request not found"} end
if r.account_id ~= a.id then return {ok=false, err="Not your request"} end
if r.status ~= "pending" then return {ok=false, err="Already decided"} end
DB.civic_requests[rid] = nil
appendLedger{type="civic_request_cancel", request=rid,
account=a.id, owner=a.owner}
persist()
return {ok=true}
end
function H.request_payment(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if a.kind ~= "checking" then
return {ok=false, err="Sign in as your checking account"}
end
if not V.username(p.target_owner or "") then
return {ok=false, err="Invalid target username"}
end
if not V.amount(p.amount) or p.amount <= 0 then
return {ok=false, err="Invalid amount"}
end
if p.amount > 1e9 then return {ok=false, err="Amount too large"} end
local memo = V.short_text(p.memo) and p.memo or nil
local target_lower = p.target_owner:lower()
if target_lower == a.owner:lower() then
return {ok=false, err="Cannot request from yourself"}
end
if target_lower == CFG.FUND_OWNER:lower() then
return {ok=false, err="Cannot bill the treasury"}
end
local target_ids = DB.byOwner[target_lower] or {}
local target_chk
for _, id in ipairs(target_ids) do
local acc = DB.accounts[id]
if acc and acc.kind == "checking" and not acc.is_treasury then
target_chk = acc; break
end
end
if not target_chk then
return {ok=false, err="Target has no account"}
end
local pending_from_sender = 0
for _, r in pairs(DB.payment_requests or {}) do
if r.status == "pending"
and r.from_owner:lower() == a.owner:lower()
and r.to_owner:lower() == target_lower then
pending_from_sender = pending_from_sender + 1
end
end
if pending_from_sender >= 5 then
return {ok=false, err="Too many pending requests to that user"}
end
local rid = "PRQ-" .. crypto.random_bytes(4)
DB.payment_requests = DB.payment_requests or {}
DB.payment_requests[rid] = {
id = rid,
from_owner = a.owner,
from_account= a.id,
to_owner = target_chk.owner,
to_account = target_chk.id,
amount = p.amount,
memo = memo,
requested_at= now(),
status = "pending",
}
appendLedger{type="payment_request", id=rid,
from=a.owner, to=target_chk.owner,
amount=p.amount, memo=memo}
persist()
return {ok=true, request_id=rid}
end
function H.list_payment_requests(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local include_decided = p.include_decided and true or false
local out = {}
for _, r in pairs(DB.payment_requests or {}) do
if r.to_owner:lower() == a.owner:lower() then
local active = (r.status == "pending"
or r.status == "auto_pending")
if include_decided or active then
table.insert(out, {
id=r.id, from_owner=r.from_owner,
amount=r.amount, memo=r.memo,
requested_at=r.requested_at,
status=r.status, decided_at=r.decided_at,
auto_armed_at=r.auto_armed_at,
})
end
end
end
table.sort(out, function(x, y)
return (x.requested_at or 0) > (y.requested_at or 0)
end)
return {ok=true, requests=out}
end
function H.list_my_sent_requests(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local include_decided = p.include_decided and true or false
local out = {}
for _, r in pairs(DB.payment_requests or {}) do
if r.from_owner:lower() == a.owner:lower() then
local active = (r.status == "pending"
or r.status == "auto_pending")
if include_decided or active then
table.insert(out, {
id=r.id, to_owner=r.to_owner,
amount=r.amount, memo=r.memo,
requested_at=r.requested_at,
status=r.status, decided_at=r.decided_at,
auto_armed_at=r.auto_armed_at,
})
end
end
end
table.sort(out, function(x, y)
return (x.requested_at or 0) > (y.requested_at or 0)
end)
return {ok=true, requests=out}
end
function H.approve_payment_request(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if a.kind ~= "checking" then
return {ok=false, err="Sign in as your checking account"}
end
local r = DB.payment_requests and DB.payment_requests[p.request_id]
if not r then return {ok=false, err="Request not found"} end
if r.to_owner:lower() ~= a.owner:lower() then
return {ok=false, err="Not your request"}
end
if r.status ~= "pending" then
return {ok=false, err="Already "..r.status}
end
local from_chk
for _, id in ipairs(DB.byOwner[r.from_owner:lower()] or {}) do
local acc = DB.accounts[id]
if acc and acc.kind == "checking" and not acc.is_treasury then
from_chk = acc; break
end
end
if not from_chk then
r.status = "rejected"; r.decided_at = now()
r.reason = "requester_account_gone"
persist()
return {ok=false, err="Requester's account no longer exists"}
end
if a.balance < r.amount then
return {ok=false, err="Insufficient funds"}
end
if DB.policy.frozen[from_chk.id] then
return {ok=false, err="Requester's account is frozen"}
end
local tax, rate = computeTax(r.amount, a.id, from_chk.id)
a.balance = a.balance - r.amount
from_chk.balance = from_chk.balance + (r.amount - tax)
creditFund(tax, "tx_tax: prq "..a.owner.." -> "..from_chk.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(a.id); markActivity(from_chk.id)
local memo = r.memo or ("PRQ:"..r.id)
postHistory(a, {t=now(), type="prq_pay_out", amount=-r.amount,
note=memo, party=from_chk.id})
postHistory(from_chk, {t=now(), type="prq_pay_in",
amount=(r.amount - tax), note=memo, party=a.id})
appendLedger{type="prq_approved", request=r.id,
from=a.id, to=from_chk.id, amount=r.amount,
tax=tax, rate=rate, memo=memo}
r.status = "approved"; r.decided_at = now()
persist()
return {ok=true, balance=a.balance, tax=tax}
end
function H.reject_payment_request(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local r = DB.payment_requests and DB.payment_requests[p.request_id]
if not r then return {ok=false, err="Request not found"} end
if r.to_owner:lower() ~= a.owner:lower() then
return {ok=false, err="Not your request"}
end
if r.status ~= "pending" and r.status ~= "auto_pending" then
return {ok=false, err="Already "..r.status}
end
r.status = "rejected"; r.decided_at = now()
appendLedger{type="prq_rejected", request=r.id,
by=a.owner, from=r.from_owner, amount=r.amount}
persist()
return {ok=true}
end
function H.cancel_payment_request(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local r = DB.payment_requests and DB.payment_requests[p.request_id]
if not r then return {ok=false, err="Request not found"} end
if r.from_owner:lower() ~= a.owner:lower() then
return {ok=false, err="Not your request"}
end
if r.status ~= "pending" and r.status ~= "auto_pending" then
return {ok=false, err="Already "..r.status}
end
DB.payment_requests[r.id] = nil
appendLedger{type="prq_cancelled", request=r.id, by=a.owner,
was=r.status}
persist()
return {ok=true}
end
function H.auto_payment_request(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
if a.kind ~= "checking" then
return {ok=false, err="Sign in as your checking account"}
end
local r = DB.payment_requests and DB.payment_requests[p.request_id]
if not r then return {ok=false, err="Request not found"} end
if r.to_owner:lower() ~= a.owner:lower() then
return {ok=false, err="Not your request"}
end
if r.status ~= "pending" then
return {ok=false, err="Cannot auto-pay; status is "..r.status}
end
if a.balance >= r.amount then
local from_chk
for _, id in ipairs(DB.byOwner[r.from_owner:lower()] or {}) do
local acc = DB.accounts[id]
if acc and acc.kind == "checking" and not acc.is_treasury then
from_chk = acc; break
end
end
if from_chk and not DB.policy.frozen[from_chk.id] then
local tax, rate = computeTax(r.amount, a.id, from_chk.id)
a.balance = a.balance - r.amount
from_chk.balance = from_chk.balance + (r.amount - tax)
creditFund(tax, "tx_tax: prq "..a.owner.." -> "..from_chk.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(a.id); markActivity(from_chk.id)
local memo = r.memo or ("PRQ:"..r.id)
postHistory(a, {t=now(), type="prq_pay_out", amount=-r.amount,
note=memo, party=from_chk.id})
postHistory(from_chk, {t=now(), type="prq_pay_in",
amount=(r.amount - tax), note=memo, party=a.id})
appendLedger{type="prq_approved", request=r.id,
from=a.id, to=from_chk.id, amount=r.amount,
tax=tax, rate=rate, memo=memo, via="auto_immediate"}
r.status = "approved"; r.decided_at = now()
persist()
return {ok=true, executed=true,
balance=a.balance, tax=tax}
end
end
r.status = "auto_pending"
r.auto_armed_at = now()
r.auto_by = a.id
appendLedger{type="prq_auto_armed", request=r.id,
by=a.owner, amount=r.amount}
persist()
return {ok=true, executed=false, status="auto_pending"}
end
function H.cancel_auto_payment_request(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local r = DB.payment_requests and DB.payment_requests[p.request_id]
if not r then return {ok=false, err="Request not found"} end
if r.to_owner:lower() ~= a.owner:lower() then
return {ok=false, err="Not your request"}
end
if r.status ~= "auto_pending" then
return {ok=false, err="Not armed for auto-pay (status: "..r.status..")"}
end
r.status = "pending"
r.auto_armed_at = nil
r.auto_by = nil
appendLedger{type="prq_auto_cancelled", request=r.id, by=a.owner}
persist()
return {ok=true}
end
processAutoPayments = function()
if not DB.payment_requests then return 0, 0 end
local by_customer = {}
for _, r in pairs(DB.payment_requests) do
if r.status == "auto_pending" then
local key = r.to_owner:lower()
by_customer[key] = by_customer[key] or {}
table.insert(by_customer[key], r)
end
end
local executed = 0
local total_amount = 0
for owner_key, reqs in pairs(by_customer) do
table.sort(reqs, function(a, b)
return (a.auto_armed_at or a.requested_at or 0)
< (b.auto_armed_at or b.requested_at or 0)
end)
local cust_chk
for _, id in ipairs(DB.byOwner[owner_key] or {}) do
local acc = DB.accounts[id]
if acc and acc.kind == "checking" and not acc.is_treasury then
cust_chk = acc; break
end
end
if cust_chk and not DB.policy.frozen[cust_chk.id] then
for _, r in ipairs(reqs) do
if cust_chk.balance < r.amount then
break
end
local from_chk
for _, id in ipairs(DB.byOwner[r.from_owner:lower()] or {}) do
local acc = DB.accounts[id]
if acc and acc.kind == "checking"
and not acc.is_treasury then
from_chk = acc; break
end
end
if not from_chk then
r.status = "rejected"
r.decided_at = now()
r.reason = "sender_account_gone"
appendLedger{type="prq_auto_failed", request=r.id,
reason="sender_account_gone"}
elseif DB.policy.frozen[from_chk.id] then
break
else
local tax, rate = computeTax(r.amount, cust_chk.id, from_chk.id)
cust_chk.balance = cust_chk.balance - r.amount
from_chk.balance = from_chk.balance + (r.amount - tax)
creditFund(tax, "tx_tax: auto-prq "..cust_chk.owner.." -> "..from_chk.owner)
DB.meta.tx_count = DB.meta.tx_count + 1
markActivity(cust_chk.id); markActivity(from_chk.id)
local memo = r.memo or ("PRQ:"..r.id)
postHistory(cust_chk, {t=now(), type="prq_pay_out",
amount=-r.amount, note="(auto) "..memo, party=from_chk.id})
postHistory(from_chk, {t=now(), type="prq_pay_in",
amount=(r.amount - tax), note="(auto) "..memo, party=cust_chk.id})
appendLedger{type="prq_approved", request=r.id,
from=cust_chk.id, to=from_chk.id, amount=r.amount,
tax=tax, rate=rate, memo=memo, via="auto_pending"}
r.status = "approved"; r.decided_at = now()
executed = executed + 1
total_amount = total_amount + r.amount
end
end
end
end
if executed > 0 then
persist()
end
return executed, total_amount
end
function H.admin_list_civic_requests(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local out = {}
for rid, r in pairs(DB.civic_requests or {}) do
if r.status == "pending" then
local job = DB.civic_jobs[r.job_id]
table.insert(out, {
id=rid, account_id=r.account_id, owner=r.owner,
job_id=r.job_id,
job_title=(job and job.title) or "?",
annual_cents=(job and job.annual_cents) or 0,
requested_at=r.requested_at,
})
end
end
table.sort(out, function(a, b) return a.requested_at < b.requested_at end)
return {ok=true, requests=out}
end
function H.admin_approve_civic_request(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local r = DB.civic_requests and DB.civic_requests[p.request_id]
if not r or r.status ~= "pending" then return {ok=false, err="Not pending"} end
local a = DB.accounts[r.account_id]
local job = DB.civic_jobs[r.job_id]
if not a then return {ok=false, err="Account gone"} end
if not job then return {ok=false, err="Job gone"} end
if a.civic_jobs and next(a.civic_jobs) then
return {ok=false, err="Player now holds another job"}
end
a.civic_jobs = a.civic_jobs or {}
a.civic_jobs[job.id] = {assigned_at=now(), on_leave=false,
week_paid=0, week_days=0}
job.holders[a.id] = true
r.status = "approved"; r.decided_at = now()
appendLedger{type="civic_request_approve", request=r.id,
account=a.id, owner=a.owner, job_id=job.id, title=job.title}
persist()
return {ok=true}
end
function H.admin_reject_civic_request(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local r = DB.civic_requests and DB.civic_requests[p.request_id]
if not r or r.status ~= "pending" then return {ok=false, err="Not pending"} end
r.status = "rejected"; r.decided_at = now()
r.reason = (type(p.reason) == "string" and #p.reason <= 80) and p.reason or nil
appendLedger{type="civic_request_reject", request=r.id,
account=r.account_id, owner=r.owner, reason=r.reason}
persist()
return {ok=true}
end
function H.admin_list_job_holders(p)
if not isAdmin(p) then return {ok=false, err="Unauthorized"} end
local job = DB.civic_jobs[p.job_id]
if not job then return {ok=false, err="Job not found"} end
local out = {}
for acct_id, _ in pairs(job.holders or {}) do
local a = DB.accounts[acct_id]
if a and a.civic_jobs and a.civic_jobs[job.id] then
local h = a.civic_jobs[job.id]
table.insert(out, {
account_id=a.id, owner=a.owner,
balance=a.balance,
on_leave=h.on_leave and true or false,
week_paid=h.week_paid or 0,
week_days=h.week_days or 0,
assigned_at=h.assigned_at,
})
end
end
table.sort(out, function(a, b) return a.balance > b.balance end)
return {ok=true, job={id=job.id, title=job.title,
annual_cents=job.annual_cents,
weekly_cents=math.floor(job.annual_cents/52),
daily_cents=dailyJobCents(job.annual_cents)},
holders=out, count=#out}
end
function H.my_jobs(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local out = {}
local total_annual = 0
if a.civic_jobs then
for jid, h in pairs(a.civic_jobs) do
local job = DB.civic_jobs[jid]
if job then
table.insert(out, {
job_id=jid, title=job.title,
annual_cents=job.annual_cents,
weekly_cents=math.floor(job.annual_cents/52),
daily_cents=dailyJobCents(job.annual_cents),
on_leave=h.on_leave and true or false,
week_paid=h.week_paid or 0,
week_days=h.week_days or 0,
})
total_annual = total_annual + job.annual_cents
end
end
end
table.sort(out, function(a, b) return a.annual_cents > b.annual_cents end)
return {ok=true, jobs=out, count=#out,
total_annual=total_annual,
total_weekly=math.floor(total_annual/52),
total_daily=math.floor(total_annual/365)}
end
function H.civic_payroll_summary(p)
local total_annual = 0
local job_count = 0
local holder_records = 0
for _, job in pairs(DB.civic_jobs) do
job_count = job_count + 1
local hc = 0
for _ in pairs(job.holders or {}) do hc = hc + 1 end
holder_records = holder_records + hc
total_annual = total_annual + (job.annual_cents * hc)
end
return {ok=true, jobs=job_count, holder_records=holder_records,
total_annual=total_annual,
total_weekly=math.floor(total_annual/52),
total_daily=math.floor(total_annual/365)}
end
function H.redeem_note(p)
local a, err = withSession(p); if not a then return {ok=false, err=err} end
local note = p.note
if type(note) ~= "table" or type(note.serial) ~= "string" or type(note.sig) ~= "string" then
return {ok=false, err="Bad note"} end
if type(note.denom) ~= "number" or note.denom <= 0 or note.denom > 1e9 then
return {ok=false, err="Bad note denomination"} end
local check = {serial=note.serial, denom=note.denom, issued=note.issued, account=note.account}
local expect = crypto.hmac(SERVER_SECRET, textutils.serialize(check))
if expect ~= note.sig then return {ok=false, err="Forged note (signature mismatch)"} end
local rec = DB.cards[note.serial]
if not rec then
return {ok=false, err="Note not in registry. Contact admin (note may pre-date last bank restore)."}
end
if rec.redeemed then
return {ok=false, err="Note already redeemed by "..(rec.redeemed_by or "?").." at "
..os.date("%Y-%m-%d %H:%M", rec.redeemed_at or 0)}
end
rec.redeemed = true
rec.redeemed_at = now()
rec.redeemed_by = a.id
local cents = math.floor(note.denom * 100)
a.balance = a.balance + cents
postHistory(a, {t=now(), type="note_redeem", amount=cents, note="Note "..note.serial})
appendLedger{type="note_redeem", account=a.id, serial=note.serial, denom=note.denom}
persist()
return {ok=true, balance=a.balance}
end
local chainOk, chainResult = verifyLedgerChain()
do
local f, oerr = fs.open(PATHS.boot_log, fs.exists(PATHS.boot_log) and "a" or "w")
if f then
pcall(function()
f.writeLine(string.format("[%s] boot v%s chain_ok=%s result=%s",
os.date("%Y-%m-%d %H:%M:%S"), VERSION, tostring(chainOk), tostring(chainResult)))
f.close()
end)
end
end
local modem_side, modem_err = findAndOpenModem()
if not modem_side then
term.setBackgroundColor(T.bg); term.setTextColor(T.debit); term.clear(); term.setCursorPos(1,1)
print("===========================================================")
print("  VRB SERVER  -  CANNOT START")
print("===========================================================")
term.setTextColor(T.ink)
print("")
print("Reason: no wireless modem found")
print("")
if modem_err == "no_wireless_modem" then
print("This computer doesn't have a wireless modem attached.")
print("")
print("Fix:")
print("  1. Place an Ender Modem or Wireless Modem on top")
print("     of this computer (any side works).")
print("  2. Right-click the modem to enable it -- the ring")
print("     should glow red.")
print("  3. Reboot this computer.")
else
print("A modem was found but couldn't be opened.")
print("Detail: "..tostring(modem_err))
print("")
print("Fix: remove and replace the modem, then reboot.")
end
return
end
local ok_host, host_err = pcall(rednet.host, CFG.PROTOCOL, CFG.HOSTNAME_SERVER)
if not ok_host then
term.setBackgroundColor(T.bg); term.setTextColor(T.debit); term.clear(); term.setCursorPos(1,1)
print("VRB SERVER -- CANNOT REGISTER HOSTNAME")
term.setTextColor(T.ink)
print("")
print("Detail: "..tostring(host_err))
print("")
print("This usually means rednet.host failed because the modem")
print("was rejected by CC: Tweaked. Try replacing the modem.")
return
end
term.setBackgroundColor(T.bg); term.setTextColor(T.accent); term.clear(); term.setCursorPos(1,1)
print("== VANGUARD RESERVE BANK ==")
term.setTextColor(T.ink)
print("Version     : " .. VERSION)
print("Hostname    : " .. CFG.HOSTNAME_SERVER)
print("Protocol    : " .. CFG.PROTOCOL)
local cryptoOk, cryptoErr = pcall(crypto.selfTest)
if not cryptoOk then
term.setTextColor(T.debit)
print("CRYPTO SELF-TEST FAILED: " .. tostring(cryptoErr))
print("Refusing to serve. SHA-256 implementation is broken.")
return
end
term.setTextColor(T.credit); print("Crypto OK   : SHA-256 + HMAC self-test passed")
term.setTextColor(T.ink)
print("Ledger head : " .. DB.meta.ledger_head)
if chainOk then
term.setTextColor(T.credit); print("Ledger OK   : "..tostring(chainResult).." entries verified")
else
term.setTextColor(T.warn)
print("LEDGER WARN : "..tostring(chainResult))
print("              continuing to serve; ledger.log untouched.")
term.setTextColor(T.ink)
DIAG.last_ledger_error = "verify: "..tostring(chainResult)
DIAG.ledger_verify_failures = (DIAG.ledger_verify_failures or 0) + 1
end
term.setTextColor(T.muted)
print("Keys in     : "..CFG.KEY_DIR)
do
local n = migratePairAccounts()
if n > 0 then
term.setTextColor(T.gold)
print(string.format("v9.2 migration: paired %d account(s)", n))
persist()
term.setTextColor(T.ink)
end
end
do
local free_kb = getFreeKB()
if free_kb then
local color = T.credit
if free_kb < DISK_LIMITS.FREE_SPACE_LOW_KB then color = T.warn end
if free_kb < DISK_LIMITS.FREE_SPACE_PANIC_KB then color = T.debit end
term.setTextColor(color)
print(string.format("Free disk   : %d KB", free_kb))
term.setTextColor(T.ink)
if free_kb < DISK_LIMITS.FREE_SPACE_PANIC_KB then
print("Running emergency cleanup at boot...")
pcall(emergencyCleanup)
local after = getFreeKB() or 0
term.setTextColor(T.credit)
print(string.format("After cleanup: %d KB free", after))
term.setTextColor(T.ink)
else
pcall(janitorSweep)
end
end
end
print(""); print("Serving. Ctrl+T to halt. Logs below."); print("")
local function sendBack(to, payload)
rednet.send(to, seal(SERVER_SECRET, payload), CFG.PROTOCOL)
end
parallel.waitForAny(
function()
while true do
local ok_loop, err_loop = pcall(function()
while true do
local sender, envelope = rednet.receive(CFG.PROTOCOL)
local payload, uerr = unseal(SERVER_SECRET, envelope, CFG.RPC_WINDOW_SEC, seenNonces)
if not payload then
DIAG.rejected_packets = DIAG.rejected_packets + 1
DIAG.last_reject_time = now()
DIAG.last_reject_reason = tostring(uerr or "?")
DIAG.last_reject_sender = sender
term.setTextColor(T.warn)
print(string.format("[%s] REJECT %d: %s", os.date("%H:%M:%S"), sender, uerr or "?"))
term.setTextColor(T.ink)
else
if type(payload.method) ~= "string" or type(payload.params) ~= "table" or not payload.rpc_id then
sendBack(sender, {rpc_id=payload.rpc_id or "?", ok=false, err="Malformed"})
DIAG.rejected_packets = DIAG.rejected_packets + 1
else
local handler = H[payload.method]
if not handler then
sendBack(sender, {rpc_id=payload.rpc_id, ok=false, err="Unknown method"})
else
local okCall, res = pcall(handler, payload.params)
if not okCall then
local err_str = tostring(res)
DIAG.server_errors = DIAG.server_errors + 1
DIAG.last_error_time = now()
DIAG.last_error_method = payload.method
DIAG.last_error_detail = err_str
term.setTextColor(T.debit)
print(string.format("[%s] CRASH %s: %s",
os.date("%H:%M:%S"), payload.method, err_str:sub(1, 80)))
term.setTextColor(T.ink)
pcall(function()
local f = fs.open(fs.combine(CFG.DATA_DIR, "errors.log"),
fs.exists(fs.combine(CFG.DATA_DIR, "errors.log")) and "a" or "w")
if f then
f.writeLine(string.format("[%s] %s: %s",
os.date("%Y-%m-%d %H:%M:%S"),
payload.method, err_str))
f.close()
end
end)
res = {ok=false, err="Server error: "..err_str:sub(1, 60)}
end
if type(res) ~= "table" then
DIAG.server_errors = DIAG.server_errors + 1
res = {ok=false, err="Handler returned non-table for "..payload.method}
end
res.rpc_id = payload.rpc_id
sendBack(sender, res)
local color = res.ok and T.muted or T.warn
term.setTextColor(color)
print(string.format("[%s] %-24s %-6d -> %s",
os.date("%H:%M:%S"), payload.method, sender,
res.ok and "ok" or ("err:"..tostring(res.err))))
term.setTextColor(T.ink)
end
end
end
end
end)
if not ok_loop then
DIAG.last_error_time = now()
DIAG.last_error_method = "rednet_loop"
DIAG.last_error_detail = tostring(err_loop):sub(1, 200)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
term.setTextColor(T.warn)
print(string.format("[%s] LOOP CRASH (restart): %s",
os.date("%H:%M:%S"), tostring(err_loop):sub(1, 80)))
term.setTextColor(T.ink)
sleep(1)
end
end
end,
function()
local last_streak_check = 0
local last_ledger_check = now()
local last_backup = 0
local last_janitor = 0
local function safe(name, fn, ...)
local ok, err = pcall(fn, ...)
if not ok then
DIAG.last_error_time = now()
DIAG.last_error_method = name
DIAG.last_error_detail = tostring(err):sub(1, 200)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
pcall(function()
local free_kb = getFreeKB()
if free_kb and free_kb < DISK_LIMITS.FREE_SPACE_PANIC_KB then
return
end
local f = fs.open(fs.combine(CFG.DATA_DIR, "errors.log"),
fs.exists(fs.combine(CFG.DATA_DIR, "errors.log")) and "a" or "w")
if f then
f.writeLine(string.format("[%s] %s: %s",
os.date("%Y-%m-%d %H:%M:%S"),
name, tostring(err)))
f.close()
end
end)
term.setTextColor(T.warn)
print(string.format("[%s] BG ERROR %s: %s",
os.date("%H:%M:%S"), name, tostring(err):sub(1, 80)))
term.setTextColor(T.ink)
end
end
while true do
local ok_outer, err_outer = pcall(function()
sleep(30)
safe("accrueInterest", accrueInterest)
safe("processRecurring", processRecurring)
safe("processAutoPayments", processAutoPayments)
safe("distributeUBI", distributeUBI)
safe("supplyTargetAdjust", supplyTargetAdjust)
safe("gcSessions", gcSessions)
if now() - last_streak_check > 3600 then
safe("checkStreakWarnings", checkStreakWarnings)
last_streak_check = now()
end
if now() - last_ledger_check > 6 * 3600 then
last_ledger_check = now()
pcall(verifyLedgerChain)
end
if now() - last_backup > 86400 then
last_backup = now()
safe("rollingBackup", rollingBackup)
end
if now() - last_janitor > 300 then
last_janitor = now()
safe("janitorSweep", janitorSweep)
end
local cutoff = now() - CFG.RPC_WINDOW_SEC * 2
for n, t in pairs(seenNonces) do if t < cutoff then seenNonces[n] = nil end end
end)
if not ok_outer then
DIAG.last_error_method = "tasks_loop"
DIAG.last_error_detail = tostring(err_outer):sub(1, 200)
DIAG.server_errors = (DIAG.server_errors or 0) + 1
sleep(1)
end
end
end
)
end
local function newClient(serverSecret, adminKey)
local c = {secret=serverSecret, admin=adminKey, seen={}}
local serverId
local lastLookupTime = 0
function c:_findServer(force)
local now_s = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time()
if not force and serverId and (now_s - lastLookupTime) < 300 then
return serverId
end
local ok_open, openErr = pcall(openModem)
if not ok_open then
return nil, "modem_error", tostring(openErr)
end
serverId = rednet.lookup(CFG.PROTOCOL, CFG.HOSTNAME_SERVER)
lastLookupTime = now_s
if not serverId then
return nil, "no_host_found", "rednet.lookup returned nil"
end
return serverId
end
function c:call(method, params, isAdmin)
local sid, err_code, err_detail = self:_findServer()
if not sid then
local msg = "Cannot reach Reserve Bank"
if err_code == "modem_error" then
msg = "Cannot reach Reserve Bank (modem issue: "..tostring(err_detail)..")"
elseif err_code == "no_host_found" then
msg = "Cannot reach Reserve Bank (no server is broadcasting on protocol "
..CFG.PROTOCOL.."; is the bank online?)"
end
return {ok=false, err=msg, err_code=err_code}
end
params = params or {}
if isAdmin then
if not self.admin then
return {ok=false, err="Admin call attempted without admin.key on this client",
err_code="no_admin_key"}
end
params._admin_nonce = crypto.random_id()
params._admin_sig = crypto.hmac(self.admin, params._admin_nonce)
end
local rpc_id = crypto.random_id()
local payload = {rpc_id=rpc_id, method=method, params=params}
local last_err = "Unknown"
for attempt = 1, CFG.RPC_RETRIES + 1 do
local ok_send = pcall(rednet.send, sid, seal(self.secret, payload), CFG.PROTOCOL)
if not ok_send then
last_err = "send failed"
else
local deadline = os.clock() + CFG.RPC_TIMEOUT
while os.clock() < deadline do
local remaining = deadline - os.clock()
local id, envelope = rednet.receive(CFG.PROTOCOL, remaining)
if id == sid then
local res = unseal(self.secret, envelope, CFG.RPC_WINDOW_SEC, self.seen)
if res and res.rpc_id == rpc_id then return res end
end
end
last_err = "Timeout waiting for response"
end
if attempt < CFG.RPC_RETRIES + 1 then
serverId = nil
local sid2 = self:_findServer(true)
if sid2 then sid = sid2 end
end
end
return {ok=false, err=last_err, err_code="rpc_timeout"}
end
return c
end
local function loadClientKeys(requireAdmin)
ensureDir(CFG.KEY_DIR)
local function load(path, prompt)
if fs.exists(path) then
local f = fs.open(path, "r")
if f then
local k = f.readAll(); f.close()
if k and #k > 0 then return k end
end
end
term.setTextColor(T.warn)
print("Key not found: "..path)
write(prompt..": ")
term.setTextColor(T.ink)
local k = read("*")
if k and #k > 0 then writeAtomic(path, k); return k end
error("Key required.")
end
local secret = load(fs.combine(CFG.KEY_DIR, "server.secret"), "Paste server secret")
local admin
if requireAdmin then
admin = load(fs.combine(CFG.KEY_DIR, "admin.key"), "Paste admin key")
end
return secret, admin
end
local THEME = {
bg = colors.black,
surface = colors.gray,
surface_alt = colors.lightGray,
ink = colors.white,
ink_muted = colors.lightGray,
ink_dim = colors.gray,
gold = colors.yellow,
gold_dim = colors.orange,
credit = colors.lime,
debit = colors.red,
warn = colors.orange,
info = colors.lightBlue,
rule = colors.gray,
rule_strong = colors.yellow,
btn_primary_bg = colors.yellow,
btn_primary_ink = colors.black,
btn_primary_shadow = colors.orange,
btn_secondary_bg = colors.lightGray,
btn_secondary_ink = colors.black,
btn_secondary_shadow = colors.gray,
btn_danger_bg = colors.red,
btn_danger_ink = colors.white,
btn_danger_shadow = colors.gray,
btn_success_bg = colors.lime,
btn_success_ink = colors.black,
btn_success_shadow = colors.green,
btn_pressed_bg = colors.white,
}
local T = {
bg=THEME.bg, panel=THEME.surface, panelAlt=THEME.surface_alt,
ink=THEME.ink, muted=THEME.ink_muted, accent=THEME.gold,
credit=THEME.credit, debit=THEME.debit, warn=THEME.warn,
rule=THEME.rule, btn=THEME.btn_primary_bg, btnInk=THEME.btn_primary_ink,
btnAlt=THEME.btn_secondary_bg, btnAltInk=THEME.btn_secondary_ink,
}
local function makeUI(surface)
local ui = {s = surface, theme = THEME, components = {}, buttons = {},
banner = nil, pressed = nil, anim_frame = 0}
function ui:size()
local w, h = self.s.getSize()
return w, h
end
function ui:clear(bg)
self.s.setBackgroundColor(bg or self.theme.bg)
self.s.setTextColor(self.theme.ink)
self.s.clear()
end
function ui:write(x, y, text, fg, bg)
self.s.setCursorPos(x, y)
if fg then self.s.setTextColor(fg) end
if bg then self.s.setBackgroundColor(bg) end
self.s.write(text)
end
function ui:fill(x, y, w, h, bg)
self.s.setBackgroundColor(bg)
for row = y, y + h - 1 do
self.s.setCursorPos(x, row)
self.s.write(string.rep(" ", w))
end
end
function ui:hline(x, y, w, fg, bg, char)
char = char or "\131"
self.s.setBackgroundColor(bg or self.theme.bg)
self.s.setTextColor(fg or self.theme.rule)
self.s.setCursorPos(x, y)
self.s.write(string.rep(char, w))
end
function ui:card(x, y, w, h, opts)
opts = opts or {}
local surface_bg = opts.bg or self.theme.surface
local shadow_bg = opts.shadow or self.theme.bg
self:fill(x, y, w, h, surface_bg)
if y + h <= ({self:size()})[2] then
self:fill(x + 1, y + h, w - 1, 1, shadow_bg)
end
if opts.title then
self.s.setBackgroundColor(surface_bg)
self.s.setTextColor(opts.title_color or self.theme.gold)
self.s.setCursorPos(x + 2, y)
self.s.write(opts.title)
self:hline(x + 1, y + 1, w - 2, self.theme.gold, surface_bg, "\140")
end
if opts.accent_top then
self:hline(x, y, w, self.theme.gold, self.theme.bg, "\140")
end
end
function ui:frame(x, y, w, h, opts)
opts = opts or {}
local fg = opts.fg or self.theme.rule
local bg = opts.bg or self.theme.bg
self.s.setBackgroundColor(bg); self.s.setTextColor(fg)
self.s.setCursorPos(x, y); self.s.write("\151")
self.s.setCursorPos(x + w - 1, y); self.s.write("\148")
self.s.setCursorPos(x, y+h-1); self.s.write("\138")
self.s.setCursorPos(x+w-1, y+h-1); self.s.write("\133")
self.s.setCursorPos(x+1, y); self.s.write(string.rep("\131", w-2))
self.s.setCursorPos(x+1, y+h-1); self.s.write(string.rep("\143", w-2))
for row = y+1, y+h-2 do
self.s.setCursorPos(x, row); self.s.write("\149")
self.s.setCursorPos(x+w-1, row); self.s.write("\149")
end
if opts.title then
self.s.setCursorPos(x + 2, y)
self.s.setTextColor(opts.title_color or self.theme.gold)
self.s.write(" "..opts.title.." ")
end
end
function ui:heading(x, y, text)
self:write(x, y, text, self.theme.gold, self.theme.bg)
end
function ui:crest(x, y)
self.s.setBackgroundColor(self.theme.surface)
self.s.setTextColor(self.theme.gold)
self.s.setCursorPos(x, y ); self.s.write("  /\\  ")
self.s.setCursorPos(x, y+1); self.s.write(" /VR\\ ")
self.s.setCursorPos(x, y+2); self.s.write("'----'")
end
function ui:button(x, y, w, label, opts)
opts = opts or {}
local kind = opts.kind or "primary"
local bg, fg, shadow
if kind == "primary" then
bg, fg, shadow = self.theme.btn_primary_bg, self.theme.btn_primary_ink, self.theme.btn_primary_shadow
elseif kind == "secondary" then
bg, fg, shadow = self.theme.btn_secondary_bg, self.theme.btn_secondary_ink, self.theme.btn_secondary_shadow
elseif kind == "danger" then
bg, fg, shadow = self.theme.btn_danger_bg, self.theme.btn_danger_ink, self.theme.btn_danger_shadow
elseif kind == "success" then
bg, fg, shadow = self.theme.btn_success_bg, self.theme.btn_success_ink, self.theme.btn_success_shadow
elseif kind == "ghost" then
bg, fg, shadow = self.theme.bg, self.theme.gold, self.theme.bg
else
bg, fg, shadow = self.theme.btn_primary_bg, self.theme.btn_primary_ink, self.theme.btn_primary_shadow
end
local pressed = self.pressed
if pressed and pressed.x == x and pressed.y == y and pressed.frame > 0 then
bg = self.theme.btn_pressed_bg
fg = self.theme.btn_primary_ink
end
self.s.setBackgroundColor(bg); self.s.setTextColor(fg)
self.s.setCursorPos(x, y); self.s.write(string.rep(" ", w))
local pad = math.max(0, math.floor((w - #label) / 2))
self.s.setCursorPos(x + pad, y); self.s.write(label)
if not opts.no_shadow then
self.s.setBackgroundColor(shadow); self.s.setCursorPos(x, y + 1)
self.s.write(string.rep(" ", w))
end
local rec = {
x = x, y = y, w = w, h = opts.no_shadow and 1 or 2,
label = label, action = opts.action, data = opts.data,
disabled = opts.disabled,
}
table.insert(self.buttons, rec)
return rec
end
function ui:pill(x, y, w, label, opts)
opts = opts or {}
return self:button(x, y, w, label, {
kind = opts.kind or "ghost", no_shadow = true,
action = opts.action, data = opts.data,
})
end
function ui:hotzone(x, y, w, h, action, data)
table.insert(self.buttons, {x=x, y=y, w=w, h=h, action=action, data=data})
end
function ui:hit(mx, my)
for _, b in ipairs(self.buttons) do
if not b.disabled
and mx >= b.x and mx < b.x + b.w
and my >= b.y and my < b.y + b.h then
return b
end
end
end
function ui:press(btn)
self.pressed = {x=btn.x, y=btn.y, frame=2}
end
function ui:tick()
local dirty = false
if self.pressed then
self.pressed.frame = self.pressed.frame - 1
if self.pressed.frame <= 0 then self.pressed = nil end
dirty = true
end
if self.banner and self.banner.ttl then
self.banner.ttl = self.banner.ttl - 1
if self.banner.ttl <= 0 then self.banner = nil end
dirty = true
end
self.anim_frame = (self.anim_frame + 1) % 60
return dirty
end
function ui:showBanner(kind, text, ttl)
self.banner = {kind = kind or "info", text = text, ttl = ttl or 30}
end
function ui:drawBanner(x, y, w)
if not self.banner then return end
local colorMap = {
ok = {bg=self.theme.credit, fg=colors.black},
error = {bg=self.theme.debit, fg=colors.white},
warn = {bg=self.theme.warn, fg=colors.black},
info = {bg=self.theme.info, fg=colors.black},
}
local c = colorMap[self.banner.kind] or colorMap.info
self:fill(x, y, w, 1, c.bg)
local text = self.banner.text
if #text > w - 2 then text = text:sub(1, w - 5) .. "..." end
self:write(x + math.max(1, math.floor((w - #text)/2)), y, text, c.fg, c.bg)
end
function ui:money(x_right, y, cents, opts)
opts = opts or {}
local text = fmtMoney(cents)
local color = opts.color or self.theme.gold
self:write(x_right - #text + 1, y, text, color, opts.bg or self.theme.bg)
end
function ui:kv(x, y, w, label, value, opts)
opts = opts or {}
self:write(x, y, label, opts.label_color or self.theme.ink_muted, opts.bg or self.theme.bg)
local rt = value
self:write(x + w - #rt, y, rt, opts.value_color or self.theme.ink, opts.bg or self.theme.bg)
end
function ui:row(x, y, w, mark, mark_color, left, right, left_color, right_color, bg)
local full_bg = bg or self.theme.bg
self:fill(x, y, w, 1, full_bg)
self:write(x, y, mark, mark_color or self.theme.ink_muted, full_bg)
self:write(x + 2, y, (left or ""):sub(1, w - #(right or "") - 4),
left_color or self.theme.ink, full_bg)
if right then
self:write(x + w - #right, y, right, right_color or self.theme.ink, full_bg)
end
end
function ui:spinner(x, y, frame)
local glyphs = {"|", "/", "-", "\\"}
local g = glyphs[(frame % 4) + 1]
self:write(x, y, g, self.theme.gold, self.theme.bg)
end
function ui:begin()
self.buttons = {}
end
function ui:flush() end
function ui:hitTest(list, mx, my)
for _, b in ipairs(list or {}) do
if mx >= b.x and mx < b.x + b.w and my >= b.y and my < b.y + b.h then return b end
end
end
function ui:box(x, y, w, h, title, fg, bg)
self:frame(x, y, w, h, {title=title, fg=fg, bg=bg})
end
function ui:drawCrest(x, y) self:crest(x, y) end
function ui:crestLarge(x, y)
self.s.setBackgroundColor(self.theme.bg)
self.s.setTextColor(self.theme.gold)
self.s.setCursorPos(x, y ); self.s.write("   _____    ")
self.s.setCursorPos(x, y+1); self.s.write("  /     \\   ")
self.s.setCursorPos(x, y+2); self.s.write(" | V R B |  ")
self.s.setCursorPos(x, y+3); self.s.write("  \\_____/   ")
self.s.setCursorPos(x, y+4); self.s.write("  |||||||   ")
end
function ui:bigNumber(x, y, text, color, bg)
color = color or self.theme.gold
bg = bg or self.theme.bg
self.s.setBackgroundColor(bg); self.s.setTextColor(color)
self.s.setCursorPos(x, y); self.s.write(text)
self.s.setCursorPos(x, y + 1); self.s.setTextColor(self.theme.gold_dim)
self.s.write(string.rep("\140", #text))
return #text
end
function ui:statusPill(x, y, label, kind)
local palette = {
ok = {bg=self.theme.credit, fg=colors.black},
bad = {bg=self.theme.debit, fg=colors.white},
warn = {bg=self.theme.warn, fg=colors.black},
info = {bg=self.theme.info, fg=colors.black},
muted = {bg=self.theme.ink_dim, fg=colors.white},
gold = {bg=self.theme.gold, fg=colors.black},
}
local c = palette[kind or "info"]
self.s.setBackgroundColor(c.bg); self.s.setTextColor(c.fg)
self.s.setCursorPos(x, y); self.s.write(" "..label.." ")
return #label + 2
end
function ui:tabBar(x, y, w, tabs, active, on_select)
self:fill(x, y, w, 2, self.theme.surface)
self:hline(x, y + 2, w, self.theme.gold, self.theme.bg, "\131")
local cx = x + 1
for _, t in ipairs(tabs) do
local tab_w = #t.label + 4
local is_active = (t.id == active)
local bg = is_active and self.theme.bg or self.theme.surface
local fg = is_active and self.theme.gold or self.theme.ink_muted
self.s.setBackgroundColor(bg); self.s.setTextColor(fg)
self.s.setCursorPos(cx, y); self.s.write(string.rep(" ", tab_w))
self.s.setCursorPos(cx, y + 1); self.s.write(string.rep(" ", tab_w))
self.s.setCursorPos(cx + 2, y + 1); self.s.write(t.label)
if is_active then
self.s.setCursorPos(cx, y); self.s.setTextColor(self.theme.gold)
self.s.write(string.rep("\131", tab_w))
end
self:hotzone(cx, y, tab_w, 2, on_select, t.id)
cx = cx + tab_w + 1
end
end
function ui:emptyState(x, y, w, h, title, subtitle, hint)
local cx = x + math.floor(w/2)
local cy = y + math.floor(h/2) - 2
self.s.setBackgroundColor(self.theme.bg)
self.s.setTextColor(self.theme.gold_dim)
self.s.setCursorPos(cx - 2, cy - 1); self.s.write("  /\\  ")
self.s.setCursorPos(cx - 2, cy ); self.s.write(" /  \\ ")
self.s.setCursorPos(cx - 2, cy + 1); self.s.write(" \\  / ")
self.s.setCursorPos(cx - 2, cy + 2); self.s.write("  \\/  ")
if title then
self:write(cx - math.floor(#title/2), cy + 4, title, self.theme.ink)
end
if subtitle then
self:write(cx - math.floor(#subtitle/2), cy + 5, subtitle, self.theme.ink_muted)
end
if hint then
self:write(cx - math.floor(#hint/2), cy + 7, hint, self.theme.gold_dim)
end
end
function ui:modal(w_hint, title, body_lines, buttons)
local W, H = self:size()
local bw = math.min(w_hint or 40, W - 4)
local bh = 6 + #body_lines
local bx = math.floor((W - bw)/2)
local by = math.floor((H - bh)/2)
self:fill(1, 1, W, H, colors.black)
for r = 1, H do
self.s.setBackgroundColor(colors.black); self.s.setTextColor(self.theme.ink_dim)
self.s.setCursorPos(1, r); self.s.write(string.rep(".", W))
end
self:fill(bx, by, bw, bh, self.theme.surface)
self:hline(bx, by, bw, self.theme.gold, self.theme.surface, "\131")
self:hline(bx, by + bh - 1, bw, self.theme.gold, self.theme.surface, "\143")
self.s.setBackgroundColor(self.theme.surface); self.s.setTextColor(self.theme.gold)
self.s.setCursorPos(bx + 2, by + 1); self.s.write(title or "")
self.s.setTextColor(self.theme.ink)
for i, line in ipairs(body_lines or {}) do
self.s.setCursorPos(bx + 2, by + 2 + i)
self.s.setBackgroundColor(self.theme.surface)
self.s.write(line:sub(1, bw - 4))
end
if buttons and #buttons > 0 then
local totalW = 0
for _, b in ipairs(buttons) do totalW = totalW + (b.w or 12) + 2 end
local bxx = bx + bw - totalW - 1
for _, b in ipairs(buttons) do
local w = b.w or 12
self:button(bxx, by + bh - 3, w, b.label, {
kind=b.kind or "primary", action=b.action, data=b.data,
})
bxx = bxx + w + 2
end
end
end
function ui:showToast(kind, text, ttl)
self.toast = {kind=kind or "info", text=text, ttl=ttl or 40}
end
function ui:drawToast()
local t = self.toast
if not t then return end
local W, H = self:size()
local w = math.min(#t.text + 4, W - 4)
local x = W - w - 1
local y = H - 4
local palette = {
ok = {bg=self.theme.credit, fg=colors.black, icon="\4"},
error = {bg=self.theme.debit, fg=colors.white, icon="!"},
warn = {bg=self.theme.warn, fg=colors.black, icon="!"},
info = {bg=self.theme.info, fg=colors.black, icon="i"},
}
local c = palette[t.kind] or palette.info
self:fill(x, y, w, 3, c.bg)
self.s.setBackgroundColor(c.bg); self.s.setTextColor(c.fg)
self.s.setCursorPos(x + 2, y + 1)
self.s.write(c.icon .. "  " .. t.text:sub(1, w - 5))
end
local prev_tick = ui.tick
function ui:tick()
local dirty = prev_tick(self)
if self.toast and self.toast.ttl then
self.toast.ttl = self.toast.ttl - 1
if self.toast.ttl <= 0 then self.toast = nil end
dirty = true
end
return dirty
end
function ui:keyboardScreen(prompt, opts)
opts = opts or {}
local W, H = self:size()
local input = opts.initial or ""
local max_len = opts.max_len or 32
local pattern = opts.pattern
local mask = opts.mask
local numeric = opts.numeric
local digits_only = opts.digits_only
local shift = false
local _last_reject_ch = nil
local _last_reject_t = 0
local min_w = numeric and 28 or 50
local min_h = numeric and 22 or 23
if W < min_w or H < min_h then
self.s.setBackgroundColor(self.theme.bg); self.s.clear()
self.s.setTextColor(self.theme.warn); self.s.setCursorPos(1, 1)
self.s.write("Monitor too small for keyboard.")
self.s.setCursorPos(1, 2)
self.s.write(string.format("Need %dx%d, have %dx%d.", min_w, min_h, W, H))
self.s.setCursorPos(1, 4)
self.s.setTextColor(self.theme.ink_muted)
self.s.write("Build a 3x3 Advanced Monitor or larger.")
self.s.setCursorPos(1, 6)
self.s.write("Tap anywhere to dismiss.")
while true do
local ev = os.pullEvent()
if ev == "monitor_touch" then return nil end
end
end
local function tryAppend(ch)
if #input >= max_len then
_last_reject_ch = "max"
_last_reject_t = os.epoch and os.epoch("utc") or 0
return
end
local candidate = input .. ch
if pattern and not candidate:match(pattern) then
_last_reject_ch = ch
_last_reject_t = os.epoch and os.epoch("utc") or 0
return
end
input = candidate
_last_reject_ch = nil
end
local function backspace()
if #input > 0 then input = input:sub(1, #input - 1) end
end
local function render()
local zones = {}
self.s.setBackgroundColor(self.theme.bg); self.s.clear()
self.s.setBackgroundColor(self.theme.surface)
for x = 1, W do
self.s.setCursorPos(x, 1); self.s.write(" ")
self.s.setCursorPos(x, 2); self.s.write(" ")
end
self.s.setTextColor(self.theme.gold); self.s.setCursorPos(2, 1)
self.s.write(prompt or "")
if opts.subtitle then
self.s.setTextColor(self.theme.ink_muted); self.s.setCursorPos(2, 2)
self.s.write(opts.subtitle)
end
local fy = 4
local fh = 3
local now_ms = os.epoch and os.epoch("utc") or 0
local rejecting = _last_reject_ch and (now_ms - _last_reject_t < 600)
local field_bg = rejecting and self.theme.debit
or (self.theme.surface_high or self.theme.surface)
self.s.setBackgroundColor(field_bg)
for y = fy, fy + fh - 1 do
for x = 2, W - 1 do
self.s.setCursorPos(x, y); self.s.write(" ")
end
end
self.s.setTextColor(self.theme.ink)
self.s.setCursorPos(3, fy + 1)
local shown = mask and string.rep("*", #input) or input
if #shown > W - 6 then shown = shown:sub(-(W - 6)) end
self.s.write(shown.."_")
if rejecting then
self.s.setBackgroundColor(self.theme.bg)
self.s.setTextColor(self.theme.warn)
local hint
if _last_reject_ch == "max" then
hint = "(max length reached)"
else
hint = "(character not allowed)"
end
self.s.setCursorPos(2, fy + fh)
self.s.write(hint)
end
self.s.setBackgroundColor(self.theme.bg)
local function key(x, y, w, h, label, action, data, color, bg)
bg = bg or self.theme.surface
color = color or self.theme.ink
self.s.setBackgroundColor(bg); self.s.setTextColor(color)
for ky = y, y + h - 1 do
for kx = x, x + w - 1 do
self.s.setCursorPos(kx, ky); self.s.write(" ")
end
end
local lx = x + math.max(0, math.floor((w - #label) / 2))
local ly = y + math.floor(h / 2)
self.s.setCursorPos(lx, ly); self.s.write(label)
self.s.setBackgroundColor(self.theme.bg)
table.insert(zones, {x=x, y=y, w=w, h=h, action=action, data=data})
end
if numeric then
local key_w = 7
local key_h = 3
local total_w = key_w * 3 + 2 * 1
local kx0 = math.floor((W - total_w) / 2)
local ky0 = 9
local layout = {
{"7","7"},{"8","8"},{"9","9"},
{"4","4"},{"5","5"},{"6","6"},
{"1","1"},{"2","2"},{"3","3"},
{"0","0"},
}
if digits_only then
table.insert(layout, {" "," "})
else
table.insert(layout, {".","."})
end
table.insert(layout, {"<-","BACK"})
for i, k in ipairs(layout) do
local row = math.floor((i - 1) / 3)
local col = (i - 1) % 3
local x = kx0 + col * (key_w + 1)
local y = ky0 + row * (key_h + 1)
if k[2] == "BACK" then
key(x, y, key_w, key_h, k[1], "kb_back", nil,
self.theme.ink, self.theme.warn)
elseif k[2] == " " then
self.s.setBackgroundColor(self.theme.bg)
for ky2 = y, y + key_h - 1 do
for kx2 = x, x + key_w - 1 do
self.s.setCursorPos(kx2, ky2); self.s.write(" ")
end
end
else
key(x, y, key_w, key_h, k[1], "kb_char", k[1])
end
end
local by = ky0 + 4 * (key_h + 1) + 1
local btn_w = math.floor((total_w - 2) / 2)
key(kx0, by, btn_w, 3, "CANCEL", "kb_cancel", nil,
self.theme.ink, self.theme.debit)
key(kx0 + btn_w + 2, by, btn_w, 3, "ENTER", "kb_enter", nil,
self.theme.ink, self.theme.credit)
else
local row0 = {"1","2","3","4","5","6","7","8","9","0"}
local row1 = {"q","w","e","r","t","y","u","i","o","p"}
local row2 = {"a","s","d","f","g","h","j","k","l"}
local row3 = {"z","x","c","v","b","n","m"}
local key_w = 4
local key_h = 3
local r0_w = #row0 * key_w + (#row0 - 1)
local r0_x = math.floor((W - r0_w) / 2)
local r0_y = 8
for i, ch in ipairs(row0) do
local x = r0_x + (i - 1) * (key_w + 1)
key(x, r0_y, key_w, key_h, ch, "kb_char", ch)
end
local r1_w = #row1 * key_w + (#row1 - 1)
local r1_x = math.floor((W - r1_w) / 2)
local r1_y = r0_y + key_h + 1
for i, ch in ipairs(row1) do
local x = r1_x + (i - 1) * (key_w + 1)
local label = shift and ch:upper() or ch
key(x, r1_y, key_w, key_h, label, "kb_char", label)
end
local r2_x = r1_x + 2
local r2_y = r1_y + key_h + 1
for i, ch in ipairs(row2) do
local x = r2_x + (i - 1) * (key_w + 1)
local label = shift and ch:upper() or ch
key(x, r2_y, key_w, key_h, label, "kb_char", label)
end
local r3_x = r2_x + 4
local r3_y = r2_y + key_h + 1
for i, ch in ipairs(row3) do
local x = r3_x + (i - 1) * (key_w + 1)
local label = shift and ch:upper() or ch
key(x, r3_y, key_w, key_h, label, "kb_char", label)
end
local back_x = r3_x + #row3 * (key_w + 1)
key(back_x, r3_y, key_w + 2, key_h, "<-", "kb_back", nil,
self.theme.ink, self.theme.warn)
key(r1_x, r3_y, r3_x - r1_x - 1, key_h,
shift and "SHIFT*" or "SHIFT", "kb_shift", nil,
self.theme.ink,
shift and self.theme.gold or self.theme.surface)
local r4_y = r3_y + key_h + 1
local cancel_w = 8
local enter_w = 8
local underscore_w = 4
local space_x = r1_x + cancel_w + 2
local underscore_x = space_x
space_x = underscore_x + underscore_w + 1
local space_w = r1_w - cancel_w - enter_w - underscore_w - 5
key(r1_x, r4_y, cancel_w, key_h, "CANCEL", "kb_cancel", nil,
self.theme.ink, self.theme.debit)
key(underscore_x, r4_y, underscore_w, key_h, "_", "kb_char", "_")
key(space_x, r4_y, space_w, key_h, "SPACE", "kb_char", " ")
key(r1_x + r1_w - enter_w, r4_y, enter_w, key_h, "ENTER",
"kb_enter", nil, self.theme.ink, self.theme.credit)
end
return zones
end
local zones = render()
while true do
local ev, _, mx, my = os.pullEvent()
if ev == "monitor_touch" then
local hit = nil
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if hit then
if hit.action == "kb_char" then
tryAppend(hit.data)
elseif hit.action == "kb_back" then
backspace()
elseif hit.action == "kb_shift" then
shift = not shift
elseif hit.action == "kb_enter" then
return input
elseif hit.action == "kb_cancel" then
return nil
end
zones = render()
end
end
end
end
function ui:choiceScreen(prompt, choices, opts)
opts = opts or {}
local W, H = self:size()
local function render()
local zones = {}
self.s.setBackgroundColor(self.theme.bg); self.s.clear()
self.s.setBackgroundColor(self.theme.surface)
for x = 1, W do
self.s.setCursorPos(x, 1); self.s.write(" ")
self.s.setCursorPos(x, 2); self.s.write(" ")
end
self.s.setTextColor(self.theme.gold); self.s.setCursorPos(2, 1)
self.s.write(prompt or "")
if opts.subtitle then
self.s.setTextColor(self.theme.ink_muted); self.s.setCursorPos(2, 2)
self.s.write(opts.subtitle)
end
local n = #choices
local card_h = math.floor((H - 8) / n)
if n <= 3 then
local card_w = math.floor((W - 4 - (n - 1) * 2) / n)
for i, c in ipairs(choices) do
local x = 3 + (i - 1) * (card_w + 2)
local y = 5
local h = H - 9
local bg = c.color or self.theme.gold
self.s.setBackgroundColor(bg); self.s.setTextColor(self.theme.bg)
for ky = y, y + h - 1 do
for kx = x, x + card_w - 1 do
self.s.setCursorPos(kx, ky); self.s.write(" ")
end
end
local lx = x + math.floor((card_w - #c.label) / 2)
self.s.setCursorPos(lx, y + math.floor(h / 2) - 1)
self.s.write(c.label)
if c.subtitle then
local sx = x + math.floor((card_w - #c.subtitle) / 2)
self.s.setCursorPos(sx, y + math.floor(h / 2) + 1)
self.s.write(c.subtitle)
end
table.insert(zones, {x=x, y=y, w=card_w, h=h, value=c.value})
end
else
for i, c in ipairs(choices) do
local y = 5 + (i - 1) * (card_h + 1)
local h = card_h
self.s.setBackgroundColor(c.color or self.theme.gold)
self.s.setTextColor(self.theme.bg)
for ky = y, y + h - 1 do
for kx = 3, W - 2 do
self.s.setCursorPos(kx, ky); self.s.write(" ")
end
end
self.s.setCursorPos(5, y + math.floor(h / 2)); self.s.write(c.label)
if c.subtitle then
self.s.setCursorPos(5 + #c.label + 4, y + math.floor(h / 2))
self.s.write(c.subtitle)
end
table.insert(zones, {x=3, y=y, w=W-4, h=h, value=c.value})
end
end
local cy = H - 3
self.s.setBackgroundColor(self.theme.debit); self.s.setTextColor(self.theme.ink)
local cw = 12
local cx = math.floor((W - cw) / 2)
for ky = cy, cy + 2 do
for kx = cx, cx + cw - 1 do
self.s.setCursorPos(kx, ky); self.s.write(" ")
end
end
self.s.setCursorPos(cx + 3, cy + 1); self.s.write("CANCEL")
table.insert(zones, {x=cx, y=cy, w=cw, h=3, value=nil, cancel=true})
return zones
end
local zones = render()
while true do
local ev, _, mx, my = os.pullEvent()
if ev == "monitor_touch" then
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
if z.cancel then return nil end
return z.value
end
end
end
end
end
function ui:confirmScreen(title, message, opts)
opts = opts or {}
local W, H = self:size()
local function render()
local zones = {}
self.s.setBackgroundColor(self.theme.bg); self.s.clear()
self.s.setBackgroundColor(self.theme.surface)
for x = 1, W do
self.s.setCursorPos(x, 1); self.s.write(" ")
self.s.setCursorPos(x, 2); self.s.write(" ")
end
self.s.setTextColor(self.theme.gold); self.s.setCursorPos(2, 1)
self.s.write(title or "")
self.s.setBackgroundColor(self.theme.bg); self.s.setTextColor(self.theme.ink)
local y = 5
for line in (message or ""):gmatch("[^\n]+") do
local sx = math.floor((W - #line) / 2)
self.s.setCursorPos(math.max(2, sx), y); self.s.write(line)
y = y + 1
end
local by = H - 4
local btn_w = 14
local ok_label = opts.ok_label or "OK"
local cancel_label = opts.cancel_label or "CANCEL"
local ok_color = opts.ok_color or self.theme.credit
local cancel_color = opts.cancel_color or self.theme.debit
local total = btn_w * 2 + 4
local x0 = math.floor((W - total) / 2)
self.s.setBackgroundColor(cancel_color); self.s.setTextColor(self.theme.ink)
for ky = by, by + 2 do
for kx = x0, x0 + btn_w - 1 do
self.s.setCursorPos(kx, ky); self.s.write(" ")
end
end
self.s.setCursorPos(x0 + math.floor((btn_w - #cancel_label) / 2), by + 1)
self.s.write(cancel_label)
table.insert(zones, {x=x0, y=by, w=btn_w, h=3, value=false})
local ox = x0 + btn_w + 4
self.s.setBackgroundColor(ok_color); self.s.setTextColor(self.theme.bg)
for ky = by, by + 2 do
for kx = ox, ox + btn_w - 1 do
self.s.setCursorPos(kx, ky); self.s.write(" ")
end
end
self.s.setCursorPos(ox + math.floor((btn_w - #ok_label) / 2), by + 1)
self.s.write(ok_label)
table.insert(zones, {x=ox, y=by, w=btn_w, h=3, value=true})
return zones
end
local zones = render()
while true do
local ev, _, mx, my = os.pullEvent()
if ev == "monitor_touch" then
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
return z.value
end
end
end
end
end
return ui
end
local function makeAudio(speaker)
local a = {speaker = speaker}
function a:play(kind)
if not self.speaker or not self.speaker.playNote then return end
local cues = {
tap = {{"hat", 0.4, 6}},
success = {{"chime", 0.6, 18}, {"chime", 0.6, 24}},
error = {{"bass", 0.8, 4}},
cash = {{"bell", 1.0, 18}, {"bell", 0.7, 24}},
click = {{"hat", 0.3, 10}},
signin = {{"chime", 0.5, 14}, {"chime", 0.5, 17}, {"chime", 0.5, 21}},
signout = {{"bass", 0.5, 10}, {"bass", 0.5, 6}},
}
local seq = cues[kind]
if not seq then return end
for _, note in ipairs(seq) do
pcall(self.speaker.playNote, note[1], note[2], note[3])
sleep(0.05)
end
end
return a
end
local function printReceipt(printer, branch, kind, fields)
if not printer then return false end
if not printer.newPage() then return false end
printer.setPageTitle("VRB Receipt")
local y = 1
local function line(s) printer.setCursorPos(1, y); printer.write(s or ""); y = y + 1 end
line("  VANGUARD RESERVE BANK")
line("  ---------------------")
line("")
line(kind)
line(string.rep("-", 24))
for _, f in ipairs(fields) do
if type(f) == "string" then line(f)
elseif type(f) == "table" then
line(string.format("%-10s %s", f[1], tostring(f[2])))
end
end
line(string.rep("-", 24))
line("Branch: "..branch)
line(os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("  Stability. Trust.")
line("      Prosperity.")
printer.endPage()
return true
end
local function runATM()
local secret_ok, secret = pcall(loadClientKeys, false)
if not secret_ok or not secret then
showStartupError("ATM", "Missing or unreadable server.secret",
tostring(secret),
{"Check that /.vrb/keys/server.secret exists",
"If missing: re-run the bootstrap with the distribution floppy",
"If file exists but unreadable: run `delete /.vrb/keys/server.secret` and re-bootstrap"})
return
end
local C = newClient(secret, nil)
local mon, mon_name = findAdvancedMonitor()
if not mon then
showStartupError("ATM", "No monitor found",
"Looked for any block of type 'monitor' adjacent to or networked with this computer",
{"Place a 3x3 grid of Advanced Monitor blocks adjacent to this computer",
"Advanced Monitors are gold-trimmed (NOT regular Monitors)",
"Make sure they're directly touching the computer or connected via wired modem",
"Reboot this computer after placing them"})
return
end
if not (mon.isColor and mon.isColor()) then
showStartupError("ATM", "Found a Monitor but it's not Advanced",
"Touch input only works on Advanced Monitors (gold-trimmed)",
{"Break the existing monitor blocks",
"Replace with Advanced Monitors -- crafted with gold ingots, not stone",
"The texture is darker / has gold trim",
"Reboot this computer after replacing"})
return
end
local ok_scale = pcall(function() mon.setTextScale(0.5) end)
if not ok_scale then
showStartupError("ATM", "Monitor accepted but couldn't set text scale",
"This may indicate a CC: Tweaked compatibility issue",
{"Try a different monitor", "Check your CC: Tweaked version"})
return
end
local ui = makeUI(mon)
local speaker = findPeripheral("speaker")
local printer = findPeripheral("printer")
local audio = makeAudio(speaker)
local branch = os.getComputerLabel() or ("Branch#"..os.getComputerID())
local ping = C:call("ping", {})
if not ping.ok then
showStartupError("ATM", "Cannot reach the Reserve Bank",
tostring(ping.err),
{"Verify the server computer is running (it should show 'Serving.')",
"Verify both this ATM's modem AND the server's modem are enabled (red ring)",
"If using regular wireless modems, both must be within 64 blocks",
"Use Ender Modems for unlimited range",
"If your server's vault is in an unloaded chunk, the server is frozen",
"Check that this computer's server.secret matches the server's"})
return
end
local S = {
screen = "home",
session = nil,
account_id = nil,
owner = nil,
kind = nil,
balance = 0,
prev_balance= 0,
keypad = "",
keypad_title= nil,
keypad_mask = false,
keypad_label= nil,
on_ok = nil,
on_cancel = nil,
list_title = nil,
list_lines = nil,
list_back = nil,
loading = false,
pending_target = nil,
pending_amount = nil,
policy = nil,
}
local function call(method, params)
S.loading = true
local r = C:call(method, params)
S.loading = false
return r
end
local function refreshBalance()
local r = call("profile", {session=S.session})
if r.ok and r.profile then
S.owner = r.profile.owner or S.owner
S.prev_balance = S.balance
if r.profile.checking then
S.balance = r.profile.checking.balance
S.account_id = r.profile.checking.id
S.kind = "checking"
end
if r.profile.savings then
S.savings = r.profile.savings.balance
S.savings_id = r.profile.savings.id
S.savings_young = r.profile.savings.young_cents or 0
else
S.savings = nil; S.savings_id = nil; S.savings_young = 0
end
return true
end
local r2 = call("balance", {session=S.session})
if r2.ok then
S.prev_balance = S.balance
S.balance = r2.balance; S.kind = r2.kind; S.owner = r2.owner
return true
end
ui:showToast("error", (r2.err or r.err) or "Session invalid")
S.session = nil; S.screen = "home"
return false
end
local function renderHeader(subtitle)
local W = ({ui:size()})[1]
ui:fill(1, 1, W, 4, ui.theme.surface)
ui:crest(2, 1)
ui:write(10, 1, "VANGUARD RESERVE BANK", ui.theme.gold, ui.theme.surface)
ui:write(10, 2, subtitle or "", ui.theme.ink, ui.theme.surface)
ui:write(10, 3, "Branch " .. branch, ui.theme.ink_muted, ui.theme.surface)
local clock = os.date("%H:%M")
ui:write(W - #clock - 1, 1, clock, ui.theme.gold, ui.theme.surface)
if S.session then
ui:statusPill(W - 14, 2, "SIGNED IN", "ok")
end
ui:hline(1, 5, W, ui.theme.gold, ui.theme.bg, "\140")
end
local function renderFooter()
local W, H = ui:size()
ui:hline(1, H - 2, W, ui.theme.rule, ui.theme.bg, "\140")
ui:write(2, H, "VRB v" .. VERSION, ui.theme.ink_muted, ui.theme.bg)
local right = "Stability \149 Trust \149 Prosperity"
ui:write(W - #right - 1, H, right, ui.theme.gold_dim, ui.theme.bg)
if S.loading then
ui:spinner(math.floor(W/2), H, ui.anim_frame)
end
end
local function renderHome()
ui:begin(); ui:clear()
renderHeader("Stability \149 Trust \149 Prosperity")
local W, H = ui:size()
local hero_y = 6
local hero_h = math.max(3, math.floor((H - 6) / 8))
ui:fill(2, hero_y, W - 2, hero_h, ui.theme.surface)
ui:write(3, hero_y, "Public bank of the Vanguard-stewarded server.",
ui.theme.ink, ui.theme.surface)
ui:write(3, hero_y + 1, "Touch a card below to begin.",
ui.theme.ink_muted, ui.theme.surface)
local actions = {
{"SIGN IN", "signin", "Access your account", ui.theme.gold},
{"OPEN ACCOUNT", "open", "Open checking or savings", ui.theme.credit},
{"PROGRESS REWARDS", "progress", "Earn USD for achievements", ui.theme.gold_dim or ui.theme.gold},
{"WORK ORDERS", "work_orders", "Public Works bounties", ui.theme.gold_dim or ui.theme.gold},
{"POLICY & RATES", "rates", "Current interest and tax", ui.theme.surface_alt or ui.theme.surface},
{"LOOK UP USER", "lookup", "Find a player's accounts", ui.theme.surface_alt or ui.theme.surface},
}
local pad = 2
local grid_y0 = hero_y + hero_h + 1
local grid_y1 = H - 2
local grid_h = grid_y1 - grid_y0
local card_w = math.floor((W - pad * 3) / 2)
local card_h = math.floor((grid_h - 2) / 3)
if card_h < 3 then card_h = 3 end
for i, act in ipairs(actions) do
local col = ((i - 1) % 2)
local row = math.floor((i - 1) / 2)
local x = pad + col * (card_w + pad)
local y = grid_y0 + row * (card_h + 1)
local color = act[4]
ui:fill(x, y, card_w, card_h, color)
local title = act[1]
local title_x = x + math.max(1, math.floor((card_w - #title) / 2))
ui:write(title_x, y + math.floor(card_h / 2) - 1, title,
ui.theme.bg, color)
local sub = act[3]
if #sub > card_w - 2 then sub = sub:sub(1, card_w - 5) .. "..." end
local sub_x = x + math.max(1, math.floor((card_w - #sub) / 2))
ui:write(sub_x, y + math.floor(card_h / 2) + 1, sub,
ui.theme.bg, color)
ui:hotzone(x, y, card_w, card_h, act[2])
end
renderFooter()
ui:drawBanner(1, 6, W)
ui:drawToast()
end
local function renderKeypad()
ui:begin(); ui:clear()
renderHeader(S.keypad_title or "ENTRY")
local W, H = ui:size()
ui:card(3, 7, W - 4, 4)
ui:write(5, 8, S.keypad_label or "", ui.theme.ink_muted, ui.theme.surface)
local shown = S.keypad_mask and string.rep("\7", #S.keypad) or S.keypad
local cursor = (ui.anim_frame % 20 < 10) and "_" or " "
ui:write(5, 9, "> " .. shown .. cursor, ui.theme.gold, ui.theme.surface)
local keys = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"CLR","0","OK"}}
local bw, bh = 10, 3
local totalW = 3 * (bw + 2) - 2
local sx = math.floor((W - totalW) / 2)
local sy = 13
for r, row in ipairs(keys) do
for c, k in ipairs(row) do
local x = sx + (c - 1) * (bw + 2)
local y = sy + (r - 1) * (bh + 1)
local kind = (k == "OK") and "success" or (k == "CLR") and "danger" or "primary"
ui:button(x, y, bw, k, {kind=kind, action="key", data=k})
end
end
ui:button(3, H - 5, 14, "CANCEL", {kind="danger", action="cancel"})
renderFooter()
ui:drawBanner(1, 6, W)
ui:drawToast()
end
local function renderDashboard()
ui:begin(); ui:clear()
renderHeader("Welcome back, " .. (S.owner or "?"))
local W, H = ui:size()
local strip_h = 4
local strip_y = 6
ui:fill(2, strip_y, W - 2, strip_h, ui.theme.surface)
ui:write(3, strip_y, "Profile: " .. (S.owner or ""),
ui.theme.ink, ui.theme.surface)
ui:write(3, strip_y + 1, "CHECKING",
ui.theme.ink_muted, ui.theme.surface)
local chk_text = fmtMoney(S.balance or 0)
ui:write(W - #chk_text - 3, strip_y + 1, chk_text,
ui.theme.gold, ui.theme.surface)
ui:write(3, strip_y + 2, "SAVINGS",
ui.theme.ink_muted, ui.theme.surface)
local sav_text = S.savings and fmtMoney(S.savings) or "(none)"
ui:write(W - #sav_text - 3, strip_y + 2, sav_text,
S.savings and ui.theme.gold or ui.theme.ink_muted,
ui.theme.surface)
if S.savings and (S.savings_young or 0) > 0 then
local young = string.format("(%s under 30 days, 50%% early-tax)",
fmtMoney(S.savings_young))
ui:write(3, strip_y + 3, young,
ui.theme.warn, ui.theme.surface)
end
local actions = {
{"PAY", "pay", ui.theme.gold},
{"CHARGE", "charge", ui.theme.gold},
{"REQUESTS", "requests", ui.theme.credit},
{"MOVE", "move", ui.theme.credit},
{"HISTORY", "history", ui.theme.gold},
{"WORK ORDERS","work_orders", ui.theme.credit},
{"CIVIC JOBS", "civic_jobs", ui.theme.credit},
{"OPEN CD", "open_cd", ui.theme.gold_dim or ui.theme.gold},
{"LOANS", "loans", ui.theme.gold_dim or ui.theme.gold},
{"EARNINGS", "earnings", ui.theme.surface_alt or ui.theme.surface},
{"INSURANCE", "insurance", ui.theme.surface_alt or ui.theme.surface},
{"NOTIFY", "notify", ui.theme.surface_alt or ui.theme.surface},
{"SIGN OUT", "signout", ui.theme.debit},
}
local pad = 1
local cols = 3
local rows = math.ceil(#actions / cols)
local grid_y0 = strip_y + strip_h + 1
local grid_y1 = H - 2
local grid_h = grid_y1 - grid_y0
local card_w = math.floor((W - pad * (cols + 1)) / cols)
local card_h = math.max(2, math.floor((grid_h - rows + 1) / rows))
for i, act in ipairs(actions) do
local col = ((i - 1) % cols)
local row = math.floor((i - 1) / cols)
local x = pad + col * (card_w + pad)
local y = grid_y0 + row * (card_h + 1)
local color = act[3]
ui:fill(x, y, card_w, card_h, color)
local title = act[1]
local title_x = x + math.max(1, math.floor((card_w - #title) / 2))
local title_y = y + math.floor(card_h / 2)
ui:write(title_x, title_y, title, ui.theme.bg, color)
ui:hotzone(x, y, card_w, card_h, act[2])
end
renderFooter()
ui:drawBanner(1, 6, W)
ui:drawToast()
end
local function renderList(title, lines, back_action, empty)
ui:begin(); ui:clear()
renderHeader(title or "")
local W, H = ui:size()
if not lines or #lines == 0 then
ui:emptyState(1, 7, W, H - 13,
empty and empty.title or "Nothing here yet",
empty and empty.subtitle or "",
empty and empty.hint or "")
else
ui:card(3, 7, W - 4, H - 13)
local y = 9
for _, line in ipairs(lines) do
if y < H - 6 then
if line.mark then
ui:row(5, y, W - 8, line.mark, line.mark_color,
line.left, line.right, line.left_color, line.right_color,
ui.theme.surface)
else
ui:write(5, y, (line.text or ""):sub(1, W - 10),
line.color or ui.theme.ink, ui.theme.surface)
end
y = y + 1
end
end
end
ui:button(3, H - 5, 14, "\27 BACK", {kind="secondary", action=back_action or "back"})
renderFooter()
ui:drawBanner(1, 6, W)
ui:drawToast()
end
local function enterKeypad(title, mask, label, onOk, onCancel)
S.keypad = ""; S.keypad_title = title; S.keypad_mask = mask
S.keypad_label = label; S.on_ok = onOk; S.on_cancel = onCancel
S.screen = "keypad"
end
local function doOpenAccount()
audio:play("click")
local owner = ui:keyboardScreen("OPEN PROFILE  -  Step 1 of 2", {
subtitle = "Enter your Minecraft username (2-16 letters, numbers, underscore)",
pattern = "^[%w_]*$",
max_len = 16,
})
if not owner or #owner < 2 then
S.screen = "home"
ui:showToast("info", "Cancelled.")
return
end
local pin = ui:keyboardScreen("OPEN PROFILE  -  Step 2 of 2", {
subtitle = "Choose a 4-digit PIN. Don't reuse one from another game.",
mask = true,
numeric = true,
digits_only = true,
pattern = "^%d*$",
max_len = 4,
})
if not pin or #pin ~= 4 then
S.screen = "home"
ui:showToast("error", "PIN must be exactly 4 digits.")
return
end
local pin2 = ui:keyboardScreen("OPEN PROFILE  -  Confirm PIN", {
subtitle = "Re-enter the same 4 digits",
mask = true,
numeric = true,
digits_only = true,
pattern = "^%d*$",
max_len = 4,
})
if pin ~= pin2 then
S.screen = "home"
audio:play("error")
ui:showToast("error", "PINs did not match. Start over.")
return
end
local r = call("open_account", {owner=owner, pin=pin})
if not r.ok then
audio:play("error")
ui:confirmScreen("Could not open profile", r.err or "Unknown error",
{ok_label="OK", cancel_label="OK"})
S.screen = "home"
return
end
audio:play("signin")
ui:confirmScreen("PROFILE OPENED",
"Welcome to the Vanguard Reserve Bank.\n\n" ..
"Checking: " .. (r.checking_id or r.account_id) .. "\n" ..
"Savings:  " .. (r.savings_id or "?") .. "\n\n" ..
"Sign in with your username, not the IDs.\n" ..
"Both share the same PIN.",
{ok_label="OK", cancel_label="OK"})
S.screen = "home"
end
local function doLookup()
audio:play("click")
local who = ui:keyboardScreen("LOOK UP USER", {
subtitle = "Find a player's accounts by their Minecraft username",
pattern = "^[%w_]*$",
max_len = 16,
})
if not who or #who < 1 then S.screen = "home"; return end
local r = call("lookup", {owner=who})
if not r.ok or not r.accounts or #r.accounts == 0 then
ui:confirmScreen("No accounts found",
"No bank accounts for "..who.." were found.",
{ok_label="OK", cancel_label="OK"})
S.screen = "home"
return
end
local lines = {}
for _, acc in ipairs(r.accounts) do
table.insert(lines, {
mark="-", mark_color=ui.theme.ink_muted,
left=acc.id.."  "..acc.kind, right="",
})
end
S.list_title = "ACCOUNTS FOR "..who:upper()
S.list_lines = lines
S.list_back = "back_to_home"
S.list_empty = {title="No accounts", subtitle="", hint=""}
S.screen = "list"
end
local function doSignin()
local owner = ui:keyboardScreen("Sign In - Username", {
subtitle = "Your minecraft username (a-z, 0-9, _)",
pattern = "^[A-Za-z0-9_]*$",
max_len = 32,
})
if not owner or #owner < 2 then
S.screen = "home"; return
end
enterKeypad("Sign In - PIN", true, "PIN:",
function(pin)
local r = call("auth_by_owner",
{owner=owner, pin=pin, branch=branch})
if r.ok then
S.session = r.session
S.account_id = r.account.id
S.owner = r.account.owner
S.kind = r.account.kind
S.balance = r.account.balance
S.prev_balance = r.account.balance
refreshBalance()
S.screen = "dashboard"
audio:play("signin")
ui:showToast("ok", "Welcome back, " .. r.account.owner)
else
audio:play("error")
ui:showToast("error", r.err or "Sign-in failed")
S.screen = "home"
end
end,
function() S.screen = "home" end)
end
local function doPay()
if not S.session then
audio:play("error"); ui:showToast("error", "Sign in first")
S.screen = "dashboard"; return
end
local lr = call("list_payable_accounts", {session=S.session})
if not lr.ok then
audio:play("error"); ui:showToast("error", lr.err or "Failed")
S.screen = "dashboard"; return
end
local accounts = lr.accounts or {}
if #accounts == 0 then
audio:play("error"); ui:showToast("info", "No other accounts to pay")
S.screen = "dashboard"; return
end
local filter = ""
local scroll = 0
local selected
local function filteredAccounts()
if filter == "" then return accounts end
local f = filter:lower()
local out = {}
for _, a in ipairs(accounts) do
if a.owner:lower():find(f, 1, true)
or a.id:lower():find(f, 1, true) then
table.insert(out, a)
end
end
return out
end
local function renderPicker()
local W, H = ui:size()
ui:begin(); ui:clear()
ui:fill(1, 1, W, 3, ui.theme.surface)
ui:write(2, 1, "PAY -- pick recipient", ui.theme.gold, ui.theme.surface)
local filtered = filteredAccounts()
ui:write(2, 2, ("%d account%s%s"):format(
#filtered, #filtered == 1 and "" or "s",
filter == "" and "" or "  (filter: \""..filter.."\")"),
ui.theme.ink_muted, ui.theme.surface)
local zones = {}
ui:fill(W - 14, 1, 14, 3, ui.theme.gold)
ui:write(W - 12, 2, "[SEARCH]", ui.theme.bg, ui.theme.gold)
table.insert(zones, {x=W-14, y=1, w=14, h=3, action="search"})
ui:fill(1, H, W, 1, ui.theme.surface)
ui:write(2, H, "[BACK]", ui.theme.gold, ui.theme.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:fill(W - 14, H, 6, 1, ui.theme.surface_alt or ui.theme.surface)
ui:write(W - 12, H, "UP", ui.theme.gold, ui.theme.surface_alt or ui.theme.surface)
table.insert(zones, {x=W-14, y=H, w=6, h=1, action="up"})
ui:fill(W - 8, H, 6, 1, ui.theme.surface_alt or ui.theme.surface)
ui:write(W - 6, H, "DOWN", ui.theme.gold, ui.theme.surface_alt or ui.theme.surface)
table.insert(zones, {x=W-8, y=H, w=8, h=1, action="down"})
local rows = H - 5
if scroll < 0 then scroll = 0 end
if scroll > math.max(0, #filtered - rows) then
scroll = math.max(0, #filtered - rows)
end
local y = 5
for i = 1, rows do
local idx = scroll + i
if idx > #filtered then break end
local a = filtered[idx]
local row_y = y + i - 1
ui:fill(1, row_y, W, 1,
(i % 2 == 0) and (ui.theme.surface_alt or ui.theme.surface)
or ui.theme.bg)
ui:write(2, row_y, a.owner:sub(1, 20), ui.theme.gold, nil)
ui:write(24, row_y, a.id, ui.theme.ink, nil)
ui:write(W - 12, row_y, (a.kind or ""):sub(1, 9),
ui.theme.ink_muted, nil)
table.insert(zones, {x=1, y=row_y, w=W, h=1,
action="pick", account=a})
end
if #filtered == 0 then
ui:write(2, 5, "No accounts match \""..filter.."\"",
ui.theme.ink_muted, ui.theme.bg)
end
return zones
end
while not selected do
local zones = renderPicker()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
S.screen = "dashboard"; return
elseif hit.action == "search" then
local s = ui:keyboardScreen("Search by username", {
subtitle = "Type letters to filter; clear to see all",
pattern = "^[%w_%s]*$", max_len = 20,
initial = filter,
})
if s ~= nil then
filter = s:gsub("%s+", "")
scroll = 0
end
elseif hit.action == "up" then
local W, H = ui:size()
scroll = scroll - (H - 5)
elseif hit.action == "down" then
local W, H = ui:size()
scroll = scroll + (H - 5)
elseif hit.action == "pick" then
selected = hit.account
end
end
local amt_str = ui:keyboardScreen(
"Pay "..selected.owner.." -- amount",
{
subtitle = "Type the dollar amount (e.g. 50 or 50.25)",
numeric = true, digits_only = false,
pattern = "^%d*%.?%d*$", max_len = 12,
})
if not amt_str or amt_str == "" then
S.screen = "dashboard"; return
end
local dollars = tonumber(amt_str)
if not dollars or dollars <= 0 then
audio:play("error"); ui:showToast("error", "Invalid amount")
S.screen = "dashboard"; return
end
local cents = math.floor(dollars * 100 + 0.5)
if cents <= 0 then
audio:play("error"); ui:showToast("error", "Amount too small")
S.screen = "dashboard"; return
end
local confirmed = ui:confirmScreen(
"Confirm payment",
string.format("Pay %s\nto %s (%s)?\n\n(Your balance: %s)",
fmtMoney(cents), selected.owner, selected.id,
fmtMoney(S.balance)),
{ok_label = "PAY  "..fmtMoney(cents), ok_color = ui.theme.gold})
if not confirmed then
S.screen = "dashboard"; return
end
local r = call("transfer", {
session = S.session,
target_id = selected.id,
amount = cents,
memo = "ATM payment",
})
if r.ok then
S.prev_balance = S.balance; S.balance = r.balance
audio:play("success")
local msg = string.format("Sent %s to %s",
fmtMoney(cents), selected.owner)
if r.tax and r.tax > 0 then
msg = msg .. " (tax " .. fmtMoney(r.tax) .. ")"
end
ui:showToast("ok", msg)
else
audio:play("error"); ui:showToast("error", r.err or "Failed")
end
S.screen = "dashboard"
end
local function doCharge()
if not S.session then
audio:play("error"); ui:showToast("error", "Sign in first")
S.screen = "dashboard"; return
end
local target = ui:keyboardScreen("CHARGE - Bill Whom?", {
subtitle = "Their Minecraft username (a-z, 0-9, _)",
pattern = "^[A-Za-z0-9_]*$",
max_len = 32,
})
if not target or #target < 2 then S.screen = "dashboard"; return end
local amt_str = ui:keyboardScreen("CHARGE - Amount", {
subtitle = "How much to charge? Decimals OK.",
numeric=true, digits_only=false,
pattern="^%d*%.?%d*$", max_len=12,
})
local dollars = tonumber(amt_str or "")
if not dollars or dollars <= 0 then S.screen = "dashboard"; return end
local cents = math.floor(dollars * 100 + 0.5)
local memo = ui:keyboardScreen("CHARGE - Memo (optional)", {
subtitle = "What is this for? Press OK to skip.",
pattern = "^[%w%s%-_,.()/!?']*$",
max_len = 60,
})
if memo and #memo == 0 then memo = nil end
local conf = ui:confirmScreen("Send charge?",
string.format("Bill %s for %s%s",
target, fmtMoney(cents),
memo and ("\nMemo: "..memo) or ""),
{ok_label="SEND", ok_color=ui.theme.gold})
if not conf then S.screen = "dashboard"; return end
local r = call("request_payment", {
session=S.session, target_owner=target,
amount=cents, memo=memo})
if r.ok then
audio:play("success")
ui:showToast("ok", "Charge sent: "..(r.request_id or "?"))
else
audio:play("error")
ui:showToast("error", r.err or "Failed")
end
S.screen = "dashboard"
end
local function doRequests()
if not S.session then
audio:play("error"); ui:showToast("error", "Sign in first")
S.screen = "dashboard"; return
end
local view = "incoming"
while true do
local r
if view == "incoming" then
r = call("list_payment_requests", {session=S.session})
else
r = call("list_my_sent_requests", {session=S.session})
end
local reqs = r.ok and r.requests or {}
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, ui.theme.surface)
ui:write(2, 1, "PAYMENT REQUESTS", ui.theme.gold, ui.theme.surface)
ui:write(2, 2,
view == "incoming"
and ("Bills addressed to you ("..#reqs..")")
or ("Charges you sent ("..#reqs..")"),
ui.theme.ink_muted, ui.theme.surface)
local zones = {}
local tab_y = 4
local tab_w = math.floor((W - 4) / 2)
ui:fill(2, tab_y, tab_w, 1,
view == "incoming" and ui.theme.gold or (ui.theme.surface_alt or ui.theme.surface))
ui:write(2 + math.floor((tab_w - 8) / 2), tab_y, "INCOMING",
view == "incoming" and ui.theme.bg or ui.theme.ink,
view == "incoming" and ui.theme.gold or (ui.theme.surface_alt or ui.theme.surface))
table.insert(zones, {x=2, y=tab_y, w=tab_w, h=1, action="tab_in"})
ui:fill(2 + tab_w + 1, tab_y, tab_w, 1,
view == "outgoing" and ui.theme.gold or (ui.theme.surface_alt or ui.theme.surface))
ui:write(2 + tab_w + 1 + math.floor((tab_w - 8) / 2), tab_y, "OUTGOING",
view == "outgoing" and ui.theme.bg or ui.theme.ink,
view == "outgoing" and ui.theme.gold or (ui.theme.surface_alt or ui.theme.surface))
table.insert(zones, {x=2 + tab_w + 1, y=tab_y, w=tab_w, h=1, action="tab_out"})
ui:fill(1, H, 8, 1, ui.theme.surface)
ui:write(2, H, "[BACK]", ui.theme.gold, ui.theme.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local y = 6
if #reqs == 0 then
ui:write(2, y,
view == "incoming" and "No charges to pay."
or "You have no pending charges out.",
ui.theme.ink_muted, ui.theme.bg)
else
for i, req in ipairs(reqs) do
if y > H - 3 then break end
local row_h = 3
ui:fill(1, y, W, row_h,
(i % 2 == 0) and (ui.theme.surface_alt or ui.theme.surface)
or ui.theme.bg)
local who = view == "incoming" and req.from_owner
or req.to_owner
ui:write(2, y, (who or "?"):sub(1, 16),
ui.theme.ink, nil)
ui:write(2, y + 1,
fmtMoney(req.amount or 0)
.. (req.memo and ("  "..req.memo:sub(1, 30)) or ""),
ui.theme.gold, nil)
if view == "incoming" and req.status == "pending" then
local has_funds = (S.balance or 0) >= (req.amount or 0)
if has_funds then
ui:fill(W - 31, y, 9, 2, ui.theme.credit)
ui:write(W - 29, y, "[PAY]", ui.theme.bg, ui.theme.credit)
table.insert(zones, {x=W-31, y=y, w=9, h=2,
action="approve", req=req})
ui:fill(W - 21, y, 11, 2, ui.theme.gold)
ui:write(W - 19, y, "[AUTO]", ui.theme.bg, ui.theme.gold)
table.insert(zones, {x=W-21, y=y, w=11, h=2,
action="auto", req=req})
ui:fill(W - 9, y, 8, 2, ui.theme.warn)
ui:write(W - 7, y, "[NO]", ui.theme.bg, ui.theme.warn)
table.insert(zones, {x=W-9, y=y, w=8, h=2,
action="reject", req=req})
else
ui:fill(W - 22, y, 13, 2, ui.theme.gold)
ui:write(W - 20, y, "[AUTO-PAY]",
ui.theme.bg, ui.theme.gold)
table.insert(zones, {x=W-22, y=y, w=13, h=2,
action="auto", req=req})
ui:fill(W - 9, y, 8, 2, ui.theme.warn)
ui:write(W - 7, y, "[NO]",
ui.theme.bg, ui.theme.warn)
table.insert(zones, {x=W-9, y=y, w=8, h=2,
action="reject", req=req})
end
elseif view == "incoming" and req.status == "auto_pending" then
ui:fill(W - 26, y, 17, 2, ui.theme.gold)
ui:write(W - 24, y, "[CANCEL AUTO]",
ui.theme.bg, ui.theme.gold)
table.insert(zones, {x=W-26, y=y, w=17, h=2,
action="cancel_auto", req=req})
ui:fill(W - 9, y, 8, 2, ui.theme.warn)
ui:write(W - 7, y, "[NO]",
ui.theme.bg, ui.theme.warn)
table.insert(zones, {x=W-9, y=y, w=8, h=2,
action="reject", req=req})
elseif view == "outgoing" and (req.status == "pending"
or req.status == "auto_pending") then
if req.status == "auto_pending" then
ui:write(W - 32, y + 1,
"(customer auto-pay armed)",
ui.theme.gold, nil)
end
ui:fill(W - 13, y, 12, 2, ui.theme.warn)
ui:write(W - 11, y, "[CANCEL]",
ui.theme.bg, ui.theme.warn)
table.insert(zones, {x=W-13, y=y, w=12, h=2,
action="cancel", req=req})
else
ui:write(W - 18, y,
"  ["..((req.status or "?")):upper().."]",
ui.theme.ink_muted, nil)
end
y = y + row_h + 1
end
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then hit = z; break end
end
if not hit then
elseif hit.action == "back" then
refreshBalance(); S.screen = "dashboard"; return
elseif hit.action == "tab_in" then
view = "incoming"
elseif hit.action == "tab_out" then
view = "outgoing"
elseif hit.action == "approve" then
local req = hit.req
local conf = ui:confirmScreen(
"Pay this charge?",
string.format("To: %s\nAmount: %s\n%sFunds will move from your checking.",
req.from_owner, fmtMoney(req.amount),
req.memo and ("Memo: "..req.memo.."\n") or ""),
{ok_label="PAY "..fmtMoney(req.amount),
ok_color=ui.theme.credit})
if conf then
local rr = call("approve_payment_request",
{session=S.session, request_id=req.id})
if rr.ok then
audio:play("cash")
ui:showToast("ok", "Paid "..fmtMoney(req.amount))
refreshBalance()
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
elseif hit.action == "auto" then
local req = hit.req
local has_funds = (S.balance or 0) >= (req.amount or 0)
local conf = ui:confirmScreen(
"Auto-pay this charge?",
string.format(
"To: %s\nAmount: %s\n%s%s",
req.from_owner, fmtMoney(req.amount),
req.memo and ("Memo: "..req.memo.."\n") or "",
has_funds
and "You have funds now -- charged immediately."
or "Charged automatically when you have funds."),
{ok_label="ARM AUTO-PAY",
ok_color=ui.theme.gold})
if conf then
local rr = call("auto_payment_request",
{session=S.session, request_id=req.id})
if rr.ok then
if rr.executed then
audio:play("cash")
ui:showToast("ok",
"Paid immediately: "..fmtMoney(req.amount))
else
audio:play("click")
ui:showToast("ok",
"Armed; pays when funds available")
end
refreshBalance()
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
elseif hit.action == "cancel_auto" then
local req = hit.req
local conf = ui:confirmScreen(
"Cancel auto-pay?",
string.format("From: %s\nAmount: %s\n%sCharge returns to pending.",
req.from_owner, fmtMoney(req.amount),
req.memo and ("Memo: "..req.memo.."\n") or ""),
{ok_label="CANCEL AUTO", ok_color=ui.theme.warn})
if conf then
local rr = call("cancel_auto_payment_request",
{session=S.session, request_id=req.id})
if rr.ok then
audio:play("click")
ui:showToast("ok", "Auto-pay disarmed")
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
elseif hit.action == "reject" then
local req = hit.req
local conf = ui:confirmScreen(
"Reject this charge?",
string.format("From: %s\nAmount: %s\n%sNothing will move.",
req.from_owner, fmtMoney(req.amount),
req.memo and ("Memo: "..req.memo.."\n") or ""),
{ok_label="REJECT", ok_color=ui.theme.warn})
if conf then
local rr = call("reject_payment_request",
{session=S.session, request_id=req.id})
if rr.ok then
audio:play("click")
ui:showToast("ok", "Rejected")
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
elseif hit.action == "cancel" then
local req = hit.req
local conf = ui:confirmScreen(
"Cancel this charge?",
string.format("To: %s\nAmount: %s",
req.to_owner, fmtMoney(req.amount)),
{ok_label="CANCEL", ok_color=ui.theme.warn})
if conf then
local rr = call("cancel_payment_request",
{session=S.session, request_id=req.id})
if rr.ok then
audio:play("click")
ui:showToast("ok", "Cancelled")
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
end
end
end
local function doMove()
if not S.session then
audio:play("error"); ui:showToast("error", "Sign in first")
S.screen = "dashboard"; return
end
if not S.savings_id then
audio:play("error")
ui:confirmScreen("No savings account",
"Your profile has no paired savings account.\n"
.."Ask an admin to add one.",
{ok_label="OK", cancel_label="OK"})
S.screen = "dashboard"; return
end
local dir = ui:choiceScreen("MOVE FUNDS", {
{label="CHECKING -> SAVINGS",
subtitle=string.format("Checking: %s", fmtMoney(S.balance or 0)),
value="chk_to_sav", color=ui.theme.credit},
{label="SAVINGS -> CHECKING",
subtitle=string.format("Savings: %s%s",
fmtMoney(S.savings or 0),
((S.savings_young or 0) > 0)
and string.format(" (%s under 30d)", fmtMoney(S.savings_young))
or ""),
value="sav_to_chk", color=ui.theme.gold},
}, {subtitle="Pick a direction"})
if not dir then S.screen = "dashboard"; return end
local amt_str = ui:keyboardScreen("Amount in dollars", {
subtitle = "How much to move? Decimals OK.",
numeric=true, digits_only=false,
pattern="^%d*%.?%d*$", max_len=12,
})
local dollars = tonumber(amt_str or "")
if not dollars or dollars <= 0 then S.screen = "dashboard"; return end
local cents = math.floor(dollars * 100 + 0.5)
local warn_text = ""
if dir == "sav_to_chk" then
local young = S.savings_young or 0
if young > 0 then
local est_taxed = math.min(cents, young)
local est_tax = math.floor(est_taxed * 0.50)
warn_text = string.format(
"\nWarning: up to %s of this move may be under 30 days old.\nWorst-case early-tax: %s.",
fmtMoney(est_taxed), fmtMoney(est_tax))
end
end
local conf = ui:confirmScreen("Confirm move",
string.format("%s\n%s",
dir == "chk_to_sav" and "Checking -> Savings" or "Savings -> Checking",
fmtMoney(cents)) .. warn_text,
{ok_label="MOVE", ok_color=ui.theme.credit})
if not conf then S.screen = "dashboard"; return end
local r = call("move_internal", {
session=S.session, direction=dir, amount=cents})
if r.ok then
audio:play("cash")
local msg = string.format("Moved %s.", fmtMoney(cents))
if (r.tax or 0) > 0 then
msg = msg .. " Early-tax: " .. fmtMoney(r.tax)
end
ui:showToast("ok", msg)
S.balance = r.checking
S.savings = r.savings
else
audio:play("error"); ui:showToast("error", r.err or "Failed")
end
S.screen = "dashboard"
end
local function doHistory()
local r = call("history", {session=S.session, limit=15})
local lines = {}
if r.ok then
for i = #r.history, 1, -1 do
local h = r.history[i]
local amt = h.amount or 0
local is_credit = amt >= 0
local mark = is_credit and "\30" or "\31"
local mark_color = is_credit and ui.theme.credit or ui.theme.debit
local stamp = os.date("%m-%d %H:%M", h.t)
local left = stamp .. "  " .. (h.note or h.type or ""):sub(1, 20)
local right = fmtMoney(amt)
table.insert(lines, {
mark=mark, mark_color=mark_color,
left=left, right=right,
right_color = is_credit and ui.theme.credit or ui.theme.debit,
})
end
S.list_title = "TRANSACTION HISTORY"
S.list_lines = lines
S.list_back = "back_to_dash"
S.list_empty = {title="No transactions yet", subtitle="Your first deposit will appear here"}
else
S.list_lines = {{text=r.err or "Error", color=ui.theme.debit}}
end
S.screen = "list"
end
local function doLoans()
local r = call("list_loans", {session=S.session})
local lines = {}
if r.ok then
for _, l in ipairs(r.loans) do
table.insert(lines, {
mark="$", mark_color=ui.theme.debit,
left=l.id, right=fmtMoney(l.balance) .. "  @ " .. string.format("%.2f%%/mo", l.mpr*100),
right_color=ui.theme.debit,
})
end
end
S.list_title = "YOUR LOANS"
S.list_lines = lines
S.list_back = "back_to_dash"
S.list_empty = {
title="No active loans",
subtitle="The Reserve offers collateralized loans",
hint="See the admin terminal to apply"
}
S.screen = "list"
end
local function doEarnings()
local r = call("my_earnings", {session=S.session})
local h = call("my_earnings_history", {session=S.session, limit=7})
local mr = call("my_rank", {session=S.session})
local mj = call("my_jobs", {session=S.session})
local lines = {}
if not r.ok then
table.insert(lines, {mark="!", mark_color=ui.theme.debit,
left="Unable to load earnings", right=r.err or ""})
elseif not r.enabled then
table.insert(lines, {mark="!", mark_color=ui.theme.warn,
left="Earnings system is currently disabled", right=""})
else
if mr.ok and mr.vanguard and mr.rank then
table.insert(lines, {
mark="*", mark_color=ui.theme.gold,
left=string.format("VANGUARD   %s  %s", mr.rank.grade, mr.rank.label),
right=fmtMoney(mr.rank.weekly_cents).."/wk",
right_color=ui.theme.gold,
})
table.insert(lines, {
mark=" ", mark_color=ui.theme.ink_muted,
left=string.format("  %s/yr  paid daily", fmtMoney(mr.rank.yearly_cents)),
right="",
})
if mr.on_leave then
table.insert(lines, {
mark="*", mark_color=ui.theme.warn,
left="  STATUS: on leave  (salary paid through inactivity)",
right="",
})
end
if (mr.week_paid or 0) > 0 then
table.insert(lines, {
mark="+", mark_color=ui.theme.credit,
left=string.format("  This week:  %d days paid", mr.week_days or 0),
right=fmtMoney(mr.week_paid),
right_color=ui.theme.credit,
})
end
table.insert(lines, {mark=" ", left="", right=""})
end
if mj.ok and mj.jobs and #mj.jobs > 0 then
table.insert(lines, {
mark="*", mark_color=ui.theme.gold,
left=string.format("CIVIC POSITIONS  (%d)", mj.count or 0),
right=fmtMoney(mj.total_annual).. "/yr",
right_color=ui.theme.gold,
})
for _, jb in ipairs(mj.jobs) do
local row_color = jb.on_leave and ui.theme.warn or ui.theme.ink
local status = jb.on_leave and "  on leave" or ""
table.insert(lines, {
mark="-", mark_color=ui.theme.ink_muted,
left=string.format("  %s%s", jb.title, status),
right=fmtMoney(jb.annual_cents).."/yr",
right_color=row_color,
})
end
if (mj.total_weekly or 0) > 0 then
table.insert(lines, {
mark=" ", mark_color=ui.theme.ink_muted,
left=string.format("  Combined  %s/wk    %s/day",
fmtMoney(mj.total_weekly), fmtMoney(mj.total_daily)),
right="",
})
end
table.insert(lines, {mark=" ", left="", right=""})
end
local streak_days = r.streak_days or 0
local mult = r.streak_mult or 1.0
local label = r.streak_label or "New"
local color = ui.theme.gold
if streak_days >= 100 then color = ui.theme.credit
elseif streak_days < 7 then color = ui.theme.ink_muted end
local next_tier = nil
local tier_start = 0
for _, t in ipairs(CFG.EARNINGS_STREAK_TIERS) do
if streak_days >= t.day then tier_start = t.day end
if streak_days < t.day and not next_tier then next_tier = t end
end
table.insert(lines, {
mark="\7", mark_color=color,
left=string.format("STREAK   day %d   %s tier", streak_days, label),
right=string.format("%.2fx", mult),
right_color=color,
})
if next_tier then
local span = next_tier.day - tier_start
local prog = streak_days - tier_start
local pct = span > 0 and (prog / span) or 0
local bar_w = 20
local filled = math.floor(pct * bar_w)
local bar = string.rep("#", filled) .. string.rep("-", bar_w - filled)
local days_to = next_tier.day - streak_days
table.insert(lines, {
mark=" ", left="  ["..bar.."]",
right=string.format("%d days to %s", days_to, next_tier.label),
right_color=ui.theme.ink_muted,
})
else
table.insert(lines, {mark=" ", mark_color=ui.theme.gold,
left="  Maximum tier reached", right="", right_color=ui.theme.gold})
end
if r.insurance_active then
table.insert(lines, {
mark="+", mark_color=ui.theme.credit,
left="  Death Insurance",
right="active",
right_color=ui.theme.credit,
})
end
table.insert(lines, {mark=" ", left="", right=""})
table.insert(lines, {mark="-", mark_color=ui.theme.gold,
left="THIS WEEK", right="", right_color=ui.theme.gold})
if not h.ok or not h.week or #h.week == 0 then
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  No earnings ticks yet this week.", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  Play "..math.floor(CFG.EARNINGS_MIN_SESSION_SEC/60)..
"+ minutes today, then wait for the tick.", right=""})
else
local max_total = 1
for _, e in ipairs(h.week) do
if (e.total or 0) > max_total then max_total = e.total end
end
for i, e in ipairs(h.week) do
local dlabel = "?"
if e.date then
local s = tostring(e.date)
if #s == 8 then
local mo = tonumber(s:sub(5,6)); local d = tonumber(s:sub(7,8))
dlabel = string.format("%02d-%02d", mo or 0, d or 0)
end
end
local bar_w = 10
local filled = math.floor((e.total or 0) / max_total * bar_w)
if filled < 0 then filled = 0 end
if filled > bar_w then filled = bar_w end
local bar = string.rep("#", filled) .. string.rep("-", bar_w - filled)
local row_color = ui.theme.ink
local note = ""
if e.died then note = "   DIED"; row_color = ui.theme.debit end
if e.skipped == "below_session_threshold" then
note = "   skip"; row_color = ui.theme.ink_muted end
table.insert(lines, {
mark=" ", left=string.format("  %s  [%s]", dlabel, bar),
right=fmtMoney(e.total or 0)..note,
right_color=row_color,
})
end
local avg = math.floor(h.week_total / #h.week)
table.insert(lines, {
mark="=", mark_color=ui.theme.gold,
left="  Week total", right=fmtMoney(h.week_total),
right_color=ui.theme.gold,
})
table.insert(lines, {
mark=" ", mark_color=ui.theme.ink_muted,
left="  Average per day", right=fmtMoney(avg),
right_color=ui.theme.ink_muted,
})
end
table.insert(lines, {mark=" ", left="", right=""})
if h.ok and h.week_components then
table.insert(lines, {mark="-", mark_color=ui.theme.gold,
left="TOP COMPONENTS THIS WEEK", right="", right_color=ui.theme.gold})
local component_labels = {
survival_wage = "Survival wage",
combat_pay = "Combat pay",
explorer_bonus = "Explorer bonus",
builder_bonus = "Builder bonus",
danger_pay = "Danger pay",
boss_bounty = "Boss bounty",
build_streak_bonus = "Build streak bonus",
}
local sorted = {}
for k, v in pairs(h.week_components) do
table.insert(sorted, {k=k, v=v})
end
table.sort(sorted, function(a, b) return a.v > b.v end)
local rank_color = {ui.theme.credit, ui.theme.gold, ui.theme.ink_muted}
for i = 1, math.min(3, #sorted) do
local s = sorted[i]
if s.v > 0 then
table.insert(lines, {
mark=tostring(i)..".", mark_color=rank_color[i],
left="  "..(component_labels[s.k] or s.k),
right=fmtMoney(s.v),
right_color=rank_color[i],
})
end
end
local lagging = nil
for i = #sorted, 1, -1 do
local s = sorted[i]
if s.v > 0 and (component_labels[s.k] or "") ~= "" then
lagging = s; break
end
end
if lagging and lagging.v < (sorted[1] and sorted[1].v or 0) / 4 then
table.insert(lines, {
mark=" ", mark_color=ui.theme.ink_muted,
left="  Lagging: "..(component_labels[lagging.k] or lagging.k),
right="try focusing here",
right_color=ui.theme.ink_muted,
})
end
end
end
S.list_title = "EARNINGS"
S.list_lines = lines
S.list_back = "back_to_dash"
S.list_empty = {
title="Earnings breakdown",
subtitle="Your daily earnings activity",
hint=""
}
S.screen = "list"
end
local function doInsurance()
local r = call("my_earnings", {session=S.session})
if not r.ok then
ui:showToast("error", r.err or "Unable to reach bank")
S.screen = "dashboard"; return
end
local lines = {}
local cost = CFG.EARNINGS_INSURANCE_COST
local duration_days = math.floor(CFG.EARNINGS_INSURANCE_DURATION / 86400)
table.insert(lines, {mark=" ", left="Death Insurance", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  A policy from the Vanguard Reserve Bank.", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  When you die, your streak drops only HALF", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  as far as it otherwise would.", right=""})
table.insert(lines, {mark=" ", left="", right=""})
table.insert(lines, {mark="$", mark_color=ui.theme.gold,
left="  Cost", right=fmtMoney(cost).." / "..duration_days.."d"})
table.insert(lines, {mark="$", mark_color=ui.theme.gold,
left="  Renewal", right="manual (no auto-debit)"})
table.insert(lines, {mark=" ", left="", right=""})
if r.insurance_active then
local remaining = r.insurance_until and (r.insurance_until - now())
local days = remaining and math.floor(remaining / 86400) or 0
table.insert(lines, {mark="+", mark_color=ui.theme.credit,
left="  STATUS", right="Active"})
table.insert(lines, {mark=" ", left="  Expires in", right=days.." days"})
table.insert(lines, {mark=" ", left="", right=""})
table.insert(lines, {mark="*", mark_color=ui.theme.gold,
left="  Use the terminal:  insurance cancel", right=""})
table.insert(lines, {mark="*", mark_color=ui.theme.gold,
left="  Or:                insurance buy (extend)", right=""})
else
table.insert(lines, {mark="-", mark_color=ui.theme.ink_muted,
left="  STATUS", right="Not insured"})
table.insert(lines, {mark=" ", left="", right=""})
table.insert(lines, {mark="*", mark_color=ui.theme.gold,
left="  Use the terminal:  insurance buy", right=""})
end
S.list_title = "DEATH INSURANCE"
S.list_lines = lines
S.list_back = "back_to_dash"
S.list_empty = {
title="Death Insurance",
subtitle="",
hint=""
}
S.screen = "list"
end
local function doNotifications()
local r = call("my_notif_subs", {session=S.session})
local lines = {}
if not r.ok then
table.insert(lines, {mark="!", mark_color=ui.theme.debit,
left="Unable to load subscriptions", right=r.err or ""})
else
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="Choose which events VRB pings you about in chat.", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="All channels are off by default.", right=""})
table.insert(lines, {mark=" ", left="", right=""})
for _, ch in ipairs(r.channels or {}) do
local state_color = ch.subscribed and ui.theme.credit or ui.theme.ink_muted
local state_text = ch.subscribed and "ON" or "off"
local mark_color = ch.subscribed and ui.theme.credit or ui.theme.ink_muted
table.insert(lines, {
mark=ch.subscribed and "+" or "-",
mark_color=mark_color,
left=ch.label,
right=state_text,
right_color=state_color,
})
table.insert(lines, {
mark=" ", mark_color=ui.theme.ink_muted,
left="  "..(ch.description or ""), right="",
})
end
table.insert(lines, {mark=" ", left="", right=""})
table.insert(lines, {mark="*", mark_color=ui.theme.gold,
left="Toggle from terminal: notify <channel> on|off", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  e.g. notify daily on", right=""})
table.insert(lines, {mark=" ", mark_color=ui.theme.ink_muted,
left="  channels: daily, streak, death, multisig, insurance", right=""})
end
S.list_title = "NOTIFICATIONS"
S.list_lines = lines
S.list_back = "back_to_dash"
S.list_empty = {title="Notifications", subtitle="", hint=""}
S.screen = "list"
end
local function doRates()
local r = call("ping", {})
S.policy = r.policy or {}
local p = S.policy
local lines = {
{text="", color=ui.theme.ink},
{text="Checking     " .. string.format("%.2f%% / month", 100*(p.chk_mpr or 0)), color=ui.theme.ink},
{text="Savings      " .. string.format("%.2f%% / month", 100*(p.sav_mpr or 0)), color=ui.theme.credit},
{text="CD  30d      " .. string.format("%.2f%% / month", 100*(p.cd_mpr_30 or 0)), color=ui.theme.ink},
{text="CD  90d      " .. string.format("%.2f%% / month", 100*(p.cd_mpr_90 or 0)), color=ui.theme.ink},
{text="CD 180d      " .. string.format("%.2f%% / month", 100*(p.cd_mpr_180 or 0)), color=ui.theme.ink},
{text="Loan         " .. string.format("%.2f%% / month", 100*(p.loan_mpr or 0)), color=ui.theme.debit},
{text="", color=ui.theme.ink},
{text="Tx tax: 5% flat (paid by sender)", color=ui.theme.warn},
{text="Income tax: 0-10% by salary bracket", color=ui.theme.warn},
{text="Savings early-withdraw tax: 50% < 30d", color=ui.theme.warn},
{text="", color=ui.theme.ink},
{text="Loan collateral required: " .. string.format("%d%%", math.floor((p.min_loan_col or 0)*100)), color=ui.theme.ink_muted},
{text="", color=ui.theme.ink},
{text="Money supply: " .. fmtMoney(r.supply or 0), color=ui.theme.gold},
{text="One Minecraft month = 30 real days", color=ui.theme.ink_muted},
}
S.list_title = "POLICY & RATES"
S.list_lines = lines
S.list_back = S.session and "back_to_dash" or "back"
S.list_empty = nil
S.screen = "list"
end
local function doProgress()
local r = call("list_catalog", {})
local lines = {}
if r.ok then
table.insert(lines, {text="Earn USD for in-game achievements.", color=ui.theme.gold})
table.insert(lines, {text="Submit claims via the terminal: claim <id> <evidence>", color=ui.theme.ink_muted})
table.insert(lines, {text="", color=ui.theme.ink})
for _, item in ipairs(r.catalog) do
table.insert(lines, {
mark="*", mark_color=ui.theme.gold,
left=item.label .. "  (" .. item.id .. ")",
right=fmtMoney(item.bounty),
right_color=ui.theme.credit,
})
end
end
S.list_title = "PROGRESS REWARDS"
S.list_lines = lines
S.list_back = S.session and "back_to_dash" or "back"
S.screen = "list"
end
local function doWorkOrders()
local function fetch()
local r = call("list_work_orders", {})
return r.ok and r.orders or {}
end
while true do
local orders = fetch()
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, ui.theme.surface)
ui:write(2, 1, "PUBLIC WORKS ORDERS", ui.theme.gold, ui.theme.surface)
ui:write(2, 2,
S.session and ("Signed in as "..(S.owner or "?"))
or "Sign in to accept orders",
ui.theme.ink_muted, ui.theme.surface)
local zones = {}
ui:fill(1, H, 8, 1, ui.theme.surface)
ui:write(2, H, "[BACK]", ui.theme.gold, ui.theme.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
if #orders == 0 then
ui:write(2, 6, "No open work orders.",
ui.theme.ink_muted, ui.theme.bg)
ui:write(2, 8, "Vanguard posts bounties for server-building projects.",
ui.theme.ink_muted, ui.theme.bg)
else
local y = 5
for _, o in ipairs(orders) do
if y >= H - 1 then break end
local mine = o.claimed_by == S.account_id
local taken = o.claimed_by and not mine
local color
if mine then color = ui.theme.gold
elseif taken then color = ui.theme.ink_muted
else color = ui.theme.credit end
ui:write(2, y, (o.title or ""):sub(1, W - 22),
ui.theme.ink, ui.theme.bg)
local status_text
if mine then status_text = "ACCEPTED BY YOU"
elseif taken then status_text = "Accepted by another"
else status_text = "OPEN" end
ui:write(2, y + 1,
fmtMoney(o.bounty or 0) .. "  -  " .. status_text,
color, ui.theme.bg)
if S.session then
if mine then
ui:fill(W - 18, y, 16, 2, ui.theme.warn)
ui:write(W - 16, y, "[CANCEL CLAIM]",
ui.theme.bg, ui.theme.warn)
table.insert(zones, {x=W-18, y=y, w=16, h=2,
action="cancel", order=o})
elseif not taken then
ui:fill(W - 18, y, 16, 2, ui.theme.credit)
ui:write(W - 14, y, "[ACCEPT]",
ui.theme.bg, ui.theme.credit)
table.insert(zones, {x=W-18, y=y, w=16, h=2,
action="accept", order=o})
end
end
y = y + 3
end
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then hit = z; break end
end
if not hit then
elseif hit.action == "back" then
S.screen = S.session and "dashboard" or "home"
return
elseif hit.action == "accept" then
local o = hit.order
local conf = ui:confirmScreen(
"Accept work order?",
string.format("\"%s\"\nBounty: %s\n\nAccepting holds the order for you.\nDo the work, then ask an admin to verify and pay.",
o.title, fmtMoney(o.bounty)),
{ok_label="ACCEPT", ok_color=ui.theme.credit})
if conf then
local r = call("claim_work_order", {
session=S.session, order_id=o.id})
if r.ok then
audio:play("success")
ui:showToast("ok", "Order accepted: "..o.title)
else
audio:play("error")
ui:showToast("error", r.err or "Failed")
end
end
elseif hit.action == "cancel" then
local o = hit.order
local conf = ui:confirmScreen(
"Cancel your claim?",
string.format("\"%s\"\nBounty: %s\n\nThe order returns to the pool.",
o.title, fmtMoney(o.bounty)),
{ok_label="CANCEL CLAIM", ok_color=ui.theme.warn})
if conf then
local r = call("cancel_work_order_claim", {
session=S.session, order_id=o.id})
if r.ok then
audio:play("click")
ui:showToast("ok", "Claim cancelled")
else
audio:play("error")
ui:showToast("error", r.err or "Failed")
end
end
end
end
end
local function doCivicJobs()
if not S.session then
audio:play("error")
ui:showToast("error", "Sign in first to apply")
S.screen = "home"; return
end
local function fetch()
return call("list_civic_jobs", {session=S.session})
end
while true do
local r = fetch()
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, ui.theme.surface)
ui:write(2, 1, "CIVIC JOBS", ui.theme.gold, ui.theme.surface)
local zones = {}
ui:fill(1, H, 8, 1, ui.theme.surface)
ui:write(2, H, "[BACK]", ui.theme.gold, ui.theme.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local current = r.ok and r.current_job
local pending = r.ok and r.pending_request
local jobs = r.ok and r.jobs or {}
if current then
local job = nil
for _, j in ipairs(jobs) do
if j.id == current then job = j; break end
end
ui:write(2, 2, ("Current job: %s  -  $%d/yr"):format(
((job and job.title) or current):sub(1, W - 20),
math.floor((job and job.annual_cents or 0) / 100)),
ui.theme.gold, ui.theme.surface)
elseif pending then
ui:write(2, 2, "Pending application: "..pending,
ui.theme.warn, ui.theme.surface)
ui:fill(2, 4, 22, 1, ui.theme.warn)
ui:write(3, 4, "[CANCEL APPLICATION]", ui.theme.bg, ui.theme.warn)
table.insert(zones, {x=2, y=4, w=22, h=1,
action="cancel_request", request_id=pending})
else
ui:write(2, 2, "Tap any job to apply. Admin reviews and approves.",
ui.theme.ink_muted, ui.theme.surface)
end
if #jobs == 0 then
ui:write(2, 6, "No civic jobs defined yet.",
ui.theme.ink_muted, ui.theme.bg)
ui:write(2, 8, "Ask an admin to create some.",
ui.theme.ink_muted, ui.theme.bg)
else
local y = 5
for _, j in ipairs(jobs) do
if y >= H - 1 then break end
local is_current = (j.id == current)
local row_color = is_current and ui.theme.gold or ui.theme.bg
if is_current then
ui:fill(1, y, W, 2, ui.theme.surface_alt or ui.theme.surface)
end
ui:write(2, y, j.title:sub(1, 30),
is_current and ui.theme.gold or ui.theme.ink,
is_current and (ui.theme.surface_alt or ui.theme.surface)
or ui.theme.bg)
ui:write(2, y + 1,
("$%d/yr  -  %d holder%s"):format(
math.floor(j.annual_cents / 100),
j.holders, j.holders == 1 and "" or "s"),
ui.theme.ink_muted,
is_current and (ui.theme.surface_alt or ui.theme.surface)
or ui.theme.bg)
if is_current then
ui:write(W - 16, y, "[YOUR JOB]",
ui.theme.gold,
ui.theme.surface_alt or ui.theme.surface)
elseif not current and not pending then
ui:fill(W - 12, y, 10, 2, ui.theme.credit)
ui:write(W - 10, y, "[APPLY]",
ui.theme.bg, ui.theme.credit)
table.insert(zones, {x=W-12, y=y, w=10, h=2,
action="apply", job=j})
end
y = y + 3
end
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then hit = z; break end
end
if not hit then
elseif hit.action == "back" then
S.screen = "dashboard"; return
elseif hit.action == "apply" then
local j = hit.job
local conf = ui:confirmScreen(
"Apply for "..j.title.."?",
string.format(
"Annual: $%d\nThis goes to the admin for approval.\nYou'll be notified.",
math.floor(j.annual_cents / 100)),
{ok_label="APPLY", ok_color=ui.theme.credit})
if conf then
local rr = call("request_civic_job", {
session=S.session, job_id=j.id})
if rr.ok then
audio:play("success")
ui:showToast("ok", "Application sent: "..rr.request_id)
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
elseif hit.action == "cancel_request" then
local conf = ui:confirmScreen(
"Cancel your pending application?",
"You can always apply again later.",
{ok_label="CANCEL APPLICATION", ok_color=ui.theme.warn})
if conf then
local rr = call("cancel_civic_request", {
session=S.session, request_id=hit.request_id})
if rr.ok then
audio:play("click")
ui:showToast("ok", "Application cancelled")
else
audio:play("error")
ui:showToast("error", rr.err or "Failed")
end
end
end
end
end
local function doOpenCD()
enterKeypad("New CD - Amount", false, "CENTS:",
function(a)
local amt = tonumber(a) or 0
if amt <= 0 then S.screen = "dashboard"; return end
S.pending_amount = amt
enterKeypad("New CD - Term (days, min 30)", false, "DAYS:",
function(d)
local days = tonumber(d) or 0
local r = call("open_cd", {session=S.session, amount=S.pending_amount, days=days})
if r.ok then
S.prev_balance = S.balance; S.balance = r.balance
audio:play("success")
ui:showToast("ok", string.format("CD opened at %.2f%%/mo", r.mpr*100))
else
audio:play("error"); ui:showToast("error", r.err or "Failed")
end
S.screen = "dashboard"
end,
function() S.screen = "dashboard" end)
end,
function() S.screen = "dashboard" end)
end
local function handle(action, data)
if action == "key" then
if data == "CLR" then S.keypad = ""; audio:play("tap")
elseif data == "OK" then
local fn = S.on_ok; S.on_ok = nil; audio:play("click")
if fn then fn(S.keypad) end
else
if #S.keypad < 12 then S.keypad = S.keypad .. data; audio:play("tap") end
end
elseif action == "cancel" then
audio:play("click")
local fn = S.on_cancel; S.on_cancel = nil
if fn then fn() end
elseif action == "signin" then audio:play("click"); doSignin()
elseif action == "open" then doOpenAccount()
elseif action == "lookup" then doLookup()
elseif action == "rates" then audio:play("click"); doRates()
elseif action == "progress" then audio:play("click"); doProgress()
elseif action == "work_orders" then audio:play("click"); doWorkOrders()
elseif action == "civic_jobs" then audio:play("click"); doCivicJobs()
elseif action == "pay" then audio:play("click"); doPay()
elseif action == "charge" then audio:play("click"); doCharge()
elseif action == "requests" then audio:play("click"); doRequests()
elseif action == "move" then audio:play("click"); doMove()
elseif action == "history" then audio:play("click"); doHistory()
elseif action == "open_cd" then audio:play("click"); doOpenCD()
elseif action == "loans" then audio:play("click"); doLoans()
elseif action == "earnings" then audio:play("click"); doEarnings()
elseif action == "insurance" then audio:play("click"); doInsurance()
elseif action == "notify" then audio:play("click"); doNotifications()
elseif action == "submit_claim" then
audio:play("click")
ui:showToast("info", "Use the terminal: claim <id> <evidence>")
elseif action == "signout" then
if S.session then call("signout", {session=S.session}) end
audio:play("signout")
S.session = nil; S.account_id = nil; S.owner = nil
S.screen = "home"; ui:showToast("ok", "Signed out")
elseif action == "back" then S.screen = "home"
elseif action == "back_to_dash" then refreshBalance(); S.screen = "dashboard"
elseif action == "back_to_home" then S.screen = "home"
end
end
local function redraw()
if S.screen == "home" then renderHome()
elseif S.screen == "keypad" then renderKeypad()
elseif S.screen == "dashboard" then renderDashboard()
elseif S.screen == "list" then renderList(S.list_title, S.list_lines, S.list_back, S.list_empty)
end
end
local function terminalHelper()
term.setBackgroundColor(ui.theme.bg); term.setTextColor(ui.theme.gold)
term.clear(); term.setCursorPos(1, 1)
print("VRB ATM  -  " .. branch)
term.setTextColor(ui.theme.ink)
print("")
print("Commands for operations the monitor keypad can't express:")
print("  new                       Open a new account")
print("  lookup <username>         Find accounts for a player")
print("  claim <id> <evidence>     Submit a progress claim (signed in)")
print("  redeem                    Redeem a Reserve Note (signed in)")
print("  audit                     Cryptographic self-audit (signed in)")
print("  shop new <label>          Create a shop")
print("  shop list                 List your shops")
print("  shop stock <id>           Add/update a listing")
print("  faction new               Create a faction with multisig")
print("  faction invite <fid> <u>  Invite a member")
print("  faction pending           Pending multisig txns")
print("  faction approve <pid>     Approve a pending txn")
print("  faction spend             Propose a treasury transfer")
print("  escrow new | list | release <eid> | refund <eid>")
print("  recur new | list | cancel <rid>")
print("  earnings                  Show your last daily earnings")
print("  insurance buy | cancel | status   Death Insurance policy")
print("  notify <channel> on|off   Toggle a notification channel")
print("  quit                      Stop this ATM")
while true do
term.setTextColor(ui.theme.gold); write("\n> "); term.setTextColor(ui.theme.ink)
local line = read()
if not line then return end
local cmd, rest = line:match("^(%S+)%s*(.*)$")
cmd = cmd or ""
if cmd == "new" then
write("Minecraft username: "); local u = read()
write("Account kind (checking/savings): "); local k = read()
if k ~= "checking" and k ~= "savings" then k = "checking" end
write("Choose a 4-digit PIN: "); local pin = read("*")
local r = C:call("open_account", {owner=u, pin=pin, kind=k})
if r.ok then print("Account created: "..r.account_id)
else print("Error: "..(r.err or "")) end
elseif cmd == "lookup" then
local r = C:call("lookup", {owner=rest})
if r.ok then
for _, a in ipairs(r.accounts) do print("  "..a.id.."  "..a.kind.."  "..a.owner) end
if #r.accounts == 0 then print("No accounts found.") end
else print("Error: "..(r.err or "")) end
elseif cmd == "claim" then
if not S.session then print("Sign in on the monitor first.") else
local pid, ev = rest:match("^(%S+)%s+(.+)$")
if not pid then print("Usage: claim <id> <evidence>") else
local r = C:call("submit_claim", {session=S.session, progress_id=pid, evidence=ev})
if r.ok then print("Claim submitted: "..r.claim_id)
else print("Error: "..(r.err or "")) end
end
end
elseif cmd == "redeem" then
if not S.session then print("Sign in first.") else
print("Paste Reserve Note (serialized, one line):")
local s = read()
local ok, note = pcall(textutils.unserialize, s)
if not ok then print("Bad note.") else
local r = C:call("redeem_note", {session=S.session, note=note})
if r.ok then print("Redeemed. Balance: "..fmtMoney(r.balance))
S.balance = r.balance
else print("Error: "..(r.err or "")) end
end
end
elseif cmd == "audit" then
if not S.session then print("Sign in first.") else
local r = C:call("self_audit", {session=S.session})
if r.ok then
print("Balance:       "..fmtMoney(r.balance))
print("Computed:      "..fmtMoney(r.computed))
print("Touched:       "..tostring(r.entries_touched).." ledger entries")
print("Head:          "..r.ledger_head)
term.setTextColor(r.ok_match and ui.theme.credit or ui.theme.warn)
print(r.ok_match and "OK: balance matches ledger." or "MISMATCH: investigate.")
term.setTextColor(ui.theme.ink)
else print("Error: "..(r.err or "")) end
end
elseif cmd == "shop" then
local sub, srest = rest:match("^(%S+)%s*(.*)$")
if sub == "new" then
if not S.session then print("Sign in first.") else
local label = srest
if #label < 3 then write("Label: "); label = read() end
local r = C:call("create_shop", {session=S.session, label=label})
print(r.ok and ("Shop: "..r.shop_id) or ("Error: "..(r.err or "")))
end
elseif sub == "list" then
if not S.session then print("Sign in first.") else
local r = C:call("list_my_shops", {session=S.session})
if r.ok then
if #r.shops == 0 then print("No shops.") end
for _, s in ipairs(r.shops) do
print(string.format("  %s  %s  %d listings  %s", s.id, s.label, s.listings,
s.active and "active" or "inactive"))
end
end
end
elseif sub == "stock" then
if not S.session then print("Sign in first.") else
local sid = srest:match("^(%S+)$")
if not sid then write("Shop ID: "); sid = read() end
write("SKU: "); local sku = read()
write("Item: "); local item = read()
write("Price (cents): "); local price = tonumber(read())
write("Stock: "); local stock = tonumber(read())
write("Note: "); local note = read()
local r = C:call("set_shop_listing", {session=S.session, shop_id=sid,
sku=sku, item=item, price=price, stock=stock, note=note})
print(r.ok and "Updated." or ("Error: "..(r.err or "")))
end
else print("Shop subcommands: new | list | stock") end
elseif cmd == "faction" then
local sub, srest = rest:match("^(%S+)%s*(.*)$")
if sub == "new" then
if not S.session then print("Sign in first.") else
write("Name: "); local name = read()
write("Required approvals (N): "); local n = tonumber(read())
write("Total signers (M): "); local m = tonumber(read())
local r = C:call("create_faction", {session=S.session, name=name,
threshold_n=n, threshold_m=m})
if r.ok then print("Faction: "..r.faction_id.."  Treasury: "..r.treasury_id)
else print("Error: "..(r.err or "")) end
end
elseif sub == "invite" then
if not S.session then print("Sign in first.") else
local fid, u = srest:match("^(%S+)%s+(%S+)$")
if fid then
local r = C:call("faction_add_member", {session=S.session, faction_id=fid, member=u})
print(r.ok and "Added." or ("Error: "..(r.err or "")))
else print("Usage: faction invite <FAC-ID> <username>") end
end
elseif sub == "pending" then
if not S.session then print("Sign in first.") else
local r = C:call("list_pending_tx", {session=S.session})
if r.ok then
if #r.pending == 0 then print("No pending transactions.") end
for _, pt in ipairs(r.pending) do
print(string.format("  %s  %s -> %s  %s  %d/%d  %s",
pt.id, pt.from, pt.to, fmtMoney(pt.amount),
pt.approvals, pt.required,
pt.you_approved and "(you approved)" or ""))
end
end
end
elseif sub == "approve" then
if not S.session then print("Sign in first.") else
local pid = srest:match("^(%S+)$")
if pid then
local r = C:call("approve_pending_tx", {session=S.session, pending_id=pid})
if r.ok then
print(r.executed and ("Executed ("..r.approvals.." sigs).")
or ("Approved. "..r.approvals.."/"..r.required..". "))
else print("Error: "..(r.err or "")) end
else print("Usage: faction approve <PND-ID>") end
end
elseif sub == "spend" then
if not S.session then print("Sign in first.") else
write("From faction ID: "); local fid = read()
write("To account: "); local tgt = read()
write("Amount (cents): "); local amt = tonumber(read())
write("Memo: "); local m = read()
local r = C:call("transfer", {session=S.session, from_faction=fid,
target_id=tgt, amount=amt, memo=m})
if r.ok then
if r.executed then print("Executed immediately.")
elseif r.pending then print("Proposed: "..r.pending.."  needs "..r.needs_approvals.." more")
else print("OK.") end
else print("Error: "..(r.err or "")) end
end
else print("Faction subcommands: new | invite | pending | approve | spend") end
elseif cmd == "escrow" then
local sub, srest = rest:match("^(%S+)%s*(.*)$")
if sub == "new" then
if not S.session then print("Sign in first.") else
write("Counterparty: "); local cp = read()
write("Amount (cents): "); local amt = tonumber(read())
write("Memo: "); local m = read()
local r = C:call("create_escrow", {session=S.session,
counterparty=cp, amount=amt, memo=m})
print(r.ok and ("Escrow: "..r.escrow_id) or ("Error: "..(r.err or "")))
end
elseif sub == "list" then
if not S.session then print("Sign in first.") else
local r = C:call("list_my_escrows", {session=S.session})
if r.ok then
if #r.escrows == 0 then print("No escrows.") end
for _, e in ipairs(r.escrows) do
print(string.format("  %s  %s -> %s  %s  [%s] (you: %s)",
e.id, e.from, e.to, fmtMoney(e.amount), e.status, e.you_are))
end
end
end
elseif sub == "release" then
local eid = srest:match("^(%S+)$")
if eid then
local r = C:call("release_escrow", {session=S.session, escrow_id=eid})
print(r.ok and "Released." or ("Error: "..(r.err or "")))
else print("Usage: escrow release <ESC-ID>") end
elseif sub == "refund" then
local eid = srest:match("^(%S+)$")
if eid then
local r = C:call("refund_escrow", {session=S.session, escrow_id=eid})
print(r.ok and "Refunded." or ("Error: "..(r.err or "")))
else print("Usage: escrow refund <ESC-ID>") end
else print("Escrow subcommands: new | list | release | refund") end
elseif cmd == "recur" then
local sub, srest = rest:match("^(%S+)%s*(.*)$")
if sub == "new" then
if not S.session then print("Sign in first.") else
write("To account: "); local cp = read()
write("Amount (cents): "); local amt = tonumber(read())
write("Interval seconds (min 3600): "); local iv = tonumber(read())
write("Runs (1-365): "); local n = tonumber(read())
write("Memo: "); local m = read()
local r = C:call("create_recurring", {session=S.session, target_id=cp,
amount=amt, interval_sec=iv, remaining=n, memo=m})
print(r.ok and ("Recurring: "..r.recur_id) or ("Error: "..(r.err or "")))
end
elseif sub == "list" then
if not S.session then print("Sign in first.") else
local r = C:call("list_my_recurring", {session=S.session})
if r.ok then
if #r.recurring == 0 then print("None.") end
for _, rc in ipairs(r.recurring) do
print(string.format("  %s -> %s  %s  every %ds  %d left",
rc.id, rc.to, fmtMoney(rc.amount), rc.interval_sec, rc.remaining))
end
end
end
elseif sub == "cancel" then
local rid = srest:match("^(%S+)$")
if rid then
local r = C:call("cancel_recurring", {session=S.session, recur_id=rid})
print(r.ok and "Cancelled." or ("Error: "..(r.err or "")))
else print("Usage: recur cancel <REC-ID>") end
else print("Recur subcommands: new | list | cancel") end
elseif cmd == "insurance" then
local sub = rest:match("^(%S+)") or ""
if sub == "buy" then
if not S.session then print("Sign in first.") else
local r = C:call("buy_insurance", {session=S.session})
if r.ok then
term.setTextColor(ui.theme.credit)
print(string.format("  + Policy active until %s",
os.date("%Y-%m-%d", r.insurance_until or 0)))
print("  + Balance: "..fmtMoney(r.balance))
term.setTextColor(ui.theme.ink)
else print("Error: "..(r.err or "")) end
end
elseif sub == "cancel" then
if not S.session then print("Sign in first.") else
write("Cancel insurance? No refund is issued. (yes): ")
if read() == "yes" then
local r = C:call("cancel_insurance", {session=S.session})
if r.ok then
term.setTextColor(ui.theme.credit); print("  + Cancelled.")
term.setTextColor(ui.theme.ink)
else print("Error: "..(r.err or "")) end
end
end
elseif sub == "status" then
if not S.session then print("Sign in first.") else
local r = C:call("my_earnings", {session=S.session})
if r.ok then
if r.insurance_active then
term.setTextColor(ui.theme.credit)
print("  + Active until "..os.date("%Y-%m-%d", r.insurance_until or 0))
term.setTextColor(ui.theme.ink)
else
print("  (not insured)")
end
else print("Error: "..(r.err or "")) end
end
else print("Insurance subcommands: buy | cancel | status") end
elseif cmd == "earnings" then
if not S.session then print("Sign in first.") else
local r = C:call("my_earnings", {session=S.session})
if r.ok then
term.setTextColor(ui.theme.gold)
print(string.format("Streak: day %d (%s)  multiplier %.2fx",
r.streak_days or 0, r.streak_label or "New", r.streak_mult or 1))
term.setTextColor(ui.theme.ink)
local b = r.breakdown
if not b then print("  (no earnings run yet)")
elseif b.skipped then print("  (last tick skipped: "..b.skipped..")")
else
local function line(label, amt)
if amt and amt > 0 then
print(string.format("  %-20s  %s", label, fmtMoney(amt)))
end
end
line("Survival wage", b.survival_wage)
line("Combat pay", b.combat_pay)
line("Explorer bonus", b.explorer_bonus)
line("Builder bonus", b.builder_bonus)
line("Danger pay", b.danger_pay)
line("Boss bounty", b.boss_bounty)
line("Build streak bonus",b.build_streak_bonus)
if b.died_today then
term.setTextColor(ui.theme.debit)
print("  ! Died today -- danger pay zeroed, streak dropped")
term.setTextColor(ui.theme.ink)
end
if b.base then
print(string.format("  %-20s  %s", "Subtotal", fmtMoney(b.base)))
if b.dimension_mult and b.dimension_mult > 1 then
print(string.format("  %-20s  %.2fx", "Nether/End bonus", b.dimension_mult))
end
print(string.format("  %-20s  %.2fx", "Streak multiplier", b.streak_mult or 1))
term.setTextColor(ui.theme.gold)
print(string.format("  %-20s  %s", "TOTAL PAID", fmtMoney(b.total or 0)))
term.setTextColor(ui.theme.ink)
end
end
else print("Error: "..(r.err or "")) end
end
elseif cmd == "notify" then
if not S.session then print("Sign in first.") else
local ch, val = rest:match("^(%S+)%s+(%S+)$")
if not ch or not val then
local r = C:call("my_notif_subs", {session=S.session})
if r.ok then
term.setTextColor(ui.theme.gold)
print("Notification subscriptions:")
term.setTextColor(ui.theme.ink)
for _, x in ipairs(r.channels or {}) do
local state = x.subscribed and "ON " or "off"
local color = x.subscribed and ui.theme.credit or ui.theme.ink_muted
term.setTextColor(color)
print(string.format("  %-12s %s  %s", x.id, state, x.description))
term.setTextColor(ui.theme.ink)
end
print("")
print("Usage: notify <channel> on|off")
else print("Error: "..(r.err or "")) end
else
local on = (val == "on" or val == "true" or val == "yes" or val == "1")
local r = C:call("set_notif_subs",
{session=S.session, subs={[ch] = on}})
if r.ok then
term.setTextColor(ui.theme.credit)
print("  + "..ch.." = "..(on and "ON" or "off"))
term.setTextColor(ui.theme.ink)
else print("Error: "..(r.err or "")) end
end
end
elseif cmd == "quit" then return
elseif cmd ~= "" then print("Unknown command.") end
end
end
redraw()
parallel.waitForAny(
function()
while true do
local ev, p1, p2, p3 = os.pullEvent()
if ev == "monitor_touch" then
local b = ui:hit(p2, p3)
if b then ui:press(b); handle(b.action, b.data) end
redraw()
elseif ev == "vrb_tick" then
if ui:tick() then redraw() else
redraw()
end
end
end
end,
function()
while true do
sleep(0.5)
os.queueEvent("vrb_tick")
end
end,
terminalHelper
)
end
local accountDetailScreen
local historyScreen
local rankPickerScreen
local jobPickerScreen
local jobDetailScreen
local function runAdminTouch()
local sec_ok, secret = pcall(loadClientKeys, false)
if not sec_ok or not secret then
showStartupError("ADMIN", "Missing server.secret", tostring(secret),
{"This admin terminal needs server.secret AND admin.key",
"Run the bootstrap with the distribution floppy"})
return
end
local admin_key
do
local p = fs.combine(CFG.KEY_DIR, "admin.key")
if not fs.exists(p) then
showStartupError("ADMIN", "Missing admin.key", nil,
{"Re-run the bootstrap and choose 'admin' as the role",
"It will copy admin.key from the distribution floppy"})
return
end
local f = fs.open(p, "r")
if not f then
showStartupError("ADMIN", "admin.key cannot be read", nil,
{"rm /.vrb/keys/admin.key", "Then re-bootstrap"})
return
end
admin_key = f.readAll(); f.close()
if not admin_key or #admin_key < 16 then
showStartupError("ADMIN", "admin.key is empty/too short", nil,
{"Re-bootstrap"})
return
end
end
local mon = findAdvancedMonitor()
if not mon then
showStartupError("ADMIN", "No monitor found", nil,
{"Place a 3x3 grid of Advanced Monitors adjacent to this computer",
"Advanced Monitors are gold-trimmed",
"Reboot after placing"})
return
end
if not (mon.isColor and mon.isColor()) then
showStartupError("ADMIN", "Monitor is not Advanced",
"Touch only works on Advanced Monitors",
{"Replace with Advanced Monitors (gold-trimmed)"})
return
end
pcall(function() mon.setTextScale(0.5) end)
local ui = makeUI(mon)
local C = newClient(secret, admin_key)
local ping = C:call("ping", {})
if not ping.ok then
showStartupError("ADMIN", "Cannot reach the Reserve Bank",
tostring(ping.err),
{"Verify the server is running",
"Verify both modems are enabled (red rings)",
"Use Ender Modems for unlimited range"})
return
end
local TH = ui.theme
local function notify(title, message, color)
ui:confirmScreen(title, message, {
ok_label = "OK", cancel_label = "OK",
ok_color = color or TH.gold,
})
end
local function errMsg(title, message)
notify(title, message, TH.debit)
end
local function okMsg(title, message)
notify(title, message, TH.credit)
end
local function parseMoney(s)
if not s or s == "" then return nil end
s = s:lower():gsub("[%$,]", "")
local mult = 1
if s:match("k$") then mult = 1000; s = s:sub(1, -2) end
if s:match("m$") then mult = 1000000; s = s:sub(1, -2) end
local n = tonumber(s)
if not n then return nil end
return math.floor(n * mult * 100)
end
local function homeScreen()
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 4, TH.surface)
ui:write(2, 1, "VANGUARD RESERVE BANK", TH.gold, TH.surface)
ui:write(2, 2, "Administrator Terminal  -  v"..VERSION,
TH.ink, TH.surface)
ui:write(2, 3, "Touch a card to begin.",
TH.ink_muted, TH.surface)
ui:write(W - 10, 1, os.date("%H:%M:%S"), TH.gold, TH.surface)
local pad = 2
local card_w = math.floor((W - pad * 4) / 2)
local card_h = math.floor((H - 8) / 4)
local zones = {}
local function card(col, row, label, sub, action, color)
local x = pad + (col - 1) * (card_w + pad)
local y = 6 + (row - 1) * (card_h + 1)
color = color or TH.gold
ui:fill(x, y, card_w, card_h, color)
local lx = x + math.floor((card_w - #label) / 2)
ui:write(lx, y + math.floor(card_h / 2) - 1, label, TH.bg, color)
if sub then
local sx = x + math.floor((card_w - #sub) / 2)
ui:write(sx, y + math.floor(card_h / 2) + 1, sub,
TH.bg, color)
end
table.insert(zones, {x=x, y=y, w=card_w, h=card_h, action=action})
end
card(1, 1, "BROWSE ACCOUNTS", "Find / edit any account", "browse",
TH.gold)
card(2, 1, "DIAGNOSTICS", "Live system health", "diag",
TH.credit)
card(1, 2, "VANGUARD", "Assign ranks  -  10 max", "vanguard",
TH.gold_dim or TH.gold)
card(2, 2, "CIVIC JOBS", "Create / assign / edit pay", "jobs",
TH.gold_dim or TH.gold)
card(1, 3, "WORK ORDERS", "Post bounties for players", "work_orders",
TH.credit)
card(2, 3, "REVIEW QUEUE", "Claims + civic apps + flags", "queue",
TH.surface_alt or TH.surface)
card(1, 4, "POLICY & MORE", "Tax, supply, advanced", "policy",
TH.surface_alt or TH.surface)
card(2, 4, "LEDGER", "Recent bank-wide events", "ledger",
TH.surface_alt or TH.surface)
ui:fill(1, H, W, 1, TH.surface)
ui:write(2, H, "Stability  -  Trust  -  Prosperity",
TH.ink_muted, TH.surface)
ui:write(W - 8, H, "[REFRESH]", TH.gold, TH.surface)
table.insert(zones, {x=W-9, y=H, w=10, h=1, action="refresh"})
ui:flush()
while true do
local ev, _, mx, my = os.pullEvent("monitor_touch")
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
return z.action
end
end
end
end
local function browseAccounts()
local accounts = {}
local filter = ""
local function refresh()
local r = C:call("admin_list_accounts", {filter=filter}, true)
if r.ok then
accounts = {}
for _, a in ipairs(r.accounts or {}) do
if a.is_treasury or a.kind ~= "savings" then
table.insert(accounts, a)
end
end
else
accounts = {}
errMsg("Could not load accounts", r.err or "?")
end
end
local scroll = 0
refresh()
local function showList()
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "BROWSE ACCOUNTS", TH.gold, TH.surface)
ui:write(2, 2, ("%d accounts  -  filter: %s")
:format(#accounts,
filter == "" and "(none)" or filter),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(W - 22, 1, 22, 3, TH.gold_dim or TH.surface)
ui:write(W - 20, 2, "[FILTER BY USERNAME]",
TH.bg, TH.gold_dim or TH.surface)
table.insert(zones, {x=W-22, y=1, w=22, h=3, action="filter"})
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local rows_per_page = H - 6
local total_pages = math.max(1, math.ceil(#accounts / rows_per_page))
local current_page = math.floor(scroll / rows_per_page) + 1
ui:write(W - 20, H, ("Page %d / %d"):format(current_page, total_pages),
TH.ink_muted, TH.surface)
ui:fill(W - 8, H, 4, 1, TH.surface_alt or TH.surface)
ui:write(W - 7, H, "UP", TH.gold,
TH.surface_alt or TH.surface)
table.insert(zones, {x=W-8, y=H, w=4, h=1, action="page_up"})
ui:fill(W - 4, H, 4, 1, TH.surface_alt or TH.surface)
ui:write(W - 3, H, "DN", TH.gold,
TH.surface_alt or TH.surface)
table.insert(zones, {x=W-4, y=H, w=4, h=1, action="page_down"})
local y = 5
for i = 1, rows_per_page do
local idx = scroll + i
if idx > #accounts then break end
local a = accounts[idx]
local row_y = y + (i - 1)
local bg = (i % 2 == 0) and (TH.surface_alt or TH.surface)
or TH.bg
ui:fill(1, row_y, W, 1, bg)
local mark = a.frozen and "F" or " "
local rank_marker = a.vanguard_rank and "V" or " "
local job_marker = (a.civic_jobs and next(a.civic_jobs))
and "J" or " "
local marks = mark .. rank_marker .. job_marker
ui:write(2, row_y, marks,
a.frozen and TH.debit or TH.gold, bg)
ui:write(6, row_y,
a.id .. "  " .. a.owner:sub(1, 14),
TH.ink, bg)
local bal = fmtMoney(a.balance or 0)
ui:write(W - #bal - 2, row_y, bal, TH.gold, bg)
table.insert(zones, {x=1, y=row_y, w=W, h=1,
action="select", account_id=a.id})
end
local legend_y = H - 1
ui:write(2, legend_y,
"F=frozen V=vanguard J=civic-job",
TH.ink_muted, TH.bg)
ui:flush()
return zones
end
while true do
local zones = showList()
local ev, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "filter" then
local s = ui:keyboardScreen("FILTER BY USERNAME", {
subtitle = "Type a substring; leave empty for all",
pattern = "^[%w_]*$",
max_len = 16,
initial = filter,
})
if s ~= nil then
filter = s
scroll = 0
refresh()
end
elseif hit.action == "page_up" then
local W, H = ui:size()
scroll = math.max(0, scroll - (H - 6))
elseif hit.action == "page_down" then
local W, H = ui:size()
local rows_per_page = H - 6
if scroll + rows_per_page < #accounts then
scroll = scroll + rows_per_page
end
elseif hit.action == "select" then
accountDetailScreen(hit.account_id)
refresh()
end
end
end
accountDetailScreen = function(account_id)
local function fetch()
local r = C:call("admin_account_detail", {account_id=account_id}, true)
if not r.ok then
errMsg("Could not load account", r.err or "?")
return nil
end
return r.account
end
while true do
local a = fetch()
if not a then return end
local sav
if a.paired_savings then
local sr = C:call("admin_account_detail",
{account_id=a.paired_savings}, true)
if sr.ok and sr.account then sav = sr.account end
end
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 4, TH.surface)
local title = "ACCOUNT  "..a.id
if a.is_treasury then title = "TREASURY  "..a.id end
ui:write(2, 1, title, TH.gold, TH.surface)
ui:write(2, 2, "Owner:    "..a.owner, TH.ink, TH.surface)
ui:write(2, 3, "Checking: "..fmtMoney(a.balance or 0),
TH.gold, TH.surface)
if sav then
local young = 0
local cutoff = now() - (30 * 24 * 60 * 60)
for _, lot in ipairs(sav.lots or {}) do
if (lot.t or 0) >= cutoff then young = young + (lot.amount or 0) end
end
local sav_text = "Savings:  "..fmtMoney(sav.balance or 0)
if young > 0 then
sav_text = sav_text .. "  ("..fmtMoney(young).." young)"
end
ui:write(2, 4, sav_text, TH.ink_muted, TH.surface)
end
local status = ""
if a.frozen then status = status.."FROZEN  " end
if a.vanguard_rank then
status = status .. (a.vanguard_label
or a.vanguard_rank) .. "  "
end
if a.on_leave then status = status.."ON LEAVE  " end
if a.civic_jobs and next(a.civic_jobs) then
local n = 0
for _ in pairs(a.civic_jobs) do n = n + 1 end
status = status..n.." civic job"..(n==1 and "" or "s").."  "
end
ui:write(W - #status - 2, 2, status, TH.ink_muted, TH.surface)
local pad = 2
local card_w = math.floor((W - pad * 4) / 2)
local card_h = math.floor((H - 8) / 4)
local zones = {}
local function ac(col, row, label, sub, action, color)
local x = pad + (col - 1) * (card_w + pad)
local y = 6 + (row - 1) * (card_h + 1)
color = color or TH.gold_dim
ui:fill(x, y, card_w, card_h, color)
local lx = x + math.floor((card_w - #label) / 2)
ui:write(lx, y + math.floor(card_h / 2) - 1, label,
TH.bg, color)
if sub then
local sx = x + math.floor((card_w - #sub) / 2)
ui:write(sx, y + math.floor(card_h / 2) + 1, sub,
TH.bg, color)
end
table.insert(zones, {x=x, y=y, w=card_w, h=card_h, action=action})
end
ac(1, 1, "EDIT BALANCE", "Set new amount", "edit_balance", TH.gold)
ac(2, 1, "SET RANK", "Vanguard rank picker", "set_rank", TH.gold)
ac(1, 2, "ASSIGN JOB", "Civic job picker", "set_job", TH.gold_dim)
ac(2, 2, a.frozen and "UNFREEZE" or "FREEZE",
a.frozen and "Unlock account"
or "Lock account",
"freeze", a.frozen and TH.credit or TH.debit)
ac(1, 3, "RESET PIN", "Set new PIN", "reset_pin", TH.surface_alt)
ac(2, 3, a.on_leave and "END LEAVE" or "START LEAVE",
a.on_leave and "Resume normal pay"
or "Pause activity check",
"leave", TH.surface_alt)
ac(1, 4, "VIEW HISTORY", "Recent transactions", "history",
TH.surface_alt)
ac(2, 4, "DELETE ACCOUNT", "Refund + remove", "delete",
TH.debit)
ui:fill(1, H, W, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:flush()
local act
while not act do
local ev, _, mx, my = os.pullEvent("monitor_touch")
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
act = z.action; break
end
end
end
if act == "back" then
return
elseif act == "edit_balance" then
local s = ui:keyboardScreen("NEW BALANCE for "..a.id, {
subtitle = "Use 1234 for $12.34, 5k for $5000, 1.5M for $1.5M",
pattern = "^[%d%.kKmM]*$",
max_len = 16,
})
if s and #s > 0 then
local cents = parseMoney(s)
if not cents then errMsg("Invalid amount", "Try '5000' or '5k'") else
local r2 = ui:keyboardScreen("REASON for adjustment", {
subtitle = "Required, 5-200 chars. Logged with your attribution.",
max_len = 100,
})
if r2 and #r2 >= 5 then
local res = C:call("admin_set_balance", {
account_id = a.id,
new_balance = cents,
reason = r2,
}, true)
if res.ok then
okMsg("Balance updated",
"New balance: "..fmtMoney(res.new_balance))
else
errMsg("Update failed", res.err or "?")
end
elseif r2 then
errMsg("Reason too short", "Need at least 5 characters")
end
end
end
elseif act == "set_rank" then
rankPickerScreen(a.id, a.owner)
elseif act == "set_job" then
jobPickerScreen(a.id, a.owner)
elseif act == "freeze" then
local conf = ui:confirmScreen(
a.frozen and "Unfreeze account?" or "Freeze account?",
a.frozen and ("Re-enable transactions on "..a.id)
or ("Block transactions on "..a.id),
{ok_label = a.frozen and "UNFREEZE" or "FREEZE",
ok_color = a.frozen and TH.credit or TH.debit})
if conf then
local res = C:call("admin_freeze", {
account_id = a.id,
frozen = not a.frozen,
}, true)
if not res.ok then errMsg("Failed", res.err or "?") end
end
elseif act == "reset_pin" then
local p = ui:keyboardScreen("NEW PIN for "..a.id, {
subtitle = "4 digits. The user must be told this PIN out-of-band.",
mask = true, numeric = true, digits_only = true,
pattern = "^%d*$", max_len = 4,
})
if p and #p == 4 then
local res = C:call("admin_set_pin", {
account_id = a.id, new_pin = p,
}, true)
if res.ok then okMsg("PIN reset",
"Tell user the new PIN: "..p)
else errMsg("Failed", res.err or "?") end
elseif p then
errMsg("PIN must be 4 digits", "")
end
elseif act == "leave" then
local res = C:call("admin_set_leave", {
account_id = a.id, on_leave = not a.on_leave,
}, true)
if not res.ok then errMsg("Failed", res.err or "?") end
elseif act == "history" then
historyScreen(a.id)
elseif act == "delete" then
if a.is_treasury then
errMsg("Cannot delete", "Treasury accounts are protected.")
else
local conf = ui:confirmScreen(
"DELETE this account?",
string.format("%s (%s)\nBalance: %s\n\nBalance refunds to the Fund.\nAll rank/job assignments are cleared.\nThis cannot be undone.",
a.owner, a.id, fmtMoney(a.balance or 0)),
{ok_label = "CONTINUE", ok_color = TH.debit})
if conf then
local typed = ui:keyboardScreen(
"Type DELETE to confirm",
{subtitle="Last chance. Empty to cancel.",
pattern="^[%w]*$", max_len=10})
if typed == "DELETE" then
local res = C:call("admin_delete_account",
{account_id=a.id}, true)
if res.ok then
okMsg("Deleted",
string.format("%s closed. %s refunded to Fund.",
a.id, fmtMoney(res.refunded or 0)))
return
else
errMsg("Failed", res.err or "?")
end
elseif typed and typed ~= "" then
errMsg("Cancelled",
"You must type DELETE exactly to confirm.")
end
end
end
end
end
end
historyScreen = function(account_id)
local r = C:call("admin_account_history", {account_id=account_id, limit=50}, true)
if not r.ok then
errMsg("Could not load history", r.err or "?")
return
end
local entries = r.entries or {}
local scroll = 0
while true do
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "HISTORY  "..account_id, TH.gold, TH.surface)
ui:write(2, 2, ("%d entries (most recent first)"):format(#entries),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local rows = H - 5
ui:fill(W - 8, H, 4, 1, TH.surface_alt or TH.surface)
ui:write(W - 7, H, "UP", TH.gold, TH.surface_alt or TH.surface)
table.insert(zones, {x=W-8, y=H, w=4, h=1, action="up"})
ui:fill(W - 4, H, 4, 1, TH.surface_alt or TH.surface)
ui:write(W - 3, H, "DN", TH.gold, TH.surface_alt or TH.surface)
table.insert(zones, {x=W-4, y=H, w=4, h=1, action="dn"})
local y = 5
for i = 1, rows do
local idx = scroll + i
if idx > #entries then break end
local e = entries[idx]
local row_y = y + i - 1
local color = TH.ink
if e.amount and e.amount < 0 then color = TH.debit end
if e.amount and e.amount > 0 then color = TH.credit end
local time_str = os.date("%m/%d %H:%M", e.t or 0)
local typ = e.type or "?"
local note = (e.note or ""):sub(1, 30)
local amt = e.amount and fmtMoney(e.amount) or ""
ui:write(2, row_y, time_str, TH.ink_muted, TH.bg)
ui:write(15, row_y, typ:sub(1, 14), TH.ink, TH.bg)
ui:write(30, row_y, note, TH.ink_muted, TH.bg)
ui:write(W - #amt - 2, row_y, amt, color, TH.bg)
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
if z.action == "back" then return end
if z.action == "up" then scroll = math.max(0, scroll - rows) end
if z.action == "dn" then
if scroll + rows < #entries then scroll = scroll + rows end
end
break
end
end
end
end
rankPickerScreen = function(account_id, owner_name)
local ranks = CFG.VANGUARD_RANKS or {}
local r0 = C:call("vanguard_summary", {}, true)
local current_count = r0.ok and (r0.total or 0) or 0
local current_max = CFG.VANGUARD_MAX_MEMBERS or 10
local scroll = 0
while true do
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "VANGUARD RANK PICKER", TH.gold, TH.surface)
ui:write(2, 2,
("for %s  (%s)  -  current roster %d/%d")
:format(owner_name, account_id, current_count, current_max),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:fill(1, 4, W, 1, TH.bg)
ui:fill(1, 5, W, H - 6, TH.bg)
ui:fill(W - 24, 1, 24, 3, TH.debit)
ui:write(W - 22, 2, "[REMOVE FROM VANGUARD]",
TH.ink, TH.debit)
table.insert(zones, {x=W-24, y=1, w=24, h=3, action="remove"})
local rows = H - 6
for i = 1, rows do
local idx = scroll + i
if idx > #ranks then break end
local rk = ranks[idx]
local row_y = 5 + i - 1
local grade = rk.grade or rk.id or "?"
local label = rk.label or rk.id or "?"
local color
if grade:sub(1, 1) == "O" then color = TH.gold
elseif grade:sub(1, 1) == "W" then color = TH.credit
else color = TH.ink end
ui:fill(1, row_y, W, 1, (i % 2 == 0)
and (TH.surface_alt or TH.surface)
or TH.bg)
ui:write(2, row_y, grade, color, nil)
ui:write(8, row_y, label:sub(1, 28), TH.ink, nil)
local pay = "$"..tostring(math.floor((rk.weekly_cents or 0)/100))
.."/wk"
ui:write(W - #pay - 2, row_y, pay, TH.gold, nil)
table.insert(zones, {x=1, y=row_y, w=W, h=1,
action="pick", rank_idx=idx})
end
ui:fill(W - 8, H, 4, 1, TH.surface_alt or TH.surface)
ui:write(W - 7, H, "UP", TH.gold,
TH.surface_alt or TH.surface)
table.insert(zones, {x=W-8, y=H, w=4, h=1, action="up"})
ui:fill(W - 4, H, 4, 1, TH.surface_alt or TH.surface)
ui:write(W - 3, H, "DN", TH.gold,
TH.surface_alt or TH.surface)
table.insert(zones, {x=W-4, y=H, w=4, h=1, action="dn"})
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "up" then
scroll = math.max(0, scroll - rows)
elseif hit.action == "dn" then
if scroll + rows < #ranks then scroll = scroll + rows end
elseif hit.action == "remove" then
local conf = ui:confirmScreen("Remove from Vanguard?",
owner_name.." will lose their rank and stop earning salary.",
{ok_label="REMOVE", ok_color=TH.debit})
if conf then
local res = C:call("admin_set_rank", {
account_id=account_id, rank_id=nil
}, true)
if res.ok then okMsg("Removed",
owner_name.." is no longer in the Vanguard.")
else errMsg("Failed", res.err or "?") end
return
end
elseif hit.action == "pick" then
local rk = ranks[hit.rank_idx]
local grade = rk.grade or rk.id or "?"
local label = rk.label or rk.id or "?"
local conf = ui:confirmScreen("Confirm assignment",
string.format(
"%s\n%s\n\nWeekly: $%d   Yearly: $%d",
grade .. "  " .. label,
"Assign to "..owner_name.." ("..account_id..")",
math.floor((rk.weekly_cents or 0)/100),
math.floor((rk.weekly_cents or 0)/100 * 52)),
{ok_label="ASSIGN  "..grade, ok_color=TH.gold})
if conf then
local res = C:call("admin_set_rank", {
account_id=account_id, rank_id=rk.id,
}, true)
if res.ok then okMsg("Rank assigned",
owner_name.." is now "..grade.."  "..label)
return
else errMsg("Failed", res.err or "?") end
end
end
end
end
jobPickerScreen = function(account_id, owner_name)
local function fetchJobs()
local r = C:call("admin_list_jobs", {}, true)
return r.ok and r.jobs or {}
end
local jobs = fetchJobs()
if #jobs == 0 then
local conf = ui:confirmScreen("No civic jobs defined",
"Go to CIVIC JOBS from the home screen to create one first.",
{ok_label="OK", cancel_label="OK"})
return
end
while true do
local jobs = fetchJobs()
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "CIVIC JOB PICKER", TH.gold, TH.surface)
ui:write(2, 2, ("Assign job to %s (%s)")
:format(owner_name, account_id),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local y = 5
for i, j in ipairs(jobs) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0)
and (TH.surface_alt or TH.surface)
or TH.bg)
ui:write(2, y, j.title:sub(1, 24), TH.ink, nil)
local pay = "$"..tostring(math.floor(j.annual_cents/100/52))
.."/wk"
ui:write(W - #pay - 2, y, pay, TH.gold, nil)
table.insert(zones, {x=1, y=y, w=W, h=1,
action="pick", job_id=j.id, job_title=j.title})
y = y + 1
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "pick" then
local conf = ui:confirmScreen("Assign civic job?",
"Assign '"..hit.job_title.."' to "..owner_name,
{ok_label="ASSIGN", ok_color=TH.gold})
if conf then
local res = C:call("admin_assign_job", {
account_id=account_id, job_id=hit.job_id,
}, true)
if res.ok then okMsg("Assigned",
owner_name.." is now a "..hit.job_title)
return
else errMsg("Failed", res.err or "?") end
end
end
end
end
local function vanguardRoster()
while true do
local r = C:call("vanguard_roster", {}, true)
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "VANGUARD ROSTER", TH.gold, TH.surface)
local count = r.ok and #(r.members or {}) or 0
local cap = CFG.VANGUARD_MAX_MEMBERS or 10
ui:write(2, 2, ("%d / %d members"):format(count, cap),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:write(W - 38, H, "Tap a member to manage their account",
TH.ink_muted, TH.surface)
local y = 5
if r.ok and r.members then
for i, m in ipairs(r.members) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0)
and (TH.surface_alt or TH.surface)
or TH.bg)
ui:write(2, y, m.rank_code, TH.gold, nil)
ui:write(8, y, m.rank_title:sub(1, 22), TH.ink, nil)
ui:write(32, y, m.owner:sub(1, 16), TH.ink, nil)
ui:write(50, y, m.account_id, TH.ink_muted, nil)
table.insert(zones, {x=1, y=y, w=W, h=1,
action="select", account_id=m.account_id})
y = y + 1
end
else
ui:write(2, 5, "No Vanguard members yet.",
TH.ink_muted, TH.bg)
ui:write(2, 7, "Browse Accounts -> select someone -> SET RANK",
TH.ink_muted, TH.bg)
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "select" then
accountDetailScreen(hit.account_id)
end
end
end
local function civicJobsManager()
while true do
local r = C:call("admin_list_jobs", {}, true)
local jobs = r.ok and r.jobs or {}
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "CIVIC JOBS", TH.gold, TH.surface)
ui:write(2, 2, ("%d jobs defined"):format(#jobs),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:fill(W - 22, 1, 22, 3, TH.credit)
ui:write(W - 19, 2, "[+ CREATE NEW JOB]",
TH.bg, TH.credit)
table.insert(zones, {x=W-22, y=1, w=22, h=3, action="create"})
local y = 5
for i, j in ipairs(jobs) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0)
and (TH.surface_alt or TH.surface)
or TH.bg)
ui:write(2, y, j.title:sub(1, 24), TH.ink, nil)
local hc = 0
for _ in pairs(j.holders or {}) do hc = hc + 1 end
ui:write(28, y, hc.." holder"..(hc==1 and "" or "s"),
TH.ink_muted, nil)
local pay = "$"..tostring(math.floor(j.annual_cents/100))
.."/yr"
ui:write(W - #pay - 2, y, pay, TH.gold, nil)
table.insert(zones, {x=1, y=y, w=W, h=1,
action="edit", job_id=j.id, job=j})
y = y + 1
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "create" then
local title = ui:keyboardScreen("NEW CIVIC JOB", {
subtitle = "Job title (e.g., Architect, Engineer, Lorekeeper)",
pattern = "^[%w%s_]*$",
max_len = 32,
})
if title and #title >= 3 then
local salary = ui:keyboardScreen("ANNUAL SALARY", {
subtitle = "Type annual amount (e.g., 80000 for $80k/yr)",
pattern = "^[%d%.kKmM]*$",
max_len = 16,
})
if salary and #salary > 0 then
local cents = parseMoney(salary)
if cents and cents > 0 then
local conf = ui:confirmScreen("Create civic job?",
title.."\n\nAnnual: "..fmtMoney(cents).."\n"
.."Weekly: "..fmtMoney(math.floor(cents/52)).."\n"
.."Daily:  "..fmtMoney(math.floor(cents/365)),
{ok_label="CREATE", ok_color=TH.credit})
if conf then
local res = C:call("admin_create_job", {
title=title, annual_cents=cents,
}, true)
if res.ok then okMsg("Created", title)
else errMsg("Failed", res.err or "?") end
end
else
errMsg("Invalid amount", "Try '80000' or '80k'")
end
end
elseif title then
errMsg("Title too short", "Need at least 3 characters")
end
elseif hit.action == "edit" then
jobDetailScreen(hit.job_id, hit.job)
end
end
end
jobDetailScreen = function(job_id, job)
while true do
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 4, TH.surface)
ui:write(2, 1, "JOB:  "..job.title, TH.gold, TH.surface)
ui:write(2, 2, "Annual: "..fmtMoney(job.annual_cents)
.."   Weekly: "..fmtMoney(math.floor(job.annual_cents/52)),
TH.ink, TH.surface)
local hc = 0
for _ in pairs(job.holders or {}) do hc = hc + 1 end
ui:write(2, 3, hc.." holder"..(hc==1 and "" or "s"),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local pad = 2
local card_w = math.floor((W - pad * 3) / 2)
local card_h = 5
ui:fill(pad, 6, card_w, card_h, TH.gold)
local lbl = "EDIT SALARY"
ui:write(pad + math.floor((card_w - #lbl) / 2), 6 + 2, lbl,
TH.bg, TH.gold)
table.insert(zones, {x=pad, y=6, w=card_w, h=card_h, action="edit_pay"})
local x2 = pad * 2 + card_w
ui:fill(x2, 6, card_w, card_h, TH.debit)
lbl = "DELETE JOB"
ui:write(x2 + math.floor((card_w - #lbl) / 2), 6 + 2, lbl,
TH.ink, TH.debit)
table.insert(zones, {x=x2, y=6, w=card_w, h=card_h, action="delete"})
ui:write(2, 13, "HOLDERS", TH.gold, TH.bg)
local y = 14
for aid in pairs(job.holders or {}) do
if y > H - 2 then break end
ui:write(4, y, aid, TH.ink, TH.bg)
y = y + 1
end
if hc == 0 then
ui:write(4, 14, "(none yet -- assign via account detail)",
TH.ink_muted, TH.bg)
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "edit_pay" then
local salary = ui:keyboardScreen("NEW ANNUAL SALARY", {
subtitle = "Current: "..fmtMoney(job.annual_cents),
pattern = "^[%d%.kKmM]*$",
max_len = 16,
})
if salary and #salary > 0 then
local cents = parseMoney(salary)
if cents and cents > 0 then
local res = C:call("admin_set_job_salary", {
job_id=job_id, annual_cents=cents,
}, true)
if res.ok then
okMsg("Updated",
"All holders get the new rate at the next tick")
job.annual_cents = cents
else errMsg("Failed", res.err or "?") end
else
errMsg("Invalid amount", "Try '80000' or '80k'")
end
end
elseif hit.action == "delete" then
local conf = ui:confirmScreen("DELETE this job?",
"All "..hc.." holders will be unassigned.\nThis cannot be undone.",
{ok_label="DELETE", ok_color=TH.debit})
if conf then
local res = C:call("admin_delete_job", {job_id=job_id}, true)
if res.ok then okMsg("Deleted", job.title); return
else errMsg("Failed", res.err or "?") end
end
end
end
end
local function diagnosticsTouch()
local last_data = nil
local last_err = nil
local function fetch()
local r = C:call("admin_diagnostics", {}, true)
if r.ok then last_data = r; last_err = nil
else last_data = nil; last_err = r.err end
end
local function durfmt(sec)
sec = math.floor(sec or 0)
if sec < 60 then return sec.."s" end
if sec < 3600 then return math.floor(sec/60).."m" end
if sec < 86400 then return math.floor(sec/3600).."h" end
return math.floor(sec/86400).."d"
end
fetch()
while true do
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "DIAGNOSTICS", TH.gold, TH.surface)
ui:write(2, 2, "Live system status",
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:fill(W - 12, H, 12, 1, TH.surface_alt or TH.surface)
ui:write(W - 10, H, "[REFRESH]", TH.gold,
TH.surface_alt or TH.surface)
table.insert(zones, {x=W-12, y=H, w=12, h=1, action="refresh"})
if last_err then
ui:fill(1, 5, W, 5, TH.debit)
ui:write(3, 6, "CANNOT REACH BANK",
TH.ink, TH.debit)
ui:write(3, 8, tostring(last_err):sub(1, W - 6),
TH.ink, TH.debit)
elseif last_data then
local d = last_data
local function row(x, y, label, value, status)
ui:write(x, y, label, TH.ink_muted, TH.bg)
local color = TH.ink
if status == "ok" then color = TH.credit
elseif status == "warn" then color = TH.warn
elseif status == "err" then color = TH.debit end
ui:write(x + 18, y, tostring(value), color, TH.bg)
end
local function header(x, y, txt)
ui:write(x, y, txt, TH.gold, TH.bg)
end
local col1 = 2; local col2 = math.floor(W / 2) + 1
header(col1, 5, "SYSTEM")
row(col1, 6, "Version", d.version, "ok")
row(col1, 7, "Uptime", durfmt(d.uptime_sec), "ok")
row(col1, 8, "Free disk", d.free_space_bytes
and math.floor(d.free_space_bytes/1024).." KB" or "?",
(d.free_space_bytes and d.free_space_bytes < 100000)
and "err" or "ok")
row(col1, 9, "Ledger size",
math.floor((d.ledger_size_bytes or 0)/1024).." KB", "ok")
header(col1, 11, "ECONOMY")
row(col1, 12, "Accounts",
d.accounts.." ("..d.accounts_frozen.." frozen)", "ok")
row(col1, 13, "Sessions", d.active_sessions, "ok")
row(col1, 14, "Money supply", fmtMoney(d.money_supply),
d.money_supply >= 0 and "ok" or "err")
row(col1, 15, "Vanguard",
d.vanguard_members.."/"..d.vanguard_max, "ok")
row(col1, 16, "Civic jobs", d.civic_jobs, "ok")
row(col1, 17, "Pending TX", d.pending_factions, "ok")
row(col1, 18, "Farm flags", d.farm_flags_pending,
d.farm_flags_pending > 0 and "warn" or "ok")
header(col2, 5, "ERRORS")
row(col2, 6, "Persist fail", d.persist_failures,
(d.persist_failures or 0) == 0 and "ok" or "err")
row(col2, 7, "Ledger fail", d.ledger_write_failures,
(d.ledger_write_failures or 0) == 0 and "ok" or "err")
row(col2, 8, "Rejects", d.rejected_packets,
(d.rejected_packets or 0) < 10 and "ok" or "warn")
row(col2, 9, "Crashes", d.server_errors,
(d.server_errors or 0) == 0 and "ok" or "warn")
header(col2, 11, "FEATURES")
row(col2, 12, "Earnings",
d.earnings_enabled and "ON" or "OFF",
d.earnings_enabled and "ok" or "warn")
row(col2, 13, "Vanguard",
d.vanguard_enabled and "ON" or "OFF",
d.vanguard_enabled and "ok" or "warn")
local issues = {}
if d.last_persist_error then
table.insert(issues, "Persist: "
..tostring(d.last_persist_error):sub(1, W - 14))
end
if d.last_error_method then
table.insert(issues, "Crash in "..d.last_error_method
..": "..tostring(d.last_error_detail or ""):sub(1, W - 30))
end
if d.last_ledger_error then
table.insert(issues, "Ledger: "
..tostring(d.last_ledger_error):sub(1, W - 14))
end
if #issues > 0 then
ui:write(2, H - 4, "ACTIVE ISSUES", TH.gold, TH.bg)
for i, iss in ipairs(issues) do
if i > 3 then break end
ui:write(2, H - 4 + i, "! "..iss, TH.debit, TH.bg)
end
else
ui:write(2, H - 2, "All systems nominal.",
TH.credit, TH.bg)
end
else
ui:write(2, 7, "Loading...", TH.ink_muted, TH.bg)
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
if z.action == "back" then return end
if z.action == "refresh" then fetch() end
break
end
end
end
end
local function reviewClaims()
while true do
local r = C:call("admin_pending_claims", {}, true)
local claims = r.ok and r.claims or {}
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "PENDING PROGRESS CLAIMS", TH.gold, TH.surface)
ui:write(2, 2, ("%d awaiting review"):format(#claims),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local y = 5
if #claims == 0 then
ui:write(2, y, "No pending claims.", TH.ink_muted, TH.bg)
end
for i, claim in ipairs(claims) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0) and (TH.surface_alt or TH.surface) or TH.bg)
ui:write(2, y, claim.owner:sub(1, 12), TH.ink, nil)
ui:write(15, y, claim.label:sub(1, 24), TH.gold, nil)
local pay = "$"..tostring(math.floor(claim.bounty/100))
ui:write(W - #pay - 14, y, pay, TH.gold, nil)
ui:write(W - 12, y, "[REVIEW]", TH.credit, nil)
table.insert(zones, {x=1, y=y, w=W, h=1, action="review",
claim=claim})
y = y + 1
end
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "review" then
local cl = hit.claim
local choice = ui:choiceScreen("Review claim",
{{label="APPROVE",
subtitle="Pay $"..math.floor(cl.bounty/100),
value="approve", color=TH.credit},
{label="REJECT",
subtitle="No payment, log only",
value="reject", color=TH.debit}},
{subtitle = cl.owner.." -> "..cl.label
.."\nEvidence: "..(cl.evidence or "(none)")})
if choice == "approve" then
local res = C:call("admin_approve_claim", {
account_id=cl.account, progress_id=cl.progress,
}, true)
if res.ok then okMsg("Approved",
cl.owner.." was paid $"..math.floor(res.bounty/100))
else errMsg("Failed", res.err or "?") end
elseif choice == "reject" then
local res = C:call("admin_reject_claim", {
account_id=cl.account, progress_id=cl.progress,
reason="Reviewed at admin terminal",
}, true)
if res.ok then okMsg("Rejected", cl.owner.."'s claim cleared")
else errMsg("Failed", res.err or "?") end
end
end
end
end
local function reviewFarmFlags()
while true do
local r = C:call("admin_list_farm_flags", {}, true)
local flags = r.ok and r.flags or {}
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "FARM-FLAG REVIEW QUEUE", TH.gold, TH.surface)
ui:write(2, 2,
("%d players with flagged combat earnings"):format(#flags),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local y = 5
if #flags == 0 then
ui:write(2, y, "No pending flags.", TH.ink_muted, TH.bg)
end
for i, fl in ipairs(flags) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0)
and (TH.surface_alt or TH.surface)
or TH.bg)
ui:write(2, y, fl.owner:sub(1, 12), TH.ink, nil)
ui:write(15, y, fl.entity:sub(1, 18)
.." x"..tostring(fl.count), TH.warn, nil)
local pay = "$"..tostring(math.floor((fl.estimated_pay or 0)/100))
ui:write(W - #pay - 14, y, pay, TH.ink_muted, nil)
ui:write(W - 12, y, "[REVIEW]", TH.gold, nil)
table.insert(zones, {x=1, y=y, w=W, h=1, action="review",
flag=fl})
y = y + 1
end
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
hit = z; break
end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "review" then
local fl = hit.flag
local choice = ui:choiceScreen("Review farm flag",
{{label="CONFIRM",
subtitle="Zero stands (it was farming)",
value="confirm", color=TH.warn},
{label="OVERRIDE",
subtitle="Retroactively pay $"
..math.floor((fl.estimated_pay or 0)/100),
value="override", color=TH.credit}},
{subtitle=fl.owner.." killed "..fl.count.." "..fl.entity})
if choice then
local res = C:call("admin_review_flag", {
flag_id=fl.id, action=choice,
}, true)
if res.ok then okMsg("Done", "Flag resolved")
else errMsg("Failed", res.err or "?") end
end
end
end
end
local function workOrdersManager()
local function fetch()
local r = C:call("admin_list_work_orders", {}, true)
if r.ok then return r.orders or {} end
local r2 = C:call("list_work_orders", {})
return r2.ok and r2.orders or {}
end
while true do
local orders = fetch()
local fund_bal = 0
local fr = C:call("admin_account_detail",
{account_id=CFG.FUND_ACCOUNT_ID}, true)
if fr.ok and fr.account then fund_bal = fr.account.balance or 0 end
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "PUBLIC WORKS ORDERS", TH.gold, TH.surface)
ui:write(2, 2,
("%d active  -  Fund balance: %s"):format(#orders, fmtMoney(fund_bal)),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:fill(W - 22, 1, 22, 3, TH.credit)
ui:write(W - 19, 2, "[+ POST NEW ORDER]", TH.bg, TH.credit)
table.insert(zones, {x=W-22, y=1, w=22, h=3, action="post"})
local y = 5
if #orders == 0 then
ui:write(2, y, "No orders posted yet.",
TH.ink_muted, TH.bg)
ui:write(2, y + 2,
"Tap [+ POST NEW ORDER] to create one.",
TH.ink_muted, TH.bg)
else
for i, o in ipairs(orders) do
if y > H - 3 then break end
ui:fill(1, y, W, 2, (i % 2 == 0) and (TH.surface_alt or TH.surface) or TH.bg)
ui:write(2, y, (o.title or ""):sub(1, W - 30), TH.ink, nil)
local status, sc
if o.completed then status = "DONE"; sc = TH.ink_muted
elseif o.claimed_by then
local who = o.claimed_owner or o.claimed_by
status = "ACCEPTED by "..who; sc = TH.gold
else
status = "OPEN -- waiting for worker"; sc = TH.credit
end
ui:write(2, y + 1, status:sub(1, W - 22), sc, nil)
local pay = fmtMoney(o.bounty or 0)
ui:write(W - #pay - 14, y, pay, TH.gold, nil)
if o.completed then
ui:write(W - 12, y, "[CLOSED]", TH.ink_muted, nil)
elseif o.claimed_by then
ui:fill(W - 13, y, 12, 2, TH.credit)
ui:write(W - 12, y, "[COMPLETE]", TH.bg, TH.credit)
table.insert(zones, {x=W-13, y=y, w=12, h=2,
action="complete", order=o})
else
ui:fill(W - 13, y, 12, 2, TH.warn)
ui:write(W - 11, y, "[DELETE]", TH.bg, TH.warn)
table.insert(zones, {x=W-13, y=y, w=12, h=2,
action="delete", order=o})
end
y = y + 3
end
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then hit = z; break end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "post" then
local title = ui:keyboardScreen("New work order title", {
subtitle="Short description (3-60 chars)",
pattern="^[%w%s%-_,.()/!?']*$", max_len=60,
})
if not title or #title < 3 then
else
local amt_str = ui:keyboardScreen("Bounty in dollars", {
subtitle="How much will the worker earn?",
numeric=true, digits_only=false,
pattern="^%d*%.?%d*$", max_len=12,
})
local dollars = tonumber(amt_str or "")
if not dollars or dollars <= 0 then
else
local cents = math.floor(dollars * 100 + 0.5)
local conf = ui:confirmScreen(
"Post work order?",
string.format("\"%s\"\nBounty: %s\n(Reserved from Fund: %s)",
title, fmtMoney(cents), fmtMoney(fund_bal)),
{ok_label="POST", ok_color=TH.credit})
if conf then
local r = C:call("admin_post_work_order",
{title=title, bounty=cents}, true)
if r.ok then okMsg("Posted",
"Work order "..r.order_id.." live at ATMs.")
else errMsg("Failed", r.err or "?") end
end
end
end
elseif hit.action == "complete" then
local o = hit.order
local who = o.claimed_owner or o.claimed_by
local conf = ui:confirmScreen(
"Mark complete and pay?",
string.format("\"%s\"\n\nWorker: %s\nBounty: %s\n\nPays from reserved Fund.",
o.title, who, fmtMoney(o.bounty)),
{ok_label="PAY "..fmtMoney(o.bounty), ok_color=TH.credit})
if conf then
local r = C:call("admin_complete_work_order",
{order_id=o.id}, true)
if r.ok then okMsg("Paid",
(r.owner or "Worker").." was paid "..fmtMoney(o.bounty))
else errMsg("Failed", r.err or "?") end
end
elseif hit.action == "delete" then
local o = hit.order
local conf = ui:confirmScreen(
"Delete work order?",
string.format("\"%s\"\nBounty: %s\n\nRefunds to the Fund.",
o.title, fmtMoney(o.bounty)),
{ok_label="DELETE", ok_color=TH.debit})
if conf then
local r = C:call("admin_delete_work_order",
{order_id=o.id}, true)
if r.ok then okMsg("Deleted", "Bounty refunded to Fund")
else errMsg("Failed", r.err or "?") end
end
end
end
end
local function reviewCivicRequests()
while true do
local r = C:call("admin_list_civic_requests", {}, true)
local reqs = r.ok and r.requests or {}
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "CIVIC JOB APPLICATIONS", TH.gold, TH.surface)
ui:write(2, 2, ("%d pending"):format(#reqs),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
local y = 5
if #reqs == 0 then
ui:write(2, y, "No pending applications.", TH.ink_muted, TH.bg)
end
for i, req in ipairs(reqs) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0) and (TH.surface_alt or TH.surface) or TH.bg)
ui:write(2, y, (req.owner or ""):sub(1, 14), TH.gold, nil)
ui:write(17, y, "->  "..req.job_title:sub(1, 22), TH.ink, nil)
local pay = "$"..tostring(math.floor((req.annual_cents or 0) / 100)).."/yr"
ui:write(W - #pay - 14, y, pay, TH.gold, nil)
ui:write(W - 12, y, "[REVIEW]", TH.credit, nil)
table.insert(zones, {x=1, y=y, w=W, h=1, action="review", req=req})
y = y + 1
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
local hit
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then hit = z; break end
end
if not hit then
elseif hit.action == "back" then
return
elseif hit.action == "review" then
local req = hit.req
local choice = ui:choiceScreen("Review application",
{{label="APPROVE",
subtitle="Assign job and start salary",
value="approve", color=TH.credit},
{label="REJECT",
subtitle="Decline the application",
value="reject", color=TH.debit}},
{subtitle = req.owner.." applies for "..req.job_title})
if choice == "approve" then
local res = C:call("admin_approve_civic_request",
{request_id=req.id}, true)
if res.ok then okMsg("Approved",
req.owner.." now holds "..req.job_title)
else errMsg("Failed", res.err or "?") end
elseif choice == "reject" then
local res = C:call("admin_reject_civic_request",
{request_id=req.id, reason="Reviewed at admin terminal"}, true)
if res.ok then okMsg("Rejected",
req.owner.."'s application cleared")
else errMsg("Failed", res.err or "?") end
end
end
end
end
local function ledgerView()
while true do
local r = C:call("admin_ledger_tail", {limit=30}, true)
local entries = r.ok and r.entries or {}
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 3, TH.surface)
ui:write(2, 1, "RECENT LEDGER", TH.gold, TH.surface)
ui:write(2, 2, ("%d most recent events"):format(#entries),
TH.ink_muted, TH.surface)
local zones = {}
ui:fill(1, H, 8, 1, TH.surface)
ui:write(2, H, "[BACK]", TH.gold, TH.surface)
table.insert(zones, {x=1, y=H, w=8, h=1, action="back"})
ui:fill(W - 12, H, 12, 1, TH.surface_alt or TH.surface)
ui:write(W - 10, H, "[REFRESH]", TH.gold, TH.surface_alt or TH.surface)
table.insert(zones, {x=W-12, y=H, w=12, h=1, action="refresh"})
local y = 5
for i, e in ipairs(entries) do
if y > H - 2 then break end
ui:fill(1, y, W, 1, (i % 2 == 0) and (TH.surface_alt or TH.surface) or TH.bg)
local ts = e.t and os.date("%H:%M", e.t) or "--:--"
ui:write(2, y, ts, TH.ink_muted, nil)
ui:write(8, y, (e.type or "?"):sub(1, 18), TH.gold, nil)
local detail = ""
if e.amount then detail = fmtMoney(e.amount) end
if e.owner then detail = detail .. "  " .. e.owner end
if e.title then detail = detail .. "  " .. e.title end
if e.from and e.to then detail = (e.from or "?").." -> "..(e.to or "?") end
ui:write(28, y, detail:sub(1, W - 30), TH.ink, nil)
y = y + 1
end
ui:flush()
local _, _, mx, my = os.pullEvent("monitor_touch")
for _, z in ipairs(zones) do
if mx >= z.x and mx < z.x + z.w
and my >= z.y and my < z.y + z.h then
if z.action == "back" then return end
break
end
end
end
end
local function reviewQueue()
while true do
local choice = ui:choiceScreen("REVIEW QUEUE",
{{label="PROGRESS CLAIMS",
subtitle="Approve / reject pending claims",
value="claims", color=TH.gold},
{label="CIVIC APPLICATIONS",
subtitle="Approve / reject job requests",
value="civic", color=TH.credit},
{label="FARM FLAGS",
subtitle="Review flagged combat earnings",
value="flags", color=TH.warn}},
{subtitle="Pick a queue to review."})
if not choice then return end
if choice == "claims" then
local ok_b, err_b = pcall(reviewClaims)
if not ok_b then errMsg("Crashed", tostring(err_b):sub(1, 200)) end
elseif choice == "civic" then
local ok_b, err_b = pcall(reviewCivicRequests)
if not ok_b then errMsg("Crashed", tostring(err_b):sub(1, 200)) end
elseif choice == "flags" then
local ok_b, err_b = pcall(reviewFarmFlags)
if not ok_b then errMsg("Crashed", tostring(err_b):sub(1, 200)) end
end
end
end
local function rotateSecret()
local conf = ui:confirmScreen("Rotate server secret?",
"This invalidates EVERY existing client.\n"
.."You'll need to re-bootstrap every ATM, viewer, shop, etc.\n"
.."Use this ONLY if you suspect the key was compromised.",
{ok_label="ROTATE", ok_color=TH.debit})
if not conf then return end
local conf2 = ui:confirmScreen("Are you SURE?",
"Last chance. Type CANCEL on the next screen if unsure.",
{ok_label="YES, ROTATE", ok_color=TH.debit})
if not conf2 then return end
local res = C:call("admin_rotate_secret", {}, true)
if res.ok then
okMsg("Rotated",
"New secret is on the server.\nWrite the new key down: "
..(res.new_secret or "(see server)"))
else
errMsg("Failed", res.err or "?")
end
end
local function policyAndMore()
while true do
local choice = ui:choiceScreen("POLICY & MORE",
{{label="ROTATE SECRET",
subtitle="Security: rotate server key",
value="rotate", color=TH.debit}},
{subtitle="Advanced administrative controls."})
if not choice then return end
if choice == "rotate" then
local ok_b, err_b = pcall(rotateSecret)
if not ok_b then errMsg("Crashed", tostring(err_b):sub(1, 200)) end
end
end
end
while true do
local action = homeScreen()
if action == "browse" then
local ok_b, err_b = pcall(browseAccounts)
if not ok_b then errMsg("Browse crashed", tostring(err_b):sub(1, 200)) end
elseif action == "diag" then
local ok_b, err_b = pcall(diagnosticsTouch)
if not ok_b then errMsg("Diagnostics crashed", tostring(err_b):sub(1, 200)) end
elseif action == "vanguard" then
local ok_b, err_b = pcall(vanguardRoster)
if not ok_b then errMsg("Vanguard crashed", tostring(err_b):sub(1, 200)) end
elseif action == "jobs" then
local ok_b, err_b = pcall(civicJobsManager)
if not ok_b then errMsg("Jobs crashed", tostring(err_b):sub(1, 200)) end
elseif action == "work_orders" then
local ok_b, err_b = pcall(workOrdersManager)
if not ok_b then errMsg("Work Orders crashed", tostring(err_b):sub(1, 200)) end
elseif action == "queue" then
reviewQueue()
elseif action == "ledger" then
ledgerView()
elseif action == "policy" then
policyAndMore()
elseif action == "refresh" then
end
end
end
local function runMint()
term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.gold); term.clear()
term.setCursorPos(1, 1)
print("================================================")
print("  VANGUARD RESERVE BANK  \149  MINT STATION")
print("================================================")
term.setTextColor(THEME.ink)
print("")
print("Paste a Reserve Note (serialized table, one line).")
print("It will be written to an inserted floppy OR printed.")
local drive = findPeripheral("drive")
local printer = findPeripheral("printer")
if not drive and not printer then
term.setTextColor(THEME.debit)
print("No output device. Attach a disk drive (with disk) or printer.")
return
end
while true do
term.setTextColor(THEME.gold); write("\n> "); term.setTextColor(THEME.ink)
local s = read()
if s == "quit" or s == nil then return end
local ok, note = pcall(textutils.unserialize, s)
if not ok or type(note) ~= "table" or not note.sig then
term.setTextColor(THEME.debit); print("Malformed note."); term.setTextColor(THEME.ink)
else
local handled = false
if drive and drive.isDiskPresent() then
local path = drive.getMountPath()
if path then
local f = fs.open(fs.combine(path, "note.vrb"), "w")
f.write(textutils.serialize(note)); f.close()
drive.setDiskLabel(string.format("VRN %s - D %s", note.serial, note.denom))
term.setTextColor(THEME.credit)
print("Written to disk: " .. drive.getDiskLabel())
term.setTextColor(THEME.ink)
handled = true
end
end
if not handled and printer and printer.newPage() then
printer.setPageTitle("RESERVE NOTE " .. note.serial)
printer.setCursorPos(1, 1); printer.write("VANGUARD RESERVE NOTE")
printer.setCursorPos(1, 2); printer.write("---------------------")
printer.setCursorPos(1, 4); printer.write("Serial:       " .. note.serial)
printer.setCursorPos(1, 5); printer.write("Denomination: D " .. note.denom)
printer.setCursorPos(1, 6); printer.write("Issued:       " .. os.date("%Y-%m-%d %H:%M", note.issued))
printer.setCursorPos(1, 8); printer.write("BEARER INSTRUMENT")
printer.setCursorPos(1, 10); printer.write("Signature:")
printer.setCursorPos(1, 11); printer.write("  " .. note.sig:sub(1, 16))
printer.setCursorPos(1, 12); printer.write("  " .. note.sig:sub(17))
printer.setCursorPos(1, 14); printer.write("Stability. Trust. Prosperity.")
printer.endPage()
term.setTextColor(THEME.credit); print("Printed.")
term.setTextColor(THEME.ink)
elseif not handled then
term.setTextColor(THEME.warn); print("Insert a disk or attach a printer.")
term.setTextColor(THEME.ink)
end
end
end
end
local function runShop()
local secret = loadClientKeys(false)
local C = newClient(secret, nil)
local cfg_path = fs.combine(CFG.DATA_DIR, "shop.cfg")
local cfg = readJSON(cfg_path, nil)
if not cfg or not cfg.shop_id then
term.clear(); term.setCursorPos(1,1)
term.setTextColor(THEME.gold); print("VRB SHOP TERMINAL - First Run")
term.setTextColor(THEME.ink)
print("Create the shop at an ATM first ('shop new <label>').")
write("Shop ID (SHP-XXXX): "); local sid = read()
if not V.shop_id(sid) then print("Invalid."); return end
cfg = {shop_id=sid}; writeJSON(cfg_path, cfg)
end
local mon = findPeripheral("monitor")
if not mon then error("Shop requires an Advanced Monitor.") end
mon.setTextScale(0.5)
local ui = makeUI(mon)
local speaker = findPeripheral("speaker")
local audio = makeAudio(speaker)
local S = {
screen = "browse",
session = nil, account_id = nil, owner = nil, balance = 0,
shop = nil,
selected_sku = nil,
keypad = "", keypad_title = nil, keypad_mask = false, keypad_label = nil,
on_ok = nil, on_cancel = nil,
}
local function refreshShop()
local r = C:call("get_shop", {shop_id=cfg.shop_id})
if r.ok then S.shop = r.shop
else S.shop = nil; ui:showToast("error", "Shop unreachable") end
end
refreshShop()
local function renderHeader()
local W = ({ui:size()})[1]
ui:fill(1, 1, W, 4, ui.theme.surface)
ui:write(2, 1, "SHOP", ui.theme.gold_dim, ui.theme.surface)
ui:write(2, 2, (S.shop and S.shop.label or "?"):sub(1, W - 15), ui.theme.gold, ui.theme.surface)
ui:write(2, 3, "operated by " .. (S.shop and S.shop.owner or "?"), ui.theme.ink_muted, ui.theme.surface)
local clock = os.date("%H:%M")
ui:write(W - #clock - 1, 1, clock, ui.theme.gold, ui.theme.surface)
if S.session then ui:statusPill(W - 14, 2, "SIGNED IN", "ok") end
ui:hline(1, 5, W, ui.theme.gold, ui.theme.bg, "\140")
end
local function renderBrowse()
ui:begin(); ui:clear()
renderHeader()
local W, H = ui:size()
local y = 7
if S.shop and S.shop.listings and #S.shop.listings > 0 then
ui:card(3, y, W - 4, H - y - 5, {title=" LISTINGS ", accent_top=true})
y = y + 2
for _, l in ipairs(S.shop.listings) do
if y < H - 7 then
local bg = ui.theme.surface
local in_stock = l.stock > 0
local name_color = in_stock and ui.theme.ink or ui.theme.ink_dim
ui:fill(4, y, W - 6, 1, bg)
ui:write(4, y, l.sku:sub(1, 14), ui.theme.gold, bg)
ui:write(20, y, l.item:sub(1, 28), name_color, bg)
local price = fmtMoney(l.price)
ui:write(W - #price - 20, y, price, ui.theme.gold, bg)
ui:write(W - 18, y, "stock " .. l.stock, ui.theme.ink_muted, bg)
if in_stock then
ui:button(W - 10, y, 8, "BUY", {
kind="success", no_shadow=true,
action="select", data=l.sku,
})
else
ui:write(W - 8, y, "OUT", ui.theme.debit, bg)
end
y = y + 2
end
end
else
ui:emptyState(1, 7, W, H - 13, "No items listed",
"The shop owner has not stocked any items yet",
"Check back soon")
end
if not S.session then
ui:button(3, H - 5, 18, "SIGN IN", {kind="primary", action="signin"})
else
ui:write(3, H - 5, "Hi, " .. (S.owner or "?"), ui.theme.ink)
ui:write(3, H - 4, "Balance: " .. fmtMoney(S.balance), ui.theme.gold)
ui:button(W - 16, H - 5, 14, "SIGN OUT", {kind="danger", action="signout"})
end
ui:hline(1, H - 2, W, ui.theme.rule, ui.theme.bg, "\140")
ui:write(2, H, "VRB Shop v" .. VERSION .. "  " .. cfg.shop_id, ui.theme.ink_muted, ui.theme.bg)
ui:drawBanner(1, 6, W)
ui:drawToast()
end
local function renderConfirm()
ui:begin(); ui:clear()
renderHeader()
local W, H = ui:size()
local l
for _, x in ipairs(S.shop.listings or {}) do if x.sku == S.selected_sku then l = x end end
if not l then S.screen = "browse"; return renderBrowse() end
ui:card(3, 7, W - 4, 10, {title=" CONFIRM PURCHASE ", accent_top=true})
ui:write(5, 9, "SKU:", ui.theme.ink_muted, ui.theme.surface)
ui:write(15, 9, l.sku, ui.theme.gold, ui.theme.surface)
ui:write(5, 10, "Item:", ui.theme.ink_muted, ui.theme.surface)
ui:write(15, 10, l.item, ui.theme.ink, ui.theme.surface)
ui:write(5, 11, "Price:", ui.theme.ink_muted, ui.theme.surface)
ui:write(15, 11, fmtMoney(l.price) .. " each", ui.theme.gold, ui.theme.surface)
ui:write(5, 12, "Stock:", ui.theme.ink_muted, ui.theme.surface)
ui:write(15, 12, tostring(l.stock), ui.theme.ink, ui.theme.surface)
if l.note and #l.note > 0 then
ui:write(5, 13, "Note:", ui.theme.ink_muted, ui.theme.surface)
ui:write(15, 13, l.note:sub(1, W - 20), ui.theme.ink_muted, ui.theme.surface)
end
ui:write(5, 15, "Balance:", ui.theme.ink_muted, ui.theme.surface)
ui:write(15, 15, fmtMoney(S.balance), ui.theme.gold, ui.theme.surface)
local btn_y = 19
ui:button(3, btn_y, 16, "BUY 1", {kind="success", action="buy", data={sku=S.selected_sku, qty=1}})
if l.stock >= 8 then
ui:button(21, btn_y, 16, "BUY 8", {kind="success", action="buy", data={sku=S.selected_sku, qty=8}})
end
if l.stock >= 64 then
ui:button(39, btn_y, 16, "BUY 64", {kind="success", action="buy", data={sku=S.selected_sku, qty=64}})
end
ui:button(W - 14, btn_y, 12, "CANCEL", {kind="secondary", action="back"})
ui:hline(1, H - 2, W, ui.theme.rule, ui.theme.bg, "\140")
ui:write(2, H, "VRB Shop v" .. VERSION, ui.theme.ink_muted, ui.theme.bg)
ui:drawBanner(1, 6, W)
ui:drawToast()
end
local function renderKeypad()
ui:begin(); ui:clear()
renderHeader()
local W, H = ui:size()
ui:card(3, 7, W - 4, 4, {title=" " .. (S.keypad_title or "") .. " "})
ui:write(5, 9, S.keypad_label or "", ui.theme.ink_muted, ui.theme.surface)
local shown = S.keypad_mask and string.rep("\7", #S.keypad) or S.keypad
local cursor = (ui.anim_frame % 20 < 10) and "_" or " "
ui:write(5 + (#(S.keypad_label or "") > 0 and 14 or 0), 9, "> " .. shown .. cursor,
ui.theme.gold, ui.theme.surface)
local keys = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"CLR","0","OK"}}
local bw, bh = 10, 3
local totalW = 3 * (bw + 2) - 2
local sx = math.floor((W - totalW) / 2)
local sy = 12
for r, row in ipairs(keys) do
for c, k in ipairs(row) do
local x = sx + (c - 1) * (bw + 2)
local y = sy + (r - 1) * (bh + 1)
local kind = (k == "OK") and "success" or (k == "CLR") and "danger" or "primary"
ui:button(x, y, bw, k, {kind=kind, action="key", data=k})
end
end
ui:button(3, H - 5, 14, "CANCEL", {kind="danger", action="cancel"})
ui:hline(1, H - 2, W, ui.theme.rule, ui.theme.bg, "\140")
ui:write(2, H, "VRB Shop v" .. VERSION, ui.theme.ink_muted, ui.theme.bg)
ui:drawToast()
end
local function enterKeypad(title, mask, label, onOk, onCancel)
S.keypad = ""; S.keypad_title = title; S.keypad_mask = mask
S.keypad_label = label; S.on_ok = onOk; S.on_cancel = onCancel
S.screen = "keypad"
end
local function doSignin()
local owner = ui:keyboardScreen("SIGN IN - USERNAME", {
subtitle = "Your minecraft username",
pattern = "^[A-Za-z0-9_]*$",
max_len = 32,
})
if not owner or #owner < 2 then S.screen = "browse"; return end
enterKeypad("SIGN IN - PIN", true, "PIN:",
function(pin)
local r = C:call("auth_by_owner",
{owner=owner, pin=pin, branch="SHOP:"..cfg.shop_id})
if r.ok then
S.session = r.session
S.account_id = r.account.id
S.owner = r.account.owner
S.balance = r.account.balance
audio:play("signin")
ui:showToast("ok", "Welcome, " .. r.account.owner)
S.screen = "browse"
else
audio:play("error")
ui:showToast("error", r.err or "Failed")
S.screen = "browse"
end
end,
function() S.screen = "browse" end)
end
local function handle(action, data)
if action == "key" then
if data == "CLR" then S.keypad = ""; audio:play("tap")
elseif data == "OK" then
local fn = S.on_ok; S.on_ok = nil; audio:play("click")
if fn then fn(S.keypad) end
else if #S.keypad < 12 then S.keypad = S.keypad .. data; audio:play("tap") end end
elseif action == "cancel" then
audio:play("click")
local fn = S.on_cancel; S.on_cancel = nil
if fn then fn() end
elseif action == "signin" then audio:play("click"); doSignin()
elseif action == "signout" then
if S.session then C:call("signout", {session=S.session}) end
audio:play("signout")
S.session = nil; S.owner = nil; S.balance = 0; S.account_id = nil
ui:showToast("ok", "Signed out")
S.screen = "browse"
elseif action == "select" then
if not S.session then
audio:play("error"); ui:showToast("error", "Sign in to buy")
else
S.selected_sku = data
S.screen = "confirm"
end
elseif action == "buy" then
if not S.session then audio:play("error"); ui:showToast("error", "Sign in first"); return end
local r = C:call("buy_from_shop", {session=S.session, shop_id=cfg.shop_id,
sku=data.sku, qty=data.qty})
if r.ok then
S.balance = r.balance
audio:play("cash")
ui:showToast("ok", string.format("Bought %dx  cost %s", data.qty, fmtMoney(r.cost)))
refreshShop()
else
audio:play("error"); ui:showToast("error", r.err or "Failed")
end
S.screen = "browse"
elseif action == "back" then S.screen = "browse"
end
end
local function redraw()
if S.screen == "browse" then renderBrowse()
elseif S.screen == "confirm" then renderConfirm()
elseif S.screen == "keypad" then renderKeypad()
end
end
redraw()
parallel.waitForAny(
function()
while true do
local ev, p1, p2, p3 = os.pullEvent()
if ev == "monitor_touch" then
local b = ui:hit(p2, p3)
if b then ui:press(b); handle(b.action, b.data) end
redraw()
elseif ev == "shop_refresh" then
refreshShop(); redraw()
elseif ev == "shop_tick" then
ui:tick(); redraw()
end
end
end,
function() while true do sleep(0.5); os.queueEvent("shop_tick") end end,
function() while true do sleep(10); os.queueEvent("shop_refresh") end end
)
end
local function runViewer()
local sec_ok, secret = pcall(loadClientKeys, false)
if not sec_ok or not secret then
showStartupError("VIEWER", "Missing or unreadable server.secret",
tostring(secret),
{"Re-run the bootstrap with the distribution floppy",
"Or copy manually: copy /disk/server.secret /.vrb/keys/server.secret"})
return
end
local C = newClient(secret, nil)
local mon, mon_name = findAdvancedMonitor()
if not mon then
showStartupError("VIEWER", "No monitor found",
"Looked for any block of type 'monitor' adjacent to or networked",
{"Place a 3x3 grid of Advanced Monitors adjacent to this computer",
"The viewer is read-only -- a regular Monitor would also work,",
"  but Advanced gives color and is recommended"})
return
end
local ping = C:call("ping", {})
if not ping.ok then
showStartupError("VIEWER", "Cannot reach the Reserve Bank",
tostring(ping.err),
{"Verify the bank server is running",
"Verify both this viewer's modem AND the server's modem are enabled (red ring)",
"If using regular wireless modems, both must be within 64 blocks",
"Use Ender Modems for unlimited range"})
return
end
mon.setTextScale(0.5)
local ui = makeUI(mon)
local function renderDashboard(stats_r, ledger_r)
ui:begin(); ui:clear()
local W, H = ui:size()
ui:fill(1, 1, W, 4, ui.theme.surface)
ui:crestLarge(2, 1)
ui:write(16, 1, "VANGUARD RESERVE BANK", ui.theme.gold, ui.theme.surface)
ui:write(16, 2, "Public Ledger Dashboard", ui.theme.ink, ui.theme.surface)
ui:write(16, 3, "Transparency is the price of trust", ui.theme.ink_muted, ui.theme.surface)
ui:write(W - 10, 1, os.date("%H:%M:%S"), ui.theme.gold, ui.theme.surface)
ui:hline(1, 5, W, ui.theme.gold, ui.theme.bg, "\140")
local left_w = math.floor((W - 6) * 0.45)
local right_x = left_w + 5
local right_w = W - right_x - 1
ui:card(3, 7, left_w, H - 9, {title=" ECONOMY ", accent_top=true})
if stats_r and stats_r.ok then
local s = stats_r.stats
local y = 9
local function stat(label, value, color)
ui:write(5, y, label, ui.theme.ink_muted, ui.theme.surface)
ui:write(5 + left_w - #value - 4, y, value, color or ui.theme.ink, ui.theme.surface)
y = y + 1
end
stat("Money supply", fmtMoney(s.supply), ui.theme.gold)
stat("Loans outstanding", fmtMoney(s.loans_out), ui.theme.debit)
stat("Transactions", tostring(s.tx_count), nil)
y = y + 1
stat("Accounts", tostring(s.accounts), nil)
stat("Active last 7d", tostring(s.active_last_week), ui.theme.credit)
stat("Factions", tostring(s.factions), nil)
stat("Active shops", tostring(s.active_shops), nil)
stat("Active loans", tostring(s.active_loans), nil)
y = y + 1
ui:hline(5, y, left_w - 6, ui.theme.gold_dim, ui.theme.surface, "\140")
y = y + 1
ui:write(5, y, "MONETARY POLICY", ui.theme.gold, ui.theme.surface); y = y + 1
local p = s.policy
stat("Savings rate", string.format("%.2f%%/mo", (p.sav_mpr or 0)*100), ui.theme.credit)
stat("Checking rate", string.format("%.2f%%/mo", (p.chk_mpr or 0)*100), nil)
stat("Loan rate", string.format("%.2f%%/mo", (p.loan_mpr or 0)*100), ui.theme.debit)
if p.ubi_enabled then
stat("UBI weekly", fmtMoney(p.ubi_weekly), ui.theme.credit)
else
stat("UBI", "disabled", ui.theme.ink_muted)
end
y = y + 1
ui:write(5, y, "TAX BRACKETS", ui.theme.gold, ui.theme.surface); y = y + 1
for _, b in ipairs(p.tax_brackets or {}) do
if y < H - 3 then
ui:write(7, y, string.format("> %s: %.2f%%",
fmtMoney(b.above), (b.rate or 0)*100), ui.theme.ink, ui.theme.surface)
y = y + 1
end
end
else
ui:write(5, 9, "Reserve Bank unreachable.", ui.theme.debit, ui.theme.surface)
end
ui:card(right_x, 7, right_w, H - 9, {title=" RECENT ACTIVITY ", accent_top=true})
if ledger_r and ledger_r.ok then
local y = 9
for i = #ledger_r.entries, 1, -1 do
if y >= H - 4 then break end
local e = ledger_r.entries[i]
local stamp = os.date("%m-%d %H:%M", e.t or 0)
local summary = e.type or "?"
if e.amount then summary = summary .. " " .. fmtMoney(e.amount)
elseif e.total then summary = summary .. " (" .. tostring(e.recipients or "?") ..
" acct, " .. fmtMoney(e.total) .. ")" end
local color = ui.theme.ink
if e.type == "deposit" or e.type == "progress_approve" or e.type == "ubi_payout"
or e.type == "wo_complete" or e.type == "interest" or e.type == "shop_sale"
or e.type == "earnings" then
color = ui.theme.credit
elseif e.type == "withdraw" or e.type == "loan_origin" or e.type == "note_issue"
or e.type == "insurance_charge"
or e.type == "salary" or e.type == "payroll_tick"
or e.type == "civic_pay" or e.type == "civic_payroll_tick" then
color = ui.theme.gold
elseif e.type == "policy_change" or e.type == "auto_policy"
or e.type == "admin_adjust" or e.type == "tax_brackets"
or e.type == "earnings_toggle" or e.type == "streak_override"
or e.type == "rank_assign" or e.type == "rank_change"
or e.type == "rank_remove" or e.type == "rank_leave"
or e.type == "vanguard_toggle"
or e.type == "job_create" or e.type == "job_edit"
or e.type == "job_delete" or e.type == "job_assign"
or e.type == "job_remove" or e.type == "job_leave" then
color = ui.theme.warn
elseif e.type == "death_penalty" or e.type == "insurance_lapse" then
color = ui.theme.debit
elseif e.type == "earnings_tick" then
color = ui.theme.gold_dim
end
ui:write(right_x + 2, y, (stamp .. "  " .. summary):sub(1, right_w - 4), color, ui.theme.surface)
y = y + 1
end
if ledger_r.head then
ui:write(right_x + 2, H - 4, "Head: " .. ledger_r.head:sub(1, right_w - 10),
ui.theme.ink_muted, ui.theme.surface)
end
else
ui:write(right_x + 2, 9, "Ledger unreachable.", ui.theme.debit, ui.theme.surface)
end
ui:hline(1, H - 2, W, ui.theme.rule, ui.theme.bg, "\140")
ui:write(2, H, "VRB Viewer v" .. VERSION, ui.theme.ink_muted, ui.theme.bg)
ui:write(W - 30, H, "Refreshes every 10 seconds", ui.theme.gold_dim, ui.theme.bg)
end
while true do
local stats = C:call("public_stats", {})
local ledger = C:call("public_ledger_tail", {limit=30})
renderDashboard(stats, ledger)
sleep(10)
end
end
local function runScoreboard()
local sec_ok, secret = pcall(loadClientKeys, false)
if not sec_ok or not secret then
showStartupError("SCOREBOARD", "Missing or unreadable server.secret",
tostring(secret),
{"Re-run the bootstrap with the distribution floppy",
"Pick role 'scoreboard' so it gets both keys"})
return
end
local p_admin = fs.combine(CFG.KEY_DIR, "admin.key")
if not fs.exists(p_admin) then
showStartupError("SCOREBOARD", "Missing admin.key",
"Scoreboard reader needs admin.key to submit earnings snapshots",
{"Re-run bootstrap and pick 'scoreboard' role",
"It will copy admin.key from the distribution floppy",
"If you wiped admin.key from the floppy, recreate it from the server"})
return
end
local f = fs.open(p_admin, "r")
if not f then
showStartupError("SCOREBOARD", "admin.key exists but cannot be read", nil,
{"Run: rm /.vrb/keys/admin.key", "Then re-bootstrap"})
return
end
local admin = f.readAll(); f.close()
if not admin or #admin < 16 then
showStartupError("SCOREBOARD", "admin.key is empty or too short",
"Length: "..tostring(admin and #admin or 0),
{"Delete and re-bootstrap"})
return
end
term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.gold); term.clear()
term.setCursorPos(1, 1)
print("===========================================================")
print("  VANGUARD RESERVE BANK  \149  Scoreboard Reader  \149  v"..VERSION)
print("===========================================================")
term.setTextColor(THEME.ink)
local C = newClient(secret, admin)
local ping = C:call("ping", {})
if not ping.ok then
showStartupError("SCOREBOARD", "Cannot reach the Reserve Bank",
tostring(ping.err),
{"Verify the bank server is running",
"Verify both modems are enabled (red rings)",
"If using regular wireless modems, both must be within 64 blocks"})
return
end
local cc = nil
local cc_side = nil
if commands and commands.exec then
cc = commands
term.setTextColor(THEME.credit)
print("+ Running on a Command Computer (commands API available)")
else
for _, side in ipairs(peripheral.getNames()) do
local pt = peripheral.getType(side)
if pt == "command_computer" or pt == "command" then
local p = peripheral.wrap(side)
if p and p.exec then cc = p; cc_side = side; break end
end
end
if cc then
term.setTextColor(THEME.credit)
print("+ Found Command Computer at "..cc_side)
end
end
if not cc then
term.setTextColor(THEME.debit)
print("! No Command Computer peripheral found.")
print("! This role requires a Command Computer attached via wired modem,")
print("! OR for this computer to BE a Command Computer.")
term.setTextColor(THEME.ink)
print("")
print("Attach one, add the peripheral (right-click modem), and reboot.")
return
end
term.setTextColor(THEME.ink)
local ok, out = cc.exec("list")
if not ok then
term.setTextColor(THEME.debit)
print("! Command Computer rejected '/list' -- no op authority.")
term.setTextColor(THEME.ink)
return
end
local ping = C:call("ping", {})
if not ping.ok then
term.setTextColor(THEME.debit)
print("! Bank unreachable: "..(ping.err or "?"))
term.setTextColor(THEME.ink)
return
end
term.setTextColor(THEME.credit)
print("+ Bank reachable (v"..(ping.version or "?")..")")
term.setTextColor(THEME.ink)
local function parseOnlinePlayers()
local ok, lines = cc.exec("list")
if not ok or type(lines) ~= "table" or #lines == 0 then return {} end
local line = table.concat(lines, " ")
local names_part = line:match("online:?%s*(.+)$") or line:match(":%s*(.+)$")
if not names_part then return {} end
local players = {}
for name in names_part:gmatch("([%w_]+)") do
if #name >= 3 and #name <= 16 then
table.insert(players, name)
end
end
return players
end
local function scoreboardGet(player, objective)
local ok, lines = cc.exec(string.format(
"scoreboard players get %s %s", player, objective))
if not ok or not lines then return nil end
for _, line in ipairs(lines) do
local n = line:match("has%s+(-?%d+)")
if n then return tonumber(n) end
end
return nil
end
local function getDimension(player)
local ok, lines = cc.exec(string.format(
"data get entity %s Dimension", player))
if not ok or not lines then return nil end
for _, line in ipairs(lines) do
local dim = line:match('"(minecraft:[%w_]+)"')
if dim then return dim end
end
return nil
end
local objectives = {}
local function addObj(name) table.insert(objectives, name) end
addObj("minecraft.custom:minecraft.play_time")
addObj("minecraft.custom:minecraft.time_since_last_death")
addObj("minecraft.custom:minecraft.damage_taken")
for entity, _ in pairs(CFG.EARNINGS_COMBAT_TIER) do
addObj("minecraft.killed:"..entity)
end
for entity, _ in pairs(CFG.EARNINGS_BOSS_BOUNTY) do
addObj("minecraft.killed:"..entity)
end
addObj("minecraft.killed:minecraft.player")
for _, stat in ipairs(CFG.EARNINGS_EXPLORE_STATS) do
addObj(stat)
end
for block, _ in pairs(CFG.EARNINGS_BUILD_MATERIALS) do
addObj("minecraft.used:"..block)
addObj("minecraft.mined:"..block)
end
print("")
term.setTextColor(THEME.gold); print("Scoreboard objective count: "..#objectives)
term.setTextColor(THEME.ink_muted)
print("  (using custom-criterion queries; no /scoreboard add required)")
print("")
local function dispatchNotifications()
local r = C:call("admin_pull_notifications", {limit=50, clear=true}, true)
if not r.ok then
term.setTextColor(THEME.debit)
print("  ! notif pull failed: "..(r.err or "?"))
term.setTextColor(THEME.ink)
return 0
end
local notifs = r.notifications or {}
if #notifs == 0 then return 0 end
local sent = 0
for _, n in ipairs(notifs) do
local msg = (n.message or ""):gsub("\\", "\\\\"):gsub('"', '\\"')
local color = n.color or "white"
local json = string.format(
'[{"text":"[VRB] ","color":"gold","bold":true},{"text":"%s","color":"%s"}]',
msg, color)
local cmd = string.format('tellraw %s %s', n.owner, json)
local ok, _ = cc.exec(cmd)
if ok then sent = sent + 1 end
end
if sent > 0 then
term.setTextColor(THEME.gold)
print(string.format("  > delivered %d/%d notifications", sent, #notifs))
term.setTextColor(THEME.ink)
end
return sent
end
local function takeSnapshotAndSubmit()
local players = parseOnlinePlayers()
if #players == 0 then
term.setTextColor(THEME.ink_muted)
print(os.date("[%H:%M] ").."no players online")
term.setTextColor(THEME.ink)
return
end
local snapshots = {}
local t0 = os.clock()
for _, player in ipairs(players) do
local snap = {}
for _, obj in ipairs(objectives) do
local v = scoreboardGet(player, obj)
if v ~= nil then snap[obj] = v end
end
snap._dimension = getDimension(player)
snapshots[player] = snap
end
local elapsed = os.clock() - t0
term.setTextColor(THEME.ink_muted)
print(string.format(os.date("[%H:%M] ").."read %d players in %.1fs",
#players, elapsed))
term.setTextColor(THEME.ink)
local r = C:call("admin_submit_snapshot",
{snapshots = snapshots, session_sec = CFG.EARNINGS_MIN_SESSION_SEC}, true)
if r.ok then
term.setTextColor(THEME.credit)
print(string.format("  + paid %d players, total %s",
r.players or 0, fmtMoney(r.total_paid or 0)))
term.setTextColor(THEME.ink)
for owner, info in pairs(r.results or {}) do
if info.error then
term.setTextColor(THEME.debit)
print(string.format("    ! %-16s  %s", owner, info.error))
elseif info.skipped then
term.setTextColor(THEME.ink_muted)
print(string.format("    . %-16s  skip (%s)", owner, info.skipped))
elseif info.died then
term.setTextColor(THEME.warn)
print(string.format("    * %-16s  died (streak %d)", owner, info.streak or 0))
elseif info.total > 0 then
term.setTextColor(THEME.credit)
print(string.format("    + %-16s  %-12s  streak %d",
owner, fmtMoney(info.total), info.streak or 0))
end
end
term.setTextColor(THEME.ink)
dispatchNotifications()
else
term.setTextColor(THEME.debit)
print("  ! bank rejected snapshot: "..(r.err or "?"))
term.setTextColor(THEME.ink)
end
end
local function secondsUntilNextTick()
local hour = CFG.EARNINGS_DAILY_TICK_HOUR
if not os.epoch then
return 12 * 3600
end
local now_s = math.floor(os.epoch("utc") / 1000)
local t = os.date("*t", now_s)
if type(t) ~= "table" or not t.year then
return 12 * 3600
end
local today_target = os.time{
year=t.year, month=t.month, day=t.day,
hour=hour, min=0, sec=0,
isdst=t.isdst,
}
if type(today_target) ~= "number" then return 12 * 3600 end
local result
if today_target > now_s then
result = today_target - now_s
else
result = (today_target + 86400) - now_s
end
if result < 0 or result > 90000 then return 12 * 3600 end
return result
end
term.setTextColor(THEME.gold)
print("Daily tick at "..string.format("%02d:00", CFG.EARNINGS_DAILY_TICK_HOUR))
print("Notifications polled every 60s.")
print("Press [T] earnings tick, [V] payroll tick, [D] diagnostics, [Q] quit.")
term.setTextColor(THEME.ink)
local function showDiag()
local r = C:call("admin_diagnostics", {}, true)
print("")
term.setTextColor(THEME.gold)
print("=== Reserve Bank Diagnostics ===")
term.setTextColor(THEME.ink)
if not r.ok then
term.setTextColor(THEME.debit)
print("FAILED to fetch: "..tostring(r.err))
term.setTextColor(THEME.ink); print("")
return
end
print(string.format("Version:           %s", r.version or "?"))
print(string.format("Uptime:            %s",
r.uptime_sec and (math.floor(r.uptime_sec/3600).."h "
..math.floor((r.uptime_sec%3600)/60).."m") or "?"))
print(string.format("Accounts:          %d (%d frozen)",
r.accounts or 0, r.accounts_frozen or 0))
print(string.format("Vanguard members:  %d/%d",
r.vanguard_members or 0, r.vanguard_max or 10))
print(string.format("Money supply:      %s", fmtMoney(r.money_supply or 0)))
print(string.format("Pending multisig:  %d", r.pending_factions or 0))
print(string.format("Farm flags:        %d pending",
r.farm_flags_pending or 0))
print(string.format("Persist failures:  %d", r.persist_failures or 0))
print(string.format("Server errors:     %d", r.server_errors or 0))
print(string.format("Rejected packets:  %d", r.rejected_packets or 0))
if r.last_error_method then
term.setTextColor(THEME.warn)
print("Last server error in: "..r.last_error_method)
term.setTextColor(THEME.ink)
end
if r.last_persist_error then
term.setTextColor(THEME.debit)
print("Last persist error: "..tostring(r.last_persist_error):sub(1, 60))
term.setTextColor(THEME.ink)
end
if r.free_space_bytes and r.free_space_bytes < 1000000 then
term.setTextColor(THEME.warn)
print(string.format("LOW DISK: %d bytes free", r.free_space_bytes))
term.setTextColor(THEME.ink)
end
print("")
end
local function mcDayTick()
local last_day = os.day and os.day("ingame") or 0
local function fire()
local mc_day = os.day and os.day("ingame") or last_day
local r = C:call("admin_run_minecraft_day_tick",
{mc_day = mc_day}, true)
if r.ok then
if r.paid_already then
term.setTextColor(THEME.ink_muted)
print(string.format(os.date("[%H:%M] ")
.."MC day %d: already paid", mc_day))
else
term.setTextColor(THEME.gold)
print(string.format(os.date("[%H:%M] ")
.."MC day %d: paid Vanguard %s (%d), civic %s (%d)",
mc_day,
fmtMoney(r.payroll_total or 0), r.payroll_count or 0,
fmtMoney(r.civic_total or 0), r.civic_count or 0))
end
term.setTextColor(THEME.ink)
else
term.setTextColor(THEME.debit)
print(string.format(os.date("[%H:%M] ")
.."MC day tick failed: %s", r.err or "?"))
term.setTextColor(THEME.ink)
end
end
fire()
while true do
sleep(30)
local d = os.day and os.day("ingame") or 0
if d > last_day then
last_day = d
fire()
end
end
end
parallel.waitForAny(
function()
while true do
local wait = secondsUntilNextTick()
term.setTextColor(THEME.ink_muted)
print(os.date("[%H:%M] ")
.. string.format("next tick in %dh %dm",
math.floor(wait / 3600), math.floor((wait % 3600) / 60)))
term.setTextColor(THEME.ink)
local remaining = wait
while remaining > 0 do
local chunk = math.min(60, remaining)
sleep(chunk)
remaining = remaining - chunk
end
takeSnapshotAndSubmit()
end
end,
function()
while true do
sleep(60)
dispatchNotifications()
end
end,
mcDayTick,
function()
while true do
local _, key = os.pullEvent("key")
if key == keys.t then
print("")
term.setTextColor(THEME.gold)
print("[manual earnings trigger]"); term.setTextColor(THEME.ink)
takeSnapshotAndSubmit()
elseif key == keys.v then
print("")
term.setTextColor(THEME.gold)
print("[manual payroll trigger]"); term.setTextColor(THEME.ink)
local mc_day = os.day and os.day("ingame") or 0
local r = C:call("admin_run_minecraft_day_tick",
{mc_day = mc_day, force = true}, true)
if r.ok then
term.setTextColor(THEME.credit)
print(string.format("paid Vanguard %s (%d), civic %s (%d)",
fmtMoney(r.payroll_total or 0), r.payroll_count or 0,
fmtMoney(r.civic_total or 0), r.civic_count or 0))
term.setTextColor(THEME.ink)
else
term.setTextColor(THEME.debit)
print("Failed: "..(r.err or "?"))
term.setTextColor(THEME.ink)
end
elseif key == keys.d then
showDiag()
elseif key == keys.q then
return
end
end
end
)
end
local function runKeygen()
ensureDir(CFG.KEY_DIR)
local sec = crypto.random_bytes(32)
local adm = crypto.random_bytes(32)
writeAtomic(fs.combine(CFG.KEY_DIR, "server.secret"), sec)
writeAtomic(fs.combine(CFG.KEY_DIR, "admin.key"), adm)
term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.gold); term.clear()
term.setCursorPos(1, 1)
print("============================================================")
print("  VANGUARD RESERVE BANK  \149  KEY GENERATION  \149  v" .. VERSION)
print("============================================================")
term.setTextColor(THEME.ink)
print("\nGenerated two keys (WRITE THEM DOWN ON PAPER):\n")
term.setTextColor(THEME.gold); print("  server.secret")
term.setTextColor(THEME.ink); print("    " .. sec)
term.setTextColor(THEME.gold); print("  admin.key")
term.setTextColor(THEME.ink); print("    " .. adm)
term.setTextColor(THEME.warn)
print("\nIf you lose both keys AND the bank computer is destroyed,")
print("the bank is unrecoverable. Back them up to paper now.\n")
term.setTextColor(THEME.ink_muted)
print("Deploy:")
print("  - Every client needs server.secret in /.vrb/keys/")
print("  - ONLY the admin terminal needs admin.key")
print("  - Transport via floppy disk, not rednet.")
end
local function runInstall()
term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.gold); term.clear()
term.setCursorPos(1, 1)
print("===========================================================")
print("  VANGUARD RESERVE BANK  \149  INSTALLER  \149  v" .. VERSION)
print("===========================================================")
term.setTextColor(THEME.ink)
print("\nPick a role for this computer. It will auto-start on reboot.\n")
term.setTextColor(THEME.gold); print("  Roles")
term.setTextColor(THEME.ink)
print("    server     - central bank (one per server, runs 24/7)")
print("    atm        - branch ATM (needs Advanced Monitor)")
print("    admin      - Vanguard admin terminal (needs admin.key)")
print("    mint       - Reserve Note writer (needs disk drive or printer)")
print("    shop       - player-run vending (needs Advanced Monitor)")
print("    viewer     - public ledger display (needs Advanced Monitor)")
print("    scoreboard - earnings reader (needs Command Computer + admin.key)")
print("")
term.setTextColor(THEME.gold); write("> ")
term.setTextColor(THEME.ink)
local role = read()
local valid = {server=1, atm=1, admin=1, mint=1, shop=1, viewer=1, scoreboard=1}
if not valid[role] then
term.setTextColor(THEME.debit); print("Invalid role."); return
end
writeAtomic("/startup.lua", string.format('shell.run("vrb", "%s")', role))
term.setTextColor(THEME.credit)
print("\nInstalled. /startup.lua will launch '" .. role .. "' on next reboot.")
end
local function runBootstrap()
local BTH = {gold=THEME.gold, ink=THEME.ink, ok=THEME.credit,
err=THEME.debit, warn=THEME.warn, muted=THEME.ink_muted}
local function bcolor(c) term.setTextColor(c) end
local function bok(m) bcolor(BTH.ok); io.write("  + "); bcolor(BTH.ink); print(m) end
local function bbad(m) bcolor(BTH.err); io.write("  X "); bcolor(BTH.ink); print(m) end
local function binfo(m) bcolor(BTH.muted); io.write("  . "); bcolor(BTH.ink); print(m) end
local function bwarn(m) bcolor(BTH.warn); io.write("  ! "); bcolor(BTH.ink); print(m) end
local function bstep(m) print(""); bcolor(BTH.gold); print("[ "..m.." ]"); bcolor(BTH.ink) end
term.setBackgroundColor(THEME.bg); bcolor(BTH.gold); term.clear(); term.setCursorPos(1, 1)
print("=========================================================")
print("  VANGUARD RESERVE BANK -- one-click setup v" .. VERSION)
print("=========================================================")
bcolor(BTH.ink); print("")
local function findFirstByType(t)
for _, n in ipairs(peripheral.getNames()) do
if peripheral.getType(n) == t then return peripheral.wrap(n), n end
end
end
local function hasModem()
for _, n in ipairs(peripheral.getNames()) do
if peripheral.getType(n) == "modem" then
local p = peripheral.wrap(n)
if p and p.isWireless and p.isWireless() then return true end
end
end
end
local function hasMonitor()
for _, n in ipairs(peripheral.getNames()) do
if peripheral.getType(n) == "monitor" then
local p = peripheral.wrap(n)
if p and p.isColor and p.isColor() then return true end
end
end
end
local function hasCommandComputer()
if commands and commands.exec then return true end
for _, n in ipairs(peripheral.getNames()) do
local t = peripheral.getType(n)
if t == "command_computer" or t == "command" then return true end
end
end
local has_secret = fs.exists("/.vrb/keys/server.secret")
local has_admin = fs.exists("/.vrb/keys/admin.key")
local has_db = fs.exists("/.vrb/db.json")
local has_startup = fs.exists("/startup.lua")
if has_startup and has_secret then
local existing_role
local sf = fs.open("/startup.lua", "r")
if sf then
local content = sf.readAll(); sf.close()
existing_role = content:match("'(%w+)'") or content:match('"(%w+)"')
end
bstep("Already configured")
bok("Current role: " .. (existing_role or "?"))
binfo("This computer is set up. On next reboot it will run as '" .. (existing_role or "?") .. "'.")
print("")
bcolor(BTH.gold); print("Quick options:"); bcolor(BTH.ink)
binfo("  [r] reboot now (start the role)")
binfo("  [u] update vrb.lua from the same pastebin (then reboot)")
binfo("  [w] WIPE everything and reset")
binfo("  [q] quit (do nothing)")
while true do
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Pick [r/u/w/q]: ")
local c = (read() or ""):lower():gsub("%s", "")
if c == "" or c == "r" or c == "reboot" then
print("Rebooting in 2..."); sleep(1); print("1..."); sleep(1); os.reboot()
elseif c == "u" or c == "update" then
local code
if fs.exists("/disk/vrb-code.txt") then
local f = fs.open("/disk/vrb-code.txt", "r")
if f then code = (f.readAll() or ""):gsub("%s", ""); f.close() end
end
if not code or code == "" then
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Pastebin code for vrb.lua: ")
code = (read() or ""):gsub("%s", "")
if #code < 6 then bbad("Invalid code."); return end
end
if fs.exists("/vrb") then fs.delete("/vrb") end
binfo("Downloading from pastebin (" .. code .. ")...")
local dl_ok = shell.run("pastebin", "get", code, "/vrb")
if not dl_ok or not fs.exists("/vrb") then
bbad("Pastebin download failed.")
return
end
bok("Updated /vrb (" .. math.floor((fs.getSize("/vrb") or 0)/1024) .. " KB)")
print("")
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Reboot to run the new code? [Y/n]: ")
local r = (read() or ""):lower():gsub("%s", "")
if r == "" or r == "y" or r == "yes" then
print("Rebooting in 2..."); sleep(1); os.reboot()
end
return
elseif c == "w" or c == "wipe" then
bcolor(BTH.warn); io.write("  ! "); bcolor(BTH.ink)
io.write("Type WIPE (uppercase) to confirm: ")
if read() == "WIPE" then
if fs.exists("/.vrb") then fs.delete("/.vrb") end
if fs.exists("/startup.lua") then fs.delete("/startup.lua") end
if fs.exists("/vrb") then fs.delete("/vrb") end
bok("Wiped. Re-run bootstrap to start over.")
return
else
bbad("Cancelled.")
end
elseif c == "q" or c == "quit" then
return
else
bbad("Pick r/u/w/q.")
end
end
end
bstep("Hardware check")
local hw = {
modem=hasModem(), monitor=hasMonitor(),
command=hasCommandComputer(),
drive=findFirstByType("drive") ~= nil,
}
if hw.modem then bok("Wireless/Ender Modem")
else bbad("No wireless modem (need Ender Modem on top)") end
if hw.monitor then bok("Advanced Monitor")
else binfo("No Advanced Monitor") end
if hw.command then bok("Command Computer")
else binfo("No Command Computer") end
if hw.drive then bok("Disk Drive")
else binfo("No Disk Drive") end
if not hw.modem then
bbad("Cannot proceed without a wireless modem.")
binfo("Place an Ender Modem on top of this computer.")
binfo("Right-click it (red ring = enabled), then re-run bootstrap.")
return
end
local drv = findFirstByType("drive")
local floppy_has_keys = drv and drv.isDiskPresent and drv.isDiskPresent()
and fs.exists("/disk/server.secret")
local role
if not floppy_has_keys then
if hw.command then
bbad("This computer has a Command Computer attached.")
bbad("That means it should be a SCOREBOARD, not a new server.")
binfo("Insert the VRB distribution floppy (with keys on it) and re-run.")
binfo("If you really want this to be a fresh server, remove the")
binfo("Command Computer first.")
return
end
if hw.monitor then
bwarn("This computer has a monitor but no keys floppy.")
binfo("If this is the FIRST computer (server), no floppy is needed yet.")
binfo("If this is a FOLLOW-UP computer (admin/atm/viewer), insert the")
binfo("distribution floppy from your server, then re-run.")
print("")
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Continue as new SERVER? [y/N]: ")
local s = (read() or ""):lower():gsub("%s", "")
if s ~= "y" and s ~= "yes" then
binfo("Aborted. Insert the floppy and re-run.")
return
end
end
if not hw.drive then
bbad("This is the first computer (no keys floppy).")
bbad("You need a Disk Drive to receive the new keys.")
binfo("Place a Disk Drive next to this computer, then re-run.")
return
end
role = "server"
bstep("Role: SERVER (first computer)")
elseif hw.command then
role = "scoreboard"
bstep("Role: SCOREBOARD (Command Computer attached)")
elseif hw.monitor then
print("")
bcolor(BTH.gold); print("This computer has a monitor. What role?"); bcolor(BTH.ink)
print("")
print("  [a] admin   - Admin terminal (uses admin.key)")
print("  [t] atm     - Branch ATM (default; press Enter)")
print("  [v] viewer  - Public economy display")
print("")
while not role do
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Press a/t/v (or Enter for atm): ")
local s = (read() or ""):lower():gsub("%s", "")
if s == "" or s == "t" or s == "atm" then role = "atm"
elseif s == "a" or s == "admin" then role = "admin"
elseif s == "v" or s == "viewer" then role = "viewer"
else bbad("Type a, t, v, or Enter.") end
end
bstep("Role: " .. role:upper())
else
bbad("This computer has no monitor and no Command Computer.")
bbad("Add the right hardware, then re-run.")
return
end
bstep("Installing /vrb")
local function isValidVRB(path)
if not fs.exists(path) then return false end
local sz = fs.getSize(path) or 0
if sz < 100000 then return false end
local f = fs.open(path, "r")
if not f then return false end
local first = f.readLine() or ""; f.close()
return first:find("VANGUARD RESERVE BANK", 1, true) ~= nil
end
if isValidVRB("/vrb") then
bok("/vrb already present and valid (" .. math.floor(fs.getSize("/vrb")/1024) .. " KB)")
else
if fs.exists("/vrb") then fs.delete("/vrb") end
local candidates = {}
for _, cdir in ipairs({"/.cache/pastebin", "/cache/pastebin"}) do
if fs.exists(cdir) and fs.isDir(cdir) then
for _, n in ipairs(fs.list(cdir)) do
table.insert(candidates, fs.combine(cdir, n))
end
end
end
local rp = shell.getRunningProgram()
if rp and fs.exists(rp) and rp ~= "/vrb" then
table.insert(candidates, 1, rp)
end
local chosen
for _, c in ipairs(candidates) do
if isValidVRB(c) then chosen = c; break end
end
if chosen then
fs.copy(chosen, "/vrb")
bok("Saved /vrb from " .. chosen .. " (" .. math.floor(fs.getSize("/vrb")/1024) .. " KB)")
else
local code
if fs.exists("/disk/vrb-code.txt") then
local f = fs.open("/disk/vrb-code.txt", "r")
if f then code = (f.readAll() or ""):gsub("%s", ""); f.close() end
if code and code ~= "" then
binfo("Using pastebin code from floppy: " .. code)
end
end
if not code or code == "" then
print("")
bcolor(BTH.gold)
print("This computer needs to download vrb.lua from pastebin.")
bcolor(BTH.ink)
binfo("Enter the 8-character pastebin code from your vrb.lua paste.")
binfo("(The 8 characters at the end of the paste's URL.)")
print("")
while true do
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Pastebin code: ")
code = (read() or ""):gsub("%s", "")
if #code >= 6 and #code <= 16 and code:match("^[%w]+$") then break end
bbad("Invalid format. Should be ~8 alphanumeric characters.")
end
if fs.exists("/disk") then
local f = fs.open("/disk/vrb-code.txt", "w")
if f then
f.write(code); f.close()
bok("Saved code to floppy for follow-up computers.")
end
end
end
binfo("Downloading vrb.lua from pastebin (" .. code .. ")...")
local dl_ok = shell.run("pastebin", "get", code, "/vrb")
if not dl_ok or not fs.exists("/vrb") then
bbad("Pastebin download failed.")
binfo("Possible reasons:")
binfo("  - Wrong pastebin code")
binfo("  - Pastebin rate-limit (wait 60s)")
binfo("  - HTTP API disabled in CC: Tweaked config")
return
end
if not isValidVRB("/vrb") then
local sz = fs.getSize("/vrb") or 0
fs.delete("/vrb")
bbad("Downloaded file is not a valid vrb.lua (" .. sz .. " bytes).")
binfo("Pastebin may have returned an error page, or wrong code.")
return
end
bok("Saved /vrb (" .. math.floor(fs.getSize("/vrb")/1024) .. " KB)")
end
end
if role == "server" then
bstep("Generate keys")
if not fs.exists("/.vrb") then fs.makeDir("/.vrb") end
if not fs.exists("/.vrb/keys") then fs.makeDir("/.vrb/keys") end
local ok_gen, err_gen = pcall(function()
local sec = crypto.random_bytes(32)
local adm = crypto.random_bytes(32)
writeAtomic(fs.combine(CFG.KEY_DIR, "server.secret"), sec)
writeAtomic(fs.combine(CFG.KEY_DIR, "admin.key"), adm)
end)
if not ok_gen then
bbad("Key generation failed: " .. tostring(err_gen))
return
end
if not (fs.exists("/.vrb/keys/server.secret")
and fs.exists("/.vrb/keys/admin.key")) then
bbad("Key files were not written.")
return
end
bok("server.secret generated"); bok("admin.key generated")
bstep("Write distribution floppy")
local d2 = findFirstByType("drive")
if not d2 then
bbad("Disk drive disappeared.")
return
end
if not (d2.isDiskPresent and d2.isDiskPresent()) then
bcolor(BTH.warn); io.write("  ! "); bcolor(BTH.ink)
print("Insert a blank floppy now...")
while true do
local ev = os.pullEvent()
if ev == "disk" then
sleep(0.3)
local d3 = findFirstByType("drive")
if d3 and d3.isDiskPresent and d3.isDiskPresent() then break end
end
end
end
if fs.exists("/disk/server.secret") then fs.delete("/disk/server.secret") end
if fs.exists("/disk/admin.key") then fs.delete("/disk/admin.key") end
fs.copy("/.vrb/keys/server.secret", "/disk/server.secret")
fs.copy("/.vrb/keys/admin.key", "/disk/admin.key")
local mf = fs.open("/disk/vrb-manifest.txt", "w")
if mf then
mf.write("VRB Distribution Floppy\nCreated: "..
os.date("%Y-%m-%d %H:%M:%S").."\n")
mf.close()
end
bok("Floppy ready: server.secret + admin.key")
bstep("Paper backup")
bcolor(BTH.warn)
print("")
print("=========================================================")
print("  WRITE BOTH KEYS DOWN ON PAPER NOW")
print("=========================================================")
bcolor(BTH.ink); print("")
binfo("If the floppy AND this computer are destroyed,")
binfo("paper is the only recovery path.")
print("")
bcolor(BTH.muted); print("server.secret:"); bcolor(BTH.gold)
local f = fs.open("/.vrb/keys/server.secret", "r")
if f then print("  "..f.readAll()); f.close() end
print("")
bcolor(BTH.muted); print("admin.key:"); bcolor(BTH.gold)
f = fs.open("/.vrb/keys/admin.key", "r")
if f then print("  "..f.readAll()); f.close() end
bcolor(BTH.ink); print("")
while true do
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
io.write("Type YES (uppercase) to confirm both written down: ")
local s = read()
if s == "YES" then break end
bbad("Must type YES exactly.")
end
else
bstep("Copy keys from floppy")
if not fs.exists("/.vrb") then fs.makeDir("/.vrb") end
if not fs.exists("/.vrb/keys") then fs.makeDir("/.vrb/keys") end
if not fs.exists("/disk/server.secret") then
bbad("Floppy missing server.secret -- not a VRB distribution floppy.")
return
end
if fs.exists("/.vrb/keys/server.secret") then fs.delete("/.vrb/keys/server.secret") end
fs.copy("/disk/server.secret", "/.vrb/keys/server.secret")
bok("Copied server.secret")
if role == "admin" or role == "scoreboard" then
if not fs.exists("/disk/admin.key") then
bbad("Floppy missing admin.key.")
binfo("Was it wiped? Recreate at server: copy /.vrb/keys/admin.key /disk/admin.key")
return
end
if fs.exists("/.vrb/keys/admin.key") then fs.delete("/.vrb/keys/admin.key") end
fs.copy("/disk/admin.key", "/.vrb/keys/admin.key")
bok("Copied admin.key")
end
end
bstep("Install /startup.lua")
if fs.exists("/startup.lua") then fs.delete("/startup.lua") end
if fs.exists("/startup") then fs.delete("/startup") end
local sf = fs.open("/startup.lua", "w")
if not sf then bbad("Could not write /startup.lua"); return end
sf.write("-- VRB auto-start\nshell.run('/vrb', '"..role.."')\n")
sf.close()
bok("/startup.lua written (auto-runs '"..role.."' on every boot)")
bstep("Setup complete")
bok("Take the floppy with you for the next computer.")
binfo("On every other computer, run the same command you ran here.")
print("")
for i = 3, 1, -1 do
bcolor(BTH.gold); io.write("  > "); bcolor(BTH.ink)
print("Rebooting in "..i.."...")
sleep(1)
end
os.reboot()
end
math.randomseed(os.epoch and os.epoch("utc") or os.time())
if ROLE == "server" then runServer()
elseif ROLE == "atm" then runATM()
elseif ROLE == "admin" then runAdminTouch()
elseif ROLE == "mint" then runMint()
elseif ROLE == "shop" then runShop()
elseif ROLE == "pos" then runPOS()
elseif ROLE == "viewer" then runViewer()
elseif ROLE == "scoreboard" then runScoreboard()
elseif ROLE == "keygen" then runKeygen()
elseif ROLE == "install" then runInstall()
elseif ROLE == "bootstrap" then runBootstrap()
elseif ROLE == "doctor" then
term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.gold); term.clear()
term.setCursorPos(1, 1)
print("== VRB DOCTOR ==")
term.setTextColor(THEME.ink)
print("")
local has_secret = fs.exists("/.vrb/keys/server.secret")
local has_admin = fs.exists("/.vrb/keys/admin.key")
local has_db = fs.exists("/.vrb/db.json")
local has_startup = fs.exists("/startup.lua")
local startup_role = nil
if has_startup then
local sf = fs.open("/startup.lua", "r")
if sf then
local content = sf.readAll(); sf.close()
startup_role = content:match("'(%w+)'") or content:match('"(%w+)"')
end
end
term.setTextColor(THEME.gold); print("Local state:"); term.setTextColor(THEME.ink)
print("  server.secret : " .. (has_secret and "PRESENT" or "MISSING"))
print("  admin.key     : " .. (has_admin and "PRESENT" or "MISSING"))
print("  db.json       : " .. (has_db and "PRESENT" or "MISSING"))
print("  /startup.lua  : " .. (has_startup and ("PRESENT (role: "..(startup_role or "?")..")") or "MISSING"))
print("")
term.setTextColor(THEME.gold); print("Diagnosis:"); term.setTextColor(THEME.ink)
if has_db and has_secret and has_admin then
print("  Looks like the SERVER. ", colors.lime)
if not has_startup then
term.setTextColor(THEME.warn)
print("  startup.lua missing! Booting goes to shell, not server.")
term.setTextColor(THEME.ink)
write("\nWrite /startup.lua now to auto-run as server? (yes): ")
if read() == "yes" then
local f = fs.open("/startup.lua", "w")
f.write("shell.run('/vrb', 'server')\n")
f.close()
term.setTextColor(THEME.gold); print("Done. Type 'reboot' to start server.")
end
else
print("  Server is configured. Type 'reboot' if it's not running.")
end
elseif has_secret and has_admin and not has_db then
print("  Has both keys but no DB. Likely admin or scoreboard.")
if not has_startup then
print("")
print("  Choose role for this computer:")
print("    [a] admin       - touchscreen admin terminal")
print("    [s] scoreboard  - earnings reader (needs Command Computer)")
write("\nRole: ")
local c = read()
local role_name = nil
if c == "a" or c == "admin" then role_name = "admin"
elseif c == "s" or c == "scoreboard" then role_name = "scoreboard" end
if role_name then
local f = fs.open("/startup.lua", "w")
f.write("shell.run('/vrb', '"..role_name.."')\n")
f.close()
term.setTextColor(THEME.gold); print("Done. Type 'reboot' to start.")
end
end
elseif has_secret and not has_admin then
print("  Has only server.secret. Likely an ATM or viewer.")
if not has_startup then
print("")
print("  Choose role for this computer:")
print("    [t] atm     - branch ATM (touchscreen)")
print("    [v] viewer  - public economy dashboard")
write("\nRole: ")
local c = read()
local role_name = nil
if c == "t" or c == "atm" then role_name = "atm"
elseif c == "v" or c == "viewer" then role_name = "viewer" end
if role_name then
local f = fs.open("/startup.lua", "w")
f.write("shell.run('/vrb', '"..role_name.."')\n")
f.close()
term.setTextColor(THEME.gold); print("Done. Type 'reboot' to start.")
end
end
else
term.setTextColor(THEME.warn)
print("  No keys present. This computer hasn't been bootstrapped.")
term.setTextColor(THEME.ink)
print("  Run 'bootstrap' from the bootstrap script you uploaded,")
print("  with the distribution floppy in a disk drive.")
end
else
local has_secret = fs.exists("/.vrb/keys/server.secret")
local has_startup = fs.exists("/startup.lua")
if not has_secret and not has_startup then
runBootstrap()
elseif has_secret and has_startup then
runBootstrap()
else
term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.gold); term.clear()
term.setCursorPos(1, 1)
print("===========================================================")
print("  VANGUARD RESERVE BANK  \149  v" .. VERSION)
print("===========================================================")
term.setTextColor(THEME.ink)
print("")
if has_secret and not has_startup then
term.setTextColor(THEME.warn)
print("Detected: keys are present but no role is auto-running.")
term.setTextColor(THEME.gold)
print("Run 'vrb bootstrap' to fix.")
term.setTextColor(THEME.ink)
else
print("This computer needs a role to run.")
print("")
print("Roles: server | atm | admin | scoreboard | viewer | mint | shop")
print("")
print("To set up: vrb bootstrap")
end
print("")
term.setTextColor(THEME.ink_muted)
print("  Stability. Trust. Prosperity.")
end
end