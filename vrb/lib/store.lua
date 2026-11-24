local ser = require("lib.ser")
local util = require("lib.util")

local byte, find, sub, format = string.byte, string.find, string.sub, string.format
local concat = table.concat

local NSHARD = 16
local TAB = "\t"

local Store = {}
Store.__index = Store
local Coll = {}
Coll.__index = Coll

local function shard_of(id)
  local h = 0
  for i = 1, #id do h = (h * 31 + byte(id, i)) % 65521 end
  return h % NSHARD
end

local function check_id(id)
  if type(id) ~= "string" or id == "" or find(id, "[\t\n\r]") then error("store: bad id " .. tostring(id), 3) end
end

function Coll:get(id) return self.data[id] end
function Coll:count() return self.n end

function Coll:put(id, rec)
  check_id(id)
  if self.data[id] == nil then self.n = self.n + 1 end
  self.data[id] = rec
  self.store:mark(self, id, true)
  return rec
end

function Coll:touch(id)
  if self.data[id] ~= nil then self.store:mark(self, id, true) end
  return self.data[id]
end

function Coll:del(id)
  if self.data[id] == nil then return end
  self.data[id] = nil
  self.n = self.n - 1
  self.store:mark(self, id, false)
end

function Coll:pairs() return pairs(self.data) end

