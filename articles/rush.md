# rush - Quick Reference

A quick reference cheatsheet for `rush`. See the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) for a detailed
introduction.

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

                   worker_id          x         y               keys
                      <char>      <num>     <num>             <char>
       1: successive_mora... 0.75739725 0.8702857 685c02d0-8d5d-4...
       2: successive_mora... 0.73470609 0.8571500 ccc33ca6-bc3c-4...
       3: successive_mora... 0.94463880 0.9719253 319d201e-249e-4...
       4: successive_mora... 0.25832031 0.5082522 aa72bab7-5f00-4...
       5: successive_mora... 0.31593424 0.5620803 9b62ede3-ea73-4...
      ---
    5829:       unquiet_lice 0.96045558 0.9800284 6b13ddaf-7b48-4...
    5830: successive_mora... 0.46340474 0.6807384 6bdd6b84-08b1-4...
    5831: successive_mora... 0.50453684 0.7103076 6b93ab6c-e46c-4...
    5832:       unquiet_lice 0.07438545 0.2727370 5e2fd392-1b0f-4...
    5833: successive_mora... 0.74783803 0.8647763 1c9c0352-bc6f-4...

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
       1: 0.7573972 0.8702857 successive_mora... 685c02d0-8d5d-4...
       2: 0.6455596 0.8034673       unquiet_lice b0551f74-940f-4...
       3: 0.7347061 0.8571500 successive_mora... ccc33ca6-bc3c-4...
       4: 0.9446388 0.9719253 successive_mora... 319d201e-249e-4...
       5: 0.2583203 0.5082522 successive_mora... aa72bab7-5f00-4...
      ---
    6214: 0.9990487 0.9995242 successive_mora... 9364de75-ae42-4...
    6215: 0.5845468 0.7645566       unquiet_lice 7db58d49-4cc2-4...
    6216: 0.8998862 0.9486233 successive_mora... 9f9486b4-4546-4...
    6217: 0.1527503 0.3908328       unquiet_lice 5add1a51-93d7-4...
    6218: 0.1106366        NA       unquiet_lice 1db068fa-ab0c-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x    worker_id               keys
           <num>       <char>             <char>
    1: 0.1106366 unquiet_lice 1db068fa-ab0c-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running       unquiet_lice 0.1106366 1db068fa-ab0c-4...        NA
       2: finished successive_mora... 0.7573972 685c02d0-8d5d-4... 0.8702857
       3: finished successive_mora... 0.7347061 ccc33ca6-bc3c-4... 0.8571500
       4: finished successive_mora... 0.9446388 319d201e-249e-4... 0.9719253
       5: finished successive_mora... 0.2583203 aa72bab7-5f00-4... 0.5082522
      ---
    6214: finished       unquiet_lice 0.6929914 3b5f2ce2-c169-4... 0.8324610
    6215: finished successive_mora... 0.9990487 9364de75-ae42-4... 0.9995242
    6216: finished       unquiet_lice 0.5845468 7db58d49-4cc2-4... 0.7645566
    6217: finished successive_mora... 0.8998862 9f9486b4-4546-4... 0.9486233
    6218: finished       unquiet_lice 0.1527503 5add1a51-93d7-4... 0.3908328

## Task Counts

``` r
rush$n_queued_tasks
```

    [1] 0

``` r
rush$n_running_tasks
```

    [1] 1

``` r
rush$n_finished_tasks
```

    [1] 6217

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
    [1] 0.1350048


    $key
    [1] "eb47e2cf-c45b-448a-82c1-fea1fe73d117"

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
