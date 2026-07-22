-- ============================================================================
--  VRB-BOOTSTRAP  v9.0
--  Streamlined setup for Vanguard Reserve Bank.
--
--  USAGE
--    On each computer, run:
--      pastebin get YOUR_BOOTSTRAP_CODE bootstrap
--      bootstrap
--    (and follow prompts)
--
--  WHAT IT DOES
--    1. Detects whether this computer is the FIRST in the deployment
--       (no floppy with VRB keys present) or a LATER computer (floppy
--       with keys already present).
--    2. For the FIRST computer (the bank server):
--       - Downloads vrb.lua from pastebin
--       - Generates fresh keys (vrb keygen)
--       - Writes keys to a blank floppy as a "distribution disk"
--       - Installs as 'server' role and reboots
--    3. For LATER computers:
--       - Reads the distribution floppy
--       - Downloads vrb.lua from pastebin
--       - Asks what role to install
--       - Copies the appropriate keys (server.secret for everyone,
--         admin.key only for admin/scoreboard roles)
--       - Installs the chosen role and reboots
--
--    The whole flow per computer is under 60 seconds.
-- ============================================================================

local PASTEBIN_VRB_LUA = "ufyybTjD"

local THEME = {
    bg     = colors.black,
    surface= colors.gray,
    gold   = colors.orange,
    ink    = colors.white,
    muted  = colors.lightGray,
    ok     = colors.lime,
    err    = colors.red,
    warn   = colors.yellow,
}

local function clear()
    term.setBackgroundColor(THEME.bg); term.setTextColor(THEME.ink); term.clear()
    term.setCursorPos(1, 1)
end

local function header(line1, line2)
    clear()
    term.setTextColor(THEME.gold); term.setCursorPos(1, 1)
    print("=========================================================")
    print("  VANGUARD RESERVE BANK  -  Bootstrap")
    print("=========================================================")
    if line1 then term.setTextColor(THEME.ink); print(""); print(line1) end
    if line2 then term.setTextColor(THEME.muted); print(line2) end
    print("")
    term.setTextColor(THEME.ink)
end

local function ok(msg)
    term.setTextColor(THEME.ok); print("  + "..msg); term.setTextColor(THEME.ink)
end
local function bad(msg)
    term.setTextColor(THEME.err); print("  ! "..msg); term.setTextColor(THEME.ink)
end
local function info(msg)
    term.setTextColor(THEME.muted); print("  . "..msg); term.setTextColor(THEME.ink)
end
local function warn(msg)
    term.setTextColor(THEME.warn); print("  > "..msg); term.setTextColor(THEME.ink)
end

local function ensureDir(p)
    if not fs.exists(p) then fs.makeDir(p) end
end

local function exists(p) return fs.exists(p) end

-- Find a disk drive peripheral
local function findDisk()
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "drive" then
            local p = peripheral.wrap(side)
            if p and p.isDiskPresent and p.isDiskPresent() then
                return side, p
            end
        end
    end
    return nil
end

-- Wait for a disk to be inserted, with a friendly prompt.
-- Uses CC:Tweaked's `disk` event for efficient waiting.
local function waitForDisk(prompt)
    print("")
    warn(prompt or "Insert a floppy disk...")
    -- Already inserted?
    local side, p = findDisk()
    if side then return side, p end
    -- Wait for a disk insertion event
    while true do
        local ev = os.pullEvent()
        if ev == "disk" then
            sleep(0.3)  -- give the FS a moment to mount
            local s2, p2 = findDisk()
            if s2 then return s2, p2 end
        end
    end
end

local function pickRole()
    print("")
    term.setTextColor(THEME.gold); print("Which role should this computer be?")
    term.setTextColor(THEME.ink)
    print("")
    print("  [1]  atm         - Branch ATM (touchscreen for players)")
    print("  [2]  admin       - Vanguard staff terminal")
    print("  [3]  scoreboard  - Earnings reader (requires Command Computer)")
    print("  [4]  viewer      - Public economy dashboard")
    print("  [5]  mint        - Reserve Note physical-currency station")
    print("  [6]  shop        - Player-run vending kiosk")
    print("")
    while true do
        write("> ")
        term.setTextColor(THEME.gold)
        local s = read():lower():gsub("%s", "")
        term.setTextColor(THEME.ink)
        if s == "1" or s == "atm"        then return "atm" end
        if s == "2" or s == "admin"      then return "admin" end
        if s == "3" or s == "scoreboard" then return "scoreboard" end
        if s == "4" or s == "viewer"     then return "viewer" end
        if s == "5" or s == "mint"       then return "mint" end
        if s == "6" or s == "shop"       then return "shop" end
        bad("Pick a number 1-6 or a role name.")
    end
end

