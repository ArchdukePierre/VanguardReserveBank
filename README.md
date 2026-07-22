# Vanguard Reserve Bank (VRB) - Version 9.0.0

## Important Note on Code Formatting
If you are reviewing the source code, you will notice it is formatted as an ugly, monolithic, and completely commentless file. This was not the original design. At the time of development, I realized that the script had completely maxed out the internal storage and memory capacity of the CC:Tweaked computer. To fit the banking system into the computer and ensure it would not crash the Minecraft world or cause severe lag, all comments and formatting had to be cut out. It was not like this at conception, but was aggressively minimized out of absolute necessity.

## Overview
The Vanguard Reserve Bank (VRB) is a highly sophisticated, single-file banking and economic system built for ComputerCraft / CC:Tweaked in Minecraft. Operating on protocol `VRB_V2`, it functions as a comprehensive central reserve bank, processing secure transactions, managing financial accounts, and driving a dynamic, action-based player economy.

## Core Features

### 1. Robust Account System
*   **Checking & Savings:** Players can open paired checking and savings accounts.
*   **Security:** Uses strict PIN hashing (HMAC-SHA256) with lockout mechanisms to prevent brute-force attacks (5 failed attempts locks the account for 15 minutes).
*   **Treasury & Reserve:** Dedicated treasury accounts ("VanguardFed") for taxation, supply tracking, and system payouts.

### 2. Custom Cryptography & Security
*   **Built-in Crypto:** Includes pure Lua implementations of SHA-256 and HMAC algorithms.
*   **Secure RPC:** Implements nonces, timestamp windows, stream XOR encryption, and MAC verification for secure remote procedure calls (RPC) over rednet to prevent packet spoofing and replay attacks.
*   **Randomization:** Seeds a custom random number generator using system time, computer ID, and hashing.

### 3. Economic & Monetary Policy
*   **Interest Rates:** Automated interest accrual for savings, checking, CDs, and loans.
*   **Taxation:** Progressive income tax brackets ranging from 0% to 10% based on earnings, alongside transaction taxes.
*   **Universal Basic Income (UBI):** Optional system to distribute weekly stipends to active citizens.
*   **Money Supply Management:** Features supply targets to dynamically adjust top tax brackets if the money supply inflates or deflates past specific thresholds.
*   **Item Backing:** The currency can be backed by physical commodities like Diamonds, Netherite, Gold, and Emeralds at fixed rates.

### 4. Player Earnings & Progress System
*   **Activity-Based Pay:** Players earn a survival wage supplemented by specific in-game actions:
    *   **Combat Pay:** Bounties for killing hostile mobs (tiered by difficulty) and massive payouts for bosses (Ender Dragon, Wither).
    *   **Exploration Bonus:** Payouts based on blocks traveled, with multipliers for exploring the Nether or End.
    *   **Builder Bonus:** Rewards for placing structural blocks.
    *   **Danger Pay:** Compensation for taking damage and surviving.
*   **Streak Mechanics:** Daily login and activity streaks multiply base earnings (up to 2.5x for a "Veteran" 365-day streak).
*   **Death Penalty & Insurance:** Dying drops the player's streak tier. Players can purchase death insurance to mitigate the streak loss.
*   **Progress Catalog:** Bounties for one-time milestones (first diamond, entering the Nether, registering a base, etc.).

### 5. Vanguard Ranks & Civic Jobs
*   **Military Payroll:** Fully integrated payroll system for the "Vanguard" military structure, ranging from Enlisted (E-1) to General (O-10), with weekly automated payouts.
*   **Civic Payroll:** Support for civilian government jobs with annual salaries translated to daily payouts.

### 6. Factions & Multisig Transactions
*   **Corporate/Faction Accounts:** Groups can form factions with shared treasury accounts.
*   **Multisignature Approvals:** Large transfers from faction accounts require multisig approval from a configurable threshold of members, generating network notifications for pending votes.

### 7. Ledger & Data Integrity
*   **Immutable Ledger:** Every transaction, error, and system event is appended to a hashed ledger (`ledger.log`), creating a blockchain-lite chain of custody to detect tampering.
*   **Auto-Maintenance:** The system actively monitors disk space, performing automatic log rotation, archive pruning, and rolling backups to prevent the CC:Tweaked computer from running out of space and corrupting the database.

## System Requirements
*   A CC:Tweaked Advanced Computer or Server.
*   An attached Wireless or Ender Modem for secure RPC communication.
*   Sufficient disk space for the rolling JSON database and cryptographic ledger.

Deployment Workflow
The script automatically detects the state of your network and adjusts its installation process accordingly.

1. First-Time Setup (The Bank Server)
If the script detects no existing cryptographic keys, it assumes this is the primary bank server.

Download: Retrieves the monolithic vrb.lua script from Pastebin.

Keygen: Generates fresh, secure cryptographic keys (server.secret and admin.key).

Distribution Floppy: Writes these keys to a blank in-game floppy disk.

Initialization: Installs the computer as the server role, writes the startup file, and reboots.

IMPORTANT: The script will pause and force the server administrator to physically write down the generated keys on real-life paper. If the server is destroyed in-game and the keys are lost, the bank's database cannot be recovered.

