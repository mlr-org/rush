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
```

## Arguments

- rush:

  ([Rush](https://rush.mlr-org.com/reference/Rush.md)).

- null_ok:

  (`logical(1)`). If `TRUE`, `NULL` is allowed.

- rushs:

  (list of [Rush](https://rush.mlr-org.com/reference/Rush.md)).

- worker:

  ([RushWorker](https://rush.mlr-org.com/reference/RushWorker.md)).

- workers:

  (list of
  [RushWorker](https://rush.mlr-org.com/reference/RushWorker.md)).

## Value

Exception if the assertion fails, otherwise the input object invisibly.

## Examples

``` r
# This example is not executed since Redis must be installed
# \donttest{
   config_local = redux::redis_config()
   rush = rsh(network_id = "test_network", config = config_local)

   assert_rush(rush)
# }
```
