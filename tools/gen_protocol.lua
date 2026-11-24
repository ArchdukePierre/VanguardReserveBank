local T = dofile(HERE .. "/../tests/lib.lua")

local lines = {}
T.solo({}, function()
  local DB = require("lib.db")
  local Bank = require("server.bank")
  local Rpc = require("server.rpc")
  local Jobs = require("server.jobs")
  local cfg = require("lib.cfg").load()
  local db = DB.open("/gen", {})
  local bank = Bank.new(db, cfg, string.rep("ab", 32))
  local rpc = Rpc.new(bank, cfg, string.rep("cd", 32))
  local jobs = Jobs.new()
  local ctl = { stats = {}, queue = {}, depth = function() return 0 end }
  for _, name in ipairs({ "accounts", "payments", "credit", "groups", "commerce", "earnings", "payroll", "community", "admin", "public" }) do
    require("server." .. name).register(rpc, bank, jobs, ctl)
  end
  local groups = { public = {}, session = {}, admin = {} }
  for _, m in ipairs(rpc:describe()) do table.insert(groups[m.auth], m) end
  lines[#lines + 1] = "# Request reference"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Generated from the method registry by `tools/gen_protocol.lua`. Do not edit by hand."
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Every method returns a table with `ok` (boolean). On failure `err` holds a message for the player and `code` a short machine code."
  lines[#lines + 1] = "Money is always integer cents. Session methods need `session` in the parameters."
  lines[#lines + 1] = "Field types: `acct` account number, `cents` and `cents+` integer cents (second is greater than zero), `pin` four digits, `user` username, `text` up to 200 characters, `str` up to 64, `id` identifier, `int`, `int+`, `num`, `bool`, `tbl`, `days`. A trailing `?` means optional."
  lines[#lines + 1] = ""
  for _, kind in ipairs({ "public", "session", "admin" }) do
    lines[#lines + 1] = "## " .. kind:sub(1, 1):upper() .. kind:sub(2) .. " methods"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "| Method | Parameters | Notes |"
    lines[#lines + 1] = "| --- | --- | --- |"
    table.sort(groups[kind], function(a, b) return a.name < b.name end)
    for _, m in ipairs(groups[kind]) do
      lines[#lines + 1] = string.format("| `%s` | %s | %s%s |", m.name, #m.fields > 0 and ("`" .. table.concat(m.fields, ", ") .. "`") or "", m.doc or "", m.write and (m.doc and " (writes)" or "writes") or "")
    end
    lines[#lines + 1] = ""
  end
end)
local f = assert(io.open(REPO .. "/docs/PROTOCOL.md", "wb"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
print("wrote docs/PROTOCOL.md (" .. #lines .. " lines)")
