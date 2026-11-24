# Vanguard Reserve Bank

A bank and economy system for ComputerCraft: Tweaked servers. Version 10.0.0.

One computer runs the bank and holds every account. ATMs, staff terminals, shop kiosks, a public dashboard, a pocket point of sale and an earnings reader are clients that talk to it over modems.

Version 10 is a rewrite of version 9. It removes the main sources of load that made version 9 lag a busy server, installs with one command and pairs computers with a code. Data from version 9 is imported on the first start.

The code was tested in a headless model of CC:Tweaked (see Tests), not in a running game. Run `vrb doctor` after installing, and `vrb scoreboard_test` once on the Command Computer.

## Install

You need HTTP enabled in the CC:Tweaked config (`http.enabled`). On each computer run:

```
wget run https://raw.githubusercontent.com/ArchdukePierre/VanguardReserveBank/main/install.lua
```

The installer asks what the computer is for, downloads only the files that role needs, and reboots into it.

1. Start with the bank server. Use an Advanced Computer with a wireless or ender modem. Pick **Bank server**. It makes the keys and asks for a network name.
2. After the reboot the server screen shows its status. Press **P** to open pairing. It shows a code like `7QK4-M2XH-9TBD`.
3. On every other computer run the installer, pick the role, and type the code. Press **S** instead of **P** on the server for a staff code, which also gives the computer the admin key. Staff terminals, the mint and the earnings reader need one.

A floppy disk also works. Press **F** on the server to write the keys to a disk in a drive, and the installer on the new computer reads them from it.

### Computers

| Role | Hardware | What it does |
| --- | --- | --- |
| Bank server | Advanced Computer, wireless or ender modem | Holds accounts, runs interest, payroll and the ledger |
| ATM | Computer, modem, Advanced Monitor (3x3 works well) | Customer screen: pay, bill, savings, loans, factions, shops and more |
| Staff terminal | As an ATM, plus a staff code | Accounts, policy, payroll, review queue, ledger, diagnostics |
| Public dashboard | Computer, modem, monitor | Money supply, rates, tax brackets and a feed of public events |
| Shop kiosk | As an ATM, optional chests | Sells one player shop's stock and can dispense it |
| Mint station | Staff computer, disk drive or printer | Issues physical Reserve Notes |
| Pocket POS | Advanced Pocket Computer with a modem | Shopkeeper tabs and billing |
| Earnings reader | Command Computer, staff code | Reads player statistics, pays earnings and salaries, delivers in-game messages |

## The server screen

| Key | Action |
| --- | --- |
| P | Open pairing for a normal computer |
| S | Open pairing for a staff computer |
| F | Write the keys, including the admin key, to a floppy disk |
| B | Back up the data to `/.vrb/backups` |
| V | Verify the whole ledger |
| A | Audit every account against its recorded entries |
| Q | Stop the server |

## Commands

Run `vrb` in the shell of any installed computer.

| Command | What it does |
| --- | --- |
| `vrb status` | Role, network, keys, modem, disk, and whether the bank answers |
| `vrb doctor` | Checks everything and says what to fix. On the server it also audits the accounts and verifies the ledger |
| `vrb update` | Downloads the latest files for this computer's role and reboots |
| `vrb join [staff]` | Pair with a code or a floppy |
| `vrb floppy [staff]` | Write keys to a disk (server only) |
| `vrb config` | Show, get, set and unset settings |
| `vrb backup`, `vrb restore <name>` | Back up or restore the bank data. Stop the server first |
| `vrb keys` | Print the keys for a paper copy |
| `vrb reset` | Delete the keys and data on this computer |

## Updating

Run `vrb update` on every computer. The server and the clients must run the same major version. Keys, data and settings are kept.

## Moving from version 9

Install version 10 on the server computer with the installer. Keep the existing `/.vrb` folder. On the first start the server finds `/.vrb/bank.db`, imports accounts, PINs, savings, certificates, loans, factions, shops, notes, earnings, ranks and jobs, and moves the old database and ledger to `/.vrb/legacy`. The old `server.secret` and `admin.key` keep working, so PINs and Reserve Notes stay valid.

Then run the installer on every ATM, terminal and kiosk. They need the new files. They also need the keys again only if they were wiped.

Delete `/.vrb/legacy` once you are satisfied. It is the old database and can be large.

Things that behave differently from version 9:

- Interest is posted once a day instead of every hour, as one summary ledger line plus one history line per account.
- Vanguard and civic pay stops while a member is on leave.
- Income tax brackets are one list. The supply target moves the top of that list.
- Account history keeps 20 entries per account by default. The ledger holds the long record.
- `admin_rotate_secret` is gone. Changing the network key now means re-pairing computers. PIN hashes and Reserve Note signatures use a separate key stored in the database, so they survive.
- Admin and server calls were renamed where they were duplicated. `docs/PROTOCOL.md` lists every call.

## ATM item deposits

The ATM shows DEPOSIT ITEMS only when it is told which two chests to use. Run these on the ATM computer, with the chest names from `peripheral.getNames()`:

```
set vrb.atm.drop <chest players put items in>
set vrb.atm.bank <chest the bank keeps them in>
```

The ATM credits only what it moved into the bank chest and puts the items back if the bank refuses the deposit. The backed items and their values are set in the staff terminal.

## Trust

Every computer that holds `server.secret` can talk to the bank, and the staff computers can also change anything. The server cannot check what an ATM claims to have received in a chest or what a shop kiosk dispensed. Keep the computers and chests of ATMs and kiosks where players cannot get at them, and give the staff code only to staff.

