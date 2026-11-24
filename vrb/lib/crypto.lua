local crypto = {}

local band, bor, bxor = bit32.band, bit32.bor, bit32.bxor
local rrotate, rshift = bit32.rrotate, bit32.rshift
local byte, char, format, rep, sub = string.byte, string.char, string.format, string.rep, string.sub
local concat, unpack = table.concat, table.unpack or unpack
local MOD = 4294967296

local K = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

crypto.compressions = 0

local W = {}

local function compress(H, s, o)
  crypto.compressions = crypto.compressions + 1
  local w = W
  for i = 1, 16 do
    local b1, b2, b3, b4 = byte(s, o + 1, o + 4)
    o = o + 4
    w[i] = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
  end
  for i = 17, 64 do
    local a, b = w[i - 15], w[i - 2]
    w[i] = (w[i - 16] + bxor(rrotate(a, 7), rrotate(a, 18), rshift(a, 3)) + w[i - 7]
      + bxor(rrotate(b, 17), rrotate(b, 19), rshift(b, 10))) % MOD
  end
  local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
  for i = 1, 64 do
    local t1 = h + bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25)) + bxor(g, band(e, bxor(f, g))) + K[i] + w[i]
    local t2 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22)) + bxor(band(a, b), band(c, bxor(a, b)))
    h, g, f = g, f, e
    e = (d + t1) % MOD
    d, c, b = c, b, a
    a = (t1 + t2) % MOD
  end
  H[1] = (H[1] + a) % MOD; H[2] = (H[2] + b) % MOD; H[3] = (H[3] + c) % MOD; H[4] = (H[4] + d) % MOD
  H[5] = (H[5] + e) % MOD; H[6] = (H[6] + f) % MOD; H[7] = (H[7] + g) % MOD; H[8] = (H[8] + h) % MOD
end

local function init()
  return { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
end

local function len_bytes(bits)
  local hi = math.floor(bits / MOD)
  local lo = bits % MOD
  return char(band(rshift(hi, 24), 255), band(rshift(hi, 16), 255), band(rshift(hi, 8), 255), band(hi, 255),
    band(rshift(lo, 24), 255), band(rshift(lo, 16), 255), band(rshift(lo, 8), 255), band(lo, 255))
end

local function finish(H, msg, prefix)
  local len = #msg
  local full = len - len % 64
  for o = 0, full - 64, 64 do compress(H, msg, o) end
  local tail = sub(msg, full + 1) .. "\128"
  local n = #tail
  tail = tail .. rep("\0", n <= 56 and 56 - n or 120 - n) .. len_bytes((len + (prefix or 0)) * 8)
  compress(H, tail, 0)
  if #tail > 64 then compress(H, tail, 64) end
  return H
end

local function words_hex(H)
  return format("%08x%08x%08x%08x%08x%08x%08x%08x", H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8])
end

local function words_raw(H)
  local o = {}
  for i = 1, 8 do
    local x = H[i]
    o[i] = char(band(rshift(x, 24), 255), band(rshift(x, 16), 255), band(rshift(x, 8), 255), band(x, 255))
  end
  return concat(o)
end

function crypto.sha256(msg) return words_hex(finish(init(), msg, 0)) end
function crypto.sha256_raw(msg) return words_raw(finish(init(), msg, 0)) end

local keycache, keycount = {}, 0

local function normalize_key(key)
  if #key == 64 and key:find("^%x+$") then
    key = (key:gsub("%x%x", function(x) return char(tonumber(x, 16)) end))
  end
  if #key > 64 then key = crypto.sha256_raw(key) end
  if #key < 64 then key = key .. rep("\0", 64 - #key) end
  return key
end

local function key_state(key)
  local ks = keycache[key]
  if ks then return ks end
  local k = normalize_key(key)
  local ip, op = {}, {}
  for i = 1, 64 do
    local c = byte(k, i)
    ip[i] = char(bxor(c, 0x36))
    op[i] = char(bxor(c, 0x5c))
  end
  local hi, ho = init(), init()
  compress(hi, concat(ip), 0)
  compress(ho, concat(op), 0)
  ks = { hi, ho }
  if keycount > 64 then keycache, keycount = {}, 0 end
  keycache[key] = ks
  keycount = keycount + 1
  return ks
end

local function hmac_words(key, msg)
  local ks = key_state(key)
  local inner = finish({ unpack(ks[1]) }, msg, 64)
  local outer = { unpack(ks[2]) }
  return finish(outer, words_raw(inner), 64)
end

function crypto.hmac(key, msg) return words_hex(hmac_words(key, msg)) end
function crypto.hmac_raw(key, msg) return words_raw(hmac_words(key, msg)) end

function crypto.equal(a, b)
  if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then return false end
  local d = 0
  for i = 1, #a do d = bor(d, bxor(byte(a, i), byte(b, i))) end
  return d == 0
end

local ctr = {}
for i = 0, 255 do ctr[i] = char(i) end

function crypto.stream(key, nonce, data)
  local n = #data
  if n == 0 then return "" end
  local sk = crypto.hmac_raw(key, "enc" .. nonce)
  local out = {}
  local blocks = math.floor((n + 31) / 32)
  for b = 0, blocks - 1 do
    local pad = crypto.sha256_raw(sk .. ctr[band(rshift(b, 24), 255)] .. ctr[band(rshift(b, 16), 255)] .. ctr[band(rshift(b, 8), 255)] .. ctr[band(b, 255)])
    local i = b * 32 + 1
    local j = i + 31
    if j > n then j = n end
    local d = { byte(data, i, j) }
    local p = { byte(pad, 1, j - i + 1) }
    for x = 1, #d do d[x] = bxor(d[x], p[x]) end
    out[b + 1] = char(unpack(d))
  end
  return concat(out)
end

local pool, counter = nil, 0
local entropy = {}

function crypto.add_entropy(v)
  entropy[#entropy + 1] = tostring(v)
  if #entropy > 16 then table.remove(entropy, 1) end
  pool = nil
end

local function reseed()
  local parts = { tostring(os.epoch("utc")), tostring(os.getComputerID and os.getComputerID() or 0), tostring(os.clock()), tostring({}), concat(entropy, ",") }
  pool = crypto.sha256_raw(concat(parts, ":"))
  counter = 0
end

function crypto.random_hex(n)
  if not pool then reseed() end
  local out, have = {}, 0
  while have < n do
    counter = counter + 1
    local block = crypto.sha256_raw(pool .. tostring(counter) .. tostring(os.epoch("utc")))
    pool = crypto.sha256_raw(pool .. block)
    local hex = format(rep("%02x", 32), byte(block, 1, 32))
    out[#out + 1] = hex
    have = have + 64
  end
  return sub(concat(out), 1, n)
end

function crypto.random_int(lo, hi)
  local span = hi - lo + 1
  local r = tonumber(crypto.random_hex(12), 16)
  return lo + r % span
end

function crypto.self_test()
  if crypto.sha256("abc") ~= "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" then return false, "sha256" end
  local k = rep(char(0x0b), 20)
  if crypto.hmac(k, "Hi There") ~= "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7" then return false, "hmac" end
  local long = rep("a", 1000)
  if crypto.sha256(long) ~= "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3" then return false, "sha256 long" end
  local m = crypto.stream("k", "n", "hello world")
  if crypto.stream("k", "n", m) ~= "hello world" then return false, "stream" end
  return true
end

return crypto
