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
       1: unpoliced_afric... 0.5891048 0.7675316 d3694f57-1b61-4...
       2: unpoliced_afric... 0.6884985 0.8297581 e70553df-3daf-4...
       3: unpoliced_afric... 0.6357345 0.7973296 d61ca806-7e0c-4...
       4: unpoliced_afric... 0.7772447 0.8816148 1820583b-d379-4...
       5: paralyzing_irio... 0.1113704 0.3337220 13e1820c-d120-4...
      ---
    8403: unpoliced_afric... 0.7823735 0.8845188 a56b4726-48da-4...
    8404: paralyzing_irio... 0.4412067 0.6642339 a0d163c3-abc2-4...
    8405: unpoliced_afric... 0.8389380 0.9159356 4f4bc4ea-3642-4...
    8406: paralyzing_irio... 0.9312404 0.9650080 d1d1bd24-040e-4...
    8407: unpoliced_afric... 0.9227421 0.9605946 c3dd0345-1630-4...

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
       1: 0.58910478 0.7675316 unpoliced_afric... d3694f57-1b61-4...
       2: 0.11137036 0.3337220 paralyzing_irio... 13e1820c-d120-4...
       3: 0.68849853 0.8297581 unpoliced_afric... e70553df-3daf-4...
       4: 0.63573446 0.7973296 unpoliced_afric... d61ca806-7e0c-4...
       5: 0.77724467 0.8816148 unpoliced_afric... 1820583b-d379-4...
      ---
    9086: 0.39070069 0.6250605 paralyzing_irio... 341c6ebe-50ac-4...
    9087: 0.53648080 0.7324485 unpoliced_afric... 376fa952-3c42-4...
    9088: 0.08843324 0.2973773 paralyzing_irio... 7ddeae8b-e8bb-4...
    9089: 0.83788688 0.9153616 unpoliced_afric... 022f0bd0-5d0e-4...
    9090: 0.64069423 0.8004338 paralyzing_irio... 62124f25-2a13-4...

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
       1: finished unpoliced_afric... 0.58910478 0.7675316 d3694f57-1b61-4...
       2: finished unpoliced_afric... 0.68849853 0.8297581 e70553df-3daf-4...
       3: finished unpoliced_afric... 0.63573446 0.7973296 d61ca806-7e0c-4...
       4: finished unpoliced_afric... 0.77724467 0.8816148 1820583b-d379-4...
       5: finished paralyzing_irio... 0.11137036 0.3337220 13e1820c-d120-4...
      ---
    9086: finished paralyzing_irio... 0.39070069 0.6250605 341c6ebe-50ac-4...
    9087: finished unpoliced_afric... 0.53648080 0.7324485 376fa952-3c42-4...
    9088: finished paralyzing_irio... 0.08843324 0.2973773 7ddeae8b-e8bb-4...
    9089: finished unpoliced_afric... 0.83788688 0.9153616 022f0bd0-5d0e-4...
    9090: finished paralyzing_irio... 0.64069423 0.8004338 62124f25-2a13-4...

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

    [1] 9090

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
    [1] 0.8275458


    $key
    [1] "8674e52e-614c-41d3-a4ab-8f9ab0c13a05"

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
