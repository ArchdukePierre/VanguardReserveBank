local ui = require("roles.atm.ui")
local fmt = require("roles.atm.fmt")
local theme = require("ui.theme")

local H = {}

function H.show(ctx)
  local res = ctx:call("history", { limit = 100 })
  if not res.ok then return ctx:fail(res) end
  local rows = {}
  for i = #res.history, 1, -1 do
    local h = res.history[i]
    local amount = h.amount or 0
    local name = fmt.type_name(h.type)
    if h._kind == "savings" then name = name .. " (savings)" end
    local sub = fmt.short(h.t or 0)
    if h.note and h.note ~= "" and not h.note:find("^PRQ:") then sub = sub .. "  " .. h.note end
    rows[#rows + 1] = { left = name, right = fmt.signed(amount), rcolor = amount < 0 and theme.bad or theme.good, sub = sub }
  end
  ui.list(ctx, { title = "History", sub = "Newest first", rows = rows, empty = "Nothing yet", hint = "Activity will show here" })
end

return H
