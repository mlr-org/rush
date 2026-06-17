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
       1: unhappy_america... 0.6851949 0.8277650 b396c977-77a3-4...
       2: chromite_scorpi... 0.4731494 0.6878585 2812ee00-2a8d-4...
       3: unhappy_america... 0.7147685 0.8454399 88e85eac-61e0-4...
       4: chromite_scorpi... 0.4993170 0.7066236 e2c7dd3e-4d40-4...
       5: unhappy_america... 0.8474362 0.9205630 4ebd187c-5228-4...
      ---
    6237: unhappy_america... 0.2618748 0.5117370 987c233f-04a1-4...
    6238: chromite_scorpi... 0.4519095 0.6722421 ee725a14-2638-4...
    6239: unhappy_america... 0.9099821 0.9539298 2ec715be-c0d9-4...
    6240: chromite_scorpi... 0.6120212 0.7823179 f0972f5a-44aa-4...
    6241: unhappy_america... 0.8389554 0.9159451 fb28268e-f38e-4...

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
       1: 0.6851949 0.8277650 unhappy_america... b396c977-77a3-4...
       2: 0.4731494 0.6878585 chromite_scorpi... 2812ee00-2a8d-4...
       3: 0.7147685 0.8454399 unhappy_america... 88e85eac-61e0-4...
       4: 0.4993170 0.7066236 chromite_scorpi... e2c7dd3e-4d40-4...
       5: 0.8474362 0.9205630 unhappy_america... 4ebd187c-5228-4...
      ---
    6678: 0.1156699 0.3401028 unhappy_america... 642b67e8-ae61-4...
    6679: 0.1449041 0.3806628 chromite_scorpi... a90cf25c-6fc0-4...
    6680: 0.1441821 0.3797132 unhappy_america... 860d2712-7d59-4...
    6681: 0.8462949 0.9199429 chromite_scorpi... 1692f312-a420-4...
    6682: 0.1003915 0.3168462 unhappy_america... 12b63cbe-a29b-4...

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
       1: finished unhappy_america... 0.6851949 0.8277650 b396c977-77a3-4...
       2: finished chromite_scorpi... 0.4731494 0.6878585 2812ee00-2a8d-4...
       3: finished unhappy_america... 0.7147685 0.8454399 88e85eac-61e0-4...
       4: finished chromite_scorpi... 0.4993170 0.7066236 e2c7dd3e-4d40-4...
       5: finished unhappy_america... 0.8474362 0.9205630 4ebd187c-5228-4...
      ---
    6678: finished unhappy_america... 0.1156699 0.3401028 642b67e8-ae61-4...
    6679: finished chromite_scorpi... 0.1449041 0.3806628 a90cf25c-6fc0-4...
    6680: finished unhappy_america... 0.1441821 0.3797132 860d2712-7d59-4...
    6681: finished chromite_scorpi... 0.8462949 0.9199429 1692f312-a420-4...
    6682: finished unhappy_america... 0.1003915 0.3168462 12b63cbe-a29b-4...

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

    [1] 6682

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
    [1] 0.3146773


    $key
    [1] "77c7d320-91a5-4b7d-a837-b5cdce87ed26"

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
