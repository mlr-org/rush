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
       1: aeromedical_vic... 0.0490654 0.2215071 8569bd31-7157-4...
       2: hermitic_albaco... 0.8072780 0.8984865 85a89274-ac60-4...
       3: aeromedical_vic... 0.4924098 0.7017192 a275857d-d8ec-4...
       4: aeromedical_vic... 0.4023383 0.6343014 aa280fb3-c87a-4...
       5: aeromedical_vic... 0.0865906 0.2942628 8d97325d-f3a4-4...
      ---
    9377: hermitic_albaco... 0.2438868 0.4938490 f658015b-61d4-4...
    9378: aeromedical_vic... 0.5712917 0.7558384 b2efbe80-9d3f-4...
    9379: hermitic_albaco... 0.8380477 0.9154495 613d185b-965b-4...
    9380: aeromedical_vic... 0.1754982 0.4189250 68e66996-5fc8-4...
    9381: hermitic_albaco... 0.0906573 0.3010935 b49d7706-00db-4...

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
        1: 0.8072780 0.8984865 hermitic_albaco... 85a89274-ac60-4...
        2: 0.0490654 0.2215071 aeromedical_vic... 8569bd31-7157-4...
        3: 0.4924098 0.7017192 aeromedical_vic... a275857d-d8ec-4...
        4: 0.4023383 0.6343014 aeromedical_vic... aa280fb3-c87a-4...
        5: 0.6470832 0.8044148 hermitic_albaco... c338743a-7447-4...
       ---
    10011: 0.1084932 0.3293831 hermitic_albaco... b7b5f9ec-7e62-4...
    10012: 0.7874097 0.8873611 aeromedical_vic... ed3a3880-415f-4...
    10013: 0.8763820 0.9361528 hermitic_albaco... 6d3af34d-c2a8-4...
    10014: 0.4123581 0.6421512 aeromedical_vic... fc0da47d-34cc-4...
    10015: 0.9020722 0.9497748 hermitic_albaco... 29830e09-6e53-4...

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
        1: finished aeromedical_vic... 0.0490654 0.2215071 8569bd31-7157-4...
        2: finished hermitic_albaco... 0.8072780 0.8984865 85a89274-ac60-4...
        3: finished aeromedical_vic... 0.4924098 0.7017192 a275857d-d8ec-4...
        4: finished aeromedical_vic... 0.4023383 0.6343014 aa280fb3-c87a-4...
        5: finished aeromedical_vic... 0.0865906 0.2942628 8d97325d-f3a4-4...
       ---
    10011: finished hermitic_albaco... 0.1084932 0.3293831 b7b5f9ec-7e62-4...
    10012: finished aeromedical_vic... 0.7874097 0.8873611 ed3a3880-415f-4...
    10013: finished hermitic_albaco... 0.8763820 0.9361528 6d3af34d-c2a8-4...
    10014: finished aeromedical_vic... 0.4123581 0.6421512 fc0da47d-34cc-4...
    10015: finished hermitic_albaco... 0.9020722 0.9497748 29830e09-6e53-4...

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

    [1] 10015

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
    [1] 0.9942187


    $key
    [1] "3e9578fb-b3f2-460c-896d-5e6f88697e17"

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

    Rscript -e 'rush::start_worker(network_id = "my_network", config = list(scheme = "redis", host = "127.0.0.1", port = "6379"))'

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
