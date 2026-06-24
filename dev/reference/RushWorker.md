# Rush Worker

RushWorker inherits all methods from
[Rush](https://rush.mlr-org.com/dev/reference/Rush.md). Upon
initialization, the worker registers itself in the Redis database as a
running worker. This class is usually not constructed directly by the
user.

In addition to the inherited methods, the worker provides methods that
require a worker identity:

- `$pop_task()`: Pop a task from the queue and mark it as running.

- `$push_running_tasks(xss)`: Create running tasks evaluated by the
  worker.

- `$finish_tasks(keys, yss)`: Save the output of tasks and mark them as
  finished.

- `$fail_tasks(keys, conditions)`: Mark tasks as failed and optionally
  save the condition objects.

## Value

Object of class
[R6::R6Class](https://r6.r-lib.org/reference/R6Class.html) and
`RushWorker`.

## Super class

[`Rush`](https://rush.mlr-org.com/dev/reference/Rush.md) -\>
`RushWorker`

## Public fields

- `worker_id`:

  (`character(1)`)  
  Identifier of the worker.

- `heartbeat`:

  ([`callr::r_bg`](https://callr.r-lib.org/reference/r_bg.html))  
  Background process for the heartbeat.

## Active bindings

- `terminated`:

  (`logical(1)`)  
  Whether to shutdown the worker. Used in the worker loop to determine
  whether to continue.

## Methods

### Public methods

- [`RushWorker$new()`](#method-RushWorker-initialize)

- [`RushWorker$pop_task()`](#method-RushWorker-pop_task)

- [`RushWorker$push_running_tasks()`](#method-RushWorker-push_running_tasks)

- [`RushWorker$finish_tasks()`](#method-RushWorker-finish_tasks)

- [`RushWorker$fail_tasks()`](#method-RushWorker-fail_tasks)

- [`RushWorker$set_terminated()`](#method-RushWorker-set_terminated)

- [`RushWorker$clone()`](#method-RushWorker-clone)

Inherited methods

- [`Rush$detect_lost_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-detect_lost_workers)
- [`Rush$empty_queue()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-empty_queue)
- [`Rush$fetch_failed_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_failed_tasks)
- [`Rush$fetch_finished_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_finished_tasks)
- [`Rush$fetch_new_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_new_tasks)
- [`Rush$fetch_queued_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_queued_tasks)
- [`Rush$fetch_running_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_running_tasks)
- [`Rush$fetch_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_tasks)
- [`Rush$fetch_tasks_with_state()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_tasks_with_state)
- [`Rush$format()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-format)
- [`Rush$is_failed_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-is_failed_task)
- [`Rush$is_running_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-is_running_task)
- [`Rush$print()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-print)
- [`Rush$print_log()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-print_log)
- [`Rush$push_failed_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_failed_tasks)
- [`Rush$push_finished_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_finished_tasks)
- [`Rush$push_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_tasks)
- [`Rush$read_hash()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_hash)
- [`Rush$read_hashes()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_hashes)
- [`Rush$read_log()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_log)
- [`Rush$reconnect()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reconnect)
- [`Rush$reset()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reset)
- [`Rush$reset_cache()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reset_cache)
- [`Rush$start_local_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_local_workers)
- [`Rush$start_remote_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_remote_workers)
- [`Rush$start_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_workers)
- [`Rush$stop_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-stop_workers)
- [`Rush$tasks_with_state()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-tasks_with_state)
- [`Rush$wait_for_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-wait_for_tasks)
- [`Rush$wait_for_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-wait_for_workers)
- [`Rush$worker_script()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-worker_script)
- [`Rush$write_hashes()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-write_hashes)

------------------------------------------------------------------------

### `RushWorker$new()`

Creates a new instance of this
[R6](https://r6.r-lib.org/reference/R6Class.html) class.

#### Usage

    RushWorker$new(
      network_id,
      config = NULL,
      worker_id = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL
    )

#### Arguments

- `network_id`:

  (`character(1)`)  
  Identifier of the rush network. Manager and workers must have the same
  id. Keys in Redis are prefixed with the instance id.

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

- `worker_id`:

  (`character(1)`)  
  Identifier of the worker. Keys in redis specific to the worker are
  prefixed with the worker id.

- `heartbeat_period`:

  (`integer(1)`)  
  Period of the heartbeat in seconds. The heartbeat is updated every
  `heartbeat_period` seconds. Must be at least 1 second.

- `heartbeat_expire`:

  (`integer(1)`)  
  Time to live of the heartbeat in seconds. The heartbeat key is set to
  expire after `heartbeat_expire` seconds. Must be at least
  `heartbeat_period`, otherwise a live worker is reaped as lost between
  two heartbeats. Set it larger than the longest pause a worker may
  experience, for example from garbage collection or swapping, because a
  live worker wrongly declared lost can leave a task in an inconsistent
  state.

------------------------------------------------------------------------

### `RushWorker$pop_task()`

Pop a task from the queue and mark it as running.

#### Usage

    RushWorker$pop_task(timeout = 1, fields = "xs")

#### Arguments

- `timeout`:

  (`numeric(1)`)  
  Time to wait for task in seconds.

- `fields`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Fields to be returned.

------------------------------------------------------------------------

### `RushWorker$push_running_tasks()`

Create running tasks.

#### Usage

    RushWorker$push_running_tasks(xss, xss_extra = NULL, extra = NULL)

#### Arguments

- `xss`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists of arguments for the function e.g.
  `list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4))`. If `xss` is empty,
  no tasks are created and the method returns an empty
  [`character()`](https://rdrr.io/r/base/character.html).

- `xss_extra`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  List of additional information stored along with the task e.g.
  `list(list(timestamp_xs = Sys.time()), list(timestamp_xs = Sys.time()))`.

- `extra`:

  (`list`)  
  Deprecated argument for additional information stored along with the
  task. Use `xss_extra` instead.

#### Returns

([`character()`](https://rdrr.io/r/base/character.html))  
Keys of the tasks.

------------------------------------------------------------------------

### `RushWorker$finish_tasks()`

Save the output of tasks and mark them as finished.

#### Usage

    RushWorker$finish_tasks(keys, yss, yss_extra = NULL, extra = NULL)

#### Arguments

- `keys`:

  (`character(1)`)  
  Keys of the associated tasks.

- `yss`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists of results for the function e.g.
  `list(list(y1 = 1, y2 = 2), list(y1 = 3, y2 = 4))`.

- `yss_extra`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  List of additional information stored along with the results e.g.
  `list(list(timestamp_ys = Sys.time()), list(timestamp_ys = Sys.time()))`.

- `extra`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  Deprecated argument for additional information stored along with the
  results. Use `yss_extra` instead.

#### Returns

(`RushWorker`)  
Invisible self.

------------------------------------------------------------------------

### `RushWorker$fail_tasks()`

Move running tasks to failed and optionally save the condition objects.

#### Usage

    RushWorker$fail_tasks(keys, conditions = NULL)

#### Arguments

- `keys`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Keys of the running tasks to be moved.

- `conditions`:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  List conditions e.g.
  `list(simpleError("Error"), simpleError("Error"))`. Defaults to
  `list(message = "Task failed")`.

#### Returns

(`RushWorker`)  
Invisible self.

------------------------------------------------------------------------

### `RushWorker$set_terminated()`

Mark the worker as terminated. Last step in the worker loop before the
worker terminates.

#### Usage

    RushWorker$set_terminated()

#### Returns

(`RushWorker`)  
Invisible self.

------------------------------------------------------------------------

### `RushWorker$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RushWorker$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
