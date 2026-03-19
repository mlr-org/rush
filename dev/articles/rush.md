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

                   worker_id           x          y               keys
                      <char>       <num>      <num>             <char>
       1: veryveryveryblu... 0.378145825 0.61493563 5ed6f0ad-3dd6-4...
       2: veryveryveryblu... 0.935713160 0.96732268 8921c1d2-205e-4...
       3: veryveryveryblu... 0.607708397 0.77955654 e7bc62e3-0e6c-4...
       4: renderable_flam... 0.906368561 0.95203391 7f4222a9-c996-4...
       5: veryveryveryblu... 0.896021320 0.94658403 84a34d30-3d5a-4...
      ---
    6242: veryveryveryblu... 0.223923863 0.47320594 8ca767d3-53c8-4...
    6243: renderable_flam... 0.224989517 0.47433060 367934d4-7a18-4...
    6244: veryveryveryblu... 0.392739617 0.62668941 88c7b3d6-70c4-4...
    6245: renderable_flam... 0.008298684 0.09109711 a0fc5764-dab8-4...
    6246: veryveryveryblu... 0.981783843 0.99085006 e20bb0fd-5754-4...

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
       1: 0.3781458 0.6149356 veryveryveryblu... 5ed6f0ad-3dd6-4...
       2: 0.9063686 0.9520339 renderable_flam... 7f4222a9-c996-4...
       3: 0.9357132 0.9673227 veryveryveryblu... 8921c1d2-205e-4...
       4: 0.6077084 0.7795565 veryveryveryblu... e7bc62e3-0e6c-4...
       5: 0.8960213 0.9465840 veryveryveryblu... 84a34d30-3d5a-4...
      ---
    6620: 0.2539474 0.5039319 veryveryveryblu... 2d233a04-97e5-4...
    6621: 0.7121231 0.8438739 renderable_flam... ddb6c0dc-108a-4...
    6622: 0.5003313 0.7073410 veryveryveryblu... 8c814e7e-65eb-4...
    6623: 0.4837936 0.6955528 renderable_flam... f34e5177-9279-4...
    6624: 0.7302348        NA veryveryveryblu... 0372edbb-a865-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.7302348 veryveryveryblu... 0372edbb-a865-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running veryveryveryblu... 0.7302348 0372edbb-a865-4...        NA
       2: finished veryveryveryblu... 0.3781458 5ed6f0ad-3dd6-4... 0.6149356
       3: finished veryveryveryblu... 0.9357132 8921c1d2-205e-4... 0.9673227
       4: finished veryveryveryblu... 0.6077084 e7bc62e3-0e6c-4... 0.7795565
       5: finished renderable_flam... 0.9063686 7f4222a9-c996-4... 0.9520339
      ---
    6620: finished renderable_flam... 0.5001089 4e53b035-9829-4... 0.7071838
    6621: finished veryveryveryblu... 0.2539474 2d233a04-97e5-4... 0.5039319
    6622: finished renderable_flam... 0.7121231 ddb6c0dc-108a-4... 0.8438739
    6623: finished veryveryveryblu... 0.5003313 8c814e7e-65eb-4... 0.7073410
    6624: finished renderable_flam... 0.4837936 f34e5177-9279-4... 0.6955528

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

    [1] 6623

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
    [1] 0.8919982


    $key
    [1] "861e88b0-f3de-4497-b115-3c4284a0bd71"

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
