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
       1: independent_gra... 0.09921012 0.3149764 d022cc7f-b64d-4...
       2:     boyish_chamois 0.28448679 0.5333730 b78ffe18-a17f-4...
       3: independent_gra... 0.23995719 0.4898542 2d9946f2-e8e4-4...
       4:     boyish_chamois 0.74839645 0.8650991 f075cace-5ea0-4...
       5: independent_gra... 0.65166599 0.8072583 87e746df-ca5e-4...
      ---
    6742:     boyish_chamois 0.61705042 0.7855256 3ff8b4a2-fae2-4...
    6743: independent_gra... 0.52262169 0.7229258 f4d6ee8e-633c-4...
    6744:     boyish_chamois 0.96632660 0.9830191 f1984735-7498-4...
    6745: independent_gra... 0.63263501 0.7953836 c2d9562d-c512-4...
    6746:     boyish_chamois 0.98743681 0.9936986 27a0948a-6e37-4...

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
       1: 0.09921012 0.3149764 independent_gra... d022cc7f-b64d-4...
       2: 0.28448679 0.5333730     boyish_chamois b78ffe18-a17f-4...
       3: 0.23995719 0.4898542 independent_gra... 2d9946f2-e8e4-4...
       4: 0.74839645 0.8650991     boyish_chamois f075cace-5ea0-4...
       5: 0.65166599 0.8072583 independent_gra... 87e746df-ca5e-4...
      ---
    7177: 0.27243966 0.5219575     boyish_chamois 02d478cc-c965-4...
    7178: 0.74060636 0.8605849     boyish_chamois 03e58a9b-e11a-4...
    7179: 0.74199285 0.8613901 independent_gra... b3ad5fba-6dc8-4...
    7180: 0.98113203 0.9905211     boyish_chamois 6f2bdf19-2fb2-4...
    7181: 0.26656722 0.5163015 independent_gra... b9d463de-b46e-4...

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
       1: finished independent_gra... 0.09921012 0.3149764 d022cc7f-b64d-4...
       2: finished     boyish_chamois 0.28448679 0.5333730 b78ffe18-a17f-4...
       3: finished independent_gra... 0.23995719 0.4898542 2d9946f2-e8e4-4...
       4: finished     boyish_chamois 0.74839645 0.8650991 f075cace-5ea0-4...
       5: finished independent_gra... 0.65166599 0.8072583 87e746df-ca5e-4...
      ---
    7177: finished     boyish_chamois 0.27243966 0.5219575 02d478cc-c965-4...
    7178: finished     boyish_chamois 0.74060636 0.8605849 03e58a9b-e11a-4...
    7179: finished independent_gra... 0.74199285 0.8613901 b3ad5fba-6dc8-4...
    7180: finished     boyish_chamois 0.98113203 0.9905211 6f2bdf19-2fb2-4...
    7181: finished independent_gra... 0.26656722 0.5163015 b9d463de-b46e-4...

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

    [1] 7181

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
    [1] 0.5990888


    $key
    [1] "93486203-911d-4790-9071-186531cec731"

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
