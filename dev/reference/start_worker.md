# Start a worker

Starts a worker. The function loads packages, initializes the
[RushWorker](https://rush.mlr-org.com/dev/reference/RushWorker.md)
instance and invokes the worker loop. This function is called by
`$start_local_workers()` or by the user after creating the worker script
with `$worker_script()`.

## Usage

``` r
start_worker(
  worker_id = NULL,
  network_id,
  config = NULL,
  lgr_thresholds = NULL,
  lgr_buffer_size = 0,
  heartbeat_period = NULL,
  heartbeat_expire = NULL,
  message_log = NULL,
  output_log = NULL
)
```

## Arguments

- worker_id:

  (`character(1)`)  
  Identifier of the worker. Keys in redis specific to the worker are
  prefixed with the worker id.

- network_id:

  (`character(1)`)  
  Identifier of the rush network. Manager and workers must have the same
  id. Keys in Redis are prefixed with the instance id.

- config:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  Configuration for the Redis connection.

- lgr_thresholds:

  (named [`character()`](https://rdrr.io/r/base/character.html) \| named
  [`numeric()`](https://rdrr.io/r/base/numeric.html))  
  Logger threshold on the workers e.g. `c("mlr3/rush" = "debug")`.

- lgr_buffer_size:

  (`integer(1)`)  
  By default (`lgr_buffer_size = 0`), the log messages are directly
  saved in the Redis data store. If `lgr_buffer_size > 0`, the log
  messages are buffered and saved in the Redis data store when the
  buffer is full. This improves the performance of the logging.

- heartbeat_period:

  (`integer(1)`)  
  Period of the heartbeat in seconds. The heartbeat is updated every
  `heartbeat_period` seconds. Must be at least 1 second.

- heartbeat_expire:

  (`integer(1)`)  
  Time to live of the heartbeat in seconds. The heartbeat key is set to
  expire after `heartbeat_expire` seconds. Must be at least
  `heartbeat_period`, otherwise a live worker is reaped as lost between
  two heartbeats. Set it larger than the longest pause a worker may
  experience, for example from garbage collection or swapping, because a
  live worker wrongly declared lost can leave a task in an inconsistent
  state.

- message_log:

  (`character(1)`)  
  Path to the message log files e.g. `/tmp/message_logs/` The message
  log files are named `message_<worker_id>.log`. If `NULL`, no messages,
  warnings or errors are stored.

- output_log:

  (`character(1)`)  
  Path to the output log files e.g. `/tmp/output_logs/` The output log
  files are named `output_<worker_id>.log`. If `NULL`, no output is
  stored.

## Value

`NULL`

## Examples

``` r
# This example is not executed since Redis must be installed
if (FALSE) { # \dontrun{
  rush::start_worker(
    network_id = "test-rush",
    config = list(host = "127.0.0.1", port = "6379"))
} # }
```
