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
       1: jewel_angelwing... 0.059883940 0.24471195 9eef682b-7c44-4...
       2: jewel_angelwing... 0.889794969 0.94328944 c304ab74-85ca-4...
       3: jewel_angelwing... 0.889909044 0.94334991 51503dfb-e553-4...
       4: jewel_angelwing... 0.653135362 0.80816790 7e741f66-b6c8-4...
       5: jewel_angelwing... 0.001139029 0.03374951 4af94c2f-cf18-4...
      ---
    6934: tzaristic_archa... 0.177892366 0.42177288 00961de6-602e-4...
    6935: jewel_angelwing... 0.106211244 0.32590067 4ae4134c-bf10-4...
    6936: jewel_angelwing... 0.046089795 0.21468534 314555d5-23f5-4...
    6937: tzaristic_archa... 0.530313600 0.72822634 a06367b8-773e-4...
    6938: tzaristic_archa... 0.764057101 0.87410360 2c083dac-7176-4...

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
       1: 0.05988394 0.2447120 jewel_angelwing... 9eef682b-7c44-4...
       2: 0.52258984 0.7229038 tzaristic_archa... e8a89998-80e0-4...
       3: 0.88979497 0.9432894 jewel_angelwing... c304ab74-85ca-4...
       4: 0.88990904 0.9433499 jewel_angelwing... 51503dfb-e553-4...
       5: 0.65313536 0.8081679 jewel_angelwing... 7e741f66-b6c8-4...
      ---
    7385: 0.72111809 0.8491867 jewel_angelwing... c7a8674a-e486-4...
    7386: 0.89508982 0.9460919 tzaristic_archa... a50f6513-fe3e-4...
    7387: 0.96571268 0.9827068 jewel_angelwing... c7eb34e7-ed22-4...
    7388: 0.02282113 0.1510667 tzaristic_archa... 9ced9e72-add4-4...
    7389: 0.84144221        NA tzaristic_archa... 4c38c691-28ef-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.8414422 tzaristic_archa... 4c38c691-28ef-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running tzaristic_archa... 0.84144221 4c38c691-28ef-4...        NA
       2: finished jewel_angelwing... 0.05988394 9eef682b-7c44-4... 0.2447120
       3: finished jewel_angelwing... 0.88979497 c304ab74-85ca-4... 0.9432894
       4: finished jewel_angelwing... 0.88990904 51503dfb-e553-4... 0.9433499
       5: finished jewel_angelwing... 0.65313536 7e741f66-b6c8-4... 0.8081679
      ---
    7385: finished jewel_angelwing... 0.89361775 eb5f88d8-90e5-4... 0.9453136
    7386: finished jewel_angelwing... 0.72111809 c7a8674a-e486-4... 0.8491867
    7387: finished tzaristic_archa... 0.89508982 a50f6513-fe3e-4... 0.9460919
    7388: finished jewel_angelwing... 0.96571268 c7eb34e7-ed22-4... 0.9827068
    7389: finished tzaristic_archa... 0.02282113 9ced9e72-add4-4... 0.1510667

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

    [1] 7388

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
    [1] 0.3762787


    $key
    [1] "c6654f17-bdad-45f1-a24a-2673b4b0c1b3"

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
