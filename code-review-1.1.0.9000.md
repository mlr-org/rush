# Critical Code Review: rush 1.1.0.9000

Review of the complete package at commit `fcfa71a` (branch `main`).
Scope: all of `R/`, `tests/testthat/`, `DESCRIPTION`, `NEWS.md`.
Generated artifacts (`man/`, `NAMESPACE`, `README.md`) and vignettes were spot-checked only.

## Summary

The package is in better shape than most distributed-computing code: the Redis command
construction is consistent, pipelines are used to batch round trips, the hash read/write
layer is genuinely well designed, and the test suite is substantial (63 tests covering
crash scenarios, heartbeats, and lost-worker detection). That is the good news.

The bad news: the fetch layer crashes when task hashes are missing (confirmed
empirically), `start_local_workers()` generates R code that cannot parse on Windows
(confirmed empirically), `pop_task()` has a crash window in which a task vanishes from
every state set and can never be recovered, and the package whose selling point is
"robust error handling" runs its heartbeat loop with zero error handling. There is dead
configuration (`start_worker_timeout` is read but never settable), a documented example
that calls the function with arguments that do not exist, no `SystemRequirements` field
despite a hard dependency on Redis >= 7.0, and the same 10-line config/assertion blocks
copy-pasted into three methods.

Verdict: **Request Changes.**

---

## Critical Issues (Blocking)

### 1. `.fetch_tasks()` crashes when any task hash is missing — `R/Rush.R:1799` ✅ RESOLVED

```r
tab = rbindlist(data, use.names = TRUE, fill = TRUE)
tab[, keys := unlist(keys)]
```

`read_hashes()` returns `NULL` for a key whose hash no longer exists, and `rbindlist()`
silently drops those `NULL`s. The subsequent `keys :=` assignment then has more keys than
rows. Verified:

```
Error: Supplied 2 items to be assigned to 1 items of column 'keys'.
```

When *all* hashes are missing you instead get a silent table of keys with no data columns.
So the failure mode is: partial miss = crash, total miss = silently wrong.

