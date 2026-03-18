# Rush Available

Returns `TRUE` if a redis config file
([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))
has been set by
[`rush_plan()`](https://rush.mlr-org.com/reference/rush_plan.md).

## Usage

``` r
rush_available()
```

## Value

`logical(1)`

## Examples

``` r
if (redux::redis_available()) {
  config_local = redux::redis_config()
  rush_plan(config = config_local, n_workers = 2)
  rush_available()
}
#> [1] TRUE
```
