# Critical code review: rush 1.2.0

Scope: all of `R/` (2,903 lines), test suite structure, DESCRIPTION, NEWS.md, pkgdown config.
Findings below were verified against a live Redis 7 instance and the current sources where possible; anything I could not fully verify is marked **Verify**.

## Summary

This is a well-engineered package with a hard problem (distributed task state over Redis) and mostly honest solutions: the Lua first-writer-wins transitions, the two-phase pop with a pending list, and the cache counters are correct designs and — rarely for this kind of code — the *why* comments actually explain invariants instead of narrating syntax. The test suite (87 tests, segfault simulations, pending-task recovery, hash-eviction cases, a `wait_until()` helper instead of sleeps) is above average.

It is not clean, though. There is one genuine blocking defect (shell quoting in `$worker_script()` that silently corrupts credentials and is an injection vector), one verified crash-with-valid-input bug (fractional or large heartbeat values), and one silent-corruption time bomb (worker id collisions are possible and completely unguarded). The irony: the author demonstrably knows about the scientific-notation-in-Redis-commands pitfall (`R/Rush.R:1628` documents it for `.n_consumed_tasks`) yet the same pitfall ships live in the heartbeat path.

## Critical issues (blocking)

### 1. `$worker_script()` quoting is broken: silent credential corruption and shell injection

`R/Rush.R:430` wraps the generated expression in **double** quotes:

```r
script = sprintf("Rscript -e \"rush::start_worker(%s)\"", format_args(args))
```

