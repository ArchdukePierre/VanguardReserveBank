local cfgmod = require("lib.cfg")
local stats = require("roles.scoreboard.stats")

local M = {}

local function show(title, ok, lines)
  print("> " .. title .. (ok and "" or "  (failed)"))
  local all = stats.lines(lines)
  if #all == 0 then print("  (no output)") end
  for _, l in ipairs(all) do print("  " .. l) end
end

function M.main(a, b)
  local args = type(a) == "table" and a or b or {}
  local exec = stats.find_exec()
  if not exec then
    print("No command access. Run this on a Command Computer.")
    return
  end
  local ok, lines = exec("list")
  show("list", ok, lines)
  local names = ok and stats.parse_online(lines) or {}
  print("parsed players: " .. (#names > 0 and table.concat(names, ", ") or "none"))
  local ook, olines = exec("scoreboard objectives list")
  show("scoreboard objectives list", ook, olines)
  local tbl = stats.build(cfgmod.load())
  local have = stats.parse_objectives(olines)
  local present = 0
  for _, e in ipairs(tbl.list) do if have[e.name] then present = present + 1 end end
  print(string.format("parsed objectives: %d of %d expected", present, #tbl.list))
  local player = args[1] or names[1]
  if not player or not player:match("^[%w_]+$") then
    print("No player to check. Pass a name or log in first.")
    return
  end
  local pok, plines = exec("scoreboard players list " .. player)
  show("scoreboard players list " .. player, pok, plines)
  local _, found, empty = stats.parse_scores(plines, tbl.by_name)
  print(string.format("parsed scores: %d%s", found, empty and " (player has no scores)" or ""))
  local dok, dlines = exec("data get entity " .. player .. " Dimension")
  show("data get entity " .. player .. " Dimension", dok, dlines)
  print("parsed dimension: " .. tostring(stats.parse_dimension(dlines)))
  if found == 0 and not empty then print("No line matched [objective]: value. Compare the output above.") end
end

return M
