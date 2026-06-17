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
       1: critical_austri... 0.03672797 0.1916454 0d274a6a-f104-4...
       2: critical_austri... 0.96026181 0.9799295 24b6a768-f7ce-4...
       3: critical_austri... 0.34626110 0.5884395 1c386f85-3713-4...
       4: critical_austri... 0.49412181 0.7029380 34e41621-4500-4...
       5: critical_austri... 0.05476713 0.2340238 f0b44291-04ea-4...
      ---
    6155: critical_austri... 0.36610330 0.6050647 ce29dcd2-44c8-4...
    6156: steamheated_man... 0.58835964 0.7670460 77e3b27f-22d3-4...
    6157: critical_austri... 0.48711128 0.6979336 7d0a432c-cdaf-4...
    6158: steamheated_man... 0.06248783 0.2499757 c2df8128-f0a8-4...
    6159: critical_austri... 0.62834371 0.7926813 0a52fa18-69e0-4...

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
       1: 0.03672797 0.1916454 critical_austri... 0d274a6a-f104-4...
       2: 0.95006289 0.9747117 steamheated_man... afcb5cb4-f976-4...
       3: 0.96026181 0.9799295 critical_austri... 24b6a768-f7ce-4...
       4: 0.34626110 0.5884395 critical_austri... 1c386f85-3713-4...
       5: 0.49412181 0.7029380 critical_austri... 34e41621-4500-4...
      ---
    6568: 0.49279009 0.7019901 steamheated_man... 056280af-bae8-4...
    6569: 0.43976658 0.6631490 critical_austri... 10e57912-0fbb-4...
    6570: 0.79437669 0.8912781 steamheated_man... 12bfd135-a0e5-4...
    6571: 0.78204814 0.8843349 steamheated_man... d5285966-5187-4...
    6572: 0.34295354        NA critical_austri... db609a5d-adcd-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3429535 critical_austri... db609a5d-adcd-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running critical_austri... 0.34295354 db609a5d-adcd-4...        NA
       2: finished critical_austri... 0.03672797 0d274a6a-f104-4... 0.1916454
       3: finished critical_austri... 0.96026181 24b6a768-f7ce-4... 0.9799295
       4: finished critical_austri... 0.34626110 1c386f85-3713-4... 0.5884395
       5: finished critical_austri... 0.49412181 34e41621-4500-4... 0.7029380
      ---
    6568: finished critical_austri... 0.06198591 4cbfee96-66c4-4... 0.2489697
    6569: finished steamheated_man... 0.49279009 056280af-bae8-4... 0.7019901
    6570: finished critical_austri... 0.43976658 10e57912-0fbb-4... 0.6631490
    6571: finished steamheated_man... 0.79437669 12bfd135-a0e5-4... 0.8912781
    6572: finished steamheated_man... 0.78204814 d5285966-5187-4... 0.8843349

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

    [1] 6571

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
    [1] 0.03651761


    $key
    [1] "b5d0addc-90b1-4ca5-8851-b918077db949"

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
