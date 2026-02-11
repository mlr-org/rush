# Rush Controller

The `Rush` controller manages workers in a rush network.

## Value

Object of class
[R6::R6Class](https://r6.r-lib.org/reference/R6Class.html) and `Rush`
with controller methods.

## Local Workers

A local worker runs on the same machine as the controller. Local workers
are spawned with the \`\$start_local_workers() method via the
[processx](https://CRAN.R-project.org/package=processx) package.

## Remote Workers

A remote worker runs on a different machine than the controller. Remote
workers are spawned with the \`\$start_remote_workers() method via the
[mirai](https://CRAN.R-project.org/package=mirai) package.

## Script Workers

Workers can be started with a script anywhere. The only requirement is
that the worker can connect to the Redis database. The script is created
with the `$worker_script()` method.

## Public fields

- `network_id`:

  (`character(1)`)  
  Identifier of the rush network.

- `config`:

  ([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))  
  Redis configuration options.

- `connector`:

  ([redux::redis_api](https://richfitz.github.io/redux/reference/redis_api.html))  
  Returns a connection to Redis.

- `processes_processx`:

  ([processx::process](http://processx.r-lib.org/reference/process.md))  
  List of processes started with `$start_local_workers()`.

- `processes_mirai`:

  ([mirai::mirai](https://mirai.r-lib.org/reference/mirai.html))  
  List of mirai processes started with `$start_remote_workers()`.

## Active bindings

- `n_workers`:

  (`integer(1)`)  
  Number of workers.

- `n_running_workers`:

  (`integer(1)`)  
  Number of running workers.

- `n_terminated_workers`:

  (`integer(1)`)  
  Number of terminated workers.

- `n_killed_workers`:

  (`integer(1)`)  
  Number of killed workers.

- `n_lost_workers`:

  (`integer(1)`)  
  Number of lost workers. Run `$detect_lost_workers()` to update the
  number of lost workers.

- `n_pre_workers`:

  (`integer(1)`)  
  Number of workers that are not yet completely started.

- `worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Ids of workers.

- `running_worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Ids of running workers.

- `terminated_worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Ids of terminated workers.

- `killed_worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Ids of killed workers.

- `lost_worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Ids of lost workers.

- `pre_worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Ids of workers that are not yet completely started.

- `tasks`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of all tasks.

- `queued_tasks`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of queued tasks.

- `running_tasks`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of running tasks.

- `finished_tasks`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of finished tasks.

- `failed_tasks`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of failed tasks.

- `n_queued_tasks`:

  (`integer(1)`)  
  Number of queued tasks.

- `n_queued_priority_tasks`:

  (`integer(1)`)  
  Number of queued priority tasks.

- `n_running_tasks`:

  (`integer(1)`)  
  Number of running tasks.

- `n_finished_tasks`:

  (`integer(1)`)  
  Number of finished tasks.

- `n_failed_tasks`:

  (`integer(1)`)  
  Number of failed tasks.

- `n_tasks`:

  (`integer(1)`)  
  Number of all tasks.

- `worker_info`:

  ([`data.table::data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html))  
  Contains information about the workers.

