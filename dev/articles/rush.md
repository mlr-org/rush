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
       1: busy_alpaca 0.002379503 0.04878015 cb852a7d-26b8-4...
       2: busy_alpaca 0.677678727 0.82321244 022ed512-eaef-4...
       3: busy_alpaca 0.286692586 0.53543682 b1c08472-8be5-4...
       4: coseys_boar 0.233071670 0.48277497 82f2c3ac-5ca1-4...
       5: busy_alpaca 0.235495685 0.48527898 098e8400-fc9d-4...
      ---
    6766: busy_alpaca 0.266860441 0.51658537 ec96de93-ba33-4...
    6767: coseys_boar 0.102402740 0.32000428 18eb0eea-4ec8-4...
    6768: busy_alpaca 0.057670384 0.24014659 8ac918b5-c0c2-4...
    6769: coseys_boar 0.098973696 0.31460085 7c15bffa-acfd-4...
    6770: busy_alpaca 0.012291006 0.11086481 3751a621-1b17-4...

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

                    x          y   worker_id               keys
                <num>      <num>      <char>             <char>
       1: 0.002379503 0.04878015 busy_alpaca cb852a7d-26b8-4...
       2: 0.233071670 0.48277497 coseys_boar 82f2c3ac-5ca1-4...
       3: 0.677678727 0.82321244 busy_alpaca 022ed512-eaef-4...
       4: 0.286692586 0.53543682 busy_alpaca b1c08472-8be5-4...
       5: 0.235495685 0.48527898 busy_alpaca 098e8400-fc9d-4...
      ---
    7178: 0.680957377 0.82520142 coseys_boar e432bf8f-8272-4...
    7179: 0.973500524 0.98666130 busy_alpaca 88c38b95-fd6f-4...
    7180: 0.001844492 0.04294755 coseys_boar ae29fcad-3a2a-4...
    7181: 0.333172546 0.57721101 busy_alpaca 8f6459dc-e892-4...
    7182: 0.673524303 0.82068526 coseys_boar da72ba06-8a7d-4...

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

             state   worker_id           x          y               keys
            <char>      <char>       <num>      <num>             <char>
       1: finished busy_alpaca 0.002379503 0.04878015 cb852a7d-26b8-4...
       2: finished busy_alpaca 0.677678727 0.82321244 022ed512-eaef-4...
       3: finished busy_alpaca 0.286692586 0.53543682 b1c08472-8be5-4...
       4: finished coseys_boar 0.233071670 0.48277497 82f2c3ac-5ca1-4...
       5: finished busy_alpaca 0.235495685 0.48527898 098e8400-fc9d-4...
      ---
    7178: finished coseys_boar 0.680957377 0.82520142 e432bf8f-8272-4...
    7179: finished busy_alpaca 0.973500524 0.98666130 88c38b95-fd6f-4...
    7180: finished coseys_boar 0.001844492 0.04294755 ae29fcad-3a2a-4...
    7181: finished busy_alpaca 0.333172546 0.57721101 8f6459dc-e892-4...
    7182: finished coseys_boar 0.673524303 0.82068526 da72ba06-8a7d-4...

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

    [1] 7182

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

Only a `RushWorker` can pop tasks from the queue.

``` r

rush_worker = RushWorker$new("my_network")

task = rush_worker$pop_task()
task
```

    $xs
    $xs$x
    [1] 0.4946768


    $key
    [1] "7d6a5a2a-dbcc-4923-8f7d-a40184ea72ce"

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
