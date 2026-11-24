local cfgmod = require("lib.cfg")
local util = require("lib.util")

local M = {}

function M.main(cmd, args)
  local cfg = cfgmod.load()
  local root = cfg.dirs.data .. "/backups"
  if cmd == "backup" then
    if cfgmod.role() ~= "server" then print("Run this on the bank server."); return end
    local DB = require("lib.db")
    local db = DB.open(cfg.dirs.db, {})
    local ok, err = db:compact()
    if not ok then print("Could not compact before the backup: " .. tostring(err)); return end
    local snap = cfg.dirs.db .. "/snap"
    local size = util.dir_size(snap)
    if util.free_space() < size + 20000 then print("Not enough free disk space for a backup (" .. math.floor(size / 1024) .. " KB needed)."); return end
    util.ensure_dir(root)
    local name = os.date("%Y%m%d-%H%M%S")
    fs.copy(snap, root .. "/" .. name)
    print("Backup saved as " .. name .. " (" .. math.floor(size / 1024) .. " KB).")
    local all = fs.list(root)
    table.sort(all)
    while #all > cfg.server.backups_keep do fs.delete(root .. "/" .. table.remove(all, 1)) end
  else
    local all = fs.exists(root) and fs.list(root) or {}
    table.sort(all)
    if not args[1] then
      print("Backups:")
      for _, n in ipairs(all) do print("  " .. n) end
      if #all == 0 then print("  (none)") end
      print("Restore one with: vrb restore <name>")
      return
    end
    if not fs.exists(root .. "/" .. args[1]) then print("No such backup."); return end
    write("This replaces the bank data with that backup. Type RESTORE to continue: ")
    if read() ~= "RESTORE" then print("Cancelled."); return end
    fs.delete(cfg.dirs.db)
    fs.makeDir(cfg.dirs.db)
    fs.copy(root .. "/" .. args[1], cfg.dirs.db .. "/snap")
    print("Restored. Reboot to start the server.")
  end
end

return M
