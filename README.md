
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rush

Rush is a package for asynchronous parallelization in R. Tasks are
queued and distributed to workers in the background. It heavily uses
Redis as a data base.

![](man/figures/README-flow.png)

## Install

[Install Redis](https://redis.io/docs/getting-started/installation/)

## Example

``` r
library(rush)

# initialize controller
rush = Rush$new("test")

# start workers
future::plan("multisession", workers = 2)

fun = function(x1, x2, ...) {
  list(y = x1 + x2)
}

rush$start_workers(fun)
rush
```

    ## <Rush>
    ## * Running Workers: 1
    ## * Queued Tasks: 0
    ## * Queued Priority Tasks: 0
    ## * Running Tasks: 0
    ## * Finished Tasks: 0
    ## * Failed Tasks: 0

``` r
# push tasks
xss = list(list(x1 = 3, x2 = 5), list(x1 = 4, x2 = 6))
keys = rush$push_tasks(xss)
```

    ## INFO  [22:28:49.274] [rush] Sending 2 task(s)

``` r
rush$wait_tasks(keys)
rush$n_finished_tasks
```

    ## [1] 2

``` r
# get results
rush$data
```

    ##    x1 x2    pid                            worker_id  y   status
    ## 1:  3  5 246883 4e1104ce-810c-44e9-8034-0f6e57208fda  8 finished
    ## 2:  4  6 246883 4e1104ce-810c-44e9-8034-0f6e57208fda 10 finished
    ##                                    keys
    ## 1: 6f117037-fd08-47a0-8cbe-874748175854
    ## 2: 118cf0df-99e6-4fed-8563-c9e3516f73c3

``` r
# push more tasks
xss = list(list(x1 = 1, x2 = 5), list(x1 = 7, x2 = 6))
keys = rush$push_tasks(xss)
```

    ## INFO  [22:28:49.357] [rush] Sending 2 task(s)

``` r
rush$wait_tasks(keys)

rush$data
```

    ##    x1 x2    pid                            worker_id  y   status
    ## 1:  3  5 246883 4e1104ce-810c-44e9-8034-0f6e57208fda  8 finished
    ## 2:  4  6 246883 4e1104ce-810c-44e9-8034-0f6e57208fda 10 finished
    ## 3:  1  5 246883 4e1104ce-810c-44e9-8034-0f6e57208fda  6 finished
    ## 4:  7  6 246883 4e1104ce-810c-44e9-8034-0f6e57208fda 13 finished
    ##                                    keys
    ## 1: 6f117037-fd08-47a0-8cbe-874748175854
    ## 2: 118cf0df-99e6-4fed-8563-c9e3516f73c3
    ## 3: 06b6dfe3-34c5-4039-92fa-fdd7d92bc5fa
    ## 4: 435be500-5c2f-45c0-a62a-d2c9c95be049

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
