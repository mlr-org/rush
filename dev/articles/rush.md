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
       1: amphitheatrical... 0.7717606 0.8784991 b0774c51-9da9-4...
       2: unilateralised_... 0.5057633 0.7111704 0079a60c-24d5-4...
       3: amphitheatrical... 0.1337752 0.3657529 2f120d2c-c278-4...
       4: unilateralised_... 0.9584148 0.9789866 a4d667f3-0c2a-4...
       5: amphitheatrical... 0.2263592 0.4757722 68fcf998-46b9-4...
      ---
    6071: amphitheatrical... 0.9078996 0.9528377 9d0dcba0-7ee5-4...
    6072: unilateralised_... 0.7492572 0.8655965 fc8df9b6-c1e3-4...
    6073: amphitheatrical... 0.7130773 0.8444391 058f4865-234e-4...
    6074: unilateralised_... 0.9100964 0.9539897 1105d541-8958-4...
    6075: amphitheatrical... 0.9544301 0.9769494 b86d9bca-be39-4...

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
       1: 0.7717606 0.8784991 amphitheatrical... b0774c51-9da9-4...
       2: 0.5057633 0.7111704 unilateralised_... 0079a60c-24d5-4...
       3: 0.1337752 0.3657529 amphitheatrical... 2f120d2c-c278-4...
       4: 0.9584148 0.9789866 unilateralised_... a4d667f3-0c2a-4...
       5: 0.2263592 0.4757722 amphitheatrical... 68fcf998-46b9-4...
      ---
    6453: 0.1388561 0.3726340 amphitheatrical... 217f5919-6647-4...
    6454: 0.6768974 0.8227377 unilateralised_... 9bb7e9b5-6241-4...
    6455: 0.5930526 0.7700991 amphitheatrical... 587aa661-eebb-4...
    6456: 0.4424177 0.6651449 unilateralised_... 9199bedf-c6f4-4...
    6457: 0.4126485 0.6423772 amphitheatrical... cd30f295-4c32-4...

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
       1: finished amphitheatrical... 0.7717606 0.8784991 b0774c51-9da9-4...
       2: finished unilateralised_... 0.5057633 0.7111704 0079a60c-24d5-4...
       3: finished amphitheatrical... 0.1337752 0.3657529 2f120d2c-c278-4...
       4: finished unilateralised_... 0.9584148 0.9789866 a4d667f3-0c2a-4...
       5: finished amphitheatrical... 0.2263592 0.4757722 68fcf998-46b9-4...
      ---
    6453: finished amphitheatrical... 0.1388561 0.3726340 217f5919-6647-4...
    6454: finished unilateralised_... 0.6768974 0.8227377 9bb7e9b5-6241-4...
    6455: finished amphitheatrical... 0.5930526 0.7700991 587aa661-eebb-4...
    6456: finished unilateralised_... 0.4424177 0.6651449 9199bedf-c6f4-4...
    6457: finished amphitheatrical... 0.4126485 0.6423772 cd30f295-4c32-4...

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

    [1] 6457

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
    [1] 0.2795882


    $key
    [1] "3c7bf5d4-211b-49cb-8e6c-21a16867b113"

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
