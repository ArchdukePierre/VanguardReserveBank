local ser = require("lib.ser")
local crypto = require("lib.crypto")
local util = require("lib.util")

local concat, sub = table.concat, string.sub
local ZERO = string.rep("0", 32)

local Ledger = {}
Ledger.__index = Ledger

function Ledger.open(dir, meta, opts)
  opts = opts or {}
  local self = setmetatable({
    dir = dir, meta = meta, buf = {}, tail = {}, tail_max = opts.tail or 400,
    max_bytes = opts.max_bytes or 160 * 1024, keep_bytes = opts.keep_bytes or 320 * 1024,
    path = fs.combine(dir, "ledger.log"), arch = fs.combine(dir, "ledger"),
    bytes = 0, blocks_written = 0,
  }, Ledger)
  util.ensure_dir(self.arch)
  meta.ledger_seq = meta.ledger_seq or 0
  meta.ledger_head = meta.ledger_head or ZERO
  self.bytes = fs.exists(self.path) and fs.getSize(self.path) or 0
  self:load_tail()
  return self
end

function Ledger:load_tail()
  if not fs.exists(self.path) then return end
  local s = util.read_file(self.path) or ""
  local last_seq = 0
  local tail = {}
  local pos = 1
  local len = #s
  while pos <= len do
    local e = s:find("\n", pos, true) or len + 1
    local line = sub(s, pos, e - 1)
    pos = e + 1
    local seq0, count = line:match("^#(%d+)|(%d+)|")
    if seq0 then
      seq0, count = tonumber(seq0), tonumber(count)
      local n = 0
      while n < count and pos <= len do
        local e2 = s:find("\n", pos, true) or len + 1
        local entry = ser.decode(sub(s, pos, e2 - 1))
        pos = e2 + 1
        n = n + 1
        if entry then
          entry.n = seq0 + n - 1
          tail[#tail + 1] = entry
          if #tail > self.tail_max then table.remove(tail, 1) end
        end
      end
      last_seq = seq0 + count - 1
    end
  end
  self.tail = tail
  self.file_seq = last_seq
end

function Ledger:last_file_seq() return self.file_seq or 0 end

function Ledger:add(kind, fields)
  local e = fields or {}
  e.type = kind
  e.t = e.t or util.now()
  self.meta.ledger_seq = self.meta.ledger_seq + 1
  e.n = self.meta.ledger_seq
  self.buf[#self.buf + 1] = e
  self.tail[#self.tail + 1] = e
  if #self.tail > self.tail_max then table.remove(self.tail, 1) end
  return e
end

function Ledger:pending() return #self.buf end

function Ledger:seal()
  local n = #self.buf
  if n == 0 then return nil end
  local lines = {}
  for i = 1, n do
    local e = self.buf[i]
    local seq = e.n
    e.n = nil
    lines[i] = ser.encode(e)
    e.n = seq
  end
  local first = self.buf[1].n
  local body = concat(lines, "\n")
  local hash = sub(crypto.sha256(self.meta.ledger_head .. "\n" .. body), 1, 32)
  local prev = self.meta.ledger_head
  self.meta.ledger_head = hash
  self.buf = {}
  return "#" .. first .. "|" .. n .. "|" .. hash .. "\n" .. body .. "\n", first + n - 1, prev
end

function Ledger:rotate()
  if not fs.exists(self.path) then return end
  local name = fs.combine(self.arch, string.format("ledger-%012.0f.log", self.meta.ledger_seq))
  pcall(fs.move, self.path, name)
  self.bytes = 0
  local files = {}
  for _, n in ipairs(fs.list(self.arch)) do
    if n:match("^ledger%-%d+%.log$") then files[#files + 1] = n end
  end
  table.sort(files)
  local total = 0
  for _, n in ipairs(files) do total = total + fs.getSize(fs.combine(self.arch, n)) end
  while #files > 1 and total > self.keep_bytes do
    local old = table.remove(files, 1)
    total = total - fs.getSize(fs.combine(self.arch, old))
    pcall(fs.delete, fs.combine(self.arch, old))
  end
end

function Ledger:write(text, last_seq, prev_head)
  if self.bytes > self.max_bytes then self:rotate() end
  local fresh = not fs.exists(self.path)
  local f = fs.open(self.path, fresh and "w" or "a")
  if not f then return false end
  local ok = pcall(function()
    if fresh then f.write("@" .. prev_head .. "\n") end
    f.write(text)
    f.close()
  end)
  if not ok then pcall(f.close); return false end
  self.bytes = self.bytes + #text
  self.file_seq = last_seq
  self.blocks_written = self.blocks_written + 1
  return true
end

function Ledger:recover(blocks)
  local wrote = 0
  for _, b in ipairs(blocks) do
    local count = tonumber(b.text:match("^#%d+|(%d+)|")) or 0
    local last = b.seq + count - 1
    if last > (self.file_seq or 0) then
      if self:write(b.text, last, b.prev) then wrote = wrote + 1 end
    end
  end
  return wrote
end

function Ledger:recent(limit, filter)
  local out = {}
  for i = #self.tail, 1, -1 do
    local e = self.tail[i]
    if not filter or filter(e) then
      out[#out + 1] = e
      if #out >= limit then break end
    end
  end
  local rev = {}
  for i = #out, 1, -1 do rev[#rev + 1] = out[i] end
  return rev
end

local function verify_file(path, state, step)
  local f = fs.open(path, "r")
  if not f then return false, "cannot read " .. path end
  local first = true
  while true do
    local line = f.readLine()
    if not line then break end
    if sub(line, 1, 1) == "@" then
      if state.prev == nil then state.prev = sub(line, 2) end
      if state.prev ~= sub(line, 2) then f.close(); return false, "broken link at " .. path end
    else
      local seq0, count, hash = line:match("^#(%d+)|(%d+)|(%x+)$")
      if not seq0 then f.close(); return false, "bad header near entry " .. tostring(state.entries) end
      count = tonumber(count)
      local body = {}
      for i = 1, count do
        local l = f.readLine()
        if not l then f.close(); return false, "truncated block at seq " .. seq0 end
        body[i] = l
      end
      local prev = state.prev or ZERO
      local want = sub(crypto.sha256(prev .. "\n" .. concat(body, "\n")), 1, 32)
      if want ~= hash then f.close(); return false, "hash mismatch at seq " .. seq0 end
      state.prev = hash
      state.entries = state.entries + count
      state.blocks = state.blocks + 1
      state.last_seq = tonumber(seq0) + count - 1
      if state.first_seq == nil then state.first_seq = tonumber(seq0) end
      if step and state.blocks % 40 == 0 then step() end
    end
  end
  f.close()
  return true
end

function Ledger:verify(step)
  local files = {}
  if fs.exists(self.arch) then
    for _, n in ipairs(fs.list(self.arch)) do
      if n:match("^ledger%-%d+%.log$") then files[#files + 1] = fs.combine(self.arch, n) end
    end
  end
  table.sort(files)
  if fs.exists(self.path) then files[#files + 1] = self.path end
  local state = { entries = 0, blocks = 0 }
  for _, p in ipairs(files) do
    local ok, err = verify_file(p, state, step)
    if not ok then return false, err, state end
  end
  if state.blocks > 0 and state.prev ~= self.meta.ledger_head then
    return false, "head mismatch (file " .. tostring(state.prev) .. " meta " .. tostring(self.meta.ledger_head) .. ")", state
  end
  return true, nil, state
end

function Ledger:verify_tail(max_bytes)
  if not fs.exists(self.path) then return true end
  local size = fs.getSize(self.path)
  if size == 0 then return true end
  local f = fs.open(self.path, "r")
  if not f then return false, "cannot read ledger" end
  local last
  while true do
    local line = f.readLine()
    if not line then break end
    local hash = line:match("^#%d+|%d+|(%x+)$")
    if hash then last = hash end
  end
  f.close()
  if last and last ~= self.meta.ledger_head then return false, "head mismatch" end
  return true
end

return Ledger