local function downloadVRB()
    if exists("/vrb") then
        -- Check if it looks like a real VRB script (size > 100KB sanity check)
        local size = fs.getSize("/vrb")
        if size and size > 100000 then
            ok("vrb.lua already present ("..math.floor(size/1024).." KB), reusing")
            info("(delete /vrb if you want to re-download)")
            return
        end
        -- Too small or garbage; re-download
        fs.delete("/vrb")
    end
    print("")
    info("Downloading vrb.lua from pastebin...")
    local args = {"get", PASTEBIN_VRB_LUA, "/vrb"}
    local ok_dl = shell.run("pastebin", table.unpack(args))
    if not ok_dl or not exists("/vrb") then
        bad("Failed to download vrb.lua from pastebin.")
        bad("Check your internet, the pastebin code, and try again.")
        bad("If pastebin is rate-limiting, wait 60 seconds before retrying.")
        error("Download failed.", 0)
    end
    local size = fs.getSize("/vrb") or 0
    if size < 100000 then
        bad("Downloaded vrb.lua looks too small ("..size.." bytes).")
        bad("Pastebin may have returned an error page. Check the code.")
        fs.delete("/vrb")
        error("Bad download.", 0)
    end
    ok("Downloaded vrb.lua ("..math.floor(size/1024).." KB)")
end

-- Read the distribution floppy and copy the right keys to local storage
local function copyKeysFromFloppy(role)
    local _, drv = waitForDisk("Insert the VRB distribution floppy and wait...")
    sleep(0.5)   -- give it a moment to mount
    if not exists("/disk/server.secret") then
        bad("This floppy doesn't have server.secret on it.")
        bad("Did you insert the right floppy? Aborting.")
        error("Bad floppy.", 0)
    end
    ensureDir("/.vrb")
    ensureDir("/.vrb/keys")
    -- server.secret: every role needs it
    if exists("/.vrb/keys/server.secret") then
        fs.delete("/.vrb/keys/server.secret")
    end
    fs.copy("/disk/server.secret", "/.vrb/keys/server.secret")
    ok("Copied server.secret")
    -- admin.key: only admin and scoreboard need it
    if role == "admin" or role == "scoreboard" then
        if not exists("/disk/admin.key") then
            bad("This floppy doesn't have admin.key.")
            bad("Did you wipe the admin.key after the admin install?")
            bad("Re-create the distribution floppy from the server.")
            error("Bad floppy for "..role..".", 0)
        end
        if exists("/.vrb/keys/admin.key") then
            fs.delete("/.vrb/keys/admin.key")
        end
        fs.copy("/disk/admin.key", "/.vrb/keys/admin.key")
        ok("Copied admin.key")
    end
end

-- Run vrb install programmatically by writing /startup.lua directly
local function writeStartup(role)
    if exists("/startup.lua") then fs.delete("/startup.lua") end
    local f = fs.open("/startup.lua", "w")
    f.write("shell.run('/vrb', '"..role.."')\n")
    f.close()
    ok("Wrote /startup.lua for role: "..role)
end

local function isFirstSetup()
    -- It's the first setup if there are NO VRB keys anywhere reachable.
    -- Check local disk first.
    if exists("/.vrb/keys/server.secret") then return false end
    -- Check inserted floppy.
    local side, drv = findDisk()
    if side and exists("/disk/server.secret") then return false end
    return true
end

-- Recovery: this computer has keys locally but no startup script.
-- Means a previous bootstrap was interrupted before reboot. Detect
-- and offer to write the floppy and finish, OR to nuke everything
-- and start over.
local function isStuckOnServer()
    return exists("/.vrb/keys/server.secret")
       and exists("/.vrb/keys/admin.key")
       and not exists("/startup.lua")
end

local function doRecoverServer()
    header("Partial setup detected.",
           "Keys exist but startup wasn't written. Recovering.")
    print("")
    info("Re-creating distribution floppy...")
    local _, drv = waitForDisk("Insert a floppy disk to receive the keys.")
    sleep(0.3)
    if exists("/disk/server.secret") then fs.delete("/disk/server.secret") end
    if exists("/disk/admin.key") then fs.delete("/disk/admin.key") end
    fs.copy("/.vrb/keys/server.secret", "/disk/server.secret")
    fs.copy("/.vrb/keys/admin.key", "/disk/admin.key")
    local mf = fs.open("/disk/vrb-manifest.txt", "w")
    mf.write("VRB Distribution Floppy (recovered)\n")
    mf.write("Created: "..os.date("%Y-%m-%d %H:%M:%S").."\n")
    mf.close()
    ok("Floppy written")
    writeStartup("server")
    print("")
    ok("Recovery complete!")
    write("Press Enter to reboot: "); read()
    os.reboot()
end

