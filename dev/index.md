# rush

Package website: [release](https://rush.mlr-org.com/) \|
[dev](https://rush.mlr-org.com/dev/)

*rush* is an R package for asynchronous and decentralized optimization.
It uses a database-centric architecture in which workers communicate
through a shared [`Redis`](https://redis.io/) database. To support
high-throughput workloads, rush combines sub-millisecond per-task
overhead with caching strategies that reduce database operations. The
package integrates with the `mlr3` ecosystem and serves as the backend
for asynchronous optimization algorithms in
[`bbotk`](https://CRAN.R-project.org/package=bbotk) and
[`mlr3tuning`](https://CRAN.R-project.org/package=mlr3tuning).

# Features

- Database-centric architecture for decentralized optimization without a
  central controller.
- Asynchronous communication between workers using
  [`Redis`](https://redis.io/).
- Sub-millisecond per-task overhead for high-throughput workloads.
- Efficient caching mechanism that minimizes database read/write
  operations.
- Task queue support for centralized tasks distribution when needed.
- Fast data transformation from Redis to
  [`data.table`](https://CRAN.R-project.org/package=data.table).
- Scales to large remote worker networks via the
  [`mirai`](https://CRAN.R-project.org/package=mirai) package.
- Worker logging directly into the Redis database using
  [`lgr`](https://CRAN.R-project.org/package=lgr).
- Minimal dependencies for lightweight integration.

## Install

Install the latest release from CRAN.

``` r
install.packages("rush")
```

Install the development version from GitHub.

``` r
pak::pak("mlr-org/rush")
```

And install
[Redis](https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/).

## Test with Redis

To test the package, set the `RUSH_TEST_USE_REDIS` environment variable
to `true`. The test suite deletes the Redis database before execution,
so never run it against a production server.

``` r
Sys.setenv(RUSH_TEST_USE_REDIS = "true")
```

# Related Work

- [future](https://CRAN.R-project.org/package=future)
- [mirai](https://CRAN.R-project.org/package=mirai)
- [batchtools](https://CRAN.R-project.org/package=batchtools)
- [crew](https://CRAN.R-project.org/package=crew)
- [rrq](https://github.com/mrc-ide/rrq)
