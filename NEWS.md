# rush 1.1.0

* `$detect_lost_workers()` no longer creates phantom failed tasks when a worker crashes between task evaluations (#89).
* `$fetch_new_tasks()` now correctly tracks seen results by using the actual cache size instead of the Redis counter, fixing cases where new results could be missed or duplicated.
* `$write_hashes()` now requires all value lists to have the same length or length 1 instead of recycling. Length mismatches raise an error (#87).
* `rsh()` no longer accepts `...` (which was ignored).

# rush 1.0.1

* `$start_workers()` now strips the enclosing environment from `worker_loop` before serialization, avoiding bloated Redis payloads when the function is a closure.
* `$fetch_tasks()` and related methods no longer fail when task parameters contain vector values instead of scalars.

# rush 1.0.0

* feat: Add `$push_finished_tasks()` method.
* feat: Combine `$wait_for_new_tasks()` and `$fetch_new_tasks()` into `$fetch_new_tasks()` with timeout argument.
* refactor: The `$wait_for_finished_tasks()` method is removed.
* perf: Cache is now a `data.table()` instead of a list. `data_format` argument is removed.
* refactor: Seed mechanism is removed. Includes `with_rng_state()`, `is_lecyer_cmrg_seed()`, `get_random_seed()`, `set_random_seed()`, `make_rng_seeds()` helper functions.
* refactor: PID is no longer stored with tasks by `$push_tasks()` and `$push_running_tasks()` methods.
* refactor: `worker_extra` field is renamed to `worker_id`.
* refactor: `$push_results()` is renamed to `$finish_tasks()`.
* fix: Heartbeat process moves worker to terminated.
* refactor: `$push_results()` is deprecated. Use `$finish_tasks()` instead.
* refactor: `$push_failed()` is deprecated. Use `$fail_tasks()` instead.
* refactor: `$terminated_on_idle` is removed.
* refactor: Removed `$push_priority_tasks()`, `$n_queued_priority_tasks`, `$priority_info`, and `$fetch_priority_tasks()`.
* fix: Redis with password is supported now.
* refactor: Remove `$restart_workers()` method.
* refactor: Squashed `"terminated"`, `"killed"` and `"lost"` worker states into `"terminated"`.
* feat: Added `push_failed_tasks()` for creating failed tasks.
* refactor: Remove `reset_cache` arguments in favor of `$reset_cache()` method.
* refactor: `network_id`, `config` and `connector` are now active bindings with validation.
* refactor: Removed `$snapshot_schedule()` and `$redis_info()` methods.
* refactor: Removed `$all_workers_terminated` and `all_workers_lost` active bindings.
* refactor: Moved `$worker_states` to `$worker_info`.
* feat: Add `"rush.max_object_size"` option to limit the size of objects stored in Redis.
* refactor: Renamed `$start_remote_workers()` to `$start_workers()`.
* feat: Add `$reset_data()` method to reset task data without resetting the network.
* fix: `rush_plan()` now allows script workers.
* fix: Default heartbeat expire is now correctly calculated as three times the heartbeat period.
* fix: Message and output log file connections are now properly closed when the worker exits.
* perf: Network-specific Redis keys are now deleted once during `$reset()` instead of once per worker.

# rush 0.4.1

* feat: The `$wait_for_workers()` method can now wait for a specific number of workers or a specific set of worker ids.
  The workers are checked for registration in the network now.

# rush 0.4.0

feat: Add `$empty_queue()` method.
fix: Queued tasks can be moved to failed now.

# rush 0.3.1

feat: Change default of `n_workers`.

# rush 0.3.0

* feat: Output and message logs can be written to files now via the `message_log` and `output_log` arguments.
* compatibility: lgr 0.5.0
* BREAKING CHANGE: The mlr3 ecosystem has a base logger now which is named `mlr3`.
  The `mlr3/rush` logger is a child of the `mlr3` logger and is used for logging messages from the `rush` package.

# rush 0.2.0

* feat: Worker can be started with the `mirai` package now.

# rush 0.1.2

* feat: Add `$reconnect()` method.

# rush 0.1.1

* fix: `Rush` class was not exported.
* fix:  `R6` package was not imported.

# rush 0.1.0

* Initial CRAN submission.
