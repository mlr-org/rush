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
       1:    catchy_dairycow 0.31968060 0.5654030 522ce790-22cc-4...
       2: inquiring_afric... 0.08749704 0.2957990 e93b702c-1882-4...
       3:    catchy_dairycow 0.84238635 0.9178161 bbdcec1a-31c1-4...
       4: inquiring_afric... 0.60576944 0.7783119 d9f9ab28-7db0-4...
       5: inquiring_afric... 0.81078445 0.9004357 18a85ae9-3d9e-4...
      ---
    8034:    catchy_dairycow 0.23515363 0.4849264 59e293cb-8175-4...
    8035: inquiring_afric... 0.70386674 0.8389677 9a7b01fa-e7a5-4...
    8036:    catchy_dairycow 0.74601799 0.8637233 ed7d15f6-f155-4...
    8037:    catchy_dairycow 0.01498579 0.1224165 0b6eb591-4db8-4...
    8038: inquiring_afric... 0.68125305 0.8253805 f3783827-d8e6-4...

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
       1: 0.31968060 0.5654030    catchy_dairycow 522ce790-22cc-4...
       2: 0.08749704 0.2957990 inquiring_afric... e93b702c-1882-4...
       3: 0.84238635 0.9178161    catchy_dairycow bbdcec1a-31c1-4...
       4: 0.60576944 0.7783119 inquiring_afric... d9f9ab28-7db0-4...
       5: 0.39981799 0.6323116    catchy_dairycow f109cbb2-1ce8-4...
      ---
    8620: 0.13255467 0.3640806    catchy_dairycow ebeb9153-d165-4...
    8621: 0.90476304 0.9511903 inquiring_afric... 73b7b7c9-af4f-4...
    8622: 0.02250514 0.1500171    catchy_dairycow ce0b7b8e-1ea0-4...
    8623: 0.12117771 0.3481059    catchy_dairycow 4344426d-53b5-4...
    8624: 0.24385280 0.4938145 inquiring_afric... 4d0ae605-387e-4...

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
       1: finished    catchy_dairycow 0.31968060 0.5654030 522ce790-22cc-4...
       2: finished inquiring_afric... 0.08749704 0.2957990 e93b702c-1882-4...
       3: finished    catchy_dairycow 0.84238635 0.9178161 bbdcec1a-31c1-4...
       4: finished inquiring_afric... 0.60576944 0.7783119 d9f9ab28-7db0-4...
       5: finished inquiring_afric... 0.81078445 0.9004357 18a85ae9-3d9e-4...
      ---
    8620: finished    catchy_dairycow 0.13255467 0.3640806 ebeb9153-d165-4...
    8621: finished inquiring_afric... 0.90476304 0.9511903 73b7b7c9-af4f-4...
    8622: finished    catchy_dairycow 0.02250514 0.1500171 ce0b7b8e-1ea0-4...
    8623: finished    catchy_dairycow 0.12117771 0.3481059 4344426d-53b5-4...
    8624: finished inquiring_afric... 0.24385280 0.4938145 4d0ae605-387e-4...

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

    [1] 8624

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
    [1] 0.4650636


    $key
    [1] "215c1cdf-6988-429e-ac4f-3091e00ebcf4"

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