- `worker_states`:

  ([`data.table::data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html))  
  Contains the states of the workers.

- `all_workers_terminated`:

  (`logical(1)`)  
  Whether all workers are terminated.

- `all_workers_lost`:

  (`logical(1)`)  
  Whether all workers are lost. Runs `$detect_lost_workers()` to detect
  lost workers.

- `priority_info`:

  ([data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html))  
  Contains the number of tasks in the priority queues.

- `snapshot_schedule`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Set a snapshot schedule to periodically save the data base on disk.
  For example, `c(60, 1000)` saves the data base every 60 seconds if
  there are at least 1000 changes. Overwrites the redis configuration
  file. Set to `NULL` to disable snapshots. For more details see
  [redis.io](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/).

- `redis_info`:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  Information about the Redis server.

## Methods

### Public methods

- [`Rush$new()`](#method-Rush-new)

- [`Rush$format()`](#method-Rush-format)

- [`Rush$print()`](#method-Rush-print)

- [`Rush$reconnect()`](#method-Rush-reconnect)

- [`Rush$start_local_workers()`](#method-Rush-start_local_workers)

- [`Rush$start_remote_workers()`](#method-Rush-start_remote_workers)

- [`Rush$worker_script()`](#method-Rush-worker_script)

- [`Rush$restart_workers()`](#method-Rush-restart_workers)

- [`Rush$wait_for_workers()`](#method-Rush-wait_for_workers)

- [`Rush$stop_workers()`](#method-Rush-stop_workers)

- [`Rush$detect_lost_workers()`](#method-Rush-detect_lost_workers)

- [`Rush$reset()`](#method-Rush-reset)

- [`Rush$reset_data()`](#method-Rush-reset_data)

- [`Rush$read_log()`](#method-Rush-read_log)

- [`Rush$print_log()`](#method-Rush-print_log)

- [`Rush$push_tasks()`](#method-Rush-push_tasks)

- [`Rush$push_priority_tasks()`](#method-Rush-push_priority_tasks)

- [`Rush$push_failed()`](#method-Rush-push_failed)

- [`Rush$empty_queue()`](#method-Rush-empty_queue)

- [`Rush$fetch_queued_tasks()`](#method-Rush-fetch_queued_tasks)

- [`Rush$fetch_priority_tasks()`](#method-Rush-fetch_priority_tasks)

- [`Rush$fetch_running_tasks()`](#method-Rush-fetch_running_tasks)

- [`Rush$fetch_finished_tasks()`](#method-Rush-fetch_finished_tasks)

- [`Rush$wait_for_finished_tasks()`](#method-Rush-wait_for_finished_tasks)

- [`Rush$fetch_new_tasks()`](#method-Rush-fetch_new_tasks)

- [`Rush$wait_for_new_tasks()`](#method-Rush-wait_for_new_tasks)

- [`Rush$fetch_failed_tasks()`](#method-Rush-fetch_failed_tasks)

- [`Rush$fetch_tasks()`](#method-Rush-fetch_tasks)

- [`Rush$fetch_tasks_with_state()`](#method-Rush-fetch_tasks_with_state)

- [`Rush$wait_for_tasks()`](#method-Rush-wait_for_tasks)

- [`Rush$write_hashes()`](#method-Rush-write_hashes)

- [`Rush$read_hashes()`](#method-Rush-read_hashes)

- [`Rush$read_hash()`](#method-Rush-read_hash)

- [`Rush$is_running_task()`](#method-Rush-is_running_task)

- [`Rush$is_failed_task()`](#method-Rush-is_failed_task)

- [`Rush$tasks_with_state()`](#method-Rush-tasks_with_state)

- [`Rush$clone()`](#method-Rush-clone)

------------------------------------------------------------------------

### Method `new()`

Creates a new instance of this
[R6](https://r6.r-lib.org/reference/R6Class.html) class.

#### Usage

    Rush$new(network_id = NULL, config = NULL, seed = NULL)

#### Arguments

- `network_id`:

  (`character(1)`)  
  Identifier of the rush network. Controller and workers must have the
  same instance id. Keys in Redis are prefixed with the instance id.

- `config`:

  ([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))  
  Redis configuration options. If `NULL`, configuration set by
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  is used. If
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  has not been called, the `REDIS_URL` environment variable is parsed.
  If `REDIS_URL` is not set, a default configuration is used. See
  [redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html)
  for details.

- `seed`:

  ([`integer()`](https://rdrr.io/r/base/integer.html))  
  Initial seed for the random number generator. Either a L'Ecuyer-CMRG
  seed (`integer(7)`) or a regular RNG seed (`integer(1)`). The later is
  converted to a L'Ecuyer-CMRG seed. If `NULL`, no seed is used for the
  random number generator.

------------------------------------------------------------------------

### Method [`format()`](https://rdrr.io/r/base/format.html)

Helper for print outputs.

#### Usage

    Rush$format(...)

#### Arguments

- `...`:

  (ignored).

#### Returns

([`character()`](https://rdrr.io/r/base/character.html)).

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print method.

#### Usage

    Rush$print()

#### Returns

([`character()`](https://rdrr.io/r/base/character.html)).

------------------------------------------------------------------------

### Method `reconnect()`

Reconnect to Redis. The connection breaks when the Rush object is saved
to disk. Call this method to reconnect after loading the object.

#### Usage

    Rush$reconnect()

------------------------------------------------------------------------

### Method `start_local_workers()`

Start workers locally with `processx`. The
[processx::process](http://processx.r-lib.org/reference/process.md) are
stored in `$processes_processx`. Alternatively, use
`$start_remote_workers()` to start workers on remote machines with
`mirai`. Parameters set by
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
have precedence over the parameters set here.

#### Usage

    Rush$start_local_workers(
      worker_loop,
      ...,
      n_workers = NULL,
      packages = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = NULL,
      supervise = TRUE,
      message_log = NULL,
      output_log = NULL
    )

#### Arguments

- `worker_loop`:

  (`function`)  
  Loop run on the workers.

- `...`:

  (`any`)  
  Arguments passed to `worker_loop`.

- `n_workers`:

  (`integer(1)`)  
  Number of workers to be started. Default is `NULL`, which means the
  number of workers is set by
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md).
  If
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  is not called, the default is `1`.

- `packages`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Packages to be loaded by the workers.

- `lgr_thresholds`:

  (named [`character()`](https://rdrr.io/r/base/character.html) \| named
  [`numeric()`](https://rdrr.io/r/base/numeric.html))  
  Logger threshold on the workers e.g. `c("mlr3/rush" = "debug")`.

- `lgr_buffer_size`:

  (`integer(1)`)  
  By default (`lgr_buffer_size = 0`), the log messages are directly
  saved in the Redis data store. If `lgr_buffer_size > 0`, the log
  messages are buffered and saved in the Redis data store when the
  buffer is full. This improves the performance of the logging.

- `supervise`:

  (`logical(1)`)  
  Whether to kill the workers when the main R process is shut down.

- `message_log`:

  (`character(1)`)  
  Path to the message log files e.g. `/tmp/message_logs/` The message
  log files are named `message_<worker_id>.log`. If `NULL`, no messages,
  warnings or errors are stored.

- `output_log`:

  (`character(1)`)  
  Path to the output log files e.g. `/tmp/output_logs/` The output log
  files are named `output_<worker_id>.log`. If `NULL`, no output is
  stored.

------------------------------------------------------------------------

### Method `start_remote_workers()`

Start workers on remote machines with `mirai`. The
[mirai::mirai](https://mirai.r-lib.org/reference/mirai.html) are stored
in `$processes_mirai`. Parameters set by
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
have precedence over the parameters set here.

#### Usage

    Rush$start_remote_workers(
      worker_loop,
      ...,
      n_workers = NULL,
      packages = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = NULL,
      message_log = NULL,
      output_log = NULL
    )

#### Arguments

- `worker_loop`:

  (`function`)  
  Loop run on the workers.

- `...`:

  (`any`)  
  Arguments passed to `worker_loop`.

- `n_workers`:

  (`integer(1)`)  
  Number of workers to be started. Default is `NULL`, which means the
  number of workers is set by
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md).
  If
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  is not called, the default is `1`.

- `packages`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Packages to be loaded by the workers.

- `lgr_thresholds`:

  (named [`character()`](https://rdrr.io/r/base/character.html) \| named
  [`numeric()`](https://rdrr.io/r/base/numeric.html))  
  Logger threshold on the workers e.g. `c("mlr3/rush" = "debug")`.

- `lgr_buffer_size`:

  (`integer(1)`)  
  By default (`lgr_buffer_size = 0`), the log messages are directly
  saved in the Redis data store. If `lgr_buffer_size > 0`, the log
  messages are buffered and saved in the Redis data store when the
  buffer is full. This improves the performance of the logging.

- `message_log`:

  (`character(1)`)  
  Path to the message log files e.g. `/tmp/message_logs/` The message
  log files are named `message_<worker_id>.log`. If `NULL`, no messages,
  warnings or errors are stored.

- `output_log`:

  (`character(1)`)  
  Path to the output log files e.g. `/tmp/output_logs/` The output log
  files are named `output_<worker_id>.log`. If `NULL`, no output is
  stored.

------------------------------------------------------------------------

### Method `worker_script()`

Generate a script to start workers.

#### Usage

    Rush$worker_script(
      worker_loop,
      ...,
      packages = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      message_log = NULL,
      output_log = NULL
    )

#### Arguments

- `worker_loop`:

  (`function`)  
  Loop run on the workers.

- `...`:

  (`any`)  
  Arguments passed to `worker_loop`.

- `packages`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Packages to be loaded by the workers.

- `lgr_thresholds`:

  (named [`character()`](https://rdrr.io/r/base/character.html) \| named
  [`numeric()`](https://rdrr.io/r/base/numeric.html))  
  Logger threshold on the workers e.g. `c("mlr3/rush" = "debug")`.

- `lgr_buffer_size`:

  (`integer(1)`)  
  By default (`lgr_buffer_size = 0`), the log messages are directly
  saved in the Redis data store. If `lgr_buffer_size > 0`, the log
  messages are buffered and saved in the Redis data store when the
  buffer is full. This improves the performance of the logging.

- `heartbeat_period`:

  (`integer(1)`)  
  Period of the heartbeat in seconds. The heartbeat is updated every
  `heartbeat_period` seconds.

- `heartbeat_expire`:

  (`integer(1)`)  
  Time to live of the heartbeat in seconds. The heartbeat key is set to
  expire after `heartbeat_expire` seconds.

- `message_log`:

  (`character(1)`)  
  Path to the message log files e.g. `/tmp/message_logs/` The message
  log files are named `message_<worker_id>.log`. If `NULL`, no messages,
  warnings or errors are stored.

- `output_log`:

  (`character(1)`)  
  Path to the output log files e.g. `/tmp/output_logs/` The output log
  files are named `output_<worker_id>.log`. If `NULL`, no output is
  stored.

------------------------------------------------------------------------

### Method `restart_workers()`

Restart workers. If the worker is is still running, it is killed and
restarted.

#### Usage

    Rush$restart_workers(worker_ids, supervise = TRUE)

#### Arguments

- `worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Worker ids to be restarted.

- `supervise`:

  (`logical(1)`)  
  Whether to kill the workers when the main R process is shut down.

------------------------------------------------------------------------

### Method `wait_for_workers()`

Wait until workers are registered in the network. Either `n`,
`worker_ids` or both must be provided.

#### Usage

    Rush$wait_for_workers(n = NULL, worker_ids = NULL, timeout = Inf)

#### Arguments

- `n`:

  (`integer(1)`)  
  Number of workers to wait for. If `NULL`, wait for all workers in
  `worker_ids`.

- `worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Worker ids to wait for. If `NULL`, wait for any `n` workers to be
  registered.

- `timeout`:

  (`numeric(1)`)  
  Timeout in seconds. Default is `Inf`.

------------------------------------------------------------------------

### Method `stop_workers()`

Stop workers.

#### Usage

    Rush$stop_workers(type = "kill", worker_ids = NULL)

#### Arguments

- `type`:

  (`character(1)`)  
  Type of stopping. Either `"terminate"` or `"kill"`. If `"kill"` the
  workers are stopped immediately. If `"terminate"` the workers evaluate
  the currently running task and then terminate. The `"terminate"`
  option must be implemented in the worker loop.

- `worker_ids`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Worker ids to be stopped. Remote workers must all be killed together.
  If `NULL` all workers are stopped.

------------------------------------------------------------------------

### Method `detect_lost_workers()`

Detect lost workers. The state of the worker is changed to `"lost"`.

#### Usage

    Rush$detect_lost_workers(restart_local_workers = FALSE)

#### Arguments

- `restart_local_workers`:

  (`logical(1)`)  
  Whether to restart lost workers. Ignored for remote workers.

------------------------------------------------------------------------

### Method `reset()`

Stop workers and delete data stored in redis.

#### Usage

    Rush$reset(type = "kill")

#### Arguments

- `type`:

  (`character(1)`)  
  Type of stopping. Either `"terminate"` or `"kill"`. If `"terminate"`
  the workers evaluate the currently running task and then terminate. If
  `"kill"` the workers are stopped immediately.

------------------------------------------------------------------------

### Method `reset_data()`

Reset the data stored in the Redis database. This is useful to remove
all tasks but keep the workers.

#### Usage

    Rush$reset_data()

------------------------------------------------------------------------

### Method `read_log()`

Read log messages written with the `lgr` package from a worker.

#### Usage

    Rush$read_log(worker_ids = NULL, time_difference = FALSE)

#### Arguments

- `worker_ids`:

  (`character(1)`)  
  Worker ids. If `NULL` all worker ids are used.

- `time_difference`:

  (`logical(1)`)  
  Whether to calculate the time difference between log messages.

#### Returns

([`data.table::data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html))
with level, timestamp, logger, caller and message, and optionally time
difference.

