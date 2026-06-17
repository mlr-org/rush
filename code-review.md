# Code review: rush

## Summary
The rush package is, on the whole, a well-engineered Redis-backed distributed task engine: the crash-recovery primitives (BLMOVE-into-per-worker-pending-list, eviction-tolerant fetch paths, monotonic-counter gating in `wait_for_tasks()`) are thoughtfully designed and well commented, and the missing-hash regression tests directly target the hardening described in NEWS.
The dominant risk area is the lost-worker recovery path: three distinct non-atomic Redis sequences (`.fail_lost_tasks` using a stale `running_tasks` snapshot, `pop_task`'s unconditional `SADD running_tasks`, and the un-transactional state move in `finish_tasks`/`fail_tasks`) can leave a task in two terminal states or lose it entirely under a heartbeat false-positive.
None of these fire deterministically — they require a narrow timing window plus (mostly) opt-in heartbeats — so they are must-fix correctness defects rather than outright blockers.
A separate `empty_queue()`-on-empty-queue bug permanently leaks an unnamespaced Redis hash that even `$reset()` cannot reclaim (reproduced live during this review).
Beyond those, the findings are resource-cleanup gaps, a genuinely broken public signature (`push_failed_tasks`), and a long tail of consistency/style/documentation nits.
No blocking defects, but several required fixes before this should ship.

## Critical issues (blocking)
None found.

## Required changes

1. **`.fail_lost_tasks` double-states a task the worker already finished** — `R/Rush.R:1728-1756` — `running_tasks` is snapshotted once at the top of `detect_lost_workers()` (line 572) and passed down through several Redis round-trips.
   A worker that finishes a task (`SREM running_tasks` + `RPUSH finished_tasks`) after the snapshot but is then flagged lost is still in the stale snapshot, so `.fail_lost_tasks` runs an unconditional `SREM running_tasks` + `SADD failed_tasks` inside MULTI/EXEC.
   The `SREM` is a no-op but the `SADD` corrupts state: the key lands in both `finished_tasks` (list) and `failed_tasks` (set), so `fetch_tasks_with_state()` returns it twice and `n_finished_tasks + n_failed_tasks` double-counts.
   Commit ee39c36 introduced this by replacing a guarded `SMOVE` (a no-op when the key already left `running_tasks`) with the unconditional `SREM`+`SADD`.
   **Fix:** gate the move on the task still being running — use `SMOVE running_tasks failed_tasks key` (atomic, only moves if present), or only `SADD` keys whose `SREM` returned 1, or check `SMISMEMBER` against `finished_tasks` inside the transaction.
   **Important:** apply that gate only to keys sourced from the `running_tasks` snapshot.
   Keys recovered from the per-worker `pending_task` list (line 1732) were popped from the queue but never added to `running_tasks`, so an `SMOVE`/`SREM-returned-1` guard would make them no-ops and the task would be lost — those keys must still be failed unconditionally.
   The fix must distinguish the two key sources, not blanket-gate them.

2. **`pop_task` unconditionally re-adds a recovered task to `running_tasks`** — `R/RushWorker.R:132-150` — The pending→running transition is split across BLMOVE, a separate `write_hashes`, and a separate `MULTI { LPOP pending; SADD running_tasks key }`.
   If `detect_lost_workers()` (via the heartbeat false-positive path) recovers the key from the pending list — `SADD failed_tasks key`, `DEL pending` — in the window before the MULTI, the worker's `LPOP` becomes a no-op but `SADD running_tasks key` still runs (MULTI gives no conditional logic; the `SADD` does not depend on the `LPOP` result).
   The still-alive worker then evaluates the task and calls `finish_tasks`, leaving the key in `failed_tasks` and `finished_tasks` simultaneously — double-processed and double-counted.
   **Fix:** make the running transition conditional on the pop.
   Use a Lua `EVAL` that `LPOP`s pending and only `SADD`s to `running_tasks` if the pop returned the expected key (and the key is not already in `failed_tasks`); if pending is empty, return NULL so the worker skips the already-recovered task.

3. **`finish_tasks`/`fail_tasks` use a non-transactional pipeline for the state move — silent task loss on mid-move crash** — `R/RushWorker.R:212-217` (and the identical `fail_tasks`, 242-252) — `r$pipeline(SREM running_tasks; RPUSH finished_tasks)` batches into one round-trip but is **not** a transaction.
   If the worker is killed or the connection drops between `SREM` being applied server-side and `RPUSH` being delivered, the key is removed from `running_tasks` but never appears in `finished_tasks`.
   Recovery cannot reclaim it: `.fail_lost_tasks` joins only on `running_tasks` and the pending list, and the key is now in neither, so the task is silently and permanently lost (and `wait_for_tasks` can hang if the worker survives the transient loss).
   Notably `.fail_lost_tasks` (`R/Rush.R:1751`) wraps the very same `SREM`+`SADD` move in MULTI/EXEC, so the unwrapped version here is an inconsistency that signals an oversight.
   **Fix:** wrap the move in MULTI/EXEC like the recovery path: `r$pipeline(.commands = c(list("MULTI"), list(c("SREM", ...), c("RPUSH", ...)), list("EXEC")))`.
   Apply to both methods.

4. **`empty_queue()` on an empty queue leaks a permanently-orphaned, unnamespaced hash** — `R/Rush.R:887-918` — When the queue is empty, `LRANGE` returns nothing so `keys` is NULL.
   `write_hashes(condition = conditions, keys = NULL)` then takes the auto-generate branch (`n_hashes = max(lens) = 1`, `keys = UUIDgenerate(n = 1)`) and writes the default `condition` to a brand-new bare-UUID hash with **no `network_id` prefix**.
   The outer `keys` stays NULL (the `write_hashes` return is not captured) so the subsequent `SADD` loop is a no-op; the hash is registered in no list/set and, being unnamespaced, never matches `network_id:*`, so `$reset()` and every cleanup path miss it.
   **Reproduced live during this review:** `rush$empty_queue()` on an empty queue raised `DBSIZE` from 0 to 1, creating a bare `bf37a267-…` hash that still `EXISTS` after `rush$reset()`.
   Reachable directly and via the deprecated `$fail_tasks()`, which calls `empty_queue()` unconditionally.
   **Fix:** add `if (!length(keys)) return(invisible(self))` immediately after the LRANGE/DEL, before `write_hashes`.

5. **`push_failed_tasks` has a required argument after a defaulted one — unusable positionally and contradicts its own docs** — `R/Rush.R:860` — The signature is `function(xss, xss_extra = NULL, conditions)`.
   The natural call `push_failed_tasks(xss, conditions)` binds the second arg to `xss_extra`, leaving `conditions` unbound, and errors with `argument "conditions" is missing, with no default`.
   Every sibling `push_*`/`finish_*` method takes its mandatory payload as the second positional arg, and the class-level roxygen (line 20) even advertises `$push_failed_tasks(xss, conditions)` — the broken positional form.
   **Fix:** reorder to `function(xss, conditions, xss_extra = NULL)`, update the `@param` order, and add a NEWS bullet (public-signature change).

6. **Heartbeat process and heartbeat key never stopped on normal worker termination** — `R/RushWorker.R:263-273` — `set_terminated()` only `SMOVE`s the worker from `running_worker_ids` to `terminated_worker_ids`.
   It does not push the kill key, `DEL` the heartbeat key, or `SREM` it from `heartbeat_keys`.
   The heartbeat is a `callr::r_bg(..., supervise = TRUE)` process reaped only when the worker R process exits — but the default `mirai` backend reuses a long-lived daemon, so when one `start_worker` call returns the daemon stays up and the heartbeat process keeps `EXPIRE`-ing its key forever.
   Worker ids are regenerated per `start_workers()` call, so each round on a reused daemon leaks a live OS process, a Redis connection, and a Redis key, with no recovery (a continuously-refreshed key never expires, so the opportunistic `heartbeat_keys` SREM never fires).
   **Fix:** in `set_terminated()`, `LPUSH` the kill key (or `DEL` the heartbeat key) and `SREM` the heartbeat key from `heartbeat_keys`, reusing the existing kill-key handling in the heartbeat loop.
   Gated on heartbeats being enabled (opt-in), but a real accumulating leak when they are.

## Suggestions

1. **`push_running_tasks` issues `SADD running_tasks` and `RPUSH all_tasks` as two separate non-pipelined commands** — `R/RushWorker.R:174-176` — It is the only create-task method that does not batch its two index writes; `push_tasks`, `push_finished_tasks`, and `push_failed_tasks` all use a single `r$pipeline`.
   If the worker dies between the two commands, the task is in `running_tasks` but absent from `all_tasks`, so `$tasks`/`$n_tasks` under-count it and `$reset()` (which DELs only `all_tasks` keys) never cleans the hash, leaking it.
   Crash recovery still works (it reads `running_tasks` + `worker_id`), so the damage is an audit-list inconsistency plus a tiny leaked hash.
   **Fix:** `r$pipeline(.commands = list(c("SADD", running_tasks, keys), c("RPUSH", all_tasks, keys)))`, matching the siblings.
   (Pipelining shrinks but does not eliminate the window; MULTI/EXEC would be strictly atomic.)

2. **Heartbeat false positive fails a live worker's in-flight task** — `R/Rush.R:611-637` — Liveness is inferred solely from `EXISTS` on the heartbeat key (TTL = `3 × heartbeat_period`), with no re-confirmation or second probe before `.fail_lost_tasks` destroys the task's state.
   Because `finish_tasks` has no membership gate, a falsely-flagged-but-alive worker that finishes concurrently double-states the task (feeds Required #1/#2).
   The 3× TTL margin and opt-in nature make a false positive uncommon, but inevitable over a long run.
   **Fix:** require two consecutive detections (or a short grace recheck) before failing, and/or make `.fail_lost_tasks` membership-gated (Required #1) to bound the damage of any false positive.

3. **`$reset()` leaks per-worker `pending_task` lists** — `R/Rush.R:662-688` — The per-worker DEL loop deletes the info hash, `terminate`, `kill`, and `events` keys but omits `pending_task`.
   A key stranded in `pending_task` by a mid-pop crash (where `detect_lost_workers` never ran for that worker) survives `reset(workers = TRUE)` as an orphan.
   **Fix:** add `c("DEL", private$.get_worker_key("pending_task", worker_id))` to the per-worker DEL list.

4. **Per-worker `events` log lists grow without bound** — `R/AppenderRedis.R:83-96` — Each worker `RPUSH`es every log event to its `<worker_id>:events` list with no `LTRIM`, TTL, or maxlen; the only deletion is in `$reset(workers = TRUE)`.
   On a long run with `info`/`debug` thresholds the list grows monotonically in Redis, and `read_log()`'s `LRANGE 0 -1` gets progressively more expensive (`print_log()` is incremental and unaffected).
   Opt-in via `lgr_thresholds`.
   **Fix:** cap the list after `RPUSH` (e.g. `LTRIM key -<max> -1`) or set a maxlen, optionally exposed as an option, and document the growth.

5. **`$reset(workers = FALSE)` retains the `events` log lists across rounds** — `R/Rush.R:650-703` — When `workers = FALSE` the entire worker-key cleanup block is skipped, so the per-worker `events` lists (task-cycle data, not worker identity) accumulate across data resets with no clearing path short of a full reset; the method doc only says "only delete the data." Most other retained keys (info hash, heartbeat, worker-id SETs) are correctly-kept live state.
   **Fix:** either document that event logs are retained, move events-list deletion out of the `if (workers)` branch, or add a `clear_logs()` method.

6. **`empty_queue()` documents failing running tasks but only drains the queue** — `R/Rush.R:877-939` — The deprecated `fail_tasks` docstring says it moves tasks "from queued and running to failed," but it delegates to `empty_queue()`, which only touches `queued_tasks`; running tasks are untouched, and `fail_tasks` also silently discards its `keys`/`conditions` args.
   Both are deprecated.
   **Fix:** correct the docstring to match `empty_queue`, or fail running tasks too if the old contract must hold during deprecation.

7. **`start_local_workers` leaks the temp args `.rds` file when the worker fails to launch** — `R/Rush.R:289-303` — Cleanup (`unlink`) lives inside the spawned Rscript expr, so the file is removed only if the worker actually starts and reaches `unlink()`.
   If `processx::process$new` throws, the process dies early, or `readRDS` errors, the file (which may contain the Redis config) is left in the manager's tempdir and accumulates across calls.
   **Fix:** register manager-side cleanup as a safety net, e.g. `on.exit(unlink(args_file), add = TRUE)` around the spawn or `tryCatch`, keeping the worker-side `unlink` for the happy path.

8. **`fetch_tasks`/`read_hashes` silently drop a hash whose every requested field is absent** — `R/Rush.R:1260-1291, 1665-1672` — When `HMGET` returns all-NULL (an existing key with none of the requested fields), the flattened result is NULL and `.fetch_tasks` treats it identically to an evicted key, dropping the row with a misleading "Removing N task(s) with missing data" warning.
   Reproduced: `fetch_queued_tasks(fields = "ys")` returns 0 rows despite the tasks existing.
   Not reachable on any default/internal path (all defaults include `xs`), only via a caller passing a non-matching custom `fields` set.
   **Fix:** distinguish eviction from unset fields via `EXISTS`/`HLEN`; keep existing keys (with NA columns) instead of dropping them.

9. **Finished-task cache returns stale NA columns when `fields` differ between fetch calls** — `R/Rush.R:1686-1724` — The cache stores already-read rows and applies `fields` only to newly consumed keys.
   A later `fetch_finished_tasks(fields = c("xs","ys"))` after an earlier `fields = "xs"` leaves the earlier rows' `ys` permanently NA (they are never re-read).
   Narrow: only bites consumers that vary `fields`.
   **Fix:** document/assert a stable `fields` set per Rush object, or cache by `(key, field)` so a wider later call re-reads the missing columns.

10. **`stop_workers` hard-errors if any requested id is not currently running** — `R/Rush.R:487` — `assert_subset(worker_ids, self$running_worker_ids)` aborts when a caller passes an already-terminated or stale id (`Must be a subset ... additional elements {ghost}`), even though stopping is naturally idempotent/best-effort; a loop stopping a known set aborts on the first id that finished on its own.
    The default `worker_ids = NULL` path is safe.
    **Fix:** use `intersect(worker_ids %??% self$running_worker_ids, self$running_worker_ids)` (after asserting it is a character vector) so non-running ids are ignored.

11. **`start_worker()` gives a cryptic `unserialize(NULL)` error when `start_args` is missing** — `R/start_worker.R:113-117` — A missing `start_args` key (worker started before config was pushed, `$reset()` between push and start, or eviction) makes `GET` return NULL and `unserialize(NULL)` fail with `'connection' must be a connection`.
    Unlike the hash read paths, this one skips `safe_bin_to_object`.
    **Fix:** add `if (is.null(bin_start_args)) error_config(...)` with an actionable message before `unserialize`.

12. **Empty `xss` to `push_*` silently swallows a Redis "wrong number of arguments" error** — `R/Rush.R:793-813` — `assert_list(xss, types = "list")` permits `list()`; `write_hashes` then returns `character(0)` and `RPUSH all_tasks character(0)` is rejected by Redis, but because it runs inside `r$pipeline` the error is returned as a value object rather than raised, so it is swallowed.
    Benign outcome (no task pushed) but hides genuine errors; applies to all `push_*` methods.
    **Fix:** short-circuit with `if (!length(xss)) return(invisible(character(0)))` at the top of each method.

13. **`pop_task` makes 4 sequential round-trips; the `worker_id` HSET can fold into the MULTI** — `R/RushWorker.R:132-155` — On the hottest path (once per task), the `worker_id` HSET (step 2, via `write_hashes`) has no dependency preventing it from running inside the step-3 transaction.
    Folding it in (ideally pipelining the whole `MULTI/HSET/LPOP/SADD/EXEC` as `.fail_lost_tasks` already does) removes a round-trip per task without changing recovery semantics (recovery uses the pending-list key name, not the hash field).
    **Fix:** move the `HSET key worker_id object_to_bin(self$worker_id)` into the transaction, serialized as `read_hashes` expects.

14. **`worker_info` issues N sequential `HMGET` round-trips instead of one pipeline** — `R/Rush.R:1517-1522` — `map(self$worker_ids, function(id) r$command(c("HMGET", ...)))` is W blocking round-trips where one pipeline suffices; every other multi-key path in the file uses `r$pipeline`, and `read_log()` is a near-identical pipelined analog.
    Read on the control path (`stop_workers`, user inspection), so cost scales with W × RTT.
    **Fix:** build the `HMGET` commands and send them in one `r$pipeline`, then `set_names(rbindlist(res), fields)`.

15. **Dead `reset_cache = TRUE` branch in `.fetch_cached_tasks` omits `.n_seen_results`** — `R/Rush.R:1686-1693` — The branch resets `.cached_tasks` and `.n_consumed_tasks` but not `.n_seen_results` (unlike the public `reset_cache()`).
    If ever invoked, `fetch_new_tasks` would compute a negative `n_new_results`, the `if (!n_new_results)` guard would fall through, and `tail(.cached_tasks, <negative>)` would drop rows from the front.
    Latent only because both call sites use the default `FALSE`.
    **Fix:** remove the unused parameter, or add `private$.n_seen_results = 0` to the branch.

16. **`store_large_object` captures a multi-element `name` for inline expressions** — `R/store_large_object.R:22-26` — `deparse(substitute(obj))` returns a length>1 vector for a multi-line inline argument, violating the documented single-label `name` contract and producing a malformed `rush_large_object`.
    The single internal caller passes a bare symbol (safe), and `name`/`id` are never read downstream.
    **Fix:** `deparse1()` / `paste(collapse = "")`, or simply drop the unused `name`/`id` fields and return `list(path = path)` with the class.

17. **`rush_plan()` compares `worker_type` before validating it** — `R/rush_plan.R:52-60` — `if (worker_type == "local")` runs before the only `assert_choice` (line 60), so `worker_type = NULL` aborts with `argument is of length zero` and a length>1 vector with `the condition has length > 1` — opaque base-R errors that violate the house rule on validating user-facing args.
    **Fix:** add `assert_choice(worker_type, c("mirai","processx","script","local","remote"))` (or at least `assert_string`) at the top before the deprecation remapping.

18. **`warn_deprecated("local"/"remote")` produces a context-free message** — `R/rush_plan.R:52-58` — Renders `"local is deprecated and will be removed in the future"` with no indication it refers to the `worker_type` value, unlike other call sites that pass descriptive strings.
    **Fix:** `warn_deprecated('worker_type = "local"')` / `'worker_type = "remote"'`.

19. **`start_worker_timeout = 0` makes `wait_for_workers` error immediately without checking** — `R/rush_plan.R:50` — `lower = 0` permits `0`, which flows into a `while (elapsed < timeout)` guard that is false on the first evaluation, so the registration check never runs and `error_timeout()` fires even if workers are already registered.
    **Fix:** perform at least one registration check before the time comparison (do-while shape), require a small positive lower bound, or document that 0 means "fail immediately."

20. **Malformed `#nolint` annotation suppresses nothing useful** — `R/Rush.R:1299` — Written without the space or `next`, it is a same-line directive sitting alone on its own comment line, so it suppresses lints on line 1299 (which holds only the comment), not the `safe_bin_to_object` call below, and violates the house `# nolint next` convention.
    **Fix:** delete it, or use `# nolint next` if a suppression is genuinely needed.

21. **Read-only active bindings omit the `rhs`/`assert_ro_binding` pattern** — `R/Rush.R:1416-1505` — The 13 bindings from `worker_ids` through `n_tasks` take no argument, so an accidental `rush$tasks = x` raises the cryptic base error `unused argument` instead of the intended `assert_ro_binding` message used by their siblings (`network_id`, `connector`, etc.).
    No corruption, but inconsistent with the documented mlr3 convention.
    **Fix:** give each a `function(rhs)` with a leading `assert_ro_binding(rhs)`.

22. **Testing/coverage gaps** — Several missing-test cases worth adding, each pinning behavior the recent hardening relies on but currently leaves unasserted: `fetch_tasks_with_state()` missing-hash path (`tests/testthat/test-RushWorker.R:482-516`); the `wait_for_tasks` cheap-counter short-circuit boundary (`R/Rush.R:1131-1142`); the `pop_task` crash window between BLMOVE and `write_hashes` without the `worker_id` field (`tests/testthat/test-Rush.R:840-879`); the deprecated `Rush$fail_tasks()` deprecation warning; `write_hashes`/`read_hashes` round-trip of NA / empty-string / inner-NULL field values (`tests/testthat/test-RushWorker.R:78-175`); and the heartbeat partial-failure case where one of N workers expires while others stay alive (`tests/testthat/test-Rush.R:799-838`).

23. **`start_rush_worker()` test helper silently ignores its `n_workers` argument** — `inst/testthat/helper.R:29-34` — The helper advertises `n_workers` but always constructs exactly one `RushWorker`; a future author writing `start_rush_worker(n_workers = 3)` would silently get one worker.
    All current call sites use the default, so no test is broken today.
    **Fix:** remove the unused parameter, or honor it by constructing `n_workers` instances.

## Noted (minor)

- **Dead DEL of `terminate_on_idle`/`local_workers`** — `R/Rush.R:684-685` — both keys are never written anywhere; the DELs are no-ops left over from removed functionality.
  Remove them.
- **`heartbeat_keys` SET member cleaned only opportunistically** — `R/Rush.R:611-638` — reaped only when `detect_lost_workers()` runs after expiry; tiny, bounded.
  Add an `SREM` at termination to be tidy (relates to Required #6).
- **All-NULL-field drop is also reachable via `fetch_tasks_with_state`** — same root cause as Suggestion #8; noted for the duplicate `.fetch_cached_tasks` path (`R/Rush.R:1707`).
- **`detect_lost_workers` walks an `errorValue` as if it were log lines** — `R/Rush.R:581` — for a crashed/interrupted mirai, `m$data` is a scalar `errorValue`, so `walk(..., lg$error)` logs one cryptic integer; the human-readable `message` is already derived just below.
  Drop the `walk` or log `message`.
- **`read_log` `@return` documents a `message` column actually named `msg`** — `R/Rush.R:723-724` — `tab$message` is NULL; fix the doc to `msg` (and note `rawMsg`/`caller`).
- **`store_large_object` `.rds` files are never auto-cleaned** — `R/store_large_object.R:19-28` — documented as caller responsibility, but asymmetric with the now-cleaned `start_local_workers` args file.
- **`start_worker()` coerces only `port`/`timeout`; a bad port silently becomes NA** — `R/start_worker.R:73-78` — `db` passes through as a string (benign) and `as.integer("not-a-port")` yields NA with only a warning.
  Coerce `db` too and `assert_int(port, lower = 1)`.
- **Public `read_hashes`/`read_hash` lack `assert_*` on `keys`/`fields`/`flatten`** — `R/Rush.R:1241-1245` — violates the public-API assertion convention (the sibling `write_hashes` asserts).
  Add `assert_character`/`assert_flag`/`assert_string`.
- **Base `setNames()` used instead of mlr3misc `set_names()`** — `R/Rush.R:1274, 1297, 1322` — the only three base calls in a file that otherwise uses `set_names`.
- **Redundant `return(invisible(keys))`** — `R/Rush.R:812, 844, 874` and `R/RushWorker.R:178` — house style prefers a bare `invisible(keys)`; siblings already do.
- **`%??% 0` fallback is dead and uses a double literal** — `R/Rush.R:1397, 1405, 1413, 1476, 1483, 1490, 1497, 1504` — `SCARD`/`LLEN` never return NULL, so the branch is unreachable; if kept, use `0L` to honor the documented `integer(1)`.
- **`reset(workers = FALSE)` pending/per-worker survival is untested** — `tests/testthat/test-Rush.R:323-346` — a pending entry surviving a data reset could let `detect_lost_workers` resurrect a phantom failed task referencing a deleted hash; add coverage.
- **`wait_for_tasks` 3-counter poll could be one pipeline** — `R/Rush.R:1131-1142` — `SCARD`+`LLEN`+`SCARD` as three RTTs per spin; optional `MULTI`/pipeline to cut to one.
  The counter-gating itself is correct and good.
- **Doc typo "data base" → "database"** — `R/AppenderRedis.R:4, 28` — fix and re-document.

## What's good
- **`finish_tasks` write ordering** (`R/RushWorker.R:199-217`) writes the `ys` hash *before* the `SREM`+`RPUSH` list move, so a finished key is never observable without its result payload — the manager's LRANGE-then-HMGET read can never see a finished task with a missing result.
- **`pop_task`'s BLMOVE-into-per-worker-pending-list crash-recovery primitive** (`R/RushWorker.R:125-155`) is genuinely well designed and well commented: it closes the window where a popped-but-not-yet-running task would be silently lost, and `.fail_lost_tasks` unions the running snapshot with a live `LRANGE` of the pending list to reclaim it.
  (The residual defects are the non-conditional re-add and the snapshot staleness, not the concept.)
- **The eviction-tolerant fetch paths** (`.fetch_tasks`/`.fetch_cached_tasks`, `R/Rush.R:1655-1725`): missing hashes are detected with `map_lgl(is.null)` and dropped in lockstep with their keys so rows stay aligned, and `.n_consumed_tasks` deliberately advances even for dropped tasks so evicted entries are never re-read.
  The comment explaining why the counter can exceed `nrow(.cached_tasks)` is exactly right.
- **`wait_for_tasks`' cheap-counter gate** (`R/Rush.R:1120-1146`): gating the expensive `LRANGE`+`SMEMBERS` membership check behind the monotonic `n_finished + n_failed` counter, with `n_seen = -1L` forcing a full first-iteration check, is correct (monotonic counters cannot miss a completion) and well-commented.
- **`safe_bin_to_object`** (`R/helper.R:33-38`) cleanly centralizes the NULL-reply guard before `redux::bin_to_object`, used consistently across the read paths.
- **`AppenderRedis$flush`** (`R/AppenderRedis.R:83-96`) documents *why* no local error handling is needed (lgr's `Logger$log` wraps appenders in `tryCatch` and demotes to warnings) — exactly the non-obvious rationale worth a comment.
- **`worker_info`'s state-set read** (`R/Rush.R:1529-1532`) wraps the running/terminated SET reads in a single MULTI/EXEC for a consistent, untorn snapshot.
- **Security-conscious worker launch**: serializing args to an RDS file and passing only `deparse(args_file)` correctly handles Windows paths and quotes without a shell-injection hazard (`R/Rush.R:289-296`), and `worker_script()` redacts the Redis password before logging while returning the real command (`R/Rush.R:408-416`).
- **The heartbeat startup handshake** (`R/RushWorker.R:74-94`) busy-waits on `TTL > 0` with an `is_alive()` check, a 5s timeout, and child-stderr surfacing, and orders `heartbeat_keys` registration before `running_worker_ids` so `detect_lost_workers` can never see a running worker whose heartbeat is not yet tracked.
- **The missing-hash regression tests** (`test-Rush.R:1071-1130`) directly target the consumed-vs-cached counter split — asserting `.n_consumed_tasks == 5` after deleting a finished hash, that repeats do not re-read, that a blocking `fetch_new_tasks` is not spuriously unblocked by a dropped hash, and that `reset_cache` rebuilds cleanly — and the pending-state recovery test (`test-Rush.R:840-879`) reconstructs the BLMOVE crash window with a raw Redis command.
- **`start_worker.R` sink handling** (lines 52-66) reverts each sink before closing its connection and reverts only its own sink — the correct fix for the prior on-exit error.

## Verdict
**Request Changes** — no blocking defects, but six required fixes (three non-atomic lost-worker recovery races, a permanent Redis-key leak reproduced live, an unusable public signature, and a heartbeat-process leak) must land before this ships.

---
*Review assisted by the [critical-code-reviewer skill](https://github.com/posit-dev/skills/blob/main/posit-dev/critical-code-reviewer/SKILL.md), run as a multi-agent workflow: 7 dimension reviewers + 5 per-file deep-reads → 67 raw findings → adversarial verification (60 survived) → synthesis. Required #1 (`.fail_lost_tasks`) and Required #4 (`empty_queue` leak) were additionally re-verified by hand against the source; #4 was reproduced live against a running Redis instance.*