Missing hashes are not hypothetical: a second `Rush` instance calling `$reset()` on a
shared network, or a Redis server with an `allkeys-lru`/`allkeys-random` eviction policy
under memory pressure ("large-scale problems" is the package's stated use case), leaves
keys in the state lists/sets whose hashes are gone. Every `fetch_*` method funnels through
this code.

Fix: keep the key-to-row correspondence explicit. Build the table from
`set_names(data, keys)` and `rbindlist(idcol = "keys")`, or filter `keys` to the non-NULL
entries before assignment and log what was dropped.

### 2. Same pattern desynchronizes the finished-task cache — `R/Rush.R:1827` ✅ RESOLVED

`.fetch_cached_tasks()` has the identical misalignment (`new_tab[, keys := unlist(new_keys)]`,
guarded only by `nrow(new_tab) > 0`). Worse, the cache offset arithmetic depends on
`nrow(private$.cached_tasks)` matching the consumed prefix of the Redis `finished_tasks`
list (`R/Rush.R:1142-1146`), and `fetch_new_tasks()` computes new results as
`nrow(cache) - .n_seen_results` (`R/Rush.R:1219`). One dropped row and every subsequent
fetch reads a shifted `LRANGE` window: duplicated or misattributed results in the exact
method (`fetch_new_tasks()`) that bbotk/mlr3tuning poll for optimization results. The
1.1.0 NEWS entry shows this counter logic has already produced bugs once.

### 3. `start_local_workers()` generates unparseable R code on Windows — `R/Rush.R:302-307` ✅ RESOLVED

```r
args = c("-e", sprintf("do.call(rush::start_worker, readRDS(%s))", shQuote(args_file)))
```

`shQuote()` produces a *shell* quote, which is then spliced into *R source code*. On
Windows, `tempfile()` returns backslash paths, so the generated code is
`readRDS('C:\Users\...')`. Verified:

```
Error: '\U' used without hex digits in character string
```

Every local worker start on Windows fails. On Unix it merely breaks for paths containing
a single quote. Use `deparse(args_file)` (proper R string escaping), or sidestep
interpolation entirely by passing the path through an environment variable or
`commandArgs()`. While here: the temp `.rds` file is never deleted by anyone — the worker
should `unlink()` it after reading.

### 4. `pop_task()` can permanently lose a task — `R/Rush.R:827-843`

```r
key = r$command(c("BLMPOP", timeout, 1, private$.get_key("queued_tasks"), "RIGHT"))[[2]][[1]]
...
self$write_hashes(worker_id = list(self$worker_id), keys = key)
r$command(c("SADD", private$.get_key("running_tasks"), key))
```

`BLMPOP` removes the key from the queue; the `SADD` to `running_tasks` happens two round
trips later. If the worker dies in between (the precise failure the heartbeat machinery
exists to handle), the task is in *no* state structure. `detect_lost_workers()` only fails
tasks found in `running_tasks` (`R/Rush.R:576`), so the task is never marked failed, and a
caller in `wait_for_tasks()` is released only by the unrelated "no running workers" escape
hatch. For a package that advertises robust error handling, this is a hole in the core
state machine. The standard Redis pattern is an atomic `BLMOVE` from the queue into a
per-worker processing list that `detect_lost_workers()` sweeps. At minimum, document the
window.

---

## Required Changes

### 5. Phantom configuration: `start_worker_timeout` can never be set — `R/Rush.R:441`, `R/rush_plan.R:92` ✅ RESOLVED

`wait_for_workers()` reads `rush_config()$start_worker_timeout` and `rush_config()`
dutifully reports the field, but `rush_plan()` has no such parameter and nothing in the
package ever assigns it. It is unreachable configuration. Either add the parameter to
`rush_plan()` or delete both references. The surrounding logic is also backwards-surprising:
an explicit `timeout = Inf` (the documented default) is silently *replaced* by the config
value, so the config wins exactly when the user asked for "wait forever".

### 6. `worker_script()` logs the Redis password — `R/Rush.R:418-419` ✅ RESOLVED

`lg$info("Rscript -e \"rush::start_worker(%s)\"", args)` interpolates the full config,
including `password`, into the log stream at info level. Anyone shipping worker logs has
shipped their Redis credentials. Redact the password in the logged variant. Also: the
method returns the script `invisible()` — the script *is* the requested artifact; return
it visibly or document why not.

### 7. Triplicated copy-paste blocks — `R/Rush.R:168-178, 256-266, 367-376` and `R/Rush.R:204-206, 281-283, 387-388` ✅ RESOLVED

The `lgr_thresholds`/`lgr_buffer_size` assertion block and the
`config = discard(unclass(self$config), is.null); config$url = NULL` dance are pasted
verbatim into `start_workers()`, `start_local_workers()`, and `worker_script()`. Three
copies means three places to forget the next fix. Extract two private helpers.

### 8. `pop_task()`/`push_running_tasks()` silently write `worker_id = NULL` on the manager — `R/Rush.R:835, 983` ✅ RESOLVED

`self$worker_id` exists only on `RushWorker`; on a `Rush` manager it is `NULL`, which is
serialized into the hash without complaint and surfaces later as an `NA` column. The class
docs explicitly advertise these as shared methods. Either error clearly ("only callable
from a worker") or document and handle the NULL deliberately.

### 9. Heartbeat startup failure is silent — `R/RushWorker.R:66-78` ✅ RESOLVED

If the callr heartbeat process fails to set a TTL within the 5-second window, the loop
just falls through, the key is registered in `heartbeat_keys` anyway, and the next
`detect_lost_workers()` declares the freshly started worker dead and fails its tasks.
A worker that cannot establish its heartbeat must error, not shrug. Additionally,
`assert_number(heartbeat_period)` has no lower bound: `heartbeat_period = 0` is accepted
and `EXPIRE key 0` deletes the heartbeat key on the first beat. Use
`assert_number(heartbeat_period, lower = ...)` with a sane minimum.

### 10. `heartbeat()` loop has no error handling — `R/heartbeat_loops.R:27-41`

One transient Redis error (timeout, failover, dropped connection) kills the background
process, the heartbeat key expires, and the manager declares a perfectly healthy worker
lost — failing its running task while the worker happily completes it. That is a
duplicate-result generator. Wrap the loop body in `tryCatch` with bounded reconnect/retry
before giving up.

### 11. `reset()` forgets `.log_counter` — `R/Rush.R:744-746` ✅ RESOLVED

`.cached_tasks` and `.n_seen_results` are reset; `.log_counter` is not. Reuse the same
network id after a reset and `print_log()` silently skips the first N messages of each
worker. One line.

### 12. Magic number 19 — `R/Rush.R:598`  ❌ RETRACTED

```r
message = if (unclass(m$data) == 19) "Worker has crashed or was killed" else as.character(m$data)
```

19 is an undocumented mirai `errorValue`. Name it (`MIRAI_CONNECTION_RESET = 19L`) with a
comment citing the mirai semantics, or use mirai's own predicate if one exists. The next
maintainer cannot grep "19".

### 13. DESCRIPTION undersells its requirements — `DESCRIPTION` ✅ RESOLVED

* There is no `SystemRequirements` field at all, yet nothing in the package works without
  a Redis server — and `BLMPOP` (`R/Rush.R:830`) requires Redis >= 7.0, `SMISMEMBER`
  (`R/Rush.R:1453`) requires >= 6.2. Declare `SystemRequirements: Redis (>= 7.0)`.
* `Depends: R (>= 3.1.0)` is fiction. mirai alone requires a far newer R, and the test
  suite uses testthat edition 3. Declare the real minimum.

### 14. `start_worker()` example cannot run; docs reference a method that does not exist — `R/start_worker.R:30-37, 7` ✅ RESOLVED

The `\dontrun` example calls `start_worker(network_id = ..., url = ..., scheme = ...,
host = ..., port = ...)` — `url`, `scheme`, `host`, `port` are not arguments of the
function (they belong inside `config`). It would error immediately if run. The description
also says the function is called "by the user after creating the worker script with
`$create_worker_script()`" — the method is `$worker_script()`. Both are documentation rot.

### 15. `start_worker()` closes connections that are still active sinks — `R/start_worker.R:52-66` ✅ RESOLVED

```r
sink(message_log_con, type = "message", append = TRUE)
on.exit(close(message_log_con), add = TRUE)
```

On exit the connection is closed while it is still the active sink — R refuses to close a
connection that is sinked, so the `on.exit` handler itself errors and the second handler
(output log) may never have run cleanly. Revert the sink first:
`on.exit({sink(type = "message"); close(message_log_con)}, add = TRUE)`.

### 16. `AppenderRedis$flush()` — style violation and no failure handling — `R/AppenderRedis.R:83-99` ❌ RETRACTED

* Line 97 uses `<-` (`private$.buffer_events <- list()`); the project's own style rules
  mandate `=`. The `get(".layout", envir = private)` / `assign(...)` indirection is copied
  from lgr internals and is unnecessary here — `private$.layout` works.
* `flush()` does no error handling. If Redis is briefly unreachable, every buffered log
  call inside the worker loop throws, turning a logging hiccup into a failed task. A
  logging appender must not be able to take down the computation it is logging.

### 17. Unreachable statement — `R/Rush.R:473-474` ✅ RESOLVED

`error_timeout()` throws; the `invisible(self)` after it is dead code. Delete it.

---

## Suggestions

### 18. Polling loops hammer Redis with full list reads — `R/Rush.R:1256`

`wait_for_tasks()` evaluates `self$finished_tasks` and `self$failed_tasks` — full
`LRANGE 0 -1` / `SMEMBERS` of *every* task key — every 10 ms. On a long optimization run
with 10⁵ finished tasks that is megabytes of Redis traffic per second to answer a yes/no
question. Use `SMISMEMBER` on the awaited keys plus the counters, or at least back off the
poll interval. Same pattern, milder, in `wait_for_workers()` and `fetch_new_tasks()`.

### 19. ~~Hot-path debug logging pays even when disabled~~ — `R/Rush.R:1303` ❌ RETRACTED

Incorrect finding. lgr checks the threshold before forcing its `...` promises, so the
`object.size` reduction inside `write_hashes()` is never evaluated when debug logging is
suppressed (verified empirically: a side-effecting argument to `lg$debug()` under an
`info` threshold is not evaluated). No change needed.

### 20. `fail_tasks()` state race produces duplicate states — `R/Rush.R:907-929`

A task popped by a worker between the `SISMEMBER` pipeline and the `LREM`/`SMOVE` pipeline
ends up in both `running_tasks` and `failed_tasks`. The docs for
`fetch_tasks_with_state()` explicitly promise tasks cannot appear twice; this breaks that
promise. A `MULTI`/Lua script would make the classification and move atomic.

### 21. Active bindings hide Redis round trips — `R/Rush.R:680`

`detect_lost_workers()`'s return line reads `self$terminated_worker_ids` twice — two
`SMEMBERS` calls for one expression. `worker_info` issues `1 + n_workers + 2` commands.
Cache binding results in locals within a method; bindings that do network I/O deserve a
comment saying so.

### 22. `config` setter swaps config without reconnecting — `R/Rush.R:1526-1532`

After assigning `rush$config = new_config`, the live connector still points at the old
server until the user remembers `reconnect()`. Either reconnect in the setter or document
the required follow-up call in the field docs.

### 23. Naming: `keys` column vs `task$key` — `R/Rush.R:1812` vs `R/Rush.R:841`

Fetched tables call the identifier column `keys`; `pop_task()` returns `task$key`. Pick
one. The `tab[, keys := unlist(keys)]` idiom also relies on the RHS `keys` resolving to
the function argument rather than a column — it works only as long as nobody stores a
field called `keys` in a hash.

### 24. Small leaks and dead imports

* `get_hostname()` never closes the `pipe()` connection (`R/helper.R:24`) — gc-time
  "closing unused connection" warnings.
* `@importFrom utils str` (`R/zzz.R:9`) — `str()` is not used anywhere in `R/`.
* `worker_info`'s `heartbeat != "NA"` string sentinel (`R/Rush.R:1675`) works only because
  `NA_character_` round-trips through Redis as the string `"NA"`; one refactor away from
  breaking silently. Store an explicit `"0"`/`"1"` flag.
* `store_large_object()` (`R/store_large_object.R:16`) does not check the directory
  exists (cryptic `saveRDS` error) and nothing ever cleans up the `.rds` files; document
  the lifecycle.
* Stray same-line `# nolint` at `R/Rush.R:1166` with no explanation — the project's own
  rules require `# nolint next`.
* `print_log()` returns `invisible(NULL)` in the no-workers branch but `invisible(self)`
  otherwise (`R/Rush.R:799-801`) — inconsistent for chaining.
* `filter_custom_fields()` (`R/AppenderRedis.R:117-121`) mutates the shared `LogEvent`,
  stripping custom fields for every appender, not just the Redis one. Currently masked
  because the console appender is removed; leave a comment or copy the event.

### 25. Test-suite timing

The suite leans on `Sys.sleep()` for synchronization (17 sleeps in `test-Rush.R` alone, up
to 5 s) — slow on every run, flaky on loaded CI. Where a condition is being awaited,
poll-with-timeout helpers would be both faster and more reliable.

---

## What Is Genuinely Good

Credit where due, and there is real credit here:

* `write_hashes()`/`read_hashes()` (`R/Rush.R:1294, 1359`) are a clean serialization layer
  with honest documentation of the broadcast semantics, explicit length validation (new in
  1.1.0, replacing silent recycling — the right call), and a correct `is.null` guard on
  `is.atomic()` for modern R.
* Redis pipelines are used consistently to batch writes; the comments explaining the
  list-vs-set trade-off for `finished_tasks` (`R/Rush.R:871-875`) are the kind of
  design-rationale comment worth having.
* The crash-recovery test coverage (`wl_segfault`, heartbeat kills, lost-worker detection)
  is far beyond what most R packages attempt.
* Conditions use the `mlr3misc` condition helpers uniformly; assertions on the public API
  are thorough.

## Verdict

**Request Changes.** Items 1–4 are correctness holes in the core state machine and the
fetch layer of a package whose entire job is correct distributed state. Items 5–17 are
required hygiene. The remaining items are minor.

The most likely production incident: a long mlr3tuning run on a memory-pressured Redis
evicts a few task hashes, and every `fetch_*` call starts throwing
`Supplied N items to be assigned to M items` (item 1) — or, quieter and worse, the
finished-task cache shifts by one row and the optimizer silently trains on results
attached to the wrong configurations (item 2).
