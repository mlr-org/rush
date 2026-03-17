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

                   worker_id          x         y               keys
                      <char>      <num>     <num>             <char>
       1: pumice_yorkshir... 0.52850586 0.7269841 48bc4355-7d2b-4...
       2: pumice_yorkshir... 0.58526129 0.7650237 5e86e6c2-8ae0-4...
       3: pumice_yorkshir... 0.32484264 0.5699497 e042a3eb-a088-4...
       4: pumice_yorkshir... 0.79313648 0.8905821 12d32e61-54b1-4...
       5: pumice_yorkshir... 0.35328024 0.5943738 85fefafa-bba4-4...
      ---
    6370: pumice_yorkshir... 0.97366573 0.9867450 307101c1-35ad-4...
    6371: impertinent_blu... 0.60800028 0.7797437 dd8693e3-a970-4...
    6372: pumice_yorkshir... 0.00748609 0.0865222 f83f2907-1976-4...
    6373: impertinent_blu... 0.55599116 0.7456481 b8eed81f-ab25-4...
    6374: pumice_yorkshir... 0.22560459 0.4749785 ddad5d09-195c-4...

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
       1: 0.52850586 0.7269841 pumice_yorkshir... 48bc4355-7d2b-4...
       2: 0.36002143 0.6000179 impertinent_blu... 97058407-fa2e-4...
       3: 0.58526129 0.7650237 pumice_yorkshir... 5e86e6c2-8ae0-4...
       4: 0.32484264 0.5699497 pumice_yorkshir... e042a3eb-a088-4...
       5: 0.79313648 0.8905821 pumice_yorkshir... 12d32e61-54b1-4...
      ---
    6767: 0.98078049 0.9903436 impertinent_blu... 3a1aa8f1-653c-4...
    6768: 0.54460569 0.7379740 pumice_yorkshir... aee43e52-4e55-4...
    6769: 0.16751154 0.4092817 impertinent_blu... 74446162-f9ca-4...
    6770: 0.58087642 0.7621525 pumice_yorkshir... 62cc0535-e688-4...
    6771: 0.04533167 0.2129124 impertinent_blu... f0660d8d-12c5-4...

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

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished pumice_yorkshir... 0.52850586 0.7269841 48bc4355-7d2b-4...
       2: finished pumice_yorkshir... 0.58526129 0.7650237 5e86e6c2-8ae0-4...
       3: finished pumice_yorkshir... 0.32484264 0.5699497 e042a3eb-a088-4...
       4: finished pumice_yorkshir... 0.79313648 0.8905821 12d32e61-54b1-4...
       5: finished pumice_yorkshir... 0.35328024 0.5943738 85fefafa-bba4-4...
      ---
    6767: finished impertinent_blu... 0.98078049 0.9903436 3a1aa8f1-653c-4...
    6768: finished pumice_yorkshir... 0.54460569 0.7379740 aee43e52-4e55-4...
    6769: finished impertinent_blu... 0.16751154 0.4092817 74446162-f9ca-4...
    6770: finished pumice_yorkshir... 0.58087642 0.7621525 62cc0535-e688-4...
    6771: finished impertinent_blu... 0.04533167 0.2129124 f0660d8d-12c5-4...

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

    [1] 6771

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
    [1] 0.1903826


    $key
    [1] "c495b6fd-81fa-41ba-bc0b-e72754777903"

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
