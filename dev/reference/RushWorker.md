# Rush Worker

RushWorker inherits all methods from
[Rush](https://rush.mlr-org.com/dev/reference/Rush.md). Upon
initialization, the worker registers itself in the Redis database.

## Value

Object of class
[R6::R6Class](https://r6.r-lib.org/reference/R6Class.html) and
`RushWorker` with worker methods.

## Super class

[`rush::Rush`](https://rush.mlr-org.com/dev/reference/Rush.md) -\>
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

- [`RushWorker$new()`](#method-RushWorker-new)

- [`RushWorker$set_terminated()`](#method-RushWorker-set_terminated)

- [`RushWorker$clone()`](#method-RushWorker-clone)

Inherited methods

- [`rush::Rush$detect_lost_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-detect_lost_workers)
- [`rush::Rush$empty_queue()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-empty_queue)
- [`rush::Rush$fail_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fail_tasks)
- [`rush::Rush$fetch_failed_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_failed_tasks)
- [`rush::Rush$fetch_finished_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_finished_tasks)
- [`rush::Rush$fetch_new_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_new_tasks)
- [`rush::Rush$fetch_queued_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_queued_tasks)
- [`rush::Rush$fetch_running_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_running_tasks)
- [`rush::Rush$fetch_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_tasks)
- [`rush::Rush$fetch_tasks_with_state()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_tasks_with_state)
- [`rush::Rush$finish_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-finish_tasks)
- [`rush::Rush$format()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-format)
- [`rush::Rush$is_failed_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-is_failed_task)
- [`rush::Rush$is_running_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-is_running_task)
- [`rush::Rush$pop_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-pop_task)
- [`rush::Rush$print()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-print)
- [`rush::Rush$print_log()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-print_log)
- [`rush::Rush$push_failed()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_failed)
- [`rush::Rush$push_failed_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_failed_tasks)
- [`rush::Rush$push_finished_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_finished_tasks)
- [`rush::Rush$push_results()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_results)
- [`rush::Rush$push_running_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_running_tasks)
- [`rush::Rush$push_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_tasks)
- [`rush::Rush$read_hash()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_hash)
- [`rush::Rush$read_hashes()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_hashes)
- [`rush::Rush$read_log()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_log)
- [`rush::Rush$reconnect()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reconnect)
- [`rush::Rush$reset()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reset)
- [`rush::Rush$reset_cache()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reset_cache)
- [`rush::Rush$start_local_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_local_workers)
- [`rush::Rush$start_remote_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_remote_workers)
- [`rush::Rush$start_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_workers)
- [`rush::Rush$stop_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-stop_workers)
- [`rush::Rush$tasks_with_state()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-tasks_with_state)
- [`rush::Rush$wait_for_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-wait_for_tasks)
- [`rush::Rush$wait_for_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-wait_for_workers)
- [`rush::Rush$worker_script()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-worker_script)
- [`rush::Rush$write_hashes()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-write_hashes)

------------------------------------------------------------------------

### Method `new()`

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
  `heartbeat_period` seconds.

- `heartbeat_expire`:

  (`integer(1)`)  
  Time to live of the heartbeat in seconds. The heartbeat key is set to
  expire after `heartbeat_expire` seconds.

------------------------------------------------------------------------

### Method `set_terminated()`

Mark the worker as terminated. Last step in the worker loop before the
worker terminates.

#### Usage

    RushWorker$set_terminated()

#### Returns

(`RushWorker`)  
Invisible self.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    RushWorker$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
