local App = require("ui.app")
local kit = require("ui.kit")
local flows = require("ui.flows")
local theme = require("ui.theme")
local Client = require("lib.client")
local cfgmod = require("lib.cfg")
local util = require("lib.util")

local M = {}
local T = theme

local RECOVERY = "/.vrb/mint"
local IDLE_SEC = 120
local NOTE_FILE = "note.vrb"

local function find_peripheral(kind)
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == kind then return peripheral.wrap(name), name end
  end
end

local function fatal(lines)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  for _, l in ipairs(lines) do print(l) end
end

local function dollars(d)
  if d == math.floor(d) then return string.format("%.0f", d) end
  return string.format("%.2f", d)
end

local function devices()
  return (find_peripheral("drive")), (find_peripheral("printer"))
end

local function disk_state(drive)
  if not drive then return "none" end
  local ok, present = pcall(drive.isDiskPresent)
  if not ok or not present then return "empty" end
  local okp, path = pcall(drive.getMountPath)
  if not okp or not path then return "unusable" end
  if fs.exists(fs.combine(path, NOTE_FILE)) then return "full", path end
  return "ready", path
end

local DISK_TEXT = {
  none = "No disk drive attached",
  empty = "Insert a disk",
  unusable = "That disk cannot hold files",
  full = "That disk already holds a note",
  ready = "Disk ready",
}

local function plan_output()
  local drive, printer = devices()
  local state, path = disk_state(drive)
  if state == "ready" then return "disk", path, drive end
  if state == "empty" or state == "none" then
    if printer then return "printer", nil, printer end
    return nil, state == "none" and "Attach a disk drive or a printer" or "Insert a disk first"
  end
  return nil, DISK_TEXT[state]
end

local function write_disk(drive, note)
  local state, path = disk_state(drive)
  if state ~= "ready" then return false, DISK_TEXT[state] end
  local f = fs.open(fs.combine(path, NOTE_FILE), "w")
  if not f then return false, "Could not write to the disk" end
  f.write(textutils.serialize(note))
  f.close()
  pcall(drive.setDiskLabel, string.format("VRN %s $%s", note.serial, dollars(note.denom)))
  return true
end

local function print_slip(printer, note)
  local ok, started = pcall(printer.newPage)
  if not ok or not started then return false, "The printer needs paper and ink" end
  printer.setPageTitle("Reserve Note " .. note.serial)
  local lines = { "VANGUARD RESERVE NOTE", "---------------------", "", "Serial", note.serial, "", "Value $" .. dollars(note.denom), "Issued " .. os.date("%Y-%m-%d %H:%M", note.issued) }
  for i, l in ipairs(lines) do
    printer.setCursorPos(1, i)
    printer.write(l)
  end
  if not printer.endPage() then return false, "The printer could not finish the page" end
  return true
end

local function parse_account(text)
  local t = text:upper():gsub("%-", "")
  local digits = t:match("^ACC(%d%d%d%d%d%d)$") or t:match("^(%d%d%d%d%d%d)$")
  if digits then return "ACC-" .. digits end
end

