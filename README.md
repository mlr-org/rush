
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rush

Package website: [release](https://rush.mlr-org.com/) \|
[dev](https://rush.mlr-org.com/dev/)

<!-- badges: start -->

[![r-cmd-check](https://github.com/mlr-org/rush/actions/workflows/r-cmd-check.yml/badge.svg)](https://github.com/mlr-org/rush/actions/workflows/r-cmd-check.yml)
[![CRAN
Status](https://www.r-pkg.org/badges/version-ago/rush)](https://cran.r-project.org/package=rush)
[![Mattermost](https://img.shields.io/badge/chat-mattermost-orange.svg)](https://lmmisld-lmu-stats-slds.srv.mwn.de/mlr_invite/)
<!-- badges: end -->

*rush* is a package designed to solve large-scale problems
asynchronously across a distributed network. Employing a database
centric model, rush enables workers to communicate tasks and their
results over a shared [`Redis`](https://redis.io/) database. Key
features include low task overhead, efficient caching, and robust error
handling. The package powers asynchronous optimization algorithms in the
[`bbotk`](https://CRAN.R-project.org/package=bbotk) and
[`mlr3tuning`](https://CRAN.R-project.org/package=paradox) packages.

# Features

- Database centric model for robust scalability.
- Efficient communication between workers
  using[`Redis`](https://redis.io/).
- Maintains low overhead, limiting delays to just a millisecond per
  task.
- Reduces read/write operations with a lightweight and efficient caching
  system.
- Offers centralized system features, such as task queues.
- Provides fast data transformation from Redis to
  [`data.table`](https://CRAN.R-project.org/package=data.table).
- Simplifies local worker setup with
  [`processx`](https://CRAN.R-project.org/package=processx).
- Enables scaling to large remote worker networks via the
  [`mirai`](https://CRAN.R-project.org/package=mirai) package.
- Automatically detects and recovers from worker failures for high
  reliability.
- Logs worker messages directly into the Redis database using
  [`lgr`](https://CRAN.R-project.org/package=lgr).
- Designed with minimal dependencies for lightweight integration.

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

# Related Work

- The [rrq](https://github.com/mrc-ide/rrq) package is a task queue
  system for R using Redis.
- The [future](https://CRAN.R-project.org/package=future) package
  provides a simple and uniform way of evaluating R expressions
  asynchronously across a range of backends.
- [batchtools](https://CRAN.R-project.org/package=batchtools) is a
  package for the execution of long-running tasks on high-performance
  computing clusters.
- The [mirai](https://CRAN.R-project.org/package=mirai) package
  evaluates an R expression asynchronously in a parallel process,
  locally or distributed over the network.
