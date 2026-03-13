# Remove Rush Plan

Removes the rush plan that was set by
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md).

## Usage

``` r
remove_rush_plan()
```

## Value

Invisible `TRUE`. Function called for side effects.

## Examples

``` r
if (redux::redis_available()) {
  config_local = redux::redis_config()
  rush_plan(config = config_local, n_workers = 2)
  remove_rush_plan()
}
```
