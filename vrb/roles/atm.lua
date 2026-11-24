local core = require("roles.atm.core")
local home = require("roles.atm.home")

local M = {}

function M.run()
  local ctx, why = core.new()
  if not ctx then
    printError("The ATM cannot start: " .. tostring(why))
    return
  end
  while true do
    local ok, err = pcall(home.loop, ctx)
    if not ok then
      if err == core.LOST then
        ctx:reset()
        pcall(ctx.say, ctx, "Signed out", { "Your session ended.", "Please sign in again." }, "warn")
      elseif err == core.IDLE then
        ctx:signout()
      else
        printError("ATM error: " .. tostring(err))
        ctx:signout()
        local shown, why = pcall(ctx.say, ctx, "Sorry", { "Something went wrong.", "Please try again." }, "error")
        if not shown and why ~= core.IDLE then sleep(1) end
      end
    end
  end
end

return M
