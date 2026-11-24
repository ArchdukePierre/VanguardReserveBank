# Changelog

## 10.0.0

Rewrite. The program is split into modules and each computer installs only what its role needs.

Server
- Write-ahead journal with group commit, sharded snapshots and background compaction. A transfer writes about 2 KB instead of the whole database.
- Hash-chained ledger written in blocks, rotated by size, repaired from the journal after a crash, verified in slices.
- Account history is an append-only list. Every balance change goes through one function and each account can be audited in one comparison.
- Requests are validated by a schema, rate limited per client, queued, handled in time slices and answered after the change is on disk.
- Retried requests return the stored reply and never run twice.
- A nearly full disk pauses writes and keeps reads working.
- Interest posts daily with one ledger line per run.
- Public dashboards receive a push every 20 seconds instead of polling.
- Imports a version 9 database on the first start.

Network
- One channel per bank network and no lookup broadcasts.
- Faster SHA-256 and HMAC with cached key state, a counter-mode cipher without per-byte string work, and plain MACed replies for public reads.

Setup
- One command installs any role. Computers pair with a code from the server or with a floppy.
- `vrb status`, `doctor`, `update`, `join`, `floppy`, `config`, `backup`, `restore`, `keys`, `reset`.

Screens
- Diff-based renderer. An idle monitor sends nothing. Text scale fits the monitor.
- New ATM, staff terminal, dashboard, shop kiosk, mint station, pocket POS and earnings reader.
- The earnings reader reads one `scoreboard players list` per player and creates its own objectives.

Behaviour changes are listed in the README under "Moving from version 9".
