# Synctatic Sugar for Rush Controller Construction

Function to construct a
[Rush](https://rush.mlr-org.com/dev/reference/Rush.md) controller.

## Usage

``` r
rsh(network_id = NULL, config = NULL, seed = NULL, ...)
```

## Arguments

- network_id:

  (`character(1)`)  
  Identifier of the rush network. Controller and workers must have the
  same instance id. Keys in Redis are prefixed with the instance id.

- config:

  ([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))  
  Redis configuration options. If `NULL`, configuration set by
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  is used. If
  [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
  has not been called, the `REDIS_URL` environment variable is parsed.
  If `REDIS_URL` is not set, a default configuration is used. See
  [redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html)
  for details.

- seed:

  ([`integer()`](https://rdrr.io/r/base/integer.html))  
  Initial seed for the random number generator. Either a L'Ecuyer-CMRG
  seed (`integer(7)`) or a regular RNG seed (`integer(1)`). The later is
  converted to a L'Ecuyer-CMRG seed. If `NULL`, no seed is used for the
  random number generator.

- ...:

  (ignored).

## Value

[Rush](https://rush.mlr-org.com/dev/reference/Rush.md) controller.

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
