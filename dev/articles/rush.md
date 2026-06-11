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

                   worker_id         x         y               keys
                      <char>     <num>     <num>             <char>
       1: unmodified_izut... 0.9956944 0.9978449 7aae81da-095e-4...
       2: unmodified_izut... 0.2483246 0.4983218 83a8213b-d3b1-4...
       3: unmodified_izut... 0.7952057 0.8917430 a45e8a96-2f3b-4...
       4: unmodified_izut... 0.5702851 0.7551722 dbe2b56c-6301-4...
       5: unmodified_izut... 0.3365929 0.5801663 1ee8fe2c-0ec1-4...
      ---
    6103: unmodified_izut... 0.8597149 0.9272081 55b7983c-2e3f-4...
    6104:      amoral_ynambu 0.4676035 0.6838154 56151f4d-38de-4...
    6105: unmodified_izut... 0.3319502 0.5761512 82fef531-e105-4...
    6106:      amoral_ynambu 0.3215234 0.5670303 68397232-6d0a-4...
    6107: unmodified_izut... 0.0355644 0.1885853 795bff35-5568-4...

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
       1: 0.99569435 0.9978449 unmodified_izut... 7aae81da-095e-4...
       2: 0.25743500 0.5073805      amoral_ynambu a7d3fa13-72f3-4...
       3: 0.24832460 0.4983218 unmodified_izut... 83a8213b-d3b1-4...
       4: 0.79520566 0.8917430 unmodified_izut... a45e8a96-2f3b-4...
       5: 0.57028509 0.7551722 unmodified_izut... dbe2b56c-6301-4...
      ---
    6491: 0.26301212 0.5128471 unmodified_izut... 26bb4740-1ed5-4...
    6492: 0.43569214 0.6600698      amoral_ynambu 3c28fc09-f251-4...
    6493: 0.26501496 0.5147960 unmodified_izut... 4afb2701-baea-4...
    6494: 0.01372413 0.1171500      amoral_ynambu 3a3a55b7-88b4-4...
    6495: 0.66084050 0.8129210 unmodified_izut... 56813a62-e22e-4...

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
       1: finished unmodified_izut... 0.99569435 0.9978449 7aae81da-095e-4...
       2: finished unmodified_izut... 0.24832460 0.4983218 83a8213b-d3b1-4...
       3: finished unmodified_izut... 0.79520566 0.8917430 a45e8a96-2f3b-4...
       4: finished unmodified_izut... 0.57028509 0.7551722 dbe2b56c-6301-4...
       5: finished unmodified_izut... 0.33659293 0.5801663 1ee8fe2c-0ec1-4...
      ---
    6491: finished unmodified_izut... 0.26301212 0.5128471 26bb4740-1ed5-4...
    6492: finished      amoral_ynambu 0.43569214 0.6600698 3c28fc09-f251-4...
    6493: finished unmodified_izut... 0.26501496 0.5147960 4afb2701-baea-4...
    6494: finished      amoral_ynambu 0.01372413 0.1171500 3a3a55b7-88b4-4...
    6495: finished unmodified_izut... 0.66084050 0.8129210 56813a62-e22e-4...

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

    [1] 6495

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
    [1] 0.3103571


    $key
    [1] "cb2308b4-0ba3-429f-ad88-badf743ec347"

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
