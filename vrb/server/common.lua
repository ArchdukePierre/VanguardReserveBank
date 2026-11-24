local util = require("lib.util")

local C = {}

function C.fail(msg, code) return { ok = false, err = msg, code = code } end

function C.memo(v) if type(v) == "string" and #v <= 200 then return v end end

function C.notify(bank, owner, channel, color, message)
  local key = owner:lower()
  local subs = bank.db:coll("subs")
  local s = subs:get(key)
  if not s then
    s = {}
    for _, ch in ipairs(bank.cfg.notify.channels) do s[ch[1]] = ch[2] and true or false end
    subs:put(key, s)
  end
  if not s[channel] then return false end
  local box = bank.db:coll("outbox")
  local seq = (bank.meta.outbox_seq or 0) + 1
  bank.meta.outbox_seq = seq
  bank:meta_touch()
  box:put(string.format("%012d", seq), { owner = owner, channel = channel, color = color or "white", message = message, t = util.now() })
  local max = bank.cfg.notify.outbox_max
  if box:count() > max then
    local ids = box:ids()
    for i = 1, #ids - max do box:del(ids[i]) end
  end
  return true
end

function C.subs_for(bank, key)
  local subs = bank.db:coll("subs")
  local s = subs:get(key)
  if not s then
    s = {}
    for _, ch in ipairs(bank.cfg.notify.channels) do s[ch[1]] = ch[2] and true or false end
    subs:put(key, s)
  end
  return s
end

function C.cap(list, n)
  while #list > n do list[#list] = nil end
  return list
end

function C.sorted(list, key, desc)
  table.sort(list, function(a, b)
    if desc then return a[key] > b[key] end
    return a[key] < b[key]
  end)
  return list
end

return C
