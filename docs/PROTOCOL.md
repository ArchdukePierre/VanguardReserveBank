# Request reference

Generated from the method registry by `tools/gen_protocol.lua`. Do not edit by hand.

Every method returns a table with `ok` (boolean). On failure `err` holds a message for the player and `code` a short machine code.
Money is always integer cents. Session methods need `session` in the parameters.
Field types: `acct` account number, `cents` and `cents+` integer cents (second is greater than zero), `pin` four digits, `user` username, `text` up to 200 characters, `str` up to 64, `id` identifier, `int`, `int+`, `num`, `bool`, `tbl`, `days`. A trailing `?` means optional.

## Public methods

| Method | Parameters | Notes |
| --- | --- | --- |
| `auth` | `account_id:acct, branch:str?, pin:pin` | Sign in with an account number and PIN (writes) |
| `auth_by_owner` | `branch:str?, owner:user, pin:pin` | Sign in with a username and PIN (writes) |
| `civic_payroll_summary` |  |  |
| `get_shop` | `shop_id:id` | Public shop listing |
| `item_rates` |  | Items that back the currency |
| `list_catalog` |  | Achievements that pay a bounty |
| `list_ranks` |  | Vanguard pay grades |
| `list_work_orders` |  | Open Public Works bounties |
| `lookup` | `owner:user` | Find a player's payable account |
| `open_account` | `owner:user, pin:pin` | Open a checking and savings pair (writes) |
| `ping` |  | Server status and public rates |
| `public_ledger_tail` | `limit:int+?` | Recent anonymized public events |
| `public_stats` |  | Economy numbers for dashboards |
| `signout` | `session:str?` |  |
| `vanguard_payroll_summary` |  |  |

## Session methods

| Method | Parameters | Notes |
| --- | --- | --- |
| `approve_payment_request` | `request_id:id` | writes |
| `approve_pending_tx` | `pending_id:id` | writes |
| `auto_payment_request` | `request_id:id` | Pay a bill now, or arm it to pay when funds arrive (writes) |
| `balance` |  |  |
| `buy_from_shop` | `qty:int+?, shop_id:id, sku:str` | writes |
| `buy_insurance` |  | writes |
| `cancel_auto_payment_request` | `request_id:id` | writes |
| `cancel_civic_request` | `request_id:id` | writes |
| `cancel_insurance` |  | writes |
| `cancel_payment_request` | `request_id:id` | writes |
| `cancel_pending_tx` | `pending_id:id` | writes |
| `cancel_recurring` | `recur_id:id` | writes |
| `cancel_work_order_claim` | `order_id:id` | writes |
| `change_pin` | `new_pin:pin, old_pin:pin` | Change the PIN on both accounts (writes) |
| `claim_work_order` | `order_id:id` | writes |
| `create_escrow` | `amount:cents+, counterparty:acct, memo:text?` | Hold funds until you release or the other side refunds (writes) |
| `create_faction` | `m:int+, n:int+, name:text` | Charter a faction with a shared treasury (writes) |
| `create_recurring` | `amount:cents+, interval_sec:int+, memo:text?, remaining:int+, target_id:acct` | Schedule repeating payments (writes) |
| `create_shop` | `label:text` | writes |
| `deposit` | `amount:cents+, note:text?` | Cash deposit (only when player deposits are enabled) (writes) |
| `faction_add_member` | `faction_id:id, member:user` | writes |
| `faction_remove_member` | `faction_id:id, member:user` | writes |
| `history` | `limit:int+?` | Recent activity across checking and savings |
| `item_deposit` | `count:int+, item:str` | Credit backed items to checking (writes) |
| `list_cds` |  |  |
| `list_civic_jobs` |  |  |
| `list_factions` |  | Factions you belong to |
| `list_loans` |  |  |
| `list_my_escrows` |  |  |
| `list_my_recurring` |  |  |
| `list_my_sent_requests` | `include_decided:bool?` | Bills you sent |
| `list_my_shops` |  |  |
| `list_payable_accounts` | `limit:int+?, offset:int?, q:str?` | Payable accounts, filtered and paged |
| `list_payment_requests` | `include_decided:bool?` | Bills sent to you |
| `list_pending_tx` |  |  |
| `move_internal` | `amount:cents+, direction:chk_to_sav|sav_to_chk` | Move money between your checking and savings (writes) |
| `my_claims` |  |  |
| `my_earnings` |  | Latest daily earnings breakdown and streak |
| `my_earnings_history` | `limit:int+?` |  |
| `my_jobs` |  |  |
| `my_notif_subs` |  |  |
| `my_rank` |  |  |
| `open_cd` | `amount:cents+, days:days` | Lock funds in a certificate of deposit (writes) |
| `profile` |  | Checking and savings summary |
| `redeem_cd` | `cd_id:id` | writes |
| `redeem_note` | `note:tbl` | Redeem a Reserve Note into checking (writes) |
| `refund_escrow` | `escrow_id:id` | writes |
| `reject_payment_request` | `request_id:id` | writes |
| `release_escrow` | `escrow_id:id` | writes |
| `remove_shop_listing` | `shop_id:id, sku:str` | writes |
| `repay_loan` | `amount:cents+, loan_id:id` | writes |
| `request_civic_job` | `job_id:id` | writes |
| `request_loan` | `amount:cents+` | Borrow against collateral held in checking (writes) |
| `request_payment` | `amount:cents+, memo:text?, target_owner:user` | Bill another player (writes) |
| `self_audit` |  | Check that this account balance matches its posted entries |
| `set_notif_subs` | `subs:tbl` | writes |
| `set_shop_listing` | `item:str, item_id:str?, note:text?, price:cents+, shop_id:id, sku:str, stock:cents` | Add or update a listing (writes) |
| `submit_claim` | `evidence:text, progress_id:id` | Claim an achievement bounty (writes) |
| `transfer` | `amount:cents+, from_faction:id?, memo:text?, target_id:acct` | Pay another account (writes) |
| `withdraw` | `amount:cents+, note:text?` | Cash withdrawal (writes) |

