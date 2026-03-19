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
       1: inconvenient_am... 0.20315474 0.4507269 86a6a062-dbca-4...
       2: inconvenient_am... 0.89278856 0.9448749 233f4a3a-82ea-4...
       3: inconvenient_am... 0.36677289 0.6056178 6b528d18-f5e7-4...
       4: inconvenient_am... 0.87446394 0.9351278 11fc4e26-997c-4...
       5: inconvenient_am... 0.59028978 0.7683032 6f808a6d-cf9f-4...
      ---
    6297: disallowable_dr... 0.70490856 0.8395883 07c28b9d-2306-4...
    6298: inconvenient_am... 0.99403219 0.9970116 2673bd9c-3851-4...
    6299: disallowable_dr... 0.42210592 0.6496968 3c8c4ec3-d94f-4...
    6300: inconvenient_am... 0.64732120 0.8045627 dc2f7a54-6985-4...
    6301: disallowable_dr... 0.07525455 0.2743256 296b0c84-4a91-4...

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
       1: 0.20315474 0.4507269 inconvenient_am... 86a6a062-dbca-4...
       2: 0.01199813 0.1095360 disallowable_dr... b3c0ef7b-323c-4...
       3: 0.89278856 0.9448749 inconvenient_am... 233f4a3a-82ea-4...
       4: 0.36677289 0.6056178 inconvenient_am... 6b528d18-f5e7-4...
       5: 0.87446394 0.9351278 inconvenient_am... 11fc4e26-997c-4...
      ---
    6691: 0.95076004 0.9750692 inconvenient_am... a784397a-86c3-4...
    6692: 0.08622080 0.2936338 disallowable_dr... 6f5fba53-e16b-4...
    6693: 0.48026498 0.6930115 inconvenient_am... bf747ec7-c27f-4...
    6694: 0.45788606 0.6766728 disallowable_dr... 02d3fbd3-a9d7-4...
    6695: 0.69411260        NA inconvenient_am... 07a2d2b0-ce2b-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.6941126 inconvenient_am... 07a2d2b0-ce2b-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running inconvenient_am... 0.6941126 07a2d2b0-ce2b-4...        NA
       2: finished inconvenient_am... 0.2031547 86a6a062-dbca-4... 0.4507269
       3: finished inconvenient_am... 0.8927886 233f4a3a-82ea-4... 0.9448749
       4: finished inconvenient_am... 0.3667729 6b528d18-f5e7-4... 0.6056178
       5: finished inconvenient_am... 0.8744639 11fc4e26-997c-4... 0.9351278
      ---
    6691: finished disallowable_dr... 0.8560615 4b5559d9-2719-4... 0.9252359
    6692: finished inconvenient_am... 0.9507600 a784397a-86c3-4... 0.9750692
    6693: finished disallowable_dr... 0.0862208 6f5fba53-e16b-4... 0.2936338
    6694: finished inconvenient_am... 0.4802650 bf747ec7-c27f-4... 0.6930115
    6695: finished disallowable_dr... 0.4578861 02d3fbd3-a9d7-4... 0.6766728

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

    [1] 6694

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
    [1] 0.8561877


    $key
    [1] "2e1f7182-fe26-470c-b7a2-b274f7fee719"

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
