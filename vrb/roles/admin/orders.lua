local theme = require("ui.theme")
local util = require("lib.util")
local Core = require("roles.admin.core")

local T = theme
local M = {}

local function status(o)
  if o.completed then return "Paid to " .. tostring(o.paid_to or "?"), T.good end
  if o.claimed_by then return "Taken by " .. tostring(o.claimed_owner or o.claimed_by), T.accent end
  return "Open", T.ink
end

local function details(ctx, o)
  local text = status(o)
  local lines = { o.title, "Bounty " .. util.money(o.bounty), "Status: " .. text, "Posted " .. Core.stamp(o.posted_at) }
  if o.description and o.description ~= "" then lines[#lines + 1] = o.description end
  ctx:message("Work order", lines)
end

local function post(ctx)
  local title = ctx:text({ title = "New work order", label = "_ is a space", subtitle = "Title, at least 3 letters", max = 60 })
  if not title then return end
  if #title < 3 then
    ctx:message("Too short", { "The title needs at least 3 characters." }, "warn")
    return
  end
  local bounty = Core.keypad(ctx, { title = "Bounty", label = "Pay for the work", kind = "money", subtitle = title })
  if not bounty then return end
  local desc
  if ctx:confirm("Description", { "Add a few words about the job?" }, { yes = "ADD", no = "SKIP" }) then
    desc = ctx:text({ title = "Description", label = "_ is a space", subtitle = "What needs doing", max = 120 })
  end
  local lines = { "Post " .. title .. "?", "Bounty " .. util.money(bounty) .. " is taken from the Vanguard fund now.", "Deleting the order gives it back." }
  if not ctx:confirm("Post order", lines, { yes = "POST" }) then return end
  if ctx:call("admin_post_work_order", { title = title, bounty = bounty, description = desc }) then ctx:say("Order posted") end
end

local function complete(ctx, o)
  local lines = { "Pay " .. util.money(o.bounty) .. " to " .. tostring(o.claimed_owner or o.claimed_by) .. " for " .. o.title .. "?", "The order is closed." }
  if not ctx:confirm("Complete order", lines, { yes = "PAY" }) then return end
  local r = ctx:call("admin_complete_work_order", { order_id = o.id })
  if r then ctx:say("Paid " .. util.money(o.bounty) .. " to " .. tostring(r.owner)) end
end

local function delete(ctx, o)
  local lines = { "Delete the order " .. o.title .. "?", util.money(o.bounty) .. " goes back to the Vanguard fund." }
  if o.claimed_by then lines[#lines + 1] = tostring(o.claimed_owner or o.claimed_by) .. " loses the claim." end
  if not ctx:confirm("Delete order", lines, { yes = "DELETE", danger = true }) then return end
  if ctx:call("admin_delete_work_order", { order_id = o.id }) then ctx:say("Order deleted") end
end

local function order_menu(ctx, o)
  local opts = { { label = "DETAILS", id = "details", kind = "panel" } }
  if not o.completed then
    if o.claimed_by then opts[#opts + 1] = { label = "COMPLETE AND PAY", id = "complete", kind = "success" } end
    opts[#opts + 1] = { label = "DELETE ORDER", id = "delete", kind = "danger" }
  end
  local id = ctx:choose(o.title, opts, { subtitle = util.money(o.bounty) .. ", " .. (status(o)) })
  if id == "details" then details(ctx, o)
  elseif id == "complete" then complete(ctx, o)
  elseif id == "delete" then delete(ctx, o) end
end

function M.run(ctx)
  local st = { offset = 0 }
  local show_done = false
  local data
  local function load()
    local r = ctx:call("admin_list_work_orders", { include_completed = show_done or nil })
    if not r then return false end
    data = r
    return true
  end
  if not load() then return end
  while true do
    local rows, open, taken = {}, 0, 0
    for _, o in ipairs(data.orders) do
      local text, color = status(o)
      if not o.completed then open = open + 1; if o.claimed_by then taken = taken + 1 end end
      rows[#rows + 1] = { left = o.title .. " [" .. text .. "]", right = util.money(o.bounty), color = color, id = o.id, data = o }
    end
    local id, o = Core.list(ctx, {
      title = "Work orders", subtitle = string.format("%.0f open, %.0f taken", open, taken), rows = rows, state = st, empty = "No work orders", hint = "Touch POST to add one",
      buttons = { { label = "POST", id = "post", kind = "primary" }, { label = show_done and "HIDE PAID" or "SHOW PAID", id = "done" }, { label = "RELOAD", id = "reload" } },
    })
    if not id then return end
    if id == "post" then post(ctx); load()
    elseif id == "done" then show_done = not show_done; load()
    elseif id == "reload" then load()
    else
      order_menu(ctx, o)
      load()
    end
  end
end

return M