local function doFirstSetup()
    header("First-time setup detected.",
           "This computer will become the bank SERVER.")
    print("")
    warn("You'll need a BLANK floppy disk in a Disk Drive next to this")
    warn("computer to receive the keys for distribution.")
    print("")
    write("Press Enter to continue, or Ctrl+T to abort: ")
    read()

    downloadVRB()

    -- Generate keys via vrb keygen (it writes to /.vrb/keys/)
    print("")
    info("Generating fresh server keys...")
    shell.run("/vrb", "keygen")
    if not exists("/.vrb/keys/server.secret")
       or not exists("/.vrb/keys/admin.key") then
        bad("Key generation failed.")
        error("keygen failed", 0)
    end
    ok("server.secret generated")
    ok("admin.key generated")

    -- Wait for floppy and write keys to it
    print("")
    warn("Now insert a BLANK floppy disk into the disk drive.")
    warn("It will become your distribution floppy.")
    local _, drv = waitForDisk("Waiting for floppy...")
    sleep(0.3)
    -- Wipe any existing files (force-overwrite)
    if exists("/disk/server.secret") then fs.delete("/disk/server.secret") end
    if exists("/disk/admin.key")     then fs.delete("/disk/admin.key") end
    fs.copy("/.vrb/keys/server.secret", "/disk/server.secret")
    fs.copy("/.vrb/keys/admin.key", "/disk/admin.key")
    -- Manifest
    local mf = fs.open("/disk/vrb-manifest.txt", "w")
    mf.write("VRB Distribution Floppy\n")
    mf.write("Created: "..os.date("%Y-%m-%d %H:%M:%S").."\n")
    mf.write("Version: 9.0\n")
    mf.write("Contains: server.secret, admin.key\n")
    mf.close()
    ok("server.secret written to floppy")
    ok("admin.key written to floppy")
    ok("Manifest written")

    print("")
    term.setTextColor(THEME.warn)
    print("=========================================================")
    print("  IMPORTANT: WRITE DOWN THE KEYS ON PAPER")
    print("=========================================================")
    term.setTextColor(THEME.ink)
    print("")
    print("server.secret:")
    term.setTextColor(THEME.gold)
    local f = fs.open("/.vrb/keys/server.secret", "r")
    print(f.readAll()); f.close()
    term.setTextColor(THEME.ink)
    print("")
    print("admin.key:")
    term.setTextColor(THEME.gold)
    f = fs.open("/.vrb/keys/admin.key", "r")
    print(f.readAll()); f.close()
    term.setTextColor(THEME.ink)
    print("")
    print("If you lose both the floppy AND this computer is destroyed,")
    print("you cannot recover the bank without these.")
    print("")
    write("Have you written them down? (yes): ")
    local ack = read()
    if ack ~= "yes" then
        warn("Aborting. Re-run bootstrap when you're ready to record them.")
        return
    end

    writeStartup("server")
    print("")
    ok("Bootstrap complete!")
    info("The server will boot automatically after reboot.")
    print("")
    print("Take the floppy with you to set up other computers.")
    print("")
    write("Press Enter to reboot: ")
    read()
    os.reboot()
end

local function doFollowupSetup()
    header("Follow-up computer setup.",
           "This computer will join an existing VRB deployment.")
    print("")

    local role = pickRole()

    downloadVRB()
    copyKeysFromFloppy(role)
    writeStartup(role)

    print("")
    ok("Bootstrap complete for role: "..role)

    if role == "admin" or role == "scoreboard" then
        print("")
        warn("This computer has admin.key installed.")
        warn("Once your admin terminal is set up, consider removing")
        warn("admin.key from the distribution floppy:")
        info("  rm /disk/admin.key")
        warn("Future ATMs/viewers/shops do not need admin.key.")
    end

    print("")
    write("Press Enter to reboot: ")
    read()
    os.reboot()
end

-- ============================================================================
-- ENTRY
-- ============================================================================

-- Handle --reset flag: wipes local VRB state. Use only if you really mean it.
local args = {...}
if args[1] == "--reset" or args[1] == "reset" then
    header("RESET MODE",
           "This will delete /.vrb and /startup.lua from THIS computer.")
    print("")
    warn("This is destructive. The bank server's data lives in /.vrb/db,")
    warn("and the keys are in /.vrb/keys. Both will be deleted on this")
    warn("computer. Make sure you have a backup before continuing.")
    print("")
    write("Type RESET to confirm: ")
    if read() ~= "RESET" then info("Aborted."); return end
    if exists("/.vrb") then fs.delete("/.vrb") end
    if exists("/startup.lua") then fs.delete("/startup.lua") end
    if exists("/vrb") then fs.delete("/vrb") end
    ok("Reset complete.")
    print("")
    write("Press Enter to reboot: "); read()
    os.reboot()
    return
end

header()
print("Vanguard Reserve Bank - Bootstrap v9.0")
print("")
print("This will set up VRB on this computer in under a minute.")
print("")

if PASTEBIN_VRB_LUA == "REPLACE_WITH_YOUR_VRB_LUA_PASTEBIN_CODE" then
    bad("Bootstrap is not configured.")
    bad("Open this script and replace the PASTEBIN_VRB_LUA constant with")
    bad("the pastebin code where you uploaded vrb.lua.")
    return
end

if isStuckOnServer() then
    doRecoverServer()
elseif isFirstSetup() then
    doFirstSetup()
else
    doFollowupSetup()
end
