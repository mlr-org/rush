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
       1: imparisyllabic_... 0.5480311 0.7402912 18b0a07f-6170-4...
       2: imparisyllabic_... 0.6276557 0.7922472 ccbcd9d2-d5f5-4...
       3: imparisyllabic_... 0.9334431 0.9661486 290a68fe-d7bd-4...
       4: uncooperative_b... 0.6972788 0.8350322 cff37fe3-dbe4-4...
       5: imparisyllabic_... 0.8451862 0.9193401 ab9be505-85fc-4...
      ---
    6233: uncooperative_b... 0.2720097 0.5215455 583ea907-194b-4...
    6234: imparisyllabic_... 0.6163486 0.7850787 836fb6e8-36d3-4...
    6235: uncooperative_b... 0.9631410 0.9813975 033e2fcf-0e2c-4...
    6236: imparisyllabic_... 0.6096719 0.7808149 2edd72e6-afe3-4...
    6237: uncooperative_b... 0.5887879 0.7673251 667e6d63-06e0-4...

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
       1: 0.5480311 0.7402912 imparisyllabic_... 18b0a07f-6170-4...
       2: 0.6972788 0.8350322 uncooperative_b... cff37fe3-dbe4-4...
       3: 0.6276557 0.7922472 imparisyllabic_... ccbcd9d2-d5f5-4...
       4: 0.9334431 0.9661486 imparisyllabic_... 290a68fe-d7bd-4...
       5: 0.8451862 0.9193401 imparisyllabic_... ab9be505-85fc-4...
      ---
    6656: 0.9316975 0.9652448 imparisyllabic_... 136241de-5d3e-4...
    6657: 0.0511168 0.2260903 imparisyllabic_... d628b685-4706-4...
    6658: 0.5974037 0.7729189 uncooperative_b... 029fdcbf-98c9-4...
    6659: 0.3853710 0.6207826 imparisyllabic_... b32c262e-6c22-4...
    6660: 0.7782705 0.8821964 uncooperative_b... 33b9f754-403a-4...

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
       1: finished imparisyllabic_... 0.5480311 0.7402912 18b0a07f-6170-4...
       2: finished imparisyllabic_... 0.6276557 0.7922472 ccbcd9d2-d5f5-4...
       3: finished imparisyllabic_... 0.9334431 0.9661486 290a68fe-d7bd-4...
       4: finished uncooperative_b... 0.6972788 0.8350322 cff37fe3-dbe4-4...
       5: finished imparisyllabic_... 0.8451862 0.9193401 ab9be505-85fc-4...
      ---
    6656: finished imparisyllabic_... 0.9316975 0.9652448 136241de-5d3e-4...
    6657: finished imparisyllabic_... 0.0511168 0.2260903 d628b685-4706-4...
    6658: finished uncooperative_b... 0.5974037 0.7729189 029fdcbf-98c9-4...
    6659: finished imparisyllabic_... 0.3853710 0.6207826 b32c262e-6c22-4...
    6660: finished uncooperative_b... 0.7782705 0.8821964 33b9f754-403a-4...

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

    [1] 6660

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
    [1] 0.00212172


    $key
    [1] "59b2a003-1430-4e9d-be00-382250c24220"

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