function Coll:ids()
  local o = {}
  for id in pairs(self.data) do o[#o + 1] = id end
  table.sort(o)
  return o
end

function Store:coll(name)
  local c = self.colls[name]
  if not c then
    c = setmetatable({ name = name, data = {}, n = 0, store = self, snap_dirty = {}, lists = self.list_decl[name] }, Coll)
    self.colls[name] = c
  end
  return c
end

function Coll:append(id, field, entry, cap)
  local rec = self.data[id]
  if not rec then return end
  local list = rec[field]
  if not list then list = {}; rec[field] = list end
  local key = "n_" .. field
  local n = (rec[key] or 0) + 1
  rec[key] = n
  entry.i = n
  list[#list + 1] = entry
  if #list > cap then table.remove(list, 1) end
  local ap = self.store.appends
  ap[#ap + 1] = { c = self.name, id = id, f = field, cap = cap, e = entry }
  self.store:mark(self, id, true)
end

function Store:mark(coll, id, present)
  self.dirty[coll.name .. TAB .. id] = present
  self.dirty_n = self.dirty_n + 1
  coll.snap_dirty[shard_of(id)] = true
end

function Store:touch_meta() self.meta_dirty = true end

local function list_dir(p)
  if not fs.exists(p) then return {} end
  return fs.list(p)
end

local function load_snapshots(self)
  local snap = fs.combine(self.dir, "snap")
  for _, name in ipairs(list_dir(snap)) do
    local path = fs.combine(snap, name)
    if name == "meta" then
      local s = util.read_file(path)
      local m = s and ser.decode(s)
      if type(m) == "table" then self.meta = m end
    elseif not name:find("%.tmp$") then
      local cname = name:match("^(.-)%.%d+$")
      if cname then
        local c = self:coll(cname)
        local f = fs.open(path, "r")
        if f then
          while true do
            local line = f.readLine()
            if not line then break end
            local id, body = line:match("^([^\t]+)\t(.*)$")
            if id then
              local rec = ser.decode(body)
              if rec ~= nil then
                if c.data[id] == nil then c.n = c.n + 1 end
                c.data[id] = rec
              end
            end
          end
          f.close()
        end
      end
    end
  end
end

local function journal_files(self)
  local out = {}
  for _, name in ipairs(list_dir(self.dir)) do
    local g = name:match("^journal%.(%d+)$")
    if g then out[#out + 1] = { gen = tonumber(g), path = fs.combine(self.dir, name) } end
  end
  table.sort(out, function(a, b) return a.gen < b.gen end)
  return out
end

local function replay(self, path)
  local f = fs.open(path, "r")
  if not f then return 0 end
  local batch, n_batches, ledger_blocks = {}, 0, {}
  local function apply()
    for _, op in ipairs(batch) do
      if op.k == "P" then
        local c = self:coll(op.c)
        local old = c.data[op.id]
        if old == nil then c.n = c.n + 1 end
        if c.lists then
          for f in pairs(c.lists) do op.rec[f] = old and old[f] or op.rec[f] or {} end
        end
        c.data[op.id] = op.rec
        c.snap_dirty[shard_of(op.id)] = true
      elseif op.k == "A" then
        local c = self:coll(op.c)
        local rec = c.data[op.id]
        if rec then
          local list = rec[op.f]
          if not list then list = {}; rec[op.f] = list end
          local last = list[#list]
          if not last or (op.e.i or 0) > (last.i or 0) then
            list[#list + 1] = op.e
            if #list > op.cap then table.remove(list, 1) end
          end
          c.snap_dirty[shard_of(op.id)] = true
        end
      elseif op.k == "D" then
        local c = self:coll(op.c)
        if c.data[op.id] ~= nil then c.n = c.n - 1 end
        c.data[op.id] = nil
        c.snap_dirty[shard_of(op.id)] = true
      elseif op.k == "M" then
        self.meta = op.rec
      elseif op.k == "L" then
        ledger_blocks[#ledger_blocks + 1] = op
      end
    end
    batch = {}
    n_batches = n_batches + 1
  end
  while true do
    local line = f.readLine()
    if not line then break end
    local k = sub(line, 1, 1)
    if k == "P" then
      local c, id, body = line:match("^P\t([^\t]+)\t([^\t]+)\t(.*)$")
      local rec = c and ser.decode(body)
      if rec ~= nil then batch[#batch + 1] = { k = "P", c = c, id = id, rec = rec } else batch = nil; break end
    elseif k == "A" then
      local c, id, f, cap, body = line:match("^A\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(%d+)\t(.*)$")
      local e = body and ser.decode(body)
      if e then batch[#batch + 1] = { k = "A", c = c, id = id, f = f, cap = tonumber(cap), e = e } else batch = nil; break end
    elseif k == "D" then
      local c, id = line:match("^D\t([^\t]+)\t([^\t]+)$")
      if c then batch[#batch + 1] = { k = "D", c = c, id = id } else batch = nil; break end
    elseif k == "M" then
      local rec = ser.decode(sub(line, 3))
      if rec ~= nil then batch[#batch + 1] = { k = "M", rec = rec } else batch = nil; break end
    elseif k == "L" then
      local seq, prev, body = line:match("^L\t(%d+)\t(%x+)\t(.*)$")
      local text = body and ser.decode(body)
      if text then batch[#batch + 1] = { k = "L", seq = tonumber(seq), prev = prev, text = text } else batch = nil; break end
    elseif k == "C" then
      local want = tonumber(sub(line, 3))
      if want == #batch then apply() else batch = nil; break end
    end
  end
  f.close()
  return n_batches, ledger_blocks
end

function Store.open(dir, opts)
  opts = opts or {}
  local self = setmetatable({
    dir = dir, colls = {}, meta = {}, dirty = {}, dirty_n = 0, meta_dirty = false, gen = 1, appends = {}, list_decl = opts.lists or {},
    compact_bytes = opts.compact_bytes or 98304, min_free = opts.min_free or 32768,
    jbytes = 0, commits = 0, bytes = 0, last_error = nil, compactions = 0, replayed = 0,
  }, Store)
  util.ensure_dir(dir)
  util.ensure_dir(fs.combine(dir, "snap"))
  for _, name in ipairs(list_dir(fs.combine(dir, "snap"))) do
    if name:find("%.tmp$") then pcall(fs.delete, fs.combine(dir, "snap/" .. name)) end
  end
  load_snapshots(self)
  local files = journal_files(self)
  self.pending_ledger = {}
  for _, jf in ipairs(files) do
    local n, blocks = replay(self, jf.path)
    self.replayed = self.replayed + (n or 0)
    for _, b in ipairs(blocks or {}) do self.pending_ledger[#self.pending_ledger + 1] = b end
    if jf.gen >= self.gen then self.gen = jf.gen end
  end
  if #files > 0 then
    self.gen = self.gen + 1
    self.need_compact = true
  end
  self.jpath = fs.combine(dir, "journal." .. self.gen)
  self.jbytes = fs.exists(self.jpath) and fs.getSize(self.jpath) or 0
  return self
end

function Store:free_ok(extra)
  return util.free_space() >= (extra or 0) + self.min_free
end

function Store:commit(extra_lines)
  if self.dirty_n == 0 and #self.appends == 0 and not self.meta_dirty and not (extra_lines and #extra_lines > 0) then return true, 0 end
  local lines, n = {}, 0
  for key, present in pairs(self.dirty) do
    local cname, id = key:match("^([^\t]+)\t(.+)$")
    local c = self.colls[cname]
    if present and c and c.data[id] ~= nil then
      n = n + 1
      lines[n] = "P\t" .. cname .. "\t" .. id .. "\t" .. (c.lists and ser.encode_skip(c.data[id], c.lists) or ser.encode(c.data[id]))
    else
      n = n + 1
      lines[n] = "D\t" .. cname .. "\t" .. id
    end
  end
  for _, ap in ipairs(self.appends) do
    n = n + 1
    lines[n] = "A\t" .. ap.c .. "\t" .. ap.id .. "\t" .. ap.f .. "\t" .. ap.cap .. "\t" .. ser.encode(ap.e)
  end
  if self.meta_dirty then
    n = n + 1
    lines[n] = "M\t" .. ser.encode(self.meta)
  end
  if extra_lines then
    for i = 1, #extra_lines do n = n + 1; lines[n] = extra_lines[i] end
  end
  n = n + 1
  lines[n] = "C\t" .. (n - 1)
  local text = concat(lines, "\n") .. "\n"
  if not self:free_ok(#text) then
    self.last_error = "disk_full"
    return false, "disk_full"
  end
  local f, err = fs.open(self.jpath, "a")
  if not f then self.last_error = "open: " .. tostring(err); return false, self.last_error end
  local ok, werr = pcall(function() f.write(text); f.close() end)
  if not ok then
    pcall(f.close)
    self.last_error = "write: " .. tostring(werr)
    return false, self.last_error
  end
  self.dirty, self.dirty_n, self.meta_dirty, self.appends = {}, 0, false, {}
  self.jbytes = self.jbytes + #text
  self.commits = self.commits + 1
  self.bytes = self.bytes + #text
  self.last_error = nil
  return true, #text
end

function Store:needs_compaction()
  return self.need_compact or self.jbytes > self.compact_bytes
end

local function write_shard(self, c, s)
  local lines, n = {}, 0
  for id, rec in pairs(c.data) do
    if shard_of(id) == s then
      n = n + 1
      lines[n] = id .. "\t" .. ser.encode(rec)
    end
  end
  local path = fs.combine(self.dir, "snap/" .. c.name .. "." .. s)
  if n == 0 then
    if fs.exists(path) then fs.delete(path) end
    return true
  end
  return util.write_atomic(path, concat(lines, "\n") .. "\n")
end

function Store:compact(step)
  if self.compacting then return false end
  self.compacting = true
  self.need_compact = false
  local old_gen = self.gen
  local ok, err = self:commit()
  if not ok then self.compacting = false; return false, err end
  self.gen = old_gen + 1
  self.jpath = fs.combine(self.dir, "journal." .. self.gen)
  self.jbytes = 0
  local failed
  local names = {}
  for name in pairs(self.colls) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local c = self.colls[name]
    for s = 0, NSHARD - 1 do
      if c.snap_dirty[s] then
        local cok, cerr = self:commit()
        if not cok then failed = cerr; break end
        c.snap_dirty[s] = nil
        local wok, werr = write_shard(self, c, s)
        if not wok then c.snap_dirty[s] = true; failed = werr; break end
        if step then step() end
      end
    end
    if failed then break end
  end
  if not failed then
    local cok = self:commit()
    local wok, werr = util.write_atomic(fs.combine(self.dir, "snap/meta"), ser.encode(self.meta))
    if not wok then failed = werr end
  end
  if failed then
    self.compacting = false
    self.last_error = "compact: " .. tostring(failed)
    return false, failed
  end
  for _, jf in ipairs(journal_files(self)) do
    if jf.gen <= old_gen then pcall(fs.delete, jf.path) end
  end
  self.compactions = self.compactions + 1
  self.compacting = false
  return true
end

function Store:stats()
  local accounts = self.colls.accounts and self.colls.accounts.n or 0
  return { commits = self.commits, bytes = self.bytes, journal_bytes = self.jbytes, compactions = self.compactions, accounts = accounts, last_error = self.last_error, dirty = self.dirty_n }
end

return Store
