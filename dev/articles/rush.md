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
       1: abashed_sable_9... 0.06733675 0.2594933 82760d80-2f67-4...
       2: adverse_leafbir... 0.92504116 0.9617906 1ccc68f3-1e27-4...
       3: abashed_sable_9... 0.93162074 0.9652050 adfefa3f-9af4-4...
       4: abashed_sable_9... 0.46081440 0.6788331 83d4efce-4382-4...
       5: abashed_sable_9... 0.55508340 0.7450392 81787527-dae9-4...
      ---
    6612: adverse_leafbir... 0.96516966 0.9824305 dff923c5-fa01-4...
    6613: abashed_sable_9... 0.46441128 0.6814773 f2205201-3696-4...
    6614: adverse_leafbir... 0.24784069 0.4978360 4eb22cb1-2364-4...
    6615: abashed_sable_9... 0.48579480 0.6969898 1724d878-1d3b-4...
    6616: adverse_leafbir... 0.29434203 0.5425330 a8a8307e-295e-4...

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
       1: 0.06733675 0.2594933 abashed_sable_9... 82760d80-2f67-4...
       2: 0.92504116 0.9617906 adverse_leafbir... 1ccc68f3-1e27-4...
       3: 0.93162074 0.9652050 abashed_sable_9... adfefa3f-9af4-4...
       4: 0.94391390 0.9715523 adverse_leafbir... 2c7b0ef2-9b2d-4...
       5: 0.46081440 0.6788331 abashed_sable_9... 83d4efce-4382-4...
      ---
    7051: 0.45129982 0.6717885 adverse_leafbir... d8211cbb-9767-4...
    7052: 0.73528083 0.8574852 abashed_sable_9... 57f9f85c-d7b2-4...
    7053: 0.60165110 0.7756617 adverse_leafbir... c8b945b6-ac19-4...
    7054: 0.03642179 0.1908449 abashed_sable_9... 58747b87-5056-4...
    7055: 0.54918724 0.7410717 adverse_leafbir... 32462431-c846-4...

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
       1: finished abashed_sable_9... 0.06733675 0.2594933 82760d80-2f67-4...
       2: finished adverse_leafbir... 0.92504116 0.9617906 1ccc68f3-1e27-4...
       3: finished abashed_sable_9... 0.93162074 0.9652050 adfefa3f-9af4-4...
       4: finished abashed_sable_9... 0.46081440 0.6788331 83d4efce-4382-4...
       5: finished abashed_sable_9... 0.55508340 0.7450392 81787527-dae9-4...
      ---
    7051: finished adverse_leafbir... 0.45129982 0.6717885 d8211cbb-9767-4...
    7052: finished abashed_sable_9... 0.73528083 0.8574852 57f9f85c-d7b2-4...
    7053: finished adverse_leafbir... 0.60165110 0.7756617 c8b945b6-ac19-4...
    7054: finished abashed_sable_9... 0.03642179 0.1908449 58747b87-5056-4...
    7055: finished adverse_leafbir... 0.54918724 0.7410717 32462431-c846-4...

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

    [1] 7055

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
    [1] 0.1416202


    $key
    [1] "6c695b2b-a7db-4ed2-b1b6-e0339184751c"

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
