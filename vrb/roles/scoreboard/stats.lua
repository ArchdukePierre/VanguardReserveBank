local S = {}

local PLAY = "minecraft.custom:minecraft.play_time"
local DEATH = "minecraft.custom:minecraft.time_since_last_death"
local DAMAGE = "minecraft.custom:minecraft.damage_taken"
local PLAYER_KILLS = "minecraft.killed:minecraft.player"

local CRITERION = {
  [DEATH] = "minecraft.custom:minecraft.time_since_death",
  [PLAYER_KILLS] = "playerKillCount",
}

local KIND = { ["minecraft.killed"] = "k", ["minecraft.used"] = "u", ["minecraft.mined"] = "m", ["minecraft.custom"] = "c" }

local DIMENSIONS = { [0] = "minecraft:overworld", [-1] = "minecraft:the_nether", [1] = "minecraft:the_end" }

local COLORS = {}
for c in ("black dark_blue dark_green dark_aqua dark_red dark_purple gold gray dark_gray blue green aqua red light_purple yellow white"):gmatch("%S+") do COLORS[c] = true end

local function hash4(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 65536 end
  return string.format("%04x", h)
end

function S.criterion(key)
  if CRITERION[key] then return CRITERION[key] end
  local head, tail = key:match("^([^:]+):(.*)$")
  if not head then return key end
  return head .. ":" .. (tail:gsub(":", "."))
end

local function objective_name(key, taken)
  local head, id = key:match("^([^:]+):(.+)$")
  local stem = (id or key):gsub("^minecraft[:%.]", ""):gsub("[^%w_]", "_")
  local name = "vrb_" .. (KIND[head] or "x") .. "_" .. stem
  if #name > 16 then name = name:sub(1, 11) .. hash4(key) end
  local salt = key
  while taken[name] do
    salt = salt .. "+"
    name = name:sub(1, 11) .. hash4(salt)
  end
  taken[name] = true
  return name
end

function S.build(cfg)
  local E = cfg.earnings
  local core, keys = {}, {}
  local function add(key, is_core)
    if core[key] == nil then
      core[key] = is_core
      keys[#keys + 1] = key
    end
  end
  add(PLAY, true)
  add(DEATH, true)
  add(DAMAGE, true)
  add(PLAYER_KILLS, true)
  for entity in pairs(E.combat_tier) do add("minecraft.killed:" .. entity, true) end
  for entity in pairs(E.boss_bounty) do add("minecraft.killed:" .. entity, true) end
  for _, stat in ipairs(E.explore_stats) do add(stat, true) end
  for block in pairs(E.build_materials) do
    add("minecraft.used:" .. block, false)
    add("minecraft.mined:" .. block, false)
  end
  table.sort(keys)
  local tbl = { list = {}, essential = {}, by_name = {}, by_key = {} }
  local taken = {}
  for _, key in ipairs(keys) do
    local e = { key = key, name = objective_name(key, taken), criterion = S.criterion(key), core = core[key] }
    tbl.list[#tbl.list + 1] = e
    tbl.by_name[e.name] = key
    tbl.by_key[key] = e
    if e.core then tbl.essential[#tbl.essential + 1] = e end
  end
  return tbl
end

function S.lines(output)
  local out = {}
  if type(output) == "string" then output = { output } end
  if type(output) ~= "table" then return out end
  for _, l in ipairs(output) do
    for piece in tostring(l):gmatch("[^\r\n]+") do out[#out + 1] = piece end
  end
  return out
end

function S.parse_online(output)
  local text = table.concat(S.lines(output), "\n")
  local rest = text:match("online:%s*(.*)$") or text:match(":%s*(.*)$")
  local names, seen = {}, {}
  if not rest then return names end
  for name in rest:gmatch("[^,%s]+") do
    if name:match("^[%w_]+$") and #name >= 2 and #name <= 32 and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  return names
end

function S.parse_scores(output, by_name)
  local scores, found, empty = {}, 0, false
  for _, line in ipairs(S.lines(output)) do
    local objective, value = line:match("^%s*%[?([%w_%.%+%-]+)%]?%s*:%s*(%-?%d+)")
    if objective then
      local key = by_name[objective]
      if key then
        scores[key] = tonumber(value)
        found = found + 1
      end
    elseif line:lower():find("no scores", 1, true) then
      empty = true
    end
  end
  return scores, found, empty
end

function S.parse_get(output)
  for _, line in ipairs(S.lines(output)) do
    local n = line:match("has%s+(%-?%d+)")
    if n then return tonumber(n) end
  end
end

function S.parse_dimension(output)
  local text = table.concat(S.lines(output), "\n")
  local d = text:match("[\"']([%w_%.%-]+:[%w_%./%-]+)[\"']")
  if d then return d end
  local n = text:match("data:%s*(%-?%d+)")
  if n then return DIMENSIONS[tonumber(n)] end
end

function S.parse_objectives(output)
  local have = {}
  for name in table.concat(S.lines(output), "\n"):gmatch("%[([^%]]+)%]") do have[name] = true end
  return have
end

local function escape(s)
  s = tostring(s):gsub("%c", " ")
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return s
end

function S.tellraw(owner, message, color)
  if type(owner) ~= "string" or not owner:match("^[%w_]+$") then return nil end
  if not COLORS[color or ""] then color = "white" end
  local text = escape(tostring(message or ""):sub(1, 240))
  return string.format('tellraw %s [{"text":"[VRB] ","color":"gold","bold":true},{"text":"%s","color":"%s"}]', owner, text, color)
end

function S.find_exec()
  if commands and commands.exec then return commands.exec end
  for _, name in ipairs(peripheral.getNames()) do
    local ok, p = pcall(peripheral.wrap, name)
    if ok and type(p) == "table" and type(p.exec) == "function" then
      return function(cmd) return p.exec(cmd) end
    end
  end
end

return S
