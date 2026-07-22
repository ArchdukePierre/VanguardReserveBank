# Vanguard Reserve Bank (VRB) - Version 9.0.0

## Important Note on Code Formatting
If you are reviewing the source code, you will notice it is formatted as an ugly, monolithic, and completely commentless file. This was not the original design. At the time of development, ArchdukePierre realized that the script had completely maxed out the internal storage and memory capacity of the CC:Tweaked computer. To fit the banking system into the computer and ensure it would not crash the Minecraft world or cause severe lag, all comments and formatting had to be cut out. It was not like this at conception, but was aggressively minimized out of absolute necessity.

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
