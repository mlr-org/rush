
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rush

Rush is a package for parallel and distributed computing in R. It
parallelizes the evaluation of R functions on a cluster of workers and
provides a shared storage between the workers. The shared storage is a
[Redis](https://redis.io) data base. Rush offers the option to define a
single manager who distributes tasks to the workers. Alternatively, the
workers can create tasks themselves and communicate the results with
each other via Rush.

![](man/figures/README-flow.png)

Single manager with multiple workers strategy.

## Install

[Install Redis](https://redis.io/docs/getting-started/installation/)

## Example

Initialize the rush controller instance. The `instance_id` identifies
the instance and worker in the network. The `config` is a list of
parameters for the connection to Redis.

``` r
library(rush)
library(redux)

config = redux::redis_config()
rush = Rush$new(instance_id = "test", config)

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

We start two worker with the [`future`](https://future.futureverse.org/)
package.

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
    ## 1:  4  6 189379 8219bdc4-a7e7-485e-b747-ba9ed83b8846 10 finished
    ## 2:  3  5 189380 d1719b60-d066-4fd9-93be-94dffcfb08a5  8 finished
    ##                                    keys
    ## 1: acbf50d1-cafe-4628-a05d-a3ed72317aef
    ## 2: 452e5a1b-8019-4ec9-98fe-ebf537878762

## Task States

Tasks have four states: `queued`, `running`, `finished`, `failed`.

  - `queued` tasks are in the wait list.
  - `running` tasks are evaluated on a worker.
  - `finished` tasks pushed their result to the data base.
  - `failed` tasks threw an error.

## Worker States

Workers have four states: `running`, `terminated`, `killed`, `lost`.

  - `running` workers are evaluating tasks.
  - `terminated` workers are stopped.
  - `killed` workers were killed by the user.
  - `lost` workers crashed.