------------------------------------------------------------------------

### Method `print_log()`

Print log messages written with the `lgr` package from a worker.

#### Usage

    Rush$print_log()

------------------------------------------------------------------------

### Method `push_tasks()`

Pushes a task to the queue. Task is added to queued tasks.

#### Usage

    Rush$push_tasks(
      xss,
      extra = NULL,
      seeds = NULL,
      timeouts = NULL,
      max_retries = NULL,
      terminate_workers = FALSE
    )

#### Arguments

- `xss`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists of arguments for the function e.g.
  `list(list(x1, x2), list(x1, x2)))`.

- `extra`:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  List of additional information stored along with the task e.g.
  `list(list(timestamp), list(timestamp)))`.

- `seeds`:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  List of L'Ecuyer-CMRG seeds for each task e.g
  `list(list(c(104071, 490840688, 1690070564, -495119766, 503491950, 1801530932, -1629447803)))`.
  If `NULL` but an initial seed is set, L'Ecuyer-CMRG seeds are
  generated from the initial seed. If `NULL` and no initial seed is set,
  no seeds are used for the random number generator.

- `timeouts`:

  ([`integer()`](https://rdrr.io/r/base/integer.html))  
  Timeouts for each task in seconds e.g. `c(10, 15)`. A single number is
  used as the timeout for all tasks. If `NULL` no timeout is set.

- `max_retries`:

  ([`integer()`](https://rdrr.io/r/base/integer.html))  
  Number of retries for each task. A single number is used as the number
  of retries for all tasks. If `NULL` tasks are not retried.

- `terminate_workers`:

  (`logical(1)`)  
  Whether to stop the workers after evaluating the tasks.

#### Returns

([`character()`](https://rdrr.io/r/base/character.html))  
Keys of the tasks.

------------------------------------------------------------------------

### Method `push_priority_tasks()`

Pushes a task to the queue of a specific worker. Task is added to queued
priority tasks. A worker evaluates the tasks in the priority queue
before the shared queue. If `priority` is `NA` the task is added to the
shared queue. If the worker is lost or worker id is not known, the task
is added to the shared queue.

#### Usage

    Rush$push_priority_tasks(xss, extra = NULL, priority = NULL)

#### Arguments

- `xss`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists of arguments for the function e.g.
  `list(list(x1, x2), list(x1, x2)))`.

- `extra`:

  (`list`)  
  List of additional information stored along with the task e.g.
  `list(list(timestamp), list(timestamp)))`.

- `priority`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Worker ids to which the tasks should be pushed.

#### Returns

([`character()`](https://rdrr.io/r/base/character.html))  
Keys of the tasks.

------------------------------------------------------------------------

### Method `push_failed()`

Pushes failed tasks to the data base. Tasks are moved from queued and
running to failed.

#### Usage

    Rush$push_failed(keys, conditions)

#### Arguments

- `keys`:

  (`character(1)`)  
  Keys of the associated tasks.

- `conditions`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  List of lists of conditions.

------------------------------------------------------------------------

### Method `empty_queue()`

Empty the queue of tasks. Moves tasks from queued to failed.

#### Usage

    Rush$empty_queue(keys = NULL, conditions = NULL)

#### Arguments

- `keys`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of the tasks to be moved. Defaults to all queued tasks.

- `conditions`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  List of lists of conditions.

------------------------------------------------------------------------

### Method `fetch_queued_tasks()`

Fetch queued tasks from the data base.

#### Usage

    Rush$fetch_queued_tasks(fields = c("xs", "xs_extra"))

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to `c("xs", "xs_extra")`.

#### Returns

`data.table()`  
Table of queued tasks.

------------------------------------------------------------------------

### Method `fetch_priority_tasks()`

Fetch queued priority tasks from the data base.

#### Usage

    Rush$fetch_priority_tasks(fields = c("xs", "xs_extra"))

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to `c("xs", "xs_extra")`.

#### Returns

`data.table()`  
Table of queued priority tasks.

------------------------------------------------------------------------

### Method `fetch_running_tasks()`

Fetch running tasks from the data base.

#### Usage

    Rush$fetch_running_tasks(fields = c("xs", "xs_extra", "worker_extra"))

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "xs_extra", "worker_extra")`.

#### Returns

`data.table()`  
Table of running tasks.

------------------------------------------------------------------------

### Method `fetch_finished_tasks()`

Fetch finished tasks from the data base. Finished tasks are cached.

#### Usage

    Rush$fetch_finished_tasks(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"),
      reset_cache = FALSE
    )

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra")`.

- `reset_cache`:

  (`logical(1)`)  
  Whether to reset the cache.

#### Returns

`data.table()`  
Table of finished tasks.

------------------------------------------------------------------------

### Method `wait_for_finished_tasks()`

Block process until a new finished task is available. Returns all
finished tasks or `NULL` if no new task is available after `timeout`
seconds.

#### Usage

    Rush$wait_for_finished_tasks(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra"),
      timeout = Inf
    )

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra")`.

- `timeout`:

  (`numeric(1)`)  
  Time to wait for a result in seconds.

#### Returns

`data.table()`  
Table of finished tasks.

------------------------------------------------------------------------

### Method `fetch_new_tasks()`

Fetch finished tasks from the data base that finished after the last
fetch. Updates the cache of the finished tasks.

#### Usage

    Rush$fetch_new_tasks(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition")
    )

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes.

#### Returns

`data.table()`  
Latest results.

------------------------------------------------------------------------

### Method `wait_for_new_tasks()`

Block process until a new finished task is available. Returns new tasks
or `NULL` if no new task is available after `timeout` seconds.

#### Usage

    Rush$wait_for_new_tasks(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"),
      timeout = Inf
    )

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra")`.

- `timeout`:

  (`numeric(1)`)  
  Time to wait for new result in seconds.

#### Returns

`data.table()`.

------------------------------------------------------------------------

### Method `fetch_failed_tasks()`

Fetch failed tasks from the data base.

#### Usage

    Rush$fetch_failed_tasks(fields = c("xs", "worker_extra", "condition"))

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "xs_extra", "worker_extra", "condition"`.

#### Returns

`data.table()`  
Table of failed tasks.

------------------------------------------------------------------------

### Method `fetch_tasks()`

Fetch all tasks from the data base.

#### Usage

    Rush$fetch_tasks(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition")
    )

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "condition", "state")`.

#### Returns

`data.table()`  
Table of all tasks.

------------------------------------------------------------------------

### Method `fetch_tasks_with_state()`

Fetch tasks with different states from the data base. If tasks with
different states are to be queried at the same time, this function
prevents tasks from appearing twice. This could be the case if a worker
changes the state of a task while the tasks are being fetched. Finished
tasks are cached.

#### Usage

    Rush$fetch_tasks_with_state(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"),
      states = c("queued", "running", "finished", "failed"),
      reset_cache = FALSE
    )

#### Arguments

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes. Defaults to
  `c("xs", "ys", "xs_extra", "worker_extra", "ys_extra")`.

- `states`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  States of the tasks to be fetched. Defaults to
  `c("queued", "running", "finished", "failed")`.

- `reset_cache`:

  (`logical(1)`)  
  Whether to reset the cache of the finished tasks.

------------------------------------------------------------------------

### Method `wait_for_tasks()`

Wait until tasks are finished. The function also unblocks when no worker
is running or all tasks failed.

#### Usage

    Rush$wait_for_tasks(keys, detect_lost_workers = FALSE)

#### Arguments

- `keys`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of the tasks to wait for.

- `detect_lost_workers`:

  (`logical(1)`)  
  Whether to detect failed tasks. Comes with an overhead.

------------------------------------------------------------------------

### Method `write_hashes()`

Writes R objects to Redis hashes. The function takes the vectors in
`...` as input and writes each element as a field-value pair to a new
hash. The name of the argument defines the field into which the
serialized element is written. For example,
`xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4))` writes
`serialize(list(x1 = 1, x2 = 2))` at field `xs` into a hash and
`serialize(list(x1 = 3, x2 = 4))` at field `xs` into another hash. The
function can iterate over multiple vectors simultaneously. For example,
`xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))`
creates two hashes with the fields `xs` and `ys`. The vectors are
recycled to the length of the longest vector. Both lists and atomic
vectors are supported. Arguments that are `NULL` are ignored.

#### Usage

    Rush$write_hashes(..., .values = list(), keys = NULL)

#### Arguments

- `...`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists to be written to the hashes. The names of the arguments are used
  as fields.

- `.values`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists to be written to the hashes. The names of the list are used as
  fields.

- `keys`:

  (character())  
  Keys of the hashes. If `NULL` new keys are generated.

#### Returns

([`character()`](https://rdrr.io/r/base/character.html))  
Keys of the hashes.

------------------------------------------------------------------------

### Method `read_hashes()`

Reads R Objects from Redis hashes. The function reads the field-value
pairs of the hashes stored at `keys`. The values of a hash are
deserialized and combined to a list. If `flatten` is `TRUE`, the values
are flattened to a single list e.g. list(xs = list(x1 = 1, x2 = 2), ys =
list(y = 3)) becomes list(x1 = 1, x2 = 2, y = 3). The reading functions
combine the hashes to a table where the names of the inner lists are the
column names. For example,
`xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))`
becomes `data.table(x1 = c(1, 3), x2 = c(2, 4), y = c(3, 7))`.

#### Usage

    Rush$read_hashes(keys, fields, flatten = TRUE)

#### Arguments

- `keys`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of the hashes.

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hashes.

- `flatten`:

  (`logical(1)`)  
  Whether to flatten the list.

#### Returns

(list of [`list()`](https://rdrr.io/r/base/list.html))  
The outer list contains one element for each key. The inner list is the
combination of the lists stored at the different fields.

------------------------------------------------------------------------

### Method `read_hash()`

Reads a single Redis hash and returns the values as a list named by the
fields.

#### Usage

    Rush$read_hash(key, fields)

#### Arguments

- `key`:

  (`character(1)`)  
  Key of the hash.

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be read from the hash.

#### Returns

(list of [`list()`](https://rdrr.io/r/base/list.html))  
The outer list contains one element for each key. The inner list is the
combination of the lists stored at the different fields.

------------------------------------------------------------------------

### Method `is_running_task()`

Checks whether tasks have the status `"running"`.

#### Usage

    Rush$is_running_task(keys)

#### Arguments

- `keys`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of the tasks.

------------------------------------------------------------------------

### Method `is_failed_task()`

Checks whether tasks have the status `"failed"`.

#### Usage

    Rush$is_failed_task(keys)

#### Arguments

- `keys`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of the tasks.

------------------------------------------------------------------------

### Method `tasks_with_state()`

Returns keys of requested states.

#### Usage

    Rush$tasks_with_state(states)

#### Arguments

- `states`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  States of the tasks.

#### Returns

(Named list of [`character()`](https://rdrr.io/r/base/character.html)).

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Rush$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
# This example is not executed since Redis must be installed
# \donttest{
   config_local = redux::redis_config()
   rush = rsh(network_id = "test_network", config = config_local)
   rush
#> <Rush>
#> * Running Workers: 0
#> * Queued Tasks: 0
#> * Queued Priority Tasks: 0
#> * Running Tasks: 0
#> * Finished Tasks: 0
#> * Failed Tasks: 0
# }
```
