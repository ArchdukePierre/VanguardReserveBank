local ser = {}

local format, gsub, find, concat = string.format, string.gsub, string.find, table.concat
local floor, huge = math.floor, math.huge
local tostring, type, pairs, next, tonumber = tostring, type, pairs, next, tonumber

local function esc(c) return format("\\%03d", c:byte()) end

local function enc_string(s)
  if find(s, '[%c"\\]') then s = gsub(s, '[%c"\\]', esc) end
  return '"' .. s .. '"'
end

local function enc_number(n)
  if n ~= n then return "(0/0)" end
  if n == huge then return "(1/0)" end
  if n == -huge then return "(-1/0)" end
  if n == floor(n) and n > -9007199254740992 and n < 9007199254740992 then return format("%.0f", n) end
  local s = format("%.14g", n)
  if tonumber(s) ~= n then s = format("%.17g", n) end
  return s
end

local encode

local function enc_table(t, out, depth, skip)
  if depth > 32 then error("ser: table too deep", 0) end
  local n = #t
  local o = out
  o[#o + 1] = "{"
  local first = true
  for i = 1, n do
    if not first then o[#o + 1] = "," end
    first = false
    encode(t[i], o, depth + 1)
  end
  for k, v in pairs(t) do
    local tk = type(k)
    if not (tk == "number" and k >= 1 and k <= n and k == floor(k)) and not (skip and skip[k]) then
      if not first then o[#o + 1] = "," end
      first = false
      if tk == "string" and find(k, "^[%a_][%w_]*$") and not ser.reserved[k] then
        o[#o + 1] = k
      else
        o[#o + 1] = "["
        encode(k, o, depth + 1)
        o[#o + 1] = "]"
      end
      o[#o + 1] = "="
      encode(v, o, depth + 1)
    end
  end
  o[#o + 1] = "}"
end

ser.reserved = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%a+") do ser.reserved[w] = true end

function encode(v, out, depth)
  local t = type(v)
  if t == "string" then out[#out + 1] = enc_string(v)
  elseif t == "number" then out[#out + 1] = enc_number(v)
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "table" then enc_table(v, out, depth)
  elseif t == "nil" then out[#out + 1] = "nil"
  else error("ser: cannot encode " .. t, 0) end
end

function ser.encode(v)
  local out = {}
  encode(v, out, 0)
  return concat(out)
end

function ser.encode_skip(t, skip)
  local out = {}
  enc_table(t, out, 0, skip)
  return concat(out)
end

local EMPTY_ENV = {}

function ser.decode(s)
  if type(s) ~= "string" then return nil, "not a string" end
  local fn, err = load("return " .. s, "=ser", "t", {})
  if not fn then return nil, err end
  local ok, res = pcall(fn)
  if not ok then return nil, res end
  return res
end

return ser
