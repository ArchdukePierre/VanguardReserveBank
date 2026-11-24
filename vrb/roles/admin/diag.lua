local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local T = theme
local M = {}

local function int(n) return util.int(n or 0) end

local function build(d)
  local rows, warnings = {}, {}
  local function add(label, value, color, note)
    rows[#rows + 1] = { left = label, right = tostring(value), rcolor = color or T.ink, color = color and color or nil }
    if color and note then warnings[#warnings + 1] = note end
  end
  local free, cap = d.free_space_bytes, d.disk_capacity
  local disk_color
  if type(free) == "number" and free ~= math.huge then
    if free < 65536 or not d.writable then disk_color = T.bad
    elseif free < 262144 or (cap and cap > 0 and free / cap < 0.1) then disk_color = T.warn end
  end
  add("Version", d.version)
  add("Uptime", util.duration(d.uptime_sec))
  add("Accounts", int(d.accounts))
  add("Frozen", int(d.accounts_frozen))
  add("Sessions", int(d.active_sessions))
  add("Vanguard", int(d.vanguard_members) .. " of " .. int(d.vanguard_max))
  add("Civic jobs", int(d.civic_jobs))
  add("Supply", util.money(d.money_supply))
  add("Requests", int(d.requests))
  add("Rejected", int(d.rejected))
  add("Throttled", int(d.rate_limited))
  add("Duplicates", int(d.duplicates))
  add("Handler avg", string.format("%.1f ms", d.handler_avg_ms or 0))
  add("Handler max", string.format("%.0f ms", d.handler_max_ms or 0))
  add("Queue now", int(d.queue_depth))
  add("Queue peak", int(d.queue_peak))
  add("Errors", int(d.errors), (d.errors or 0) > 0 and T.warn or nil, "server errors")
  if d.last_error then
    rows[#rows + 1] = { left = "Last error: " .. tostring(d.last_error.method) .. " " .. tostring(d.last_error.err), color = T.bad }
  end
  add("Disk free", Core.bytes(free), disk_color, "disk space is low")
  add("Disk size", Core.bytes(cap))
  add("Writable", d.writable and "yes" or "NO", (not d.writable) and T.bad or nil, "writes are paused")
  add("Database", Core.bytes(d.db_bytes))
  add("Ledger rows", int(d.ledger_entries))
  add("Ledger size", Core.bytes(d.ledger_bytes))
  add("Journal", Core.bytes(d.journal_bytes))
  add("Commits", int(d.commits))
  add("Compactions", int(d.compactions))
  add("Store error", d.store_error and tostring(d.store_error) or "none", d.store_error and T.bad or nil, "storage error")
  add("Audit bad", int(d.audit_mismatched), (d.audit_mismatched or 0) > 0 and T.bad or nil, "audit mismatches")
  add("Farm flags", int(d.farm_flags_pending))
  add("Factions wait", int(d.pending_factions))
  add("Earnings pay", Core.onoff(d.earnings_enabled))
  add("Vanguard pay", Core.onoff(d.vanguard_enabled))
  rows[#rows + 1] = { left = "Background jobs", color = T.accent }
  for _, j in ipairs(d.jobs or {}) do
    add(j.name, int(j.runs) .. " runs " .. string.format("%.0f", j.last_ms or 0) .. " ms", j.err and T.bad or nil, "job " .. tostring(j.name) .. " failed")
    if j.err then rows[#rows + 1] = { left = "  " .. tostring(j.err), color = T.bad } end
  end
  return rows, warnings
end

function M.audit(ctx)
  local r = ctx:call("admin_audit", nil, { timeout = 10 })
  if not r then return end
  local lines = { string.format("%.0f accounts checked", r.accounts), "Held in accounts " .. util.money(r.total), "Money supply " .. util.money(r.supply) }
  local bad = r.mismatched or {}
  if #bad == 0 then
    lines[#lines + 1] = "Every balance matches its entries."
    ctx:message("Audit clean", lines, "ok")
  else
    local shown = {}
    for i = 1, math.min(4, #bad) do shown[#shown + 1] = bad[i] end
    lines[#lines + 1] = string.format("%.0f do not match:", #bad)
    lines[#lines + 1] = table.concat(shown, ", ") .. (#bad > 4 and (" and " .. (#bad - 4) .. " more") or "")
    ctx:message("Audit found problems", lines, "error")
  end
end

function M.backup(ctx)
  if not ctx:confirm("Back up now", { "Compact the database and copy it to the backups folder on the server.", "The previous backup is replaced." }, { yes = "BACK UP" }) then return end
  if ctx:call("admin_backup", nil, { timeout = 20 }) then ctx:say("Backup saved") end
end

function M.run(ctx)
  local st = { offset = 0 }
  local d
  local function load()
    local r = ctx:call("admin_diagnostics")
    if not r then return false end
    d = r
    return true
  end
  if not load() then return end
  while true do
    local rows, warnings = build(d)
    local id = Core.list(ctx, {
      title = "Diagnostics", subtitle = #warnings == 0 and "Everything looks fine" or ("Check: " .. table.concat(warnings, ", ")), rows = rows, state = st,
      buttons = { { label = "REFRESH", id = "refresh", kind = "primary" }, { label = "AUDIT", id = "audit" }, { label = "BACKUP", id = "backup" } },
    })
    if not id then return end
    if id == "refresh" then load()
    elseif id == "audit" then M.audit(ctx)
    elseif id == "backup" then M.backup(ctx) end
  end
end

return M
