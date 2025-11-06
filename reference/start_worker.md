# Start a worker

Starts a worker. The function loads the globals and packages,
initializes the
[RushWorker](https://rush.mlr-org.com/reference/RushWorker.md) instance
and invokes the worker loop. This function is called by
`$start_local_workers()` or by the user after creating the worker script
with `$create_worker_script()`. Use with caution. The global environment
is changed.

## Usage

``` r
start_worker(
  worker_id = NULL,
  network_id,
  config = NULL,
  remote = TRUE,
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
  Identifier of the rush network. Controller and workers must have the
  same instance id. Keys in Redis are prefixed with the instance id.

- config:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  Configuration for the Redis connection.

- remote:

  (`logical(1)`)  
  Whether the worker is on a remote machine.

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
  `heartbeat_period` seconds.

- heartbeat_expire:

  (`integer(1)`)  
  Time to live of the heartbeat in seconds. The heartbeat key is set to
  expire after `heartbeat_expire` seconds.

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

## Note

The function initializes the connection to the Redis data base. It loads
the packages and copies the globals to the global environment of the
worker. The function initialize the
[RushWorker](https://rush.mlr-org.com/reference/RushWorker.md) instance
and starts the worker loop.

## Examples

``` r
# This example is not executed since Redis must be installed
if (FALSE) { # \dontrun{
  rush::start_worker(
   network_id = 'test-rush',
   remote = TRUE,
   url = 'redis://127.0.0.1:6379',
   scheme = 'redis',
   host = '127.0.0.1',
   port = '6379')
} # }
```
