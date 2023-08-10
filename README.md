
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rush

![](man/figures/README-flow.png)

## Example

``` r
library(rush)
future::plan("multisession", workers = 2)

# initialize server
config = redux::redis_config()
server = Server$new("test", config)
server$reset()

fun = function(x1, x2) {
  list(y = x1 + x2)
}

# start workers
server$start_workers(fun)
server
```

    ## <Server>
    ## * Running Workers: 2
    ## * Queued Tasks: 0
    ## * Running Tasks: 0
    ## * Finished Tasks: 0
    ## * Archived Tasks: 0

``` r
# check workers
server$check_workers()
```

    ## [1] TRUE

``` r
# push tasks
xss = list(list(x1 = 3, x2 = 5), list(x1 = 4, x2 = 6))
server$push_tasks(xss)
```

    ## INFO  [14:18:52.278] [rush] Sending 2 tasks(s)

``` r
Sys.sleep(1)
server$n_finished_tasks
```

    ## [1] 2

``` r
# sync data
server$data
```

    ## INFO  [14:18:53.316] [rush] Receiving 2 result(s)

    ## [[1]]
    ## [[1]]$x1
    ## [1] 4
    ## 
    ## [[1]]$x2
    ## [1] 6
    ## 
    ## [[1]]$y
    ## [1] 10
    ## 
    ## [[1]]$pid
    ## [1] 321385
    ## 
    ## 
    ## [[2]]
    ## [[2]]$x1
    ## [1] 3
    ## 
    ## [[2]]$x2
    ## [1] 5
    ## 
    ## [[2]]$y
    ## [1] 8
    ## 
    ## [[2]]$pid
    ## [1] 321385

``` r
server$n_archived_tasks
```

    ## [1] 2

``` r
# push more tasks
xss = list(list(x1 = 1, x2 = 5), list(x1 = 7, x2 = 6))
server$push_tasks(xss)
```

    ## INFO  [14:18:53.323] [rush] Sending 2 tasks(s)

``` r
Sys.sleep(1)
server
```

    ## <Server>
    ## * Running Workers: 2
    ## * Queued Tasks: 0
    ## * Running Tasks: 0
    ## * Finished Tasks: 2
    ## * Archived Tasks: 2

``` r
# to data.table
data.table::rbindlist(server$data)
```

    ## INFO  [14:18:54.334] [rush] Receiving 2 result(s)

    ##    x1 x2  y    pid
    ## 1:  4  6 10 321385
    ## 2:  3  5  8 321385
    ## 3:  1  5  6 321384
    ## 4:  7  6 13 321385

## `Server`

**public**

  - `$initialize(id, config)`
      - Initializes server
      - `id` is a unique identifier for the data base
      - `config` is used to connect to the server
  - `$start_workers(fun, n)`
      - Starts `fun` on `n` workers
      - `fun` runs in a loop on new tasks
      - `$pull_task()` pulls task
      - `$push_result()` pushes result of `fun` to data base
  - `$stop_workers()`
      - Stops worker
  - `$check_workers()`
      - Checks if an error occurred on a worker
      - Returns `TRUE` if no error occurred
      - Returns error message if an error occurred
  - `$push_tasks(xss, extra)` -\> `keys`
      - Pushes tasks to workers
      - Adds task to task queue
      - Associates task with a key
      - `xss` -\> `list(list(x1 = 3, x2 = 5), list(x1 = 4, x2 = 6))`
      - `extra` -\> `list(list(timestamp, untransformed_x1,
        untransformed_x2), list(timestamp, untransformed_x1,
        untransformed_x2))`
      - Entries of `xss` and `extra` are stored with the same hash
      - Is called in the main process
  - `$pop_task()` -\> `list(key, xs = list(x1 = 3, x2 = 5))`
      - Pulls task from task queue
      - Is called on workers
  - `$push_result(key, ys)` -\>
      - Push result to data base
      - `ys` -\> `list(y = 1)`
      - Is called on workers
  - `$sync_data()`
      - Syncs data base with main process
      - Deserializes data base entries
      - Caches data in list
      - Is called in the main process

**fields**

  - `$connector`
      - Returns connection to data base
  - `$data`
      - Returns list of tasks and results
  - `$terminate`
      - Returns `TRUE` if the worker should terminate
  - `$queued_tasks`
      - Returns keys in task queue
  - `$running_tasks`
      - Returns keys of running tasks
  - `$finished_tasks`
      - Returns keys of finished tasks
  - `$archived_tasks`
      - Returns keys of tasks synced to local cache

**private**

  - `$.write_values(values, field, keys = NULL)`
      - Takes multiple lists (`values`), serializes them and writes them
        to individual redis hashes at `field`
      - If no keys are provided, new keys are generated
      - `values` -\> `list(list(x1 = 3, x2 = 5), list(x1 = 4, x2 = 6))`
  - `$.read_values(keys, fields)`
      - Reads multiple redis hashes at `fields` and deserializes them
      - `fields` -\> `c("xs", "x_extra", "ys")`
