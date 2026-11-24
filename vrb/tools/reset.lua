local cfgmod = require("lib.cfg")

local M = {}

function M.main(cmd)
  if cmd == "keys" then
    local s, a = cfgmod.read_key("server.secret"), cfgmod.read_key("admin.key")
    print("Write these down and keep them somewhere safe. Anyone with the admin key can move money.")
    print("")
    print("server.secret:")
    print(s or "(none)")
    print("admin.key:")
    print(a or "(none)")
    return
  end
  print("This deletes every key and all bank data on this computer.")
  write("Type RESET to continue: ")
  if read() ~= "RESET" then print("Cancelled."); return end
  if fs.exists("/.vrb") then fs.delete("/.vrb") end
  if fs.exists("/startup.lua") then fs.delete("/startup.lua") end
  print("Done. The program files in /vrb are still there. Run the installer to set a new role.")
end

return M
