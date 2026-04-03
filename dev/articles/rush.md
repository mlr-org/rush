# rush - Quick Reference

A quick reference cheatsheet for `rush`. See the
[tutorial](https://rush.mlr-org.com/dev/articles/tutorial.md) for a
detailed introduction.

## Worker Loop

``` r
library(rush)

worker_loop = function(rush) {
  while (!rush$terminated) {

    xs = list(x = runif(1L))
    key = rush$push_running_tasks(xss = list(xs))

    ys = list(y = sqrt(xs$x))
    rush$finish_tasks(key, yss = list(ys))
  }
}
```

## Rush Manager

``` r
config = redux::redis_config()

rush = rsh(network_id = "my_network", config = config)
rush
```

    ── <Rush> ──────────────────────────────────────────────────────────────────────
    • Running Workers: 0
    • Queued Tasks: 0
    • Running Tasks: 0
    • Finished Tasks: 0
    • Failed Tasks: 0

## Start Workers

``` r
mirai::daemons(n = 2L)

rush$start_workers(
  worker_loop = worker_loop,
  n_workers = 2L)
```

## Wait for Workers

``` r
rush$wait_for_workers(n = 2L)
```

## Fetch Results

``` r
rush$fetch_finished_tasks()
```

                   worker_id           x          y               keys
                      <char>       <num>      <num>             <char>
       1: amoebaean_queen... 0.593420959 0.77033821 5ea44bd8-f8a0-4...
       2: amoebaean_queen... 0.761690096 0.87274859 abd428ad-a01c-4...
       3: amoebaean_queen... 0.503596239 0.70964515 79d95c51-7075-4...
       4: amoebaean_queen... 0.916436107 0.95730669 cd332abd-72d2-4...
       5: amoebaean_queen... 0.350166291 0.59174850 71a75c39-f1bf-4...
      ---
    6224: amoebaean_queen... 0.200940625 0.44826401 e66dfeea-4322-4...
    6225:      tiff_betafish 0.125827482 0.35472170 966c17fc-32ed-4...
    6226: amoebaean_queen... 0.009691689 0.09844638 d51d2f8c-6a73-4...
    6227:      tiff_betafish 0.149033937 0.38604914 3b322646-2bd9-4...
    6228: amoebaean_queen... 0.001544900 0.03930522 fa7b86c8-042b-4...

## Stop Workers

``` r
rush$stop_workers(type = "kill")
```

## Tasks

| Component   | Description                                         |
|-------------|-----------------------------------------------------|
| `key`       | Unique task identifier                              |
| `xs`        | Named list of inputs                                |
| `ys`        | Named list of results                               |
| `state`     | `"running"`, `"finished"`,`"failed"`, or `"queued"` |
| `worker_id` | ID of the worker that ran the task                  |

## More fetch methods

``` r
rush$fetch_tasks()
```

                  x         y          worker_id               keys
              <num>     <num>             <char>             <char>
       1: 0.5934210 0.7703382 amoebaean_queen... 5ea44bd8-f8a0-4...
       2: 0.2934747 0.5417331      tiff_betafish 22f0ba95-13af-4...
       3: 0.7616901 0.8727486 amoebaean_queen... abd428ad-a01c-4...
       4: 0.5035962 0.7096451 amoebaean_queen... 79d95c51-7075-4...
       5: 0.9164361 0.9573067 amoebaean_queen... cd332abd-72d2-4...
      ---
    6629: 0.9941326 0.9970620      tiff_betafish 477c479a-17e3-4...
    6630: 0.5562540 0.7458244 amoebaean_queen... ab9e6543-26fa-4...
    6631: 0.2619281 0.5117891      tiff_betafish 36591f71-9eeb-4...
    6632: 0.9811911 0.9905509 amoebaean_queen... cf6d7395-d37d-4...
    6633: 0.6601270 0.8124820      tiff_betafish cf91450e-94df-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished amoebaean_queen... 0.5934210 0.7703382 5ea44bd8-f8a0-4...
       2: finished amoebaean_queen... 0.7616901 0.8727486 abd428ad-a01c-4...
       3: finished amoebaean_queen... 0.5035962 0.7096451 79d95c51-7075-4...
       4: finished amoebaean_queen... 0.9164361 0.9573067 cd332abd-72d2-4...
       5: finished amoebaean_queen... 0.3501663 0.5917485 71a75c39-f1bf-4...
      ---
    6629: finished      tiff_betafish 0.9941326 0.9970620 477c479a-17e3-4...
    6630: finished amoebaean_queen... 0.5562540 0.7458244 ab9e6543-26fa-4...
    6631: finished      tiff_betafish 0.2619281 0.5117891 36591f71-9eeb-4...
    6632: finished amoebaean_queen... 0.9811911 0.9905509 cf6d7395-d37d-4...
    6633: finished      tiff_betafish 0.6601270 0.8124820 cf91450e-94df-4...

## Task Counts

``` r
rush$n_queued_tasks
```

    [1] 0

``` r
rush$n_running_tasks
```

    [1] 0

``` r
rush$n_finished_tasks
```

    [1] 6633

``` r
rush$n_failed_tasks
```

    [1] 0

## Push Tasks to Queue

``` r
xss = replicate(25, list(x = runif(1L)), simplify = FALSE)

rush$push_tasks(xss = xss)
```

## Pop Task from Queue

``` r
task = rush$pop_task()
task
```

    $xs
    $xs$x
    [1] 0.03057839


    $key
    [1] "60d1881d-d578-4df9-be39-bb609cb16ad8"

``` r
worker_loop = function(rush) {
  repeat {
    task = rush$pop_task()
    if (is.null(task)) break

    ys = list(y = sqrt(task$xs$x))
    rush$finish_tasks(task$key, yss = list(ys))
  }
}
```

## Local Workers

``` r
rush$start_local_workers(
  worker_loop = worker_loop,
  n_workers = 2)
```

## Script Workers

``` r
script = rush$worker_script(worker_loop = worker_loop)
cat(script)
```

    Rscript -e "rush::start_worker(network_id = 'my_network', config = list(scheme = 'redis', host = '127.0.0.1', port = '6379'))"

## Heartbeats

``` r
script = rush$worker_script(
  worker_loop = worker_loop,
  heartbeat_period = 10,
  heartbeat_expire = 30)
```

## Reset Network

``` r
rush$reset()
```

## Handling R Errors

``` r
worker_loop = function(rush) {
  while (!rush$terminated) {

    xs = list(x = runif(1))
    key = rush$push_running_tasks(xss = list(xs))

    tryCatch({
      ys = list(y = some_function(xs$x))
      rush$finish_tasks(key, yss = list(ys))
    }, error = function(e) {
      rush$fail_tasks(key, conditions = list(list(message = e$message)))
    })
  }
}
```

## Detecting Lost Workers

``` r
rush$detect_lost_workers()
```

    NULL

## Logging

``` r
worker_loop = function(rush) {
  lg = lgr::get_logger("mlr3/rush")
  lg$info("Worker %s started on %s", rush$worker_id, rush$hostname)
}

rush$start_workers(
  worker_loop = worker_loop,
  n_workers = 2,
  lgr_thresholds = c(rush = "info"))
```

``` r
rush$print_log()
```

## Debugging

``` r
rush_worker = RushWorker$new("test-network")

worker_loop(rush_worker)
```

``` r
mirai::daemons(1L)

worker_ids = rush$start_workers(
  worker_loop = worker_loop,
  n_workers = 1,
  message_log = "message",
  output_log = "output")
```

## Rush Plan

``` r
rush_plan(
  n_workers = 4,
  config = redux::redis_config(),
  worker_type = "mirai")
```
