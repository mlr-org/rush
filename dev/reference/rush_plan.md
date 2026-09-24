# Create Rush Plan

Stores the number of workers and Redis configuration options
([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))
for [Rush](https://rush.mlr-org.com/dev/reference/Rush.md). Instead of a
single number of workers, the workers can be distributed over the
compute profiles of [mirai](https://CRAN.R-project.org/package=mirai)
with the `profiles` argument. The function tests the connection to Redis
and throws an error if the connection fails. This function is usually
used in third-party packages to setup how workers are started.

## Usage

``` r
rush_plan(
  n_workers = NULL,
  config = NULL,
  lgr_thresholds = NULL,
  lgr_buffer_size = NULL,
  large_objects_path = NULL,
  worker_type = "mirai",
  start_worker_timeout = NULL,
  profiles = NULL,
  restart = FALSE,
  launcher = NULL,
  max_restarts = 3L
)
```

## Arguments

- n_workers:

  (`integer(1)`)  
  Number of workers to be started.

- config:

  ([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))  
  Configuration options used to connect to Redis. If `NULL`, the
  `REDIS_URL` environment variable is parsed. If `REDIS_URL` is not set,
  a default configuration is used. See
  [redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html)
  for details.

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

- large_objects_path:

  (`character(1)`)  
  The path to the directory where large objects are stored. These files
  are not removed automatically and the caller is responsible for
  cleaning them up, e.g. by pointing this at a subdirectory of
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- worker_type:

  (`character(1)`)  
  The type of worker to use. Options are `"mirai"` to start with
  [mirai](https://CRAN.R-project.org/package=mirai), `"processx"` to use
  [processx](https://CRAN.R-project.org/package=processx) or `"script"`
  to get a script to run.

- start_worker_timeout:

  (`numeric(1)`)  
  Default timeout in seconds used by `$wait_for_workers()` of
  [Rush](https://rush.mlr-org.com/dev/reference/Rush.md) when no
  `timeout` is passed. If `NULL`, `$wait_for_workers()` waits
  indefinitely by default. A timeout of `0` checks once and errors
  immediately if the workers are not yet registered.

- profiles:

  (named [`integer()`](https://rdrr.io/r/base/integer.html))  
  Number of workers to be started on each `mirai` compute profile, e.g.
  `c(cpu = 2, gpu = 2)`. The names are the compute profiles created with
  [`mirai::daemons()`](https://mirai.r-lib.org/reference/daemons.html)
  and the values are the number of workers started on the daemons of the
  respective profile. Cannot be combined with `n_workers`.

- restart:

  (`logical(1)`)  
  Whether to restart lost workers started with `$start_workers()`.
  `$detect_lost_workers()` starts a new worker with a new worker id for
  each lost worker. The new worker runs on the same compute profile and
  stores the id of the lost worker in `restarted_from`. Default is
  `FALSE`.

- launcher:

  (`function()` \| [`list()`](https://rdrr.io/r/base/list.html))  
  Relaunches a daemon when the daemon of a lost worker has died, e.g.
  because its Slurm job was canceled. Either a launcher configuration of
  [mirai](https://CRAN.R-project.org/package=mirai) created with
  [`mirai::cluster_config()`](https://mirai.r-lib.org/reference/cluster_config.html),
  [`mirai::ssh_config()`](https://mirai.r-lib.org/reference/ssh_config.html),
  or
  [`mirai::remote_config()`](https://mirai.r-lib.org/reference/remote_config.html),
  which is passed to
  [`mirai::launch_remote()`](https://mirai.r-lib.org/reference/launch_local.html),
  or a function with the arguments `n` and `profile` that launches `n`
  daemons on the compute profile `profile`. If `NULL`, the new worker
  waits until a daemon is available, e.g. because the scheduler requeues
  the job. Only used if `restart = TRUE`.

- max_restarts:

  (`integer(1)`)  
  Maximum number of restarts of a worker and its successors. Default is
  `3`.

## Value

[`list()`](https://rdrr.io/r/base/list.html) with the stored
configuration.

## Examples

``` r
if (redux::redis_available()) {
  config_local = redux::redis_config()
  rush_plan(config = config_local, n_workers = 2)

  rush = rsh(network_id = "test_network")
  rush
}
#> 
#> ── <Rush> ──────────────────────────────────────────────────────────────────────
#> • Running Workers: 0
#> • Queued Tasks: 0
#> • Running Tasks: 0
#> • Finished Tasks: 0
#> • Failed Tasks: 0
```
