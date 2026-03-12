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
       1: suburbicarian_s... 0.09974565 0.3158253 56cf7fb2-8789-4...
       2: suburbicarian_s... 0.93069119 0.9647234 57dd6862-e036-4...
       3: suburbicarian_s... 0.34559728 0.5878752 be68ffff-4297-4...
       4: suburbicarian_s... 0.40885032 0.6394140 0d000e22-2da3-4...
       5: suburbicarian_s... 0.21154444 0.4599396 b171c9ce-e973-4...
      ---
    6566:          pink_seal 0.71800139 0.8473496 a136b5b0-c43c-4...
    6567: suburbicarian_s... 0.38018747 0.6165934 740ae573-b696-4...
    6568:          pink_seal 0.55022901 0.7417742 29424a0d-33e5-4...
    6569: suburbicarian_s... 0.27217297 0.5217020 cb6e6421-26e1-4...
    6570:          pink_seal 0.28252197 0.5315280 68377a55-b603-4...

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
       1: 0.09974565 0.3158253 suburbicarian_s... 56cf7fb2-8789-4...
       2: 0.30369689 0.5510870          pink_seal 835beee3-b7ee-4...
       3: 0.93069119 0.9647234 suburbicarian_s... 57dd6862-e036-4...
       4: 0.34559728 0.5878752 suburbicarian_s... be68ffff-4297-4...
       5: 0.40885032 0.6394140 suburbicarian_s... 0d000e22-2da3-4...
      ---
    6950: 0.54819324 0.7404007 suburbicarian_s... d5086e24-6b2f-4...
    6951: 0.34754479 0.5895293          pink_seal db82e8c3-a85c-4...
    6952: 0.57035386 0.7552178 suburbicarian_s... 0d45bbc8-fb1e-4...
    6953: 0.62031282 0.7875994          pink_seal 91eb2697-e63f-4...
    6954: 0.97596939        NA suburbicarian_s... 099b559f-2158-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.9759694 suburbicarian_s... 099b559f-2158-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running suburbicarian_s... 0.97596939 099b559f-2158-4...        NA
       2: finished suburbicarian_s... 0.09974565 56cf7fb2-8789-4... 0.3158253
       3: finished suburbicarian_s... 0.93069119 57dd6862-e036-4... 0.9647234
       4: finished suburbicarian_s... 0.34559728 be68ffff-4297-4... 0.5878752
       5: finished suburbicarian_s... 0.40885032 0d000e22-2da3-4... 0.6394140
      ---
    6950: finished          pink_seal 0.39255112 5a03b864-838c-4... 0.6265390
    6951: finished suburbicarian_s... 0.54819324 d5086e24-6b2f-4... 0.7404007
    6952: finished          pink_seal 0.34754479 db82e8c3-a85c-4... 0.5895293
    6953: finished suburbicarian_s... 0.57035386 0d45bbc8-fb1e-4... 0.7552178
    6954: finished          pink_seal 0.62031282 91eb2697-e63f-4... 0.7875994

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

    [1] 6953

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
    [1] 0.6990255


    $key
    [1] "74ac984e-aa5a-4fec-8fba-b62dff7e37c2"

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