function M.run()
  local cfg = cfgmod.load()
  local secret, admin = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
  if not secret or not admin then
    return fatal({
      "MINT: missing keys",
      "",
      secret and "server.secret: found" or "server.secret: MISSING",
      admin and "admin.key: found" or "admin.key: MISSING",
      "",
      "Copy both files from the bank install disk",
      "to /.vrb/keys and start again.",
    })
  end
  local client, why = Client.new({ admin = admin })
  if not client then return fatal({ "MINT: network problem", "", tostring(why) }) end
  local drive, printer = devices()
  if not drive and not printer then
    return fatal({ "MINT: no output device", "", "Attach a disk drive or a printer", "and start this computer again." })
  end
  local mon, name = find_peripheral("monitor")
  local app = App.new({ surface = mon, name = name, idle = IDLE_SEC })
  local S = {}

  local function draw(s)
    kit.header(s, "Mint station", "Reserve Notes")
    local w = math.min(s.w - 4, 46)
    local x = math.floor((s.w - w) / 2) + 1
    kit.card(s, x, 6, w, 5, "OUTPUT")
    local drive, printer = devices()
    local state = disk_state(drive)
    s:text(x + 2, 7, "Disk", T.muted, T.panel)
    s:text(x + 11, 7, util.ellipsis(DISK_TEXT[state], w - 13), state == "ready" and T.good or T.warn, T.panel)
    s:text(x + 2, 8, "Printer", T.muted, T.panel)
    s:text(x + 11, 8, printer and "Attached" or "Not attached", printer and T.good or T.muted, T.panel)
    if S.last then s:text(x + 2, 9, util.ellipsis("Last " .. S.last, w - 4), T.muted, T.panel) end
    local bh = s.h >= 24 and 3 or 2
    kit.button(s, x, 12, w, "ISSUE A NOTE", "issue", { kind = "primary", h = bh })
    kit.button(s, x, 12 + bh + 1, w, "QUIT", "quit", { kind = "secondary", h = bh })
    kit.footer(s, "I issues a note", "Q quits")
  end

  local function resolve_account()
    local text = flows.text(app, { title = "Issue a note", label = "Account or username", max = 32, allowed = "^[%w_%-]$" })
    if not text then return nil end
    local id = parse_account(text)
    local owner
    if not id then
      if #text < 2 or not text:match("^[%w_]+$") then
        flows.message(app, "Not a valid name", { "Use an account number like ACC-123456", "or a player name." }, "warn")
        return nil
      end
      local r = client:call("lookup", { owner = text })
      if not r.ok then
        flows.message(app, "Lookup failed", { r.err or "Try again" }, "error")
        return nil
      end
      for _, a in ipairs(r.accounts or {}) do
        if a.kind == "checking" then id, owner = a.id, a.owner end
      end
      id = id or (r.accounts and r.accounts[1] and r.accounts[1].id)
      if not id then
        flows.message(app, "No account", { "There is no account for " .. text .. "." }, "warn")
        return nil
      end
    end
    local d = client:call("admin_account_detail", { account_id = id }, { admin = true })
    if not d.ok then
      flows.message(app, "Account not found", { d.err or id }, "error")
      return nil
    end
    return d.account
  end

  local function pick_denomination()
    local options = {}
    for i, d in ipairs(cfg.server.note_denominations) do options[i] = { label = "$" .. dollars(d), id = d, kind = "panel" } end
    return flows.choose(app, "Note value", options, { h = app.s.h >= 30 and 2 or 1, subtitle = "Pick the value to print or write" })
  end

  local function deliver(note)
    util.ensure_dir(RECOVERY)
    local backup = RECOVERY .. "/" .. note.serial .. ".vrb"
    util.write_atomic(backup, textutils.serialize(note))
    while true do
      local kind, reason, device = plan_output()
      local ok, err
      if kind == "disk" then
        ok, err = write_disk(device, note)
        if ok then
          pcall(fs.delete, backup)
          return "Written to the disk"
        end
      elseif kind == "printer" then
        ok, err = print_slip(device, note)
        if ok then return "Slip printed. Record kept in " .. backup end
      else
        err = reason
      end
      local retry = flows.confirm(app, "Note not delivered", { err or "No output device", "The note is saved in", backup }, { yes = "RETRY", no = "LATER" })
      if not retry then return "Saved in " .. backup end
    end
  end

  local function issue()
    local account = resolve_account()
    if not account then return end
    if account.frozen then return flows.message(app, "Account frozen", { account.owner .. "'s account is frozen." }, "warn") end
    local denom = pick_denomination()
    if not denom then return end
    if account.balance < denom * 100 then
      return flows.message(app, "Not enough funds", { string.format("%s has %s.", account.owner, util.money(account.balance)), "The note is worth $" .. dollars(denom) .. "." }, "warn")
    end
    local kind, reason = plan_output()
    if not kind then return flows.message(app, "No place for the note", { reason, "Nothing was issued." }, "warn") end
    local yes = flows.confirm(app, "Issue note", {
      string.format("%s (%s)", account.owner, account.id),
      "Note value $" .. dollars(denom),
      "Balance goes from " .. util.money(account.balance),
      "to " .. util.money(account.balance - denom * 100),
      kind == "disk" and "It will be written to the disk." or "It will be printed.",
    }, { yes = "ISSUE", no = "CANCEL" })
    if not yes then return end
    local r = client:call("admin_issue_note", { account_id = account.id, denomination = denom }, { admin = true })
    if not r.ok or type(r.note) ~= "table" then
      return flows.message(app, "Not issued", { r.err or "The bank refused the request" }, "error")
    end
    local result = deliver(r.note)
    S.last = r.note.serial .. " $" .. dollars(r.note.denom)
    flows.message(app, "Note issued", { r.note.serial, "Value $" .. dollars(r.note.denom), result, "Balance now " .. util.money(r.balance or 0) }, "ok")
  end

  while true do
    app:show(draw)
    local kind, a = app:wait({ events = { disk = true, disk_eject = true } })
    if kind == "tap" then
      if a.id == "issue" then issue() elseif a.id == "quit" then break end
    elseif kind == "char" then
      local c = tostring(a):lower()
      if c == "i" then issue() elseif c == "q" then break end
    elseif kind == "key" and a == "enter" then
      issue()
    end
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
end

return M
