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
       1: confirmed_bedli... 0.09485495 0.3079853 5ce053b4-b6b1-4...
       2: confirmed_bedli... 0.71114445 0.8432938 c5a2a6a6-33c4-4...
       3: confirmed_bedli... 0.17831913 0.4222785 b1d7e2bb-75d5-4...
       4: confirmed_bedli... 0.26791095 0.5176011 97133b1c-cecc-4...
       5: confirmed_bedli... 0.01548153 0.1244248 a0e20ef5-5e8d-4...
      ---
    5801: avaricious_amer... 0.98016703 0.9900339 99c8871b-955b-4...
    5802: avaricious_amer... 0.76563159 0.8750038 8958a9a1-1934-4...
    5803: confirmed_bedli... 0.67109973 0.8192068 91538b31-1ca4-4...
    5804: avaricious_amer... 0.97024875 0.9850121 dc1973bb-d3cd-4...
    5805: confirmed_bedli... 0.26417127 0.5139759 c65df86c-4e1a-4...

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
       1: 0.09485495 0.3079853 confirmed_bedli... 5ce053b4-b6b1-4...
       2: 0.21597653 0.4647327 avaricious_amer... 5e3fefcf-88dc-4...
       3: 0.71114445 0.8432938 confirmed_bedli... c5a2a6a6-33c4-4...
       4: 0.17831913 0.4222785 confirmed_bedli... b1d7e2bb-75d5-4...
       5: 0.26791095 0.5176011 confirmed_bedli... 97133b1c-cecc-4...
      ---
    6192: 0.62465816 0.7903532 avaricious_amer... 2187950e-c8e1-4...
    6193: 0.86478929 0.9299405 confirmed_bedli... 606269af-8522-4...
    6194: 0.46871763 0.6846296 avaricious_amer... 026d605a-5df1-4...
    6195: 0.49067774 0.7004839 confirmed_bedli... b6296c49-6900-4...
    6196: 0.44172072        NA avaricious_amer... 618c02bf-bbed-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.4417207 avaricious_amer... 618c02bf-bbed-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running avaricious_amer... 0.44172072 618c02bf-bbed-4...        NA
       2: finished confirmed_bedli... 0.09485495 5ce053b4-b6b1-4... 0.3079853
       3: finished confirmed_bedli... 0.71114445 c5a2a6a6-33c4-4... 0.8432938
       4: finished confirmed_bedli... 0.17831913 b1d7e2bb-75d5-4... 0.4222785
       5: finished confirmed_bedli... 0.26791095 97133b1c-cecc-4... 0.5176011
      ---
    6192: finished confirmed_bedli... 0.96168636 54a2d4af-05e4-4... 0.9806561
    6193: finished avaricious_amer... 0.62465816 2187950e-c8e1-4... 0.7903532
    6194: finished confirmed_bedli... 0.86478929 606269af-8522-4... 0.9299405
    6195: finished avaricious_amer... 0.46871763 026d605a-5df1-4... 0.6846296
    6196: finished confirmed_bedli... 0.49067774 b6296c49-6900-4... 0.7004839

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

    [1] 6195

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
    [1] 0.7253032


    $key
    [1] "a89c434d-06cb-4be4-b8f3-11812c9fb5bf"

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
