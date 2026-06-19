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
       1:  inaccurate_eel 0.54003205 0.7348687 8cde3e8d-f2ec-4...
       2: quartzitic_lamb 0.86403646 0.9295356 e2b9b657-b67e-4...
       3:  inaccurate_eel 0.37303898 0.6107692 6c4749b3-df89-4...
       4: quartzitic_lamb 0.90137017 0.9494052 a8853a20-3cf9-4...
       5:  inaccurate_eel 0.42164317 0.6493406 b44edda5-9f9a-4...
      ---
    6210: quartzitic_lamb 0.02415541 0.1554201 a14e2c06-0cb9-4...
    6211:  inaccurate_eel 0.84682165 0.9202291 9297c159-d716-4...
    6212: quartzitic_lamb 0.22434293 0.4736485 62a9606d-8c26-4...
    6213:  inaccurate_eel 0.07160866 0.2675979 f19cf47d-f214-4...
    6214: quartzitic_lamb 0.46225220 0.6798913 06192bdd-c90c-4...

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

                   x         y       worker_id               keys
               <num>     <num>          <char>             <char>
       1: 0.54003205 0.7348687  inaccurate_eel 8cde3e8d-f2ec-4...
       2: 0.86403646 0.9295356 quartzitic_lamb e2b9b657-b67e-4...
       3: 0.37303898 0.6107692  inaccurate_eel 6c4749b3-df89-4...
       4: 0.90137017 0.9494052 quartzitic_lamb a8853a20-3cf9-4...
       5: 0.42164317 0.6493406  inaccurate_eel b44edda5-9f9a-4...
      ---
    6653: 0.70217250 0.8379573 quartzitic_lamb f0a161af-bb44-4...
    6654: 0.67250281 0.8200627  inaccurate_eel ebd81290-e6d2-4...
    6655: 0.70788370 0.8413582 quartzitic_lamb d0da2e30-2636-4...
    6656: 0.04716122 0.2171664  inaccurate_eel 0996c561-3b4b-4...
    6657: 0.01564483        NA quartzitic_lamb 1d13b74d-63e5-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

                x       worker_id               keys
            <num>          <char>             <char>
    1: 0.01564483 quartzitic_lamb 1d13b74d-63e5-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state       worker_id          x               keys         y
            <char>          <char>      <num>             <char>     <num>
       1:  running quartzitic_lamb 0.01564483 1d13b74d-63e5-4...        NA
       2: finished  inaccurate_eel 0.54003205 8cde3e8d-f2ec-4... 0.7348687
       3: finished quartzitic_lamb 0.86403646 e2b9b657-b67e-4... 0.9295356
       4: finished  inaccurate_eel 0.37303898 6c4749b3-df89-4... 0.6107692
       5: finished quartzitic_lamb 0.90137017 a8853a20-3cf9-4... 0.9494052
      ---
    6653: finished  inaccurate_eel 0.39007419 a8e8383d-0ea4-4... 0.6245592
    6654: finished quartzitic_lamb 0.70217250 f0a161af-bb44-4... 0.8379573
    6655: finished  inaccurate_eel 0.67250281 ebd81290-e6d2-4... 0.8200627
    6656: finished quartzitic_lamb 0.70788370 d0da2e30-2636-4... 0.8413582
    6657: finished  inaccurate_eel 0.04716122 0996c561-3b4b-4... 0.2171664

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

    [1] 6656

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
    [1] 0.6420547


    $key
    [1] "78d36315-92de-499a-b71f-380f24c2f99f"

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