## Admin methods

| Method | Parameters | Notes |
| --- | --- | --- |
| `admin_account_detail` | `account_id:acct` |  |
| `admin_account_history` | `account_id:acct, limit:int+?` |  |
| `admin_approve_civic_request` | `request_id:id` | writes |
| `admin_approve_claim` | `account_id:acct, override_bounty:cents?, progress_id:id` | writes |
| `admin_assign_job` | `account_id:acct, force:bool?, job_id:id` | writes |
| `admin_audit` |  | Check every account against its posted entries |
| `admin_backup` |  | Compact and copy the snapshot to /.vrb/backups (writes) |
| `admin_cancel_recurring` | `recur_id:id` | writes |
| `admin_complete_work_order` | `order_id:id` | writes |
| `admin_create_job` | `annual_cents:cents+, title:text` | writes |
| `admin_day_tick` | `force:bool?, mc_day:int` | Pay Vanguard and civic salaries once per Minecraft day (writes) |
| `admin_deactivate_shop` | `reason:text?, shop_id:id` | writes |
| `admin_delete_account` | `account_id:acct` | Close an owner's accounts; the balance goes to the treasury (writes) |
| `admin_delete_job` | `job_id:id` | writes |
| `admin_delete_work_order` | `order_id:id` | writes |
| `admin_diagnostics` |  | Live server health |
| `admin_earnings_state` | `owner:user` |  |
| `admin_edit_job` | `annual_cents:cents+?, job_id:id, title:text?` | writes |
| `admin_force_ubi` |  | writes |
| `admin_freeze` | `account_id:acct, frozen:bool` | writes |
| `admin_issue` | `account_id:acct, amount:int, reason:text` | Issue or recall money from the treasury (writes) |
| `admin_issue_note` | `account_id:acct, denomination:num` | Turn account funds into a physical Reserve Note (writes) |
| `admin_ledger_tail` | `limit:int+?` |  |
| `admin_list_accounts` | `all_kinds:bool?, filter:str?, limit:int+?, offset:int?` | Accounts, filtered and paged |
| `admin_list_civic_requests` |  |  |
| `admin_list_factions` |  |  |
| `admin_list_farm_flags` |  |  |
| `admin_list_job_holders` | `job_id:id` |  |
| `admin_list_jobs` |  |  |
| `admin_list_recurring` |  |  |
| `admin_list_vanguard` |  |  |
| `admin_list_work_orders` | `include_completed:bool?` |  |
| `admin_pending_claims` |  |  |
| `admin_post_work_order` | `bounty:cents+, description:text?, title:text` | writes |
| `admin_pull_notifications` | `clear:bool?, limit:int+?` | Pending in-game messages for the scoreboard reader (writes) |
| `admin_reject_civic_request` | `reason:text?, request_id:id` | writes |
| `admin_reject_claim` | `account_id:acct, progress_id:id, reason:text?` | writes |
| `admin_reset_pin` | `account_id:acct, new_pin:pin` | writes |
| `admin_review_flag` | `action:confirm|override, flag_id:id` | writes |
| `admin_set_balance` | `account_id:acct, confirm_extreme:bool?, new_balance:int, reason:text` | writes |
| `admin_set_catalog_item` | `bounty:cents?, id:id, label:text?, once:bool?, remove:bool?` | writes |
| `admin_set_earnings_enabled` | `enabled:bool` | writes |
| `admin_set_item_rate` | `item:str, rate:cents?` | writes |
| `admin_set_job_leave` | `account_id:acct, job_id:id, on_leave:bool` | writes |
| `admin_set_leave` | `account_id:acct, on_leave:bool` | Pause or resume Vanguard pay (writes) |
| `admin_set_policy` | `policy:tbl` | Change scalar policy values (writes) |
| `admin_set_pvp_enabled` | `enabled:bool` | writes |
| `admin_set_rank` | `account_id:acct, rank_id:id?` | Assign, change or clear a Vanguard rank (writes) |
| `admin_set_streak` | `days:int, owner:user` | writes |
| `admin_set_supply_target` | `enabled:bool?, high:cents?, low:cents?` | writes |
| `admin_set_tax_bracket` | `brackets:tbl` | Replace the income tax brackets (writes) |
| `admin_set_ubi` | `enabled:bool?, weekly:cents?` | writes |
| `admin_set_vanguard_enabled` | `enabled:bool` | writes |
| `admin_stats` |  |  |
| `admin_submit_snapshot` | `session_sec:num?, snapshots:tbl` | Daily stat snapshots from the scoreboard reader (writes) |
| `admin_unassign_job` | `account_id:acct, job_id:id` | writes |
| `admin_unlock` | `account_id:acct` | writes |
| `admin_verify_ledger` |  | Start or poll a full ledger verification |

