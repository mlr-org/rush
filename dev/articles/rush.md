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
       1: appreciative_ba... 0.54193212 0.7361604 b43932c8-681d-4...
       2: appreciative_ba... 0.76679000 0.8756655 ffb679bc-4fce-4...
       3: appreciative_ba... 0.22803156 0.4775265 5ac0f8ad-a1fa-4...
       4: appreciative_ba... 0.09503441 0.3082765 543321e6-bf00-4...
       5: appreciative_ba... 0.84798485 0.9208609 5a5a4dc3-5925-4...
      ---
    6224: skipping_harpye... 0.17696827 0.4206760 a5bbece9-99e8-4...
    6225: appreciative_ba... 0.41281036 0.6425032 e57a72f0-c5ad-4...
    6226: skipping_harpye... 0.53140307 0.7289740 c0d6e7d7-e648-4...
    6227: appreciative_ba... 0.74079067 0.8606920 1b5ca059-1537-4...
    6228: skipping_harpye... 0.72728945 0.8528127 4fe53e95-cfbd-4...

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
       1: 0.54193212 0.7361604 appreciative_ba... b43932c8-681d-4...
       2: 0.22513471 0.4744836 skipping_harpye... 11120787-f0ac-4...
       3: 0.76679000 0.8756655 appreciative_ba... ffb679bc-4fce-4...
       4: 0.22803156 0.4775265 appreciative_ba... 5ac0f8ad-a1fa-4...
       5: 0.09503441 0.3082765 appreciative_ba... 543321e6-bf00-4...
      ---
    6614: 0.93179928 0.9652975 skipping_harpye... 9594f7ac-27b8-4...
    6615: 0.40534885 0.6366701 appreciative_ba... 6088bd25-56a8-4...
    6616: 0.48137068 0.6938088 appreciative_ba... 096ead19-9b0b-4...
    6617: 0.65218042 0.8075769 skipping_harpye... e2607863-24ea-4...
    6618: 0.09194513        NA skipping_harpye... f40e47cb-907f-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

                x          worker_id               keys
            <num>             <char>             <char>
    1: 0.09194513 skipping_harpye... f40e47cb-907f-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running skipping_harpye... 0.09194513 f40e47cb-907f-4...        NA
       2: finished appreciative_ba... 0.54193212 b43932c8-681d-4... 0.7361604
       3: finished appreciative_ba... 0.76679000 ffb679bc-4fce-4... 0.8756655
       4: finished appreciative_ba... 0.22803156 5ac0f8ad-a1fa-4... 0.4775265
       5: finished appreciative_ba... 0.09503441 543321e6-bf00-4... 0.3082765
      ---
    6614: finished appreciative_ba... 0.51460287 c7cabaf6-237e-4... 0.7173583
    6615: finished skipping_harpye... 0.93179928 9594f7ac-27b8-4... 0.9652975
    6616: finished appreciative_ba... 0.40534885 6088bd25-56a8-4... 0.6366701
    6617: finished appreciative_ba... 0.48137068 096ead19-9b0b-4... 0.6938088
    6618: finished skipping_harpye... 0.65218042 e2607863-24ea-4... 0.8075769

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

    [1] 6617

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
    [1] 0.8376459


    $key
    [1] "9ea5355c-0f7c-437e-8359-38f5f24423eb"

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
