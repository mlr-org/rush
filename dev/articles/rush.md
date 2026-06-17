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
       1: zincous_gilamon... 0.31423644 0.5605680 3aa1430a-b08e-4...
       2: zincous_gilamon... 0.70087825 0.8371847 d58a571e-1c16-4...
       3: delegable_kestr... 0.33850901 0.5818153 080c4bf6-a118-4...
       4: zincous_gilamon... 0.99174584 0.9958644 eab996da-6e1f-4...
       5: delegable_kestr... 0.63659217 0.7978673 3af5e176-b599-4...
      ---
    6069: delegable_kestr... 0.01347392 0.1160772 c325718f-573e-4...
    6070: zincous_gilamon... 0.60541353 0.7780832 1ff3c912-c654-4...
    6071: delegable_kestr... 0.13841081 0.3720360 05ebb649-7121-4...
    6072: zincous_gilamon... 0.79428055 0.8912242 e51f1fcb-3c91-4...
    6073: delegable_kestr... 0.16660148 0.4081684 88b1fe9f-6dbd-4...

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
       1: 0.3142364 0.5605680 zincous_gilamon... 3aa1430a-b08e-4...
       2: 0.3385090 0.5818153 delegable_kestr... 080c4bf6-a118-4...
       3: 0.7008782 0.8371847 zincous_gilamon... d58a571e-1c16-4...
       4: 0.9917458 0.9958644 zincous_gilamon... eab996da-6e1f-4...
       5: 0.6365922 0.7978673 delegable_kestr... 3af5e176-b599-4...
      ---
    6500: 0.9234423 0.9609591 delegable_kestr... 1907457d-fd0a-4...
    6501: 0.2858953 0.5346918 zincous_gilamon... 623cea9f-266d-4...
    6502: 0.1852218 0.4303740 delegable_kestr... be9250b3-57eb-4...
    6503: 0.4340945 0.6588585 zincous_gilamon... 9f0ffc04-eba7-4...
    6504: 0.3887645 0.6235098 delegable_kestr... c9cb06cb-3976-4...

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
       1: finished zincous_gilamon... 0.3142364 0.5605680 3aa1430a-b08e-4...
       2: finished zincous_gilamon... 0.7008782 0.8371847 d58a571e-1c16-4...
       3: finished delegable_kestr... 0.3385090 0.5818153 080c4bf6-a118-4...
       4: finished zincous_gilamon... 0.9917458 0.9958644 eab996da-6e1f-4...
       5: finished delegable_kestr... 0.6365922 0.7978673 3af5e176-b599-4...
      ---
    6500: finished delegable_kestr... 0.9234423 0.9609591 1907457d-fd0a-4...
    6501: finished zincous_gilamon... 0.2858953 0.5346918 623cea9f-266d-4...
    6502: finished delegable_kestr... 0.1852218 0.4303740 be9250b3-57eb-4...
    6503: finished zincous_gilamon... 0.4340945 0.6588585 9f0ffc04-eba7-4...
    6504: finished delegable_kestr... 0.3887645 0.6235098 c9cb06cb-3976-4...

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

    [1] 6504

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
    [1] 0.6715569


    $key
    [1] "26e43c5e-d3d1-4179-b140-9b3e83ddf939"

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