while every embedded value (`R/Rush.R:398, 401, 408, 422, 425`) is quoted with `shQuote(value, type = "sh")`, which produces **single**-quoted strings designed for a single-quote context. Inside double quotes, `$`, `` ` ``, and `\` remain live shell syntax, and shQuote's `'\''` escape for embedded single quotes becomes literal garbage.

Verified: a password `pa$$word` produces a script that, when actually run through a shell, sends `pa15359word` (the `$$` expanded to the shell PID) to Redis. The failure is silent — the worker just fails to authenticate on a remote host with no process handle. Worse, a password or log path containing `$(...)` executes arbitrary commands on whatever machine the script is pasted into. Since the whole point of this method is "run this script anywhere," and the Redis password may be set by someone other than the person running the script, this is an injection vector, not just a correctness bug.

The existing test ("worker script contains the password but the log redacts it") does not catch this because the helper `start_script_worker()` (`tests/testthat/helper.R`) strips the outer double quotes with a regex and passes the inner string directly to `processx` — **the shell is never involved**. The one code path this method exists for is the one path the tests bypass.

**Fix:** build the R expression with `deparse()` per string (R-level escaping, double quotes), then quote the *entire* `-e` payload exactly once with `shQuote(expr, type = "sh")`. Add a test that runs the returned script through an actual `sh -c`, with a metacharacter password. Also state in the docs that the script targets POSIX shells (the current output is wrong for `cmd.exe` regardless).

## Required changes

### 2. Heartbeat arguments: validation admits values that are guaranteed to crash

`R/RushWorker.R:59-62` and `R/Rush.R:383-385` validate with `assert_number(heartbeat_period, lower = 1)` — fractional and large doubles pass. The heartbeat loop then issues `c("EXPIRE", heartbeat_key, heartbeat_expire)` (`R/heartbeat_loops.R:28`), and `c()` coercion produces `"4.5"` or `"1e+05"`, both of which Redis rejects.

Verified live: `RushWorker$new(..., heartbeat_period = 1.5)` fails with

```
Error in redis_command(ptr, cmd) : ERR value is not an integer or out of range
```

surfaced through the "heartbeat process terminated during startup" path — opaque, but at least fail-fast. Through `$worker_script()`, however, the crash happens **on the remote host**: the worker dies before registering, the manager has no handle, and the user sees nothing but a `wait_for_workers()` timeout.

The documentation (`man-roxygen/param_heartbeat_period.R`) already promises `integer(1)`; the assertion just doesn't enforce it. The existing validation test (`tests/testthat/test-RushWorker.R`, "heartbeat_period and heartbeat_expire are validated") checks lower bounds only.

**Fix:** `assert_int(..., coerce = TRUE)`/`assert_count` in both places, and build the command with `as.integer()` so scientific notation is structurally impossible — the same defense already applied to `.n_consumed_tasks` at `R/Rush.R:1629`.

### 3. Worker id collisions are unguarded and corrupt the network silently

Worker ids come from `ids::adjective_animal()` at `R/Rush.R:214`, `R/Rush.R:281`, and `R/RushWorker.R:51`. Verified: the generator samples **with replacement** — 3 duplicates in a single 10,000-draw call (combo space ≈ 1.7×10⁷). Nothing checks uniqueness: not within a call, not across `start_workers()` calls, and not against ids already registered in Redis — `RushWorker$new()` (`R/RushWorker.R:106-121`) ignores the `SADD` return value and happily `HSET`-overwrites an existing worker's info hash.

On collision, two OS processes share one logical identity: `processes_mirai[[id]]` resolves to only one of them, `$stop_workers()` kills one while the other keeps writing, heartbeat keys collide, `detect_lost_workers()` misattributes tasks, and the per-worker event log interleaves two processes. None of this errors — it just produces wrong results.

Probability is honest-but-real: ~0.03% per 100-worker network, ~3% at 1,000 workers. For a package whose stated purpose is powering large-scale asynchronous optimization across thousands of runs, this *will* fire eventually, and it will be undebuggable when it does.

**Fix:** deduplicate within a call (`while (anyDuplicated(ids))`), and treat registration as a claim: if `SADD worker_ids` returns 0, regenerate (or error). Alternatively suffix a short UUID fragment — readability is preserved and the collision space becomes astronomical.

## Suggestions

### 4. The heartbeat loop has zero fault tolerance

`R/heartbeat_loops.R:27-41`: any single transient Redis error (network blip, failover, restart) kills the loop, the key expires, and a *live* worker is declared lost — its running tasks are failed and, per the documented semantics, every subsequent result it produces is discarded. The class docs warn users to size `heartbeat_expire` for GC pauses, but the watchdog's own fragility is a bigger false-positive source and is undocumented. A `tryCatch` with bounded retry around the `EXPIRE`/`BLPOP` would make the reaper far less trigger-happy. Given that a false "lost" verdict destroys results, this deserves the robustness.

### 5. `detect_lost_workers()` can still report a cleanly terminated heartbeat worker as lost

`R/Rush.R:637` snapshots `running_worker_ids` before any checks; `set_terminated()` (`R/RushWorker.R:308-331`) SMOVEs and deletes the heartbeat key in a non-transactional pipeline. A worker terminating between the snapshot and the `EXISTS` probe (`R/Rush.R:684-695`) is matched via the stale snapshot and reported lost: ERROR log, inclusion in the return value, and a `.fail_lost_tasks()` sweep. Task state itself is protected by the Lua guards, so the damage is a wrong return value plus alarming log noise — but NEWS explicitly claims this exact behavior was fixed ("now returns only the worker ids it actually detected as lost... instead of also including workers that terminated cleanly while the method was running"). Re-read the running set inside the heartbeat branch, or intersect with a fresh `SMEMBERS` at match time.

### 6. Deprecation without a warning is not deprecation

The `extra` arguments in `push_tasks()` (`R/Rush.R:872-876`), `push_running_tasks()` (`R/RushWorker.R:186-190`), and `finish_tasks()` (`R/RushWorker.R:225-229`) are documented as deprecated but accepted in complete silence, while `start_remote_workers()` (`R/Rush.R:340`) correctly calls `warn_deprecated()`. Silent deprecations never become removable because no downstream caller ever finds out. Add `warn_deprecated()` on the `!is.null(extra)` path.

### 7. Task hashes are not namespaced — orphaned keys are unfindable

`write_hashes()` stores task hashes at bare `UUIDgenerate()` keys (`R/Rush.R:1255`). The only mapping from network to task keys is the `all_tasks` list; if a manager dies before `reset()`, the orphaned hashes carry no prefix, so they cannot even be `SCAN`ned for cleanup on a shared Redis. Prefixing task keys with `network_id:` costs a few bytes per key and makes operational cleanup possible. **Verify:** this may be a deliberate memory/latency tradeoff, but it deserves a documented justification if so.

### 8. `$start_workers()` daemon check is racy for remote daemons (Verify)

`R/Rush.R:185-198` errors when `status()$connections == 0`. Remote/SSH daemons connect asynchronously, so calling `start_workers()` promptly after `daemons(url = ...)` — the exact flow the class documentation advertises — can fail spuriously with "No daemons available." Local daemons connect fast enough to mask this. Consider polling briefly, or distinguishing "no daemons configured" from "none connected yet."

### 9. `print()` on a restored object throws a raw redux error

The `print()` method (`R/Rush.R:144-153`) performs five Redis reads. A `Rush` object restored from disk (the documented `$reconnect()` scenario, e.g. inside a saved bbotk archive) explodes with a bare `redis_command` error on the *first* thing anyone does with it — printing. Catch the connection failure and print a "disconnected — call `$reconnect()`" line instead.

## Noted (minor, mention once)

- **Missing `#' @include Rush.R` on `RushWorker`** (`R/RushWorker.R`) and no `Collate:` in DESCRIPTION. Verified that R6 resolves `inherit` lazily, so this is not a load-order bug — but it violates the project's own checked-in convention ("Derived classes must declare `#' @include ParentClass.R`"). One line.
- **Dead cleanup command:** `reset()` deletes `network:terminate` (`R/Rush.R:753`), a key nothing in the package ever sets. Grep confirms a single occurrence. Either legacy cruft to delete or a missing global-terminate feature.
- **Cargo-cult `require_namespaces(c("redux", "data.table"))`** in `AppenderRedis$initialize` (`R/AppenderRedis.R:70`) — both are hard Imports of rush; the runtime check is copied from lgr's optional-dependency appenders and can never fail here.
- **`read_log()` with zero events** returns a 0-row table *without* the documented columns (`R/Rush.R:811-830`), so `tab[level > 300]` on the empty result errors. Construct the empty table with the documented schema.
- **Misleading skip message:** `skip_if_no_redis()` reports "Redis is not available" even when Redis is running but `RUSH_TEST_USE_REDIS` is unset (`inst/testthat/helper.R`). Say which condition failed — a contributor with a running Redis will chase the wrong problem.
- **Spurious ERROR noise in `stop_workers(type = "kill")`:** a worker that exits between the running-set check and the kill makes `stop_mirai()`/`$kill()` return `FALSE`, logging "Failed to kill worker" (`R/Rush.R:550-553, 568-571`) for a worker that is simply already gone.

