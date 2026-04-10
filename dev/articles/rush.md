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
       1: sprightful_gnat... 0.4014993 0.6336398 66678b25-74dc-4...
       2:    waiting_gharial 0.4138530 0.6433141 8118a454-9a33-4...
       3: sprightful_gnat... 0.2844850 0.5333714 2c7c1df0-da2a-4...
       4: sprightful_gnat... 0.4132344 0.6428331 17f61d9a-595e-4...
       5:    waiting_gharial 0.7277590 0.8530879 4c026094-2223-4...
      ---
    8302: sprightful_gnat... 0.2016141 0.4490145 60fa9002-e64d-4...
    8303:    waiting_gharial 0.3250599 0.5701403 2f54e033-8a74-4...
    8304:    waiting_gharial 0.9653620 0.9825284 ffdca1e2-c912-4...
    8305: sprightful_gnat... 0.2458452 0.4958278 004e79ac-0367-4...
    8306:    waiting_gharial 0.3230346 0.5683613 9635d9b1-3bb5-4...

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
       1: 0.4014993 0.6336398 sprightful_gnat... 66678b25-74dc-4...
       2: 0.4138530 0.6433141    waiting_gharial 8118a454-9a33-4...
       3: 0.2844850 0.5333714 sprightful_gnat... 2c7c1df0-da2a-4...
       4: 0.7277590 0.8530879    waiting_gharial 4c026094-2223-4...
       5: 0.4132344 0.6428331 sprightful_gnat... 17f61d9a-595e-4...
      ---
    8960: 0.7966253 0.8925387    waiting_gharial b967c192-105b-4...
    8961: 0.6830988 0.8264979 sprightful_gnat... 96f0322b-bc7a-4...
    8962: 0.3730375 0.6107680    waiting_gharial a4718a90-57c6-4...
    8963: 0.8039718        NA sprightful_gnat... 40dee93e-8ae6-4...
    8964: 0.9497568        NA    waiting_gharial 1941542d-2254-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.8039718 sprightful_gnat... 40dee93e-8ae6-4...
    2: 0.9497568    waiting_gharial 1941542d-2254-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running sprightful_gnat... 0.8039718 40dee93e-8ae6-4...        NA
       2:  running    waiting_gharial 0.9497568 1941542d-2254-4...        NA
       3: finished sprightful_gnat... 0.4014993 66678b25-74dc-4... 0.6336398
       4: finished    waiting_gharial 0.4138530 8118a454-9a33-4... 0.6433141
       5: finished sprightful_gnat... 0.2844850 2c7c1df0-da2a-4... 0.5333714
      ---
    8960: finished    waiting_gharial 0.2969637 2dbab3ec-e57d-4... 0.5449437
    8961: finished sprightful_gnat... 0.1385431 a1a68a01-ad55-4... 0.3722137
    8962: finished    waiting_gharial 0.7966253 b967c192-105b-4... 0.8925387
    8963: finished sprightful_gnat... 0.6830988 96f0322b-bc7a-4... 0.8264979
    8964: finished    waiting_gharial 0.3730375 a4718a90-57c6-4... 0.6107680

## Task Counts

``` r
rush$n_queued_tasks
```

    [1] 0

``` r
rush$n_running_tasks
```

    [1] 2

``` r
rush$n_finished_tasks
```

    [1] 8962

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

``` r
task = rush$pop_task()
task
```

    $xs
    $xs$x
    [1] 0.9668259


    $key
    [1] "21fdb2f0-e8e9-4beb-97ec-a001c859184c"

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
