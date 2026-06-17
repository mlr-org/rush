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
       1: fair_rottweiler 0.19127370 0.4373485 195b297d-0de9-4...
       2: fair_rottweiler 0.04035168 0.2008773 0f424b58-4f24-4...
       3: fair_rottweiler 0.66016774 0.8125071 e4dd9aad-67f7-4...
       4: fair_rottweiler 0.37282706 0.6105957 a890db51-a7a6-4...
       5: fair_rottweiler 0.95942500 0.9795024 3be60104-1011-4...
      ---
    7102: fair_rottweiler 0.14828458 0.3850774 e865830d-6650-4...
    7103: kingsize_fulmar 0.29604142 0.5440969 f5163224-c4a9-4...
    7104: fair_rottweiler 0.90997762 0.9539275 c1f297a8-7f42-4...
    7105: kingsize_fulmar 0.42362685 0.6508662 b001ec0b-e581-4...
    7106: fair_rottweiler 0.03388636 0.1840825 dba79223-0006-4...

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
       1: 0.19127370 0.4373485 fair_rottweiler 195b297d-0de9-4...
       2: 0.31848986 0.5643491 kingsize_fulmar c0023311-3347-4...
       3: 0.04035168 0.2008773 fair_rottweiler 0f424b58-4f24-4...
       4: 0.66016774 0.8125071 fair_rottweiler e4dd9aad-67f7-4...
       5: 0.37282706 0.6105957 fair_rottweiler a890db51-a7a6-4...
      ---
    7697: 0.69856413 0.8358015 fair_rottweiler 85c05bec-929c-4...
    7698: 0.59972385 0.7744184 kingsize_fulmar 686d5373-8ff8-4...
    7699: 0.84021672 0.9166334 fair_rottweiler a7a76464-7f8a-4...
    7700: 0.42986564 0.6556414 kingsize_fulmar a3cb41fc-9f92-4...
    7701: 0.28531845 0.5341521 fair_rottweiler c0da5074-71c4-4...

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

             state       worker_id          x         y               keys
            <char>          <char>      <num>     <num>             <char>
       1: finished fair_rottweiler 0.19127370 0.4373485 195b297d-0de9-4...
       2: finished fair_rottweiler 0.04035168 0.2008773 0f424b58-4f24-4...
       3: finished fair_rottweiler 0.66016774 0.8125071 e4dd9aad-67f7-4...
       4: finished fair_rottweiler 0.37282706 0.6105957 a890db51-a7a6-4...
       5: finished fair_rottweiler 0.95942500 0.9795024 3be60104-1011-4...
      ---
    7697: finished fair_rottweiler 0.69856413 0.8358015 85c05bec-929c-4...
    7698: finished kingsize_fulmar 0.59972385 0.7744184 686d5373-8ff8-4...
    7699: finished fair_rottweiler 0.84021672 0.9166334 a7a76464-7f8a-4...
    7700: finished kingsize_fulmar 0.42986564 0.6556414 a3cb41fc-9f92-4...
    7701: finished fair_rottweiler 0.28531845 0.5341521 c0da5074-71c4-4...

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

    [1] 7701

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
    [1] 0.4009581


    $key
    [1] "cbc72da7-7cdb-46bc-b294-19ce6998ee25"

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
