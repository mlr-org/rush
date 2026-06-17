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
       1: cactuslike_leaf... 0.9553239 0.9774067 6f108225-35dd-4...
       2:         chosen_bee 0.7519759 0.8671654 649670d2-9fee-4...
       3:         chosen_bee 0.7311224 0.8550570 90c3d86f-4ffd-4...
       4: cactuslike_leaf... 0.8358226 0.9142333 6bb7127f-7fcb-4...
       5:         chosen_bee 0.8021546 0.8956308 3eb8c560-3d5a-4...
      ---
    7264: cactuslike_leaf... 0.6765695 0.8225384 cdb2b2ce-3770-4...
    7265:         chosen_bee 0.2568821 0.5068354 d3599e55-f5c1-4...
    7266: cactuslike_leaf... 0.6697829 0.8184027 c6751790-f074-4...
    7267:         chosen_bee 0.1450629 0.3808713 d64653cb-7830-4...
    7268: cactuslike_leaf... 0.3288826 0.5734829 00e71556-18bd-4...

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
       1: 0.9553239 0.9774067 cactuslike_leaf... 6f108225-35dd-4...
       2: 0.7519759 0.8671654         chosen_bee 649670d2-9fee-4...
       3: 0.8358226 0.9142333 cactuslike_leaf... 6bb7127f-7fcb-4...
       4: 0.7311224 0.8550570         chosen_bee 90c3d86f-4ffd-4...
       5: 0.3265460 0.5714421 cactuslike_leaf... 0789bdd3-a5d2-4...
      ---
    7756: 0.7324171 0.8558137         chosen_bee a6517144-66a8-4...
    7757: 0.2745030 0.5239303 cactuslike_leaf... c7e23a5d-7657-4...
    7758: 0.7575396 0.8703675         chosen_bee 537973a1-f525-4...
    7759: 0.5373938        NA cactuslike_leaf... 6d483490-6fc8-4...
    7760: 0.4219639 0.6495875         chosen_bee 1dbbfeb0-652d-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.5373938 cactuslike_leaf... 6d483490-6fc8-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running cactuslike_leaf... 0.5373938 6d483490-6fc8-4...        NA
       2: finished cactuslike_leaf... 0.9553239 6f108225-35dd-4... 0.9774067
       3: finished         chosen_bee 0.7519759 649670d2-9fee-4... 0.8671654
       4: finished         chosen_bee 0.7311224 90c3d86f-4ffd-4... 0.8550570
       5: finished cactuslike_leaf... 0.8358226 6bb7127f-7fcb-4... 0.9142333
      ---
    7756: finished cactuslike_leaf... 0.5666554 2d2b1e93-5d2c-4... 0.7527651
    7757: finished         chosen_bee 0.7324171 a6517144-66a8-4... 0.8558137
    7758: finished cactuslike_leaf... 0.2745030 c7e23a5d-7657-4... 0.5239303
    7759: finished         chosen_bee 0.7575396 537973a1-f525-4... 0.8703675
    7760: finished         chosen_bee 0.4219639 1dbbfeb0-652d-4... 0.6495875

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

    [1] 7759

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
    [1] 0.1910454


    $key
    [1] "d568003c-546c-405e-a7fc-9c71dcbd20cb"

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
