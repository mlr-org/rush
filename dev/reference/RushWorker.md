# Rush Worker

RushWorker evaluates tasks and writes results to the data base. The
worker inherits from
[Rush](https://rush.mlr-org.com/dev/reference/Rush.md).

## Value

Object of class
[R6::R6Class](https://r6.r-lib.org/reference/R6Class.html) and
`RushWorker` with worker methods.

## Note

The worker registers itself in the data base of the rush network.

## Super class

[`rush::Rush`](https://rush.mlr-org.com/dev/reference/Rush.md) -\>
`RushWorker`

## Public fields

- `worker_id`:

  (`character(1)`)  
  Identifier of the worker.

- `remote`:

  (`logical(1)`)  
  Whether the worker is on a remote machine.

- `heartbeat`:

  ([`callr::r_bg`](https://callr.r-lib.org/reference/r_bg.html))  
  Background process for the heartbeat.

## Active bindings

- `terminated`:

  (`logical(1)`)  
  Whether to shutdown the worker. Used in the worker loop to determine
  whether to continue.

- `terminated_on_idle`:

  (`logical(1)`)  
  Whether to shutdown the worker if no tasks are queued. Used in the
  worker loop to determine whether to continue.

## Methods

### Public methods

- [`RushWorker$new()`](#method-RushWorker-new)

- [`RushWorker$push_running_tasks()`](#method-RushWorker-push_running_tasks)

- [`RushWorker$pop_task()`](#method-RushWorker-pop_task)

- [`RushWorker$push_results()`](#method-RushWorker-push_results)

- [`RushWorker$set_terminated()`](#method-RushWorker-set_terminated)

- [`RushWorker$clone()`](#method-RushWorker-clone)

Inherited methods

- [`rush::Rush$detect_lost_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-detect_lost_workers)
- [`rush::Rush$empty_queue()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-empty_queue)
- [`rush::Rush$fetch_failed_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_failed_tasks)
- [`rush::Rush$fetch_finished_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_finished_tasks)
- [`rush::Rush$fetch_new_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_new_tasks)
- [`rush::Rush$fetch_priority_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_priority_tasks)
- [`rush::Rush$fetch_queued_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_queued_tasks)
- [`rush::Rush$fetch_running_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_running_tasks)
- [`rush::Rush$fetch_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_tasks)
- [`rush::Rush$fetch_tasks_with_state()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-fetch_tasks_with_state)
- [`rush::Rush$format()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-format)
- [`rush::Rush$is_failed_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-is_failed_task)
- [`rush::Rush$is_running_task()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-is_running_task)
- [`rush::Rush$print()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-print)
- [`rush::Rush$print_log()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-print_log)
- [`rush::Rush$push_failed()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_failed)
- [`rush::Rush$push_priority_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_priority_tasks)
- [`rush::Rush$push_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-push_tasks)
- [`rush::Rush$read_hash()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_hash)
- [`rush::Rush$read_hashes()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_hashes)
- [`rush::Rush$read_log()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-read_log)
- [`rush::Rush$reconnect()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reconnect)
- [`rush::Rush$reset()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reset)
- [`rush::Rush$reset_data()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-reset_data)
- [`rush::Rush$restart_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-restart_workers)
- [`rush::Rush$start_local_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_local_workers)
- [`rush::Rush$start_remote_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-start_remote_workers)
- [`rush::Rush$stop_workers()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-stop_workers)
- [`rush::Rush$tasks_with_state()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-tasks_with_state)
- [`rush::Rush$wait_for_finished_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-wait_for_finished_tasks)
- [`rush::Rush$wait_for_new_tasks()`](https://rush.mlr-org.com/dev/reference/Rush.html#method-wait_for_new_tasks)
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
      remote,
      worker_id = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      seed = NULL
    )

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

- `remote`:

  (`logical(1)`)  
  Whether the worker is started on a remote machine. See
  [Rush](https://rush.mlr-org.com/dev/reference/Rush.md) for details.

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

- `seed`:

  ([`integer()`](https://rdrr.io/r/base/integer.html))  
  Initial seed for the random number generator. Either a L'Ecuyer-CMRG
  seed (`integer(7)`) or a regular RNG seed (`integer(1)`). The later is
  converted to a L'Ecuyer-CMRG seed. If `NULL`, no seed is used for the
  random number generator.

------------------------------------------------------------------------

### Method `push_running_tasks()`

Push a task to running tasks without queue.

#### Usage

    RushWorker$push_running_tasks(xss, extra = NULL)

#### Arguments

- `xss`:

  (list of named [`list()`](https://rdrr.io/r/base/list.html))  
  Lists of arguments for the function e.g.
  `list(list(x1, x2), list(x1, x2)))`.

- `extra`:

  (`list`)  
  List of additional information stored along with the task e.g.
  `list(list(timestamp), list(timestamp)))`.

#### Returns

([`character()`](https://rdrr.io/r/base/character.html))  
Keys of the tasks.

------------------------------------------------------------------------

### Method `pop_task()`

Pop a task from the queue. Task is moved to the running tasks.

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

### Method `push_results()`

Pushes results to the data base.

#### Usage

    RushWorker$push_results(keys, yss, extra = NULL)

#### Arguments

- `keys`:

  (`character(1)`)  
  Keys of the associated tasks.

- `yss`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  List of lists of named results.

- `extra`:

  (named [`list()`](https://rdrr.io/r/base/list.html))  
  List of lists of additional information stored along with the results.

------------------------------------------------------------------------

### Method `set_terminated()`

Mark the worker as terminated. Last step in the worker loop before the
worker terminates.

#### Usage

    RushWorker$set_terminated()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    RushWorker$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
