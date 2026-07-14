# Changelog

## rush (development version)

## rush 1.2.0

CRAN release: 2026-07-13

- fix: `$start_workers()`, `$start_local_workers()`,
  [`start_worker()`](https://rush.mlr-org.com/dev/reference/start_worker.md),
  and `RushWorker$new()` now append a random suffix to generated worker
  ids so that ids are unique by construction and can no longer collide.
- fix: `$start_workers()` and `RushWorker$new()` now reject fractional
  `heartbeat_period` and `heartbeat_expire` values and coerce
  integer-valued doubles.
- chore: The minimum R version is now 3.6.0, and Redis (\>= 7.0) is
  declared as a system requirement.
- refactor: Remove deprecated worker types `"local"` and `"remote"`.
- fix: `AppenderRedis` now strips custom fields from log events in its
  own layout instead of mutating the shared log event. Previously, the
  custom fields were also removed from the output log and console output
  when `output_log` was set. The `filter_custom_fields()` function is
  removed.
- refactor: `$fail_tasks()`, `$finish_tasks()`, `$pop_task()`, and
  `$push_running_tasks()` are moved from `Rush` to `RushWorker` so that
  a task is only marked as failed or finished by the worker that
  processes it.
- fix: `$fail_tasks()`, `$finish_tasks()`, `$pop_task()`, and
  `$detect_lost_workers()` now change task states with guarded
  first-writer-wins transitions implemented as Lua scripts. A task can
  no longer be recorded as finished and failed at the same time when a
  live worker is wrongly declared lost. The losing transition is
  discarded with a warning.
- fix: `$stop_workers(type = "kill")` now marks the running and pending
  tasks of killed workers as failed with the condition message
  `"Worker was killed"`. Previously these tasks remained in the running
  state indefinitely.
- refactor: The deprecated methods `$push_failed()` and
  `$push_results()` are removed. Use `$fail_tasks()` and
  `$finish_tasks()` instead.
- fix: `$empty_queue()` no longer creates an orphaned hash in the Redis
  database when the queue is already empty.
- BREAKING CHANGE: The `$empty_queue()` method now empties the entire
  queue instead of a specified set of tasks. The `keys` and `conditions`
  arguments are removed.
- fix: `$detect_lost_workers()` no longer marks a task as both finished
  and failed, or loses a task.
- fix: `$detect_lost_workers()` now returns only the worker ids it
  actually detected as lost during the call, instead of also including
  workers that terminated cleanly while the method was running.
- fix: `$detect_lost_workers()` no longer reports a heartbeat worker as
  lost and fails its tasks when the worker terminates cleanly while the
  method is running.
- fix: `$pop_task()` no longer loses a task when a worker crashes
  between popping the task from the queue and marking it as running. The
  task is now moved atomically into a per-worker pending list and
  recovered as a failed task by `$detect_lost_workers()`.
- fix: `$push_tasks()`, `$push_finished_tasks()`,
  `$push_failed_tasks()`, and `$push_running_tasks()` now return early
  when called with an empty list of tasks.
- fix: `$fetch_tasks()`, `$fetch_finished_tasks()`, and
  `$fetch_new_tasks()` no longer fail when task hashes have been removed
  from the database. Affected tasks are dropped with a warning.
- fix: `$fetch_new_tasks()` and `$fetch_finished_tasks()` no longer fail
  after more than 100,000 tasks have been fetched. The internal counter
  of consumed tasks is now stored as an integer so it can no longer be
  formatted in scientific notation in Redis commands.
- fix: `$fetch_failed_tasks()` and related methods now return the
  documented `condition` column holding the whole condition object.
- feat: The `extra` argument of `$push_tasks()`,
  `$push_running_tasks()`, and `$finish_tasks()` methods is deprecated
  in favor of the consistently named `xss_extra` and `yss_extra`
  arguments.
- fix: `$start_local_workers()` now redirects the standard error stream
  of workers to a file instead of a pipe. Previously, a worker writing
  more than the operating system’s pipe buffer to standard error blocked
  forever because the pipe was only drained after the worker terminated.
- fix: `$start_local_workers()` no longer generates unparseable worker
  startup code on Windows or when the temporary directory path contains
  quotes. The temporary arguments file is now deleted after the worker
  reads it.
- fix: `$stop_workers()` no longer errors when a requested worker id is
  not running. Such ids are now skipped with a warning.
- perf: `$wait_for_tasks()` no longer reads the full finished list and
  failed task set on every poll.
- fix: `$worker_script()` now embeds values as R string literals and
  shell-quotes the whole `Rscript -e` payload exactly once for POSIX
  shells.
- fix: `$worker_script()` no longer logs the Redis password. The logged
  script shows `<redacted>` instead. The method now returns the script
  visibly.
- fix: `$worker_script()` now validates the `heartbeat_period`,
  `heartbeat_expire`, `message_log`, and `output_log` arguments instead
  of interpolating them into the shell command unchecked.
- fix: `RushWorker$new()` now errors when the heartbeat process fails to
  set the heartbeat key within the startup timeout instead of silently
  registering a dead heartbeat. `heartbeat_period` and
  `heartbeat_expire` must now be at least 1 second, and
  `heartbeat_expire` must be at least `heartbeat_period` seconds.
- fix: `$reset()` now also resets the internal log counter, so
  `$print_log()` no longer skips messages when the same network id is
  reused after a reset.
- fix: `$reset()` now deletes all keys in a single `MULTI`/`EXEC`
  transaction so a concurrent reader can no longer observe a half-reset
  network.
- feat:
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  gains the `start_worker_timeout` argument, which sets the default
  timeout used by `$wait_for_workers()`. An explicit `timeout` passed to
  `$wait_for_workers()` is no longer overridden by the configuration.
- fix: `$wait_for_workers(timeout = 0)` now checks once and errors
  immediately if the workers are not yet registered, instead of never
  checking.
- fix:
  [`start_worker()`](https://rush.mlr-org.com/dev/reference/start_worker.md)
  no longer errors on exit when `message_log` or `output_log` is set.
  The sinks are now reverted before the log connections are closed.
- fix:
  [`start_worker()`](https://rush.mlr-org.com/dev/reference/start_worker.md)
  now checks that `message_log` and `output_log` are existing
  directories, so a wrong path raises a clear error instead of a cryptic
  “cannot open the connection”.
- perf: `$worker_info` reads all workers in one pipelined round trip.
- refactor: Large objects are now stored under UUID keys.

## rush 1.1.0

CRAN release: 2026-04-24

- fix: `$detect_lost_workers()` no longer creates phantom failed tasks
  when a worker crashes between task evaluations
  ([\#89](https://github.com/mlr-org/rush/issues/89)).
- fix: `$fetch_new_tasks()` now correctly tracks seen results by using
  the actual cache size instead of the Redis counter, fixing cases where
  new results could be missed or duplicated.
- fix: `$write_hashes()` now requires all value lists to have the same
  length or length 1 instead of recycling. Length mismatches raise an
  error ([\#87](https://github.com/mlr-org/rush/issues/87)).
- fix: [`rsh()`](https://rush.mlr-org.com/dev/reference/rsh.md) no
  longer accepts `...` (which was ignored).

## rush 1.0.1

CRAN release: 2026-04-04

- fix: `$start_workers()` now strips the enclosing environment from
  `worker_loop` before serialization, avoiding bloated Redis payloads
  when the function is a closure.
- fix: `$fetch_tasks()` and related methods no longer fail when task
  parameters contain vector values instead of scalars.

## rush 1.0.0

CRAN release: 2026-03-18

- feat: Add `$push_finished_tasks()` method.
- feat: Combine `$wait_for_new_tasks()` and `$fetch_new_tasks()` into
  `$fetch_new_tasks()` with timeout argument.
- refactor: The `$wait_for_finished_tasks()` method is removed.
- perf: Cache is now a `data.table()` instead of a list. `data_format`
  argument is removed.
- refactor: Seed mechanism is removed. Includes `with_rng_state()`,
  `is_lecyer_cmrg_seed()`, `get_random_seed()`, `set_random_seed()`,
  `make_rng_seeds()` helper functions.
- refactor: PID is no longer stored with tasks by `$push_tasks()` and
  `$push_running_tasks()` methods.
- refactor: `worker_extra` field is renamed to `worker_id`.
- refactor: `$push_results()` is renamed to `$finish_tasks()`.
- fix: Heartbeat process moves worker to terminated.
- refactor: `$push_results()` is deprecated. Use `$finish_tasks()`
  instead.
- refactor: `$push_failed()` is deprecated. Use `$fail_tasks()` instead.
- refactor: `$terminated_on_idle` is removed.
- refactor: Removed `$push_priority_tasks()`,
  `$n_queued_priority_tasks`, `$priority_info`, and
  `$fetch_priority_tasks()`.
- fix: Redis with password is supported now.
- refactor: Remove `$restart_workers()` method.
- refactor: Squashed `"terminated"`, `"killed"` and `"lost"` worker
  states into `"terminated"`.
- feat: Added `push_failed_tasks()` for creating failed tasks.
- refactor: Remove `reset_cache` arguments in favor of `$reset_cache()`
  method.
- refactor: `network_id`, `config` and `connector` are now active
  bindings with validation.
- refactor: Removed `$snapshot_schedule()` and `$redis_info()` methods.
- refactor: Removed `$all_workers_terminated` and `all_workers_lost`
  active bindings.
- refactor: Moved `$worker_states` to `$worker_info`.
- feat: Add `"rush.max_object_size"` option to limit the size of objects
  stored in Redis.
- refactor: Renamed `$start_remote_workers()` to `$start_workers()`.
- feat: Add `$reset_data()` method to reset task data without resetting
  the network.
- fix:
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  now allows script workers.
- fix: Default heartbeat expire is now correctly calculated as three
  times the heartbeat period.
- fix: Message and output log file connections are now properly closed
  when the worker exits.
- perf: Network-specific Redis keys are now deleted once during
  `$reset()` instead of once per worker.

## rush 0.4.1

CRAN release: 2025-11-06

- feat: The `$wait_for_workers()` method can now wait for a specific
  number of workers or a specific set of worker ids. The workers are
  checked for registration in the network now.

## rush 0.4.0

CRAN release: 2025-10-08

- feat: Add `$empty_queue()` method.
- fix: Queued tasks can be moved to failed now.

## rush 0.3.1

CRAN release: 2025-09-16

- feat: Change default of `n_workers`.

## rush 0.3.0

CRAN release: 2025-07-31

- feat: Output and message logs can be written to files now via the
  `message_log` and `output_log` arguments.
- compatibility: lgr 0.5.0
- BREAKING CHANGE: The mlr3 ecosystem has a base logger now which is
  named `mlr3`. The `mlr3/rush` logger is a child of the `mlr3` logger
  and is used for logging messages from the `rush` package.

## rush 0.2.0

CRAN release: 2025-05-30

- feat: Worker can be started with the `mirai` package now.

## rush 0.1.2

CRAN release: 2024-11-06

- feat: Add `$reconnect()` method.

## rush 0.1.1

CRAN release: 2024-07-05

- fix: `Rush` class was not exported.
- fix: `R6` package was not imported.

## rush 0.1.0

CRAN release: 2024-06-20

- Initial CRAN submission.
