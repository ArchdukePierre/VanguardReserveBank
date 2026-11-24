# Architecture

## Layout

```
install.lua          one-command installer and updater
manifest.lua         file list with sizes and SHA-256, read by the installer
vrb/boot.lua         entry point, the `vrb` command
vrb/lib/             crypto, serializer, storage, ledger, network, client, config, pairing
vrb/server/          the bank: accounts, payments, credit, groups, commerce, earnings, payroll, community, admin, public
vrb/ui/              screen buffer, event loop, widgets, input flows
vrb/roles/           atm, admin, viewer, shop, mint, pos, scoreboard
vrb/tools/           doctor, config, backup, pairing helpers, reset
tests/               a headless CC:Tweaked model and the test suite
```

The installer copies only the files a role needs. A server gets `lib`, `server` and `tools`. An ATM gets `lib`, `ui`, `tools` and its own role.

## Data on the server

All state lives in `/.vrb/data`.

- `snap/` holds each collection split into 16 shard files (`accounts.0` to `accounts.15`). One record per line.
- `journal.N` is a write-ahead log. Every change is appended there first as one batch with a commit marker. A batch that is cut off by a crash has no marker and is ignored on the next start.
- `ledger.log` and `ledger/` hold the audit trail.

Records live in memory. A change marks its record dirty. After the server has handled the requests that are waiting, it writes one journal batch for everything that changed, then sends the replies. A reply is never sent before its change is on disk.

Account history is an append-only list. A batch carries the new entries only, each numbered, so replaying an old journal over a newer snapshot cannot duplicate an entry.

When the journal passes `compact_bytes` the server starts a new journal generation, rewrites the shards that changed (committing before each shard so a shard always holds committed state) and deletes the old journals. A crash at any point replays both generations over whatever shards were written.

If free space drops under `min_free_bytes` the server stops accepting writes and keeps answering reads. Players get a clear message. Nothing is deleted to make room.

## Ledger

Entries are buffered and written as blocks. A block header holds the first sequence number, the entry count and a hash: SHA-256 of the previous hash, a newline and the block body, cut to 32 hex characters. The head hash is kept in the database meta. Blocks are also written into the journal batch, so a crash between the two files is repaired on the next start. The log rotates at `ledger_max_bytes` and old files are kept until `ledger_keep_bytes`. Verification walks every retained file and compares the final hash with the head. It runs on a timer and on request, in slices.

## Money rules

Every balance change goes through `Bank:post`. It adds the amount to the balance and to a running sum on the account, and records a history entry. An account is consistent when `balance == base + sum`. `base` is zero for new accounts and the balance at import time for accounts migrated from v9. The audit checks this for every account in one pass.

## Network

Clients transmit to one channel derived from the network name. The server replies to the client's own channel. There is no lookup step and no broadcast discovery.

An envelope holds a nonce, a timestamp, a flag, a body and an HMAC-SHA256 over all of them. Bodies are encrypted with a SHA-256 counter stream unless the method is a public read. The server rejects stale timestamps, repeated nonces and bad MACs before it decodes anything. Requests carry an id. The server keeps each reply for two minutes, so a retry after a lost reply returns the stored answer and does not run the request again.

Admin requests carry an HMAC over the request id, method and timestamp, made with the admin key.

Each client channel gets a token bucket (burst 12, 4 per second). Packets over the limit are dropped before any crypto runs. The queue holds 256 requests.

The server pushes public stats to `channel + 1` every 20 seconds. Dashboards listen and never poll.

## Screens

`ui.screen` keeps a back buffer and a record of what each row last sent to the monitor. `flush` writes only the rows that changed, and only the changed span of each row. A screen that did not change writes nothing, so an idle monitor generates no network traffic to players.

## Pairing

Pressing P on the server opens a three minute window and shows a 12 character code. A new computer sends an HMAC made with a key derived from the code. The server answers with the secret encrypted under the same key. A code works once. Eight wrong attempts close the window. S makes a staff code that also hands out the admin key.
