# Get Rush Config

Returns the rush config that was set by
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md).

## Usage

``` r
rush_config()
```

## Value

[`list()`](https://rdrr.io/r/base/list.html) with the stored
configuration.

## Examples

``` r
# This example is not executed since Redis must be installed
# \donttest{
  config_local = redux::redis_config()
  rush_plan(config = config_local, n_workers = 2)
  rush_config()
#> $config
#> Redis configuration:
#>   - url: redis://127.0.0.1:6379
#>   - scheme: redis
#>   - host: 127.0.0.1
#>   - port: 6379
#>   - path: 
#>   - password: 
#>   - db: 
#>   - timeout: 
#> 
#> $n_workers
#> [1] 2
#> 
#> $lgr_thresholds
#> NULL
#> 
#> $lgr_buffer_size
#> NULL
#> 
#> $large_objects_path
#> NULL
#> 
#> $start_worker_timeout
#> NULL
#> 
#> $worker_type
#> [1] "mirai"
#> 
# }
```
