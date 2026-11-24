local Store = require("lib.store")
local Ledger = require("lib.ledger")
local ser = require("lib.ser")

local DB = {}
DB.__index = DB

function DB.open(dir, opts)
  opts = opts or {}
  opts.lists = opts.lists or { accounts = { hist = true } }
  local store = Store.open(dir, opts)
  local ledger = Ledger.open(dir, store.meta, opts)
  local recovered = 0
  if store.pending_ledger and #store.pending_ledger > 0 then
    recovered = ledger:recover(store.pending_ledger)
    if recovered > 0 then ledger:load_tail() end
    store.pending_ledger = {}
  end
  return setmetatable({ store = store, ledger = ledger, meta = store.meta, recovered = recovered, failures = 0 }, DB)
end

function DB:coll(name) return self.store:coll(name) end

function DB:log(kind, fields) return self.ledger:add(kind, fields) end

function DB:dirty() return self.store.dirty_n > 0 or #self.store.appends > 0 or self.store.meta_dirty or self.ledger:pending() > 0 end

function DB:commit()
  local ledger, store = self.ledger, self.store
  local pending = ledger.buf
  local text, last, prev = ledger:seal()
  local extra
  if text then
    extra = { "L\t" .. pending[1].n .. "\t" .. prev .. "\t" .. ser.encode(text) }
    store.meta_dirty = true
  end
  local ok, err = store:commit(extra)
  if not ok then
    if text then
      ledger.buf = pending
      self.meta.ledger_head = prev
    end
    self.failures = self.failures + 1
    return false, err
  end
  if text then
    if not ledger:write(text, last, prev) then ledger.write_failed = (ledger.write_failed or 0) + 1 end
  end
  return true
end

function DB:needs_compaction() return self.store:needs_compaction() end
function DB:compact(step) return self.store:compact(step) end
function DB:writable() return self.store:free_ok(16384) end

return DB
