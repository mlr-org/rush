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
       1: mathematical_ar... 0.99413150 0.9970614 e3b624b9-2a61-4...
       2: mathematical_ar... 0.65605477 0.8099721 e3a48ec9-d09e-4...
       3: cinderlike_gere... 0.18367650 0.4285750 e43856dd-9e07-4...
       4: mathematical_ar... 0.60643491 0.7787393 d1074452-1e8b-4...
       5: cinderlike_gere... 0.79770038 0.8931407 4a1fd8f1-14f0-4...
      ---
    5807: cinderlike_gere... 0.80353555 0.8964014 c4c9e379-b204-4...
    5808: mathematical_ar... 0.86434712 0.9297027 94e9762a-23ea-4...
    5809: cinderlike_gere... 0.01821536 0.1349643 99637fbb-7a34-4...
    5810: mathematical_ar... 0.29059195 0.5390658 cfc7e47b-d02b-4...
    5811: cinderlike_gere... 0.56390456 0.7509358 7e19328f-ca1e-4...

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
       1: 0.18367650 0.4285750 cinderlike_gere... e43856dd-9e07-4...
       2: 0.99413150 0.9970614 mathematical_ar... e3b624b9-2a61-4...
       3: 0.65605477 0.8099721 mathematical_ar... e3a48ec9-d09e-4...
       4: 0.60643491 0.7787393 mathematical_ar... d1074452-1e8b-4...
       5: 0.79770038 0.8931407 cinderlike_gere... 4a1fd8f1-14f0-4...
      ---
    6183: 0.04346914 0.2084925 mathematical_ar... fd03c593-89ab-4...
    6184: 0.96513930 0.9824150 mathematical_ar... 024e1058-1eed-4...
    6185: 0.86346738 0.9292295 cinderlike_gere... 41dbd2eb-3106-4...
    6186: 0.73126798        NA cinderlike_gere... 6a174533-7ff0-4...
    6187: 0.16360562        NA mathematical_ar... d2148f38-3ee0-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.7312680 cinderlike_gere... 6a174533-7ff0-4...
    2: 0.1636056 mathematical_ar... d2148f38-3ee0-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running cinderlike_gere... 0.73126798 6a174533-7ff0-4...        NA
       2:  running mathematical_ar... 0.16360562 d2148f38-3ee0-4...        NA
       3: finished mathematical_ar... 0.99413150 e3b624b9-2a61-4... 0.9970614
       4: finished mathematical_ar... 0.65605477 e3a48ec9-d09e-4... 0.8099721
       5: finished cinderlike_gere... 0.18367650 e43856dd-9e07-4... 0.4285750
      ---
    6183: finished cinderlike_gere... 0.99742349 f05ebdfd-0027-4... 0.9987109
    6184: finished cinderlike_gere... 0.91241083 c0e80454-f8be-4... 0.9552020
    6185: finished mathematical_ar... 0.04346914 fd03c593-89ab-4... 0.2084925
    6186: finished mathematical_ar... 0.96513930 024e1058-1eed-4... 0.9824150
    6187: finished cinderlike_gere... 0.86346738 41dbd2eb-3106-4... 0.9292295

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

    [1] 6185

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
    [1] 0.2870881


    $key
    [1] "28bb96d1-ece3-4d4c-951e-2bb5c35c21ae"

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
