local App = require("ui.app")
local flows = require("ui.flows")
local Client = require("lib.client")

local unpack = table.unpack or unpack

local Core = {}
local Ctx = {}

Core.IDLE = setmetatable({}, { __tostring = function() return "idle timeout" end })
Core.LOST = setmetatable({}, { __tostring = function() return "session ended" end })

local READS = { profile = true, history = true, balance = true, self_audit = true, ping = true, lookup = true, item_rates = true,
  public_stats = true, public_ledger_tail = true, get_shop = true, signout = true }

local function is_read(method)
  return READS[method] or method:find("^list_") or method:find("^my_")
end

local function find_one(kind)
  local found, found_name
  peripheral.find(kind, function(name, obj)
    if not found then found, found_name = obj, name end
    return true
  end)
  return found, found_name
end

function Ctx:find(kind)
  return find_one(kind)
end

function Ctx:beep(kind)
  local sp = self.speaker
  if not sp then return end
  if kind == "error" then pcall(sp.playNote, "bass", 1, 4)
  elseif kind == "ok" then pcall(sp.playNote, "bell", 1, 18) end
end

function Ctx:say(title, lines, kind)
  self:beep(kind)
  flows.message(self.app, title, lines, kind)
end

function Ctx:toast(text, kind)
  self:beep(kind)
  self.app:notify(text, kind or "info", 3)
end

function Ctx:fail(res, title, write)
  local lines
  if res.code == "timeout" then
    lines = { "The bank is not responding.", write and "Check HISTORY before you try again." or "Try again in a moment." }
  else
    lines = { res.err or "Something went wrong." }
  end
  self:say(title or "Sorry", lines, "error")
end

function Ctx:pub(method, params)
  local res = self.client:call(method, params or {})
  self.touched = os.clock()
  return res
end

function Ctx:call(method, params)
  params = params or {}
  params.session = self.session
  local res = self.client:call(method, params)
  self.touched = os.clock()
  if res.code == "no_session" and self.session then error(Core.LOST, 0) end
  if res.ok and not is_read(method) then self.dirty = true end
  return res
end

function Ctx:load_ping()
  local res = self:pub("ping", {})
  if res.ok then self.ping = res end
  return res.ok
end

function Ctx:rate(name)
  local pol = self.ping and self.ping.policy
  return pol and pol[name] or 0
end

function Ctx:refresh()
  local res = self:call("profile", {})
  if res.ok then
    self.profile, self.dirty = res.profile, false
    return true
  end
  self:toast(res.err or "Could not update your balances", "error")
  return false
end

function Ctx:fresh()
  if self.dirty or not self.profile then return self:refresh() end
  return true
end

function Ctx:ready()
  if not self:fresh() then return false end
  if not self.ping and not self:load_ping() then
    self:say("Sorry", { "The bank is not answering.", "Try again in a moment." }, "error")
    return false
  end
  return true
end

function Ctx:checking()
  local c = self.profile and self.profile.checking
  return c and c.balance or 0
end

function Ctx:savings()
  local s = self.profile and self.profile.savings
  return s and s.balance or 0, s and s.young_cents or 0
end

function Ctx:begin(res)
  self.session, self.account = res.session, res.account
  self.profile, self.dirty = nil, true
  self:load_ping()
end

function Ctx:reset()
  self.session, self.account, self.profile, self.dirty, self.resting = nil, nil, nil, false, false
  self.app.toast = nil
end

function Ctx:signout()
  local sid = self.session
  self:reset()
  if sid then self.client:call("signout", { session = sid }, { timeout = 2, retries = 1 }) end
end

function Ctx:print_lines(title, lines)
  local p = self:find("printer")
  if not p then return false, "No printer is attached." end
  local ok, err = pcall(function()
    if p.getPaperLevel() < 1 then error("The printer is out of paper.", 0) end
    if p.getInkLevel() < 1 then error("The printer is out of ink.", 0) end
    if not p.newPage() then error("The printer is busy.", 0) end
    p.setPageTitle(title)
    local w, h = p.getPageSize()
    for i, line in ipairs(lines) do
      if i > h then break end
      p.setCursorPos(1, i)
      p.write(line:sub(1, w))
    end
    p.endPage()
  end)
  if not ok then return false, tostring(err) end
  return true
end

function Core.new()
  local client, why = Client.new({})
  if not client then return nil, why end
  local mon, mon_name = find_one("monitor")
  local app = App.new({ surface = mon, name = mon_name, idle = 60, min_w = 39, min_h = 19 })
  local ctx = setmetatable({
    app = app, client = client, idle = 60, touched = os.clock(), is_monitor = mon ~= nil, dirty = false,
    branch = (os.getComputerLabel() or ("ATM" .. os.getComputerID())):sub(1, 64),
    speaker = find_one("speaker"),
  }, { __index = Ctx })
  local raw_wait = App.wait
  function app:wait(o)
    o = o or {}
    local opts = { events = o.events }
    local saved = self.idle
    if ctx.resting then
      self.idle = nil
    else
      opts.timeout = math.max(0.1, ctx.idle - (os.clock() - ctx.touched))
    end
    local r = { raw_wait(self, opts) }
    self.idle = saved
    if r[1] == "timeout" then error(Core.IDLE, 0) end
    ctx.touched = os.clock()
    return unpack(r)
  end
  return ctx
end

return Core
