
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

-   Parallelize arbitrary R expressions.
-   Centralized and decentralized network architecture.
-   Small overhead of a few milliseconds per task.
-   Easy start of local workers with `processx`
-   Start workers on any platform with a batch script.
-   Designed to work with
    [`data.table`](https://cran.r-project.org/web/packages/data.table/index.html).
-   Results are cached in the R session to minimize read and write
    operations.
-   Detect and recover from worker failures.
-   Start heartbeats to monitor workers on remote machines.
-   Snapshot the in-memory data base to disk.
-   Store
    [`lgr`](https://cran.r-project.org/web/packages/lgr/index.html)
    messages of the workers in the Redis data base.
-   Light on dependencies.

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

We start two workers.

``` r
rush$start_workers(fun = fun, n_workers = 2)
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

    ##       x1    x2    pid                            worker_id     y    state
    ##    <num> <num>  <int>                               <char> <num>   <char>
    ## 1:     3     5 334357 999e4669-6733-4a0a-b59f-2b7592fea479     8 finished
    ## 2:     4     6 334354 bc58f319-177f-41de-bcde-04cf34ac5ef3    10 finished
    ##                                    keys
    ##                                  <char>
    ## 1: 5231bcf8-d540-43f7-b519-4d3b6a586774
    ## 2: aa6d2f4c-d2f2-452d-a831-4d36d00c4bf3

## Decentralized Rush Network

![](man/figures/README-flow-2.png)

*Decentralized network with four workers.*