## Settings

Defaults are in `vrb/lib/defaults.lua`. Overrides live in `/.vrb/config` and are managed with `vrb config`:

```
vrb config set net.network myserver
vrb config set server.history_depth 30
vrb config set earnings.daily_tick_hour 3
```

Economy values such as rates, tax and UBI are changed from the staff terminal and stored in the database.

## Disk space

CC:Tweaked gives a computer 1,000,000 bytes by default (`computer_space_limit` in the server config). The server watches it.

With 150 players (301 accounts) the data was 377 KB: 123 KB of snapshots, the ledger and a journal of up to 64 KB. The server's program files are about 234 KB, an ATM's about 197 KB and the smaller clients' 113 to 199 KB. Version 9 put 387 KB on every computer. If you expect more players, raise `computer_space_limit`. History depth, ledger size and backup count are settings under `server`.

When free space falls under 32 KB the server pauses writes, keeps answering reads and shows a warning on the staff terminal. It does not delete anything to make room.

## Troubleshooting

Run `vrb doctor` first. It names the problem on most computers.

- **Clients say the bank is not responding.** Check that the server screen is up, that both modems are active (a wireless modem has a 64 block range, an ender modem has none) and that `vrb config get net.network` matches on both computers.
- **A staff terminal says the admin key does not match.** The computer was paired with a normal code. Run `vrb join staff` with a staff code, or `vrb keys` on the server and copy the key.
- **Changes are paused.** The server disk is nearly full. Delete `/.vrb/legacy`, delete old files in `/.vrb/backups`, or raise `computer_space_limit`.
- **A player is locked out.** Five wrong PINs lock an account for 15 minutes. Staff can unlock it in the accounts screen.
- **The ledger check fails.** Something edited the ledger files or the disk was damaged. Keep `/.vrb/data/ledger.log` and `/.vrb/data/ledger/` as they are and compare with a backup. Account balances do not depend on the ledger.
- **The server stopped.** `startup.lua` restarts it after 8 seconds. On the next start it replays the journal and repairs the ledger from it.
- **The earnings reader pays nothing.** Run `vrb scoreboard_test` on the Command Computer and look at the raw command output it prints.

## What was wrong with version 9

Measured in the test model in `tests/` with 150 accounts:

| | Version 9 | Version 10 |
| --- | --- | --- |
| Disk written per transfer | 169,716 bytes | 2,458 bytes, snapshot compaction included |
| VM instructions per transfer | 820,000 | 180,000 |
| Disk written to open 150 accounts | 28.7 MB | 0.5 MB |
| Monitor writes on an idle ATM | a full redraw twice a second | none |

The causes:

- Every change rewrote the whole database, history included, and then replaced the file. The cost grew with every account. When the disk filled up, each failed save ran a cleanup that deleted backups and ledger archives and then waited half a second inside the request handler.
- Every ATM and shop kiosk redrew its whole monitor twice a second even when nobody touched it. That keeps the monitor changing, so the server keeps sending terminal updates to every nearby player.
- The ledger was opened, hashed and appended once per entry. Several calls read and parsed the whole ledger. Dashboards polled two of them every 10 seconds.
- A retried request ran again. A transfer whose reply was lost could pay twice.
- The earnings reader sent about 100 server commands per player to objectives the code never created.
- The program was one 387 KB file that every computer loaded, including ATMs.

## Tests

The tests run the program itself in a headless model of CC:Tweaked (`tests/cc.lua`) with a 1 MB disk, timers, modems and monitors. You need Python and the `lupa` package:

```
pip install lupa
python tests/run.py tests/test_server.lua
python tests/run_all.py
```

| Test | Covers |
| --- | --- |
| `test_crypto.lua` | SHA-256, HMAC and cipher against published vectors, v9 PIN hash compatibility |
| `test_store.lua` | Journal replay, torn writes, interrupted compaction, ledger tamper detection, rotation, recovery, full disk |
| `test_server.lua` | Sign in, payments, tax, savings, bills, lockout, admin signing, restart |
| `test_economy.lua` | Certificates, loans, interest, factions, escrow, shops, notes, earnings, payroll, work orders |
| `test_resilience.lua` | Concurrent clients, flooding, replays, retried requests, full disk |
| `test_migrate.lua` | Importing a database made by the version 9 server |
| `test_pairing.lua`, `test_install.lua` | Pairing codes, the installer and first boot |
| `test_idle.lua`, `test_tools.lua` | Idle cost of the server, `vrb doctor`, `config`, `backup`, `restore`, `reset` |
| `test_ui.lua` | The screen toolkit and an idle monitor |
| `test_atm.lua`, `test_admin.lua`, `test_viewer.lua`, `test_shop.lua`, `test_mint.lua`, `test_pos.lua`, `test_scoreboard.lua` | Each program, driven with touch, keyboard and the mocked chests, disks, printers and Command Computer |

`tests/bench_new.lua <accounts> <transfers>` gives the new numbers. For the old ones extract the version 9 program with `git show a8005c1:VanguardReserveBank.lua > old.lua` and run `python tests/run.py tests/bench_old.lua old.lua <accounts> <transfers>`. `tools/make_manifest.py` rewrites `manifest.lua` and must run before a release. `tools/gen_protocol.lua` rewrites `docs/PROTOCOL.md`.

More detail is in `docs/ARCHITECTURE.md`, `docs/PROTOCOL.md` and `docs/UI.md`.

## License

MIT. See `LICENSE`.
