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
       1: giggly_sapsucke... 0.39200289 0.6261013 9c45fb87-f987-4...
       2:    boarish_roebuck 0.79557028 0.8919475 c7063816-07b2-4...
       3: giggly_sapsucke... 0.56821322 0.7537992 4b2652ea-53a6-4...
       4:    boarish_roebuck 0.11240657 0.3352709 86526711-9108-4...
       5: giggly_sapsucke... 0.19102450 0.4370635 aa818d77-2e02-4...
      ---
    7057:    boarish_roebuck 0.93195175 0.9653765 552051b3-b922-4...
    7058: giggly_sapsucke... 0.84759802 0.9206509 caa64c87-1f98-4...
    7059:    boarish_roebuck 0.14235865 0.3773045 f58a6bbd-cfe9-4...
    7060: giggly_sapsucke... 0.91671327 0.9574514 f9144c7c-949a-4...
    7061:    boarish_roebuck 0.04327468 0.2080257 4c97d6d4-9cb9-4...

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

                  x         y          worker_id condition               keys
              <num>     <num>             <char>    <list>             <char>
       1: 0.7955703 0.8919475    boarish_roebuck    [NULL] c7063816-07b2-4...
       2: 0.3920029 0.6261013 giggly_sapsucke...    [NULL] 9c45fb87-f987-4...
       3: 0.5682132 0.7537992 giggly_sapsucke...    [NULL] 4b2652ea-53a6-4...
       4: 0.1124066 0.3352709    boarish_roebuck    [NULL] 86526711-9108-4...
       5: 0.1910245 0.4370635 giggly_sapsucke...    [NULL] aa818d77-2e02-4...
      ---
    7511: 0.3391814 0.5823928 giggly_sapsucke...    [NULL] 63654afb-0416-4...
    7512: 0.3396464 0.5827919    boarish_roebuck    [NULL] a83ee7ee-28d5-4...
    7513: 0.8939849 0.9455077 giggly_sapsucke...    [NULL] 3fa278cd-6ac9-4...
    7514: 0.1893518 0.4351458    boarish_roebuck    [NULL] b81bf523-20c0-4...
    7515: 0.4217815        NA giggly_sapsucke... <list[1]> d01bc240-30cc-4...

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

               x          worker_id condition               keys
           <num>             <char>    <list>             <char>
    1: 0.4217815 giggly_sapsucke... <list[1]> d01bc240-30cc-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished giggly_sapsucke... 0.3920029 0.6261013 9c45fb87-f987-4...
       2: finished    boarish_roebuck 0.7955703 0.8919475 c7063816-07b2-4...
       3: finished giggly_sapsucke... 0.5682132 0.7537992 4b2652ea-53a6-4...
       4: finished    boarish_roebuck 0.1124066 0.3352709 86526711-9108-4...
       5: finished giggly_sapsucke... 0.1910245 0.4370635 aa818d77-2e02-4...
      ---
    7510: finished    boarish_roebuck 0.4060143 0.6371925 8eddd00c-b4f3-4...
    7511: finished giggly_sapsucke... 0.3391814 0.5823928 63654afb-0416-4...
    7512: finished    boarish_roebuck 0.3396464 0.5827919 a83ee7ee-28d5-4...
    7513: finished giggly_sapsucke... 0.8939849 0.9455077 3fa278cd-6ac9-4...
    7514: finished    boarish_roebuck 0.1893518 0.4351458 b81bf523-20c0-4...

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

    [1] 7514

``` r

rush$n_failed_tasks
```

    [1] 1

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
    [1] 0.2031435


    $key
    [1] "e0b44b5d-3be2-469f-b14b-f8d9485f5bfb"

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

    character(0)

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
