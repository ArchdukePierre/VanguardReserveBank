local flows = require("ui.flows")
local kit = require("ui.kit")
local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local M = {}

function M.run(ctx)
  local app = ctx.app
  local counts, stamp
  local function load()
    local c, bad = ctx:queue_counts()
    counts = c
    if not c then
      if bad.code == "timeout" then ctx:say("The bank did not answer", "error", 5) else ctx:fail(bad) end
    end
    stamp = util.clock(util.now())
  end
  local function draw(s)
    kit.header(s, "Staff console", "Touch a card")
    local pending = counts and (counts.claims + counts.civic + counts.flags) or false
    local items = {
      { label = "ACCOUNTS", id = "accounts", kind = "primary", sub = "Look up" },
      { label = "DIAGNOSTICS", short = "DIAG", id = "diag", kind = "secondary", sub = "Health" },
      { label = "VANGUARD", id = "vanguard", kind = "primary", sub = "Ranks, pay" },
      { label = "CIVIC JOBS", id = "jobs", kind = "primary", sub = "Jobs, pay" },
      { label = "WORK ORDERS", short = "ORDERS", id = "orders", kind = "primary", sub = "Bounties" },
      { label = "REVIEW QUEUE", short = "REVIEW", id = "queue", kind = (pending and pending > 0) and "success" or "primary", badge = pending },
      { label = "POLICY", id = "policy", kind = "primary", sub = "Rates, tax" },
      { label = "LEDGER", id = "ledger", kind = "secondary", sub = "Recent" },
      { label = "MORE", id = "more", kind = "secondary", sub = "Tools" },
    }
    local used = Core.grid(s, items, 5, s.h - 4)
    if counts and s.h >= 30 then
      s:text(2, 5 + used + 1, util.ellipsis(string.format("Waiting: %.0f claims, %.0f applications, %.0f farm flags", counts.claims, counts.civic, counts.flags), s.w - 2), theme.muted)
    end
    kit.footer(s, stamp and ("Loaded " .. stamp) or "Not loaded")
    kit.button(s, s.w - 10, s.h, 9, "REFRESH", "refresh", { kind = "secondary" })
  end
  local function open(id)
    local ok, err = pcall(function() require("roles.admin." .. id).run(ctx) end)
    ctx.pending = nil
    if not ok and err == "Terminated" then error(err, 0) end
    if not ok and err ~= Core.IDLE then
      print("admin: " .. tostring(err))
      flows.message(app, "Something went wrong", { tostring(err) }, "error")
    end
  end
  load()
  ctx:show(draw)
  while true do
    local kind, r = app:wait()
    if kind == "tap" then
      if r.id == "refresh" then
        load()
      else
        open(r.id)
        if r.id == "queue" then load() end
      end
      ctx:show(draw)
    end
  end
end

return M
