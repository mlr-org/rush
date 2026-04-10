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

                   worker_id         x         y               keys
                      <char>     <num>     <num>             <char>
       1: edificial_hapuk... 0.3891178 0.6237931 e714d3fe-8f10-4...
       2: edificial_hapuk... 0.7930518 0.8905346 065abd2a-1ea4-4...
       3:         dour_stoat 0.8369184 0.9148324 2bdd8522-0807-4...
       4: edificial_hapuk... 0.9630687 0.9813606 3a4264c0-5e66-4...
       5: edificial_hapuk... 0.3444444 0.5868938 cf5560ce-76fb-4...
      ---
    6235:         dour_stoat 0.7054983 0.8399394 925cfbc6-1cb0-4...
    6236: edificial_hapuk... 0.9918042 0.9958937 fbb95aff-0350-4...
    6237:         dour_stoat 0.4574070 0.6763187 5525a3ce-0b96-4...
    6238: edificial_hapuk... 0.9865696 0.9932621 f6dad018-94de-4...
    6239:         dour_stoat 0.8181510 0.9045170 80b7c4dd-88c9-4...

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
       1: 0.3891178 0.6237931 edificial_hapuk... e714d3fe-8f10-4...
       2: 0.8369184 0.9148324         dour_stoat 2bdd8522-0807-4...
       3: 0.7930518 0.8905346 edificial_hapuk... 065abd2a-1ea4-4...
       4: 0.9630687 0.9813606 edificial_hapuk... 3a4264c0-5e66-4...
       5: 0.3444444 0.5868938 edificial_hapuk... cf5560ce-76fb-4...
      ---
    6616: 0.3714314 0.6094517 edificial_hapuk... 7fbffe51-3196-4...
    6617: 0.8969158 0.9470564         dour_stoat afbd7b3e-eea2-4...
    6618: 0.0555755 0.2357446 edificial_hapuk... 125bebc8-6f30-4...
    6619: 0.6441699 0.8026019         dour_stoat 00983361-c177-4...
    6620: 0.3421263        NA edificial_hapuk... 359be0f8-548f-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3421263 edificial_hapuk... 359be0f8-548f-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running edificial_hapuk... 0.3421263 359be0f8-548f-4...        NA
       2: finished edificial_hapuk... 0.3891178 e714d3fe-8f10-4... 0.6237931
       3: finished edificial_hapuk... 0.7930518 065abd2a-1ea4-4... 0.8905346
       4: finished         dour_stoat 0.8369184 2bdd8522-0807-4... 0.9148324
       5: finished edificial_hapuk... 0.9630687 3a4264c0-5e66-4... 0.9813606
      ---
    6616: finished         dour_stoat 0.7050136 c596bd04-9062-4... 0.8396509
    6617: finished edificial_hapuk... 0.3714314 7fbffe51-3196-4... 0.6094517
    6618: finished         dour_stoat 0.8969158 afbd7b3e-eea2-4... 0.9470564
    6619: finished edificial_hapuk... 0.0555755 125bebc8-6f30-4... 0.2357446
    6620: finished         dour_stoat 0.6441699 00983361-c177-4... 0.8026019

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

    [1] 6619

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
    [1] 0.3076274


    $key
    [1] "60218bc4-36f5-4a77-8302-ea3ddd37bcb1"

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
