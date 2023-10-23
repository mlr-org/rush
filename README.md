
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rush

*rush* is a package for parallel and distributed computing in R. It
evaluates an R expression asynchronously on a cluster of workers and
provides a shared storage between the workers. The shared storage is a
[Redis](https://redis.io) data base. Rush offers a centralized and
decentralized network architecture. The centralized network has a single
controller (`Rush`) and multiple workers (`RushWorker`). Tasks are
created centrally and distributed to workers by the controller. The
decentralized network has no controller. The workers sample tasks and
communicate the results asynchronously with other workers.

# Features

  - Parallelize arbitrary R expressions.
  - Centralized and decentralized network architecture.
  - Small overhead of a few milliseconds per task.
  - Easy starting of workers with the
    [`future`](https://future.futureverse.org/) package.
  - Start workers on any platform with a batch script.
  - Designed to work with
    [`data.table`](https://cran.r-project.org/web/packages/data.table/index.html).
  - Results are cached in the R session to minimize read and write
    operations.
  - Detect and recover from worker failures.
  - Start heartbeats to monitor workers on remote machines.
  - Snapshot the in-memory data base to disk.
  - Store
    [`lgr`](https://cran.r-project.org/web/packages/lgr/index.html)
    messages of the workers in the Redis data base.
  - Light on dependencies.

## Install

Install the development version from GitHub.

``` r
remotes::install_github("mlr-org/rush")
```

And install
[Redis](https://redis.io/docs/getting-started/installation/).

## Centralized Rush Network

![](man/figures/README-flow.png)

*Centralized network with a single controller and three workers.*

The example below shows the evaluation of a simple function in a
centralized network. The `network_id` identifies the instance and
workers in the network. The `config` is a list of parameters for the
connection to Redis.

``` r
library(rush)

config = redux::redis_config()
rush = Rush$new(network_id = "test", config)

rush
```

    ## <Rush>
    ## * Running Workers: 0
    ## * Queued Tasks: 0
    ## * Queued Priority Tasks: 0
    ## * Running Tasks: 0
    ## * Finished Tasks: 0
    ## * Failed Tasks: 0

Next, we define a function that we want to evaluate on the workers.

``` r
fun = function(x1, x2, ...) {
  list(y = x1 + x2)
}
```

We start two workers with the
[`future`](https://future.futureverse.org/) package.

``` r
future::plan("multisession", workers = 2)

rush$start_workers(fun = fun)
```

Now we can push tasks to the workers.

``` r
xss = list(list(x1 = 3, x2 = 5), list(x1 = 4, x2 = 6))
keys = rush$push_tasks(xss)
rush$await_tasks(keys)
```

And retrieve the results.

``` r
rush$fetch_finished_tasks()
```

    ##    x1 x2    pid                            worker_id  y   status
    ## 1:  3  5 224861 aaa9bbea-ab25-4c47-a9ef-2cde95ee7144  8 finished
    ## 2:  4  6 234065 858f7aa4-18bd-48e0-a69f-0f0297a9051c 10 finished
    ##                                    keys
    ## 1: c37c5467-693d-4df9-a1f6-fd2a5d0aaf65
    ## 2: 0bd23506-eecb-42ee-beba-a37be45b51b8

## Decentralized Rush Network

![](man/figures/README-flow-2.png)

*Decentralized network with four workers.*
