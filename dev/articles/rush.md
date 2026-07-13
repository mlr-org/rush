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
       1: antioptimistic_... 0.29906874 0.5468718 84d0a3ac-e60a-4...
       2: pebbly_polytura... 0.73955355 0.8599730 40030a24-9c2b-4...
       3: antioptimistic_... 0.95455539 0.9770135 0ad19a46-34e1-4...
       4: pebbly_polytura... 0.75011891 0.8660941 12d51e86-db15-4...
       5: antioptimistic_... 0.97526884 0.9875570 dc0e479b-1a1e-4...
      ---
    6442: antioptimistic_... 0.52716243 0.7260595 087625bc-34a5-4...
    6443: pebbly_polytura... 0.01286073 0.1134052 2a184c5c-1154-4...
    6444: antioptimistic_... 0.79504121 0.8916508 0270a017-d224-4...
    6445: antioptimistic_... 0.97279694 0.9863047 8c8f29ed-e817-4...
    6446: pebbly_polytura... 0.48478804 0.6962672 180d9a48-1c64-4...

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

                  x         y          worker_id condition               keys
              <num>     <num>             <char>    <list>             <char>
       1: 0.2990687 0.5468718 antioptimistic_...    [NULL] 84d0a3ac-e60a-4...
       2: 0.7395535 0.8599730 pebbly_polytura...    [NULL] 40030a24-9c2b-4...
       3: 0.9545554 0.9770135 antioptimistic_...    [NULL] 0ad19a46-34e1-4...
       4: 0.7501189 0.8660941 pebbly_polytura...    [NULL] 12d51e86-db15-4...
       5: 0.9752688 0.9875570 antioptimistic_...    [NULL] dc0e479b-1a1e-4...
      ---
    6891: 0.3384182 0.5817373 antioptimistic_...    [NULL] 2c76c602-fa11-4...
    6892: 0.8649725 0.9300390 pebbly_polytura...    [NULL] b3d5f43b-267b-4...
    6893: 0.7403408 0.8604306 antioptimistic_...    [NULL] 0dd22e8a-7171-4...
    6894: 0.1110834        NA pebbly_polytura... <list[1]> 0f9d1ce6-b5ea-4...
    6895: 0.5515319        NA antioptimistic_... <list[1]> a5f9cccc-5d77-4...

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

               x          worker_id condition               keys
           <num>             <char>    <list>             <char>
    1: 0.1110834 pebbly_polytura... <list[1]> 0f9d1ce6-b5ea-4...
    2: 0.5515319 antioptimistic_... <list[1]> a5f9cccc-5d77-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished antioptimistic_... 0.2990687 0.5468718 84d0a3ac-e60a-4...
       2: finished pebbly_polytura... 0.7395535 0.8599730 40030a24-9c2b-4...
       3: finished antioptimistic_... 0.9545554 0.9770135 0ad19a46-34e1-4...
       4: finished pebbly_polytura... 0.7501189 0.8660941 12d51e86-db15-4...
       5: finished antioptimistic_... 0.9752688 0.9875570 dc0e479b-1a1e-4...
      ---
    6889: finished antioptimistic_... 0.2737990 0.5232581 1a5e069a-8386-4...
    6890: finished pebbly_polytura... 0.7858297 0.8864704 7b5f9cce-4d8e-4...
    6891: finished antioptimistic_... 0.3384182 0.5817373 2c76c602-fa11-4...
    6892: finished pebbly_polytura... 0.8649725 0.9300390 b3d5f43b-267b-4...
    6893: finished antioptimistic_... 0.7403408 0.8604306 0dd22e8a-7171-4...

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

    [1] 6893

``` r

rush$n_failed_tasks
```

    [1] 2

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
    [1] 0.8136654


    $key
    [1] "63591e81-cabe-4e11-b375-b2fd418eb645"

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
