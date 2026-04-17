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
       1:     associated_cur 0.76530829 0.8748190 534ac23d-4a2f-4...
       2:     associated_cur 0.55853688 0.7473532 103b0689-4ce2-4...
       3:     associated_cur 0.37676048 0.6138082 293cfc40-a27d-4...
       4: coquettish_orop... 0.07573229 0.2751950 61cb6df6-53f1-4...
       5:     associated_cur 0.89976842 0.9485612 625c6536-ea55-4...
      ---
    6206:     associated_cur 0.81025770 0.9001432 9a79d14f-9012-4...
    6207: coquettish_orop... 0.44312278 0.6656747 004f8f96-7683-4...
    6208:     associated_cur 0.25362246 0.5036094 7bf342d4-2d86-4...
    6209: coquettish_orop... 0.64403315 0.8025168 6aad5ec7-a294-4...
    6210:     associated_cur 0.80389674 0.8966029 606b2e9f-d569-4...

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
       1: 0.76530829 0.8748190     associated_cur 534ac23d-4a2f-4...
       2: 0.07573229 0.2751950 coquettish_orop... 61cb6df6-53f1-4...
       3: 0.55853688 0.7473532     associated_cur 103b0689-4ce2-4...
       4: 0.37676048 0.6138082     associated_cur 293cfc40-a27d-4...
       5: 0.89976842 0.9485612     associated_cur 625c6536-ea55-4...
      ---
    6599: 0.72878749 0.8536905 coquettish_orop... e1365e32-a8e0-4...
    6600: 0.96914679 0.9844525     associated_cur 5f468802-96b9-4...
    6601: 0.95784075 0.9786934     associated_cur df34d92c-b81a-4...
    6602: 0.13173620 0.3629548 coquettish_orop... f32485cd-0f11-4...
    6603: 0.15421244 0.3926989     associated_cur 987ffd89-a3f0-4...

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
       1: finished     associated_cur 0.76530829 0.8748190 534ac23d-4a2f-4...
       2: finished     associated_cur 0.55853688 0.7473532 103b0689-4ce2-4...
       3: finished     associated_cur 0.37676048 0.6138082 293cfc40-a27d-4...
       4: finished coquettish_orop... 0.07573229 0.2751950 61cb6df6-53f1-4...
       5: finished     associated_cur 0.89976842 0.9485612 625c6536-ea55-4...
      ---
    6599: finished coquettish_orop... 0.72878749 0.8536905 e1365e32-a8e0-4...
    6600: finished     associated_cur 0.96914679 0.9844525 5f468802-96b9-4...
    6601: finished     associated_cur 0.95784075 0.9786934 df34d92c-b81a-4...
    6602: finished coquettish_orop... 0.13173620 0.3629548 f32485cd-0f11-4...
    6603: finished     associated_cur 0.15421244 0.3926989 987ffd89-a3f0-4...

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

    [1] 6603

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
    [1] 0.3606309


    $key
    [1] "59fde079-550d-4346-a142-b5f4fd4d786f"

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
