# rush - Quick Reference

A quick reference cheatsheet for `rush`. See the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) for a detailed
introduction.

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
       1: misandrist_caec... 0.23236395 0.4820414 d90f7ad1-8038-4...
       2: inhumane_inganu... 0.08040668 0.2835607 6cc3c0fb-f0e9-4...
       3: misandrist_caec... 0.31325469 0.5596916 1be72e4c-469b-4...
       4: misandrist_caec... 0.77611152 0.8809719 b091b850-2fa5-4...
       5: misandrist_caec... 0.98188898 0.9909031 570a5ccb-169b-4...
      ---
    6430: misandrist_caec... 0.17659334 0.4202301 28eaf584-95c8-4...
    6431: inhumane_inganu... 0.02371087 0.1539833 4b4fff60-7fa3-4...
    6432: misandrist_caec... 0.92815865 0.9634099 d9832063-deae-4...
    6433: inhumane_inganu... 0.94354499 0.9713624 6415979c-b189-4...
    6434: misandrist_caec... 0.48448815 0.6960518 7ebcae46-ac22-4...

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
       1: 0.23236395 0.4820414 misandrist_caec... d90f7ad1-8038-4...
       2: 0.08040668 0.2835607 inhumane_inganu... 6cc3c0fb-f0e9-4...
       3: 0.31325469 0.5596916 misandrist_caec... 1be72e4c-469b-4...
       4: 0.64702543 0.8043789 inhumane_inganu... 9d954c67-36b3-4...
       5: 0.77611152 0.8809719 misandrist_caec... b091b850-2fa5-4...
      ---
    6865: 0.78314690 0.8849559 inhumane_inganu... 7588aec1-9a41-4...
    6866: 0.02513432 0.1585381 misandrist_caec... 2ce7aaab-1dca-4...
    6867: 0.30766597 0.5546765 inhumane_inganu... 35b6e6ac-2226-4...
    6868: 0.90656172 0.9521353 misandrist_caec... 764ca7dd-fba9-4...
    6869: 0.87473137 0.9352707 inhumane_inganu... 5ac0c8de-7b10-4...

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
       1: finished misandrist_caec... 0.23236395 0.4820414 d90f7ad1-8038-4...
       2: finished inhumane_inganu... 0.08040668 0.2835607 6cc3c0fb-f0e9-4...
       3: finished misandrist_caec... 0.31325469 0.5596916 1be72e4c-469b-4...
       4: finished misandrist_caec... 0.77611152 0.8809719 b091b850-2fa5-4...
       5: finished misandrist_caec... 0.98188898 0.9909031 570a5ccb-169b-4...
      ---
    6865: finished inhumane_inganu... 0.78314690 0.8849559 7588aec1-9a41-4...
    6866: finished misandrist_caec... 0.02513432 0.1585381 2ce7aaab-1dca-4...
    6867: finished inhumane_inganu... 0.30766597 0.5546765 35b6e6ac-2226-4...
    6868: finished misandrist_caec... 0.90656172 0.9521353 764ca7dd-fba9-4...
    6869: finished inhumane_inganu... 0.87473137 0.9352707 5ac0c8de-7b10-4...

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

    [1] 6869

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
    [1] 0.3836843


    $key
    [1] "ef8677a2-86d5-47c0-aa79-ab68951c3103"

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
