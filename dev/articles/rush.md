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
       1: feudalist_vicer... 0.47961942 0.6925456 bbbcfb07-9c67-4...
       2: feudalist_vicer... 0.71403481 0.8450058 c2de0576-780a-4...
       3: feudalist_vicer... 0.68642895 0.8285101 c2a61cd2-3cb7-4...
       4: feudalist_vicer... 0.26846893 0.5181399 3c7704bc-9955-4...
       5: feudalist_vicer... 0.04585124 0.2141290 37df8b3f-6539-4...
      ---
    6144: stigmatophilic_... 0.89833429 0.9478050 5239c349-2867-4...
    6145: stigmatophilic_... 0.28513266 0.5339781 6d11e232-ee5e-4...
    6146: feudalist_vicer... 0.66186414 0.8135503 ea2656dc-9600-4...
    6147: feudalist_vicer... 0.72166610 0.8495093 50254ca8-b020-4...
    6148: stigmatophilic_... 0.07750136 0.2783907 9972f19d-6bd5-4...

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
       1: 0.4796194 0.6925456 feudalist_vicer... bbbcfb07-9c67-4...
       2: 0.6928707 0.8323885 stigmatophilic_... 26a856ed-8ef6-4...
       3: 0.7140348 0.8450058 feudalist_vicer... c2de0576-780a-4...
       4: 0.6864289 0.8285101 feudalist_vicer... c2a61cd2-3cb7-4...
       5: 0.2684689 0.5181399 feudalist_vicer... 3c7704bc-9955-4...
      ---
    6567: 0.7793319 0.8827978 stigmatophilic_... 8954472c-42c5-4...
    6568: 0.3931908 0.6270492 feudalist_vicer... f79c50d7-6005-4...
    6569: 0.9437186 0.9714518 stigmatophilic_... b7defa70-ab7a-4...
    6570: 0.5722047 0.7564421 feudalist_vicer... ff0317a0-9444-4...
    6571: 0.7448158 0.8630271 stigmatophilic_... 08f214ee-3121-4...

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
       1: finished feudalist_vicer... 0.47961942 0.6925456 bbbcfb07-9c67-4...
       2: finished feudalist_vicer... 0.71403481 0.8450058 c2de0576-780a-4...
       3: finished feudalist_vicer... 0.68642895 0.8285101 c2a61cd2-3cb7-4...
       4: finished feudalist_vicer... 0.26846893 0.5181399 3c7704bc-9955-4...
       5: finished feudalist_vicer... 0.04585124 0.2141290 37df8b3f-6539-4...
      ---
    6567: finished stigmatophilic_... 0.77933192 0.8827978 8954472c-42c5-4...
    6568: finished feudalist_vicer... 0.39319076 0.6270492 f79c50d7-6005-4...
    6569: finished stigmatophilic_... 0.94371863 0.9714518 b7defa70-ab7a-4...
    6570: finished feudalist_vicer... 0.57220468 0.7564421 ff0317a0-9444-4...
    6571: finished stigmatophilic_... 0.74481576 0.8630271 08f214ee-3121-4...

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

    [1] 6571

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
    [1] 0.6310696


    $key
    [1] "4e8507fd-b6d8-4773-90d4-e067d82f31b9"

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
