# Assertion for Rush Objects

Most assertion functions ensure the right class attribute, and
optionally additional properties. If an assertion fails, an exception is
raised. Otherwise, the input object is returned invisibly.

## Usage

``` r
assert_rush(rush, null_ok = FALSE)

assert_rushs(rushs, null_ok = FALSE)

assert_rush_worker(worker, null_ok = FALSE)

assert_rush_workers(workers, null_ok = FALSE)

assert_profiles(profiles)
```

## Arguments

- rush:

  ([Rush](https://rush.mlr-org.com/dev/reference/Rush.md)).

- null_ok:

  (`logical(1)`). If `TRUE`, `NULL` is allowed.

- rushs:

  (list of [Rush](https://rush.mlr-org.com/dev/reference/Rush.md)).

- worker:

  ([RushWorker](https://rush.mlr-org.com/dev/reference/RushWorker.md)).

- workers:

  (list of
  [RushWorker](https://rush.mlr-org.com/dev/reference/RushWorker.md)).

- profiles:

  (named [`integer()`](https://rdrr.io/r/base/integer.html)). The names
  are `mirai` compute profiles and the values the number of workers per
  profile. Unlike the other assertions, the profiles are returned
  coerced to [`integer()`](https://rdrr.io/r/base/integer.html) and not
  invisibly. If `NULL`, `NULL` is returned.

## Value

Exception if the assertion fails, otherwise the input object invisibly.

## Examples

``` r
if (redux::redis_available()) {
   config_local = redux::redis_config()
   rush = rsh(network_id = "test_network", config = config_local)

   assert_rush(rush)
}
```
