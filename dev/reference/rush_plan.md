# Create Rush Plan

Stores the number of workers and Redis configuration options
([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))
for [Rush](https://rush.mlr-org.com/dev/reference/Rush.md). The function
tests the connection to Redis and throws an error if the connection
fails. This function is usually used in third-party packages to setup
how workers are started.

## Usage

``` r
rush_plan(
  n_workers = NULL,
  config = NULL,
  lgr_thresholds = NULL,
  lgr_buffer_size = NULL,
  large_objects_path = NULL,
  worker_type = "mirai"
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
  The path to the directory where large objects are stored.

- worker_type:

  (`character(1)`)  
  The type of worker to use. Options are `"mirai"` to start with
  [mirai](https://CRAN.R-project.org/package=mirai), `"processx"` to use
  [processx](https://CRAN.R-project.org/package=processx) or `"script"`
  to get a script to run.

## Value

[`list()`](https://rdrr.io/r/base/list.html) with the stored
configuration.

## Examples

``` r
# This example is not executed since Redis must be installed
# \donttest{
config_local = redux::redis_config()
rush_plan(config = config_local, n_workers = 2)

rush = rsh(network_id = "test_network")
rush
#> 
#> ── <Rush> ──────────────────────────────────────────────────────────────────────
#> • Running Workers: 0
#> • Queued Tasks: 0
#> • Running Tasks: 0
#> • Finished Tasks: 0
#> • Failed Tasks: 0
# }
```
