local net = require("lib.net")
local crypto = require("lib.crypto")
local cfgmod = require("lib.cfg")
local util = require("lib.util")

local Client = {}
Client.__index = Client

function Client.new(opts)
  opts = opts or {}
  local c = cfgmod.load()
  local self = setmetatable({
    secret = opts.secret or cfgmod.read_key("server.secret"),
    admin = opts.admin,
    channel = opts.channel or cfgmod.channel(c),
    reply = net.reply_channel(),
    window = c.net.rpc_window,
    timeout = opts.timeout or c.net.timeout,
    retries = opts.retries or c.net.retries,
    seen = {},
    calls = 0,
  }, Client)
  if not self.secret then return nil, "server.secret is missing" end
  local m = net.find_modem(opts.modem or c.net.modem)
  if not m then return nil, "no modem attached" end
  self.modem = m
  m.open(self.reply)
  return self
end

function Client:call(method, params, o)
  o = o or {}
  self.calls = self.calls + 1
  local id = net.nonce()
  local payload = { i = id, m = method, p = params or {} }
  if o.admin then
    if not self.admin then return { ok = false, err = "This terminal has no admin key", code = "no_admin" } end
    local ts = util.now()
    payload.ts = ts
    payload.a = crypto.hmac(self.admin, id .. ":" .. method .. ":" .. ts)
  end
  local timeout = o.timeout or self.timeout
  for attempt = 1, o.retries or self.retries do
    self.modem.transmit(self.channel, self.reply, net.seal(self.secret, payload, true))
    local tid = os.startTimer(timeout)
    while true do
      local ev, a, b, c, d = os.pullEvent()
      if ev == "modem_message" then
        if b == self.reply then
          local res = net.open_env(self.secret, d, self.window, self.seen)
          if res and res.i == id then
            os.cancelTimer(tid)
            net.prune_seen(self.seen, self.window)
            return res.r
          end
        end
      elseif ev == "timer" and a == tid then
        break
      end
    end
    timeout = timeout + 1
  end
  return { ok = false, err = "The bank is not responding", code = "timeout" }
end

function Client:open_broadcast()
  self.modem.open(self.channel + 1)
end

function Client:wait_broadcast(timeout)
  local tid = timeout and os.startTimer(timeout) or nil
  while true do
    local ev, a, b, c, d = os.pullEvent()
    if ev == "modem_message" and b == self.channel + 1 then
      local p = net.open_env(self.secret, d, self.window, self.seen)
      if p then
        if tid then os.cancelTimer(tid) end
        net.prune_seen(self.seen, self.window)
        return p
      end
    elseif ev == "timer" and a == tid then
      return nil
    end
  end
end

return Client