2. Follow-Up Setup (Network Nodes)
If the script detects an existing deployment (via the insertion of the distribution floppy), it will configure the computer to join the VRB network.

Sneakernet Security: Reads the server.secret (and admin.key if applicable) from the physical distribution floppy, ensuring keys are never transmitted over easily intercepted wireless modems.

Role Selection: Prompts the user to assign a specific function to the computer.

Initialization: Copies the appropriate keys, writes the startup file, and reboots.

Available Node Roles
When setting up a follow-up computer, the bootstrap script allows you to configure it as one of the following:

[1] atm: Branch ATM - Touchscreen interface for players to access Checking/Savings accounts.

[2] admin: Vanguard Staff Terminal - Highly privileged terminal for managing the treasury, taxes, and payroll.

[3] scoreboard: Earnings Reader - Interfaces with a Command Computer to track player stats for activity-based pay.

[4] viewer: Public Economy Dashboard - Read-only display of market stats and the money supply.

[5] mint: Reserve Note Station - Kiosk for exchanging physical Minecraft items for digital currency.

[6] shop: Player-Run Vending Kiosk - Storefront connected to faction/corporate multi-signature accounts.

Troubleshooting & Emergency Commands
Partial Setup Recovery: If a server setup is interrupted before the startup file is written, the script will automatically detect the orphaned keys and offer to rebuild the distribution floppy without wiping the existing keypair.

Factory Reset (bootstrap --reset): Running the script with the --reset flag will destructively wipe the local /.vrb directory, keys, and startup files. Use this only if you intend to completely wipe a node or bank server.
"""

with open("vrb_bootstrap_readme.md", "w") as f:
f.write(content)

generate_bootstrap_readme()


Your markdown file is ready.
[file-tag: code-generated-file-83335951-2e52-4fb7-9c27-d30e4e6102c0]

The README has been formatted using clear headings, bullet points, and horizontal rules for scannability. It details the installation process, the dual-phase deployment workflow (Server vs. Follow-up Nodes), all available roles mapping directly to the Lua script's functions, and the required security procedures.

There is a file you can reference named "vrb_bootstrap_readme.md". Refer to this file by its name verbatim.
[source: 1]# Vanguard Reserve Bank (VRB) - Bootstrap Script v9.0

## Overview
This bootstrap script is the automated deployment and installation utility for the Vanguard Reserve Bank (VRB) system on CC:Tweaked in Minecraft. Because the main VRB system is a complex, monolithic script requiring strict cryptographic security, this bootstrap utility ensures a foolproof, streamlined installation process across multiple in-game computers in under 60 seconds per node.

---

## Installation & Usage

To install the VRB system on a new CC:Tweaked computer, run the following commands in the in-game terminal:

pastebin get YOUR_BOOTSTRAP_CODE bootstrap
bootstrap
(Note: You must edit the PASTEBIN_VRB_LUA variable in the script to match your specific pastebin upload before deploying.)

Deployment Workflow
The script automatically detects the state of your network and adjusts its installation process accordingly.

1. First-Time Setup (The Bank Server)
If the script detects no existing cryptographic keys, it assumes this is the primary bank server.

Download: Retrieves the monolithic vrb.lua script from Pastebin.

Keygen: Generates fresh, secure cryptographic keys (server.secret and admin.key).

Distribution Floppy: Writes these keys to a blank in-game floppy disk.

Initialization: Installs the computer as the server role, writes the startup file, and reboots.

IMPORTANT: The script will pause and force the server administrator to physically write down the generated keys on real-life paper. If the server is destroyed in-game and the keys are lost, the bank's database cannot be recovered.

2. Follow-Up Setup (Network Nodes)
If the script detects an existing deployment (via the insertion of the distribution floppy), it will configure the computer to join the VRB network.

Sneakernet Security: Reads the server.secret (and admin.key if applicable) from the physical distribution floppy, ensuring keys are never transmitted over easily intercepted wireless modems.

Role Selection: Prompts the user to assign a specific function to the computer.

Initialization: Copies the appropriate keys, writes the startup file, and reboots.

Available Node Roles
When setting up a follow-up computer, the bootstrap script allows you to configure it as one of the following:

[1] atm: Branch ATM - Touchscreen interface for players to access Checking/Savings accounts.

[2] admin: Vanguard Staff Terminal - Highly privileged terminal for managing the treasury, taxes, and payroll.

[3] scoreboard: Earnings Reader - Interfaces with a Command Computer to track player stats for activity-based pay.

[4] viewer: Public Economy Dashboard - Read-only display of market stats and the money supply.

[5] mint: Reserve Note Station - Kiosk for exchanging physical Minecraft items for digital currency.

[6] shop: Player-Run Vending Kiosk - Storefront connected to faction/corporate multi-signature accounts.

Troubleshooting & Emergency Commands
Partial Setup Recovery: If a server setup is interrupted before the startup file is written, the script will automatically detect the orphaned keys and offer to rebuild the distribution floppy without wiping the existing keypair.

Factory Reset (bootstrap --reset): Running the script with the --reset flag will destructively wipe the local /.vrb directory, keys, and startup files. Use this only if you intend to completely wipe a node or bank server.