## What is genuinely good

- `R/lua_scripts.R:1-11`: the first-writer-wins invariant is stated precisely, and all four scripts implement it correctly. This is the hardest part of the package and it is right.
- The pending-list two-phase pop (`R/RushWorker.R:132-175`) closes the pop/crash window correctly, and the recovery path is tested ("a task lost in the pending state is recovered").
- Comments consistently explain constraints the code cannot show: the OS pipe-buffer rationale (`R/Rush.R:310-312`), the `timeout = 0` semantics (`R/Rush.R:474-476`), the cache-counter invariants (`R/Rush.R:1625-1629`).
- NEWS.md is disciplined and accurate about behavior changes — with the one exception flagged in §5.

## Not verified

- Downstream contracts: `rush_plan(worker_type = ...)` is stored and returned but never consumed inside rush; I assume bbotk/mlr3tuning read it. Cannot confirm from this repository.
- Windows behavior of `$worker_script()` output and `heartbeat` SIGKILL semantics.
- Whether `redux::redis_config()` tolerates string `db`/other numeric config fields round-tripped through `worker_script()` (only `port` and `timeout` are coerced back in `start_worker()`, `R/start_worker.R:76-81`).

## Verdict

**Request changes.**

The architecture and the concurrency discipline are sound — better than most code that touches distributed state. But #1 silently corrupts credentials and doubles as an injection vector in the method's primary use case, #2 is a verified crash on input the assertions explicitly permit and the docs contradict, and #3 is silent state corruption with a trivially cheap guard. All three fixes are small and local. Items 4–9 are quality-of-failure improvements: this package's entire value proposition is robust error handling, so how it fails *is* the product.

## Next steps

1. Fix the three top findings (#1 quoting, #2 integer coercion + assertions, #3 id uniqueness) — each is a small, local change with an obvious test.
2. Discuss the suggestions (§4–§9) and decide which are worth scheduling; §4 (heartbeat retry) has the best cost/benefit.
3. Optionally turn this review into GitHub issues per finding.
