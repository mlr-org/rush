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
       1: stilllife_black... 0.495815792 0.70414188 5b1fef01-1203-4...
       2: dominating_vult... 0.981810588 0.99086356 78da2ebe-30bc-4...
       3: stilllife_black... 0.280859102 0.52996142 b0f1a349-4e36-4...
       4: dominating_vult... 0.428863080 0.65487639 f44ff0dc-6bf2-4...
       5: stilllife_black... 0.262010891 0.51186999 3a807191-51cb-4...
      ---
    6162: dominating_vult... 0.594084032 0.77076847 239fcbc8-7867-4...
    6163: dominating_vult... 0.691890963 0.83179983 18da559f-eabe-4...
    6164: stilllife_black... 0.004554999 0.06749073 ee8546c0-d8d5-4...
    6165: dominating_vult... 0.711632126 0.84358291 c3d8b036-988f-4...
    6166: stilllife_black... 0.455761238 0.67510091 31c4383e-9de1-4...

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
       1: 0.9818106 0.9908636 dominating_vult... 78da2ebe-30bc-4...
       2: 0.4958158 0.7041419 stilllife_black... 5b1fef01-1203-4...
       3: 0.2808591 0.5299614 stilllife_black... b0f1a349-4e36-4...
       4: 0.4288631 0.6548764 dominating_vult... f44ff0dc-6bf2-4...
       5: 0.2620109 0.5118700 stilllife_black... 3a807191-51cb-4...
      ---
    6578: 0.8857373 0.9411362 stilllife_black... b2772024-4da5-4...
    6579: 0.9408875 0.9699936 dominating_vult... dd23544c-e5e6-4...
    6580: 0.0824808 0.2871947 stilllife_black... 8c157e16-be83-4...
    6581: 0.1668255 0.4084428 dominating_vult... 30b34a02-b7f4-4...
    6582: 0.8645960        NA stilllife_black... e6fc28bf-fa73-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

              x          worker_id               keys
          <num>             <char>             <char>
    1: 0.864596 stilllife_black... e6fc28bf-fa73-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running stilllife_black... 0.8645960 e6fc28bf-fa73-4...        NA
       2: finished stilllife_black... 0.4958158 5b1fef01-1203-4... 0.7041419
       3: finished dominating_vult... 0.9818106 78da2ebe-30bc-4... 0.9908636
       4: finished stilllife_black... 0.2808591 b0f1a349-4e36-4... 0.5299614
       5: finished dominating_vult... 0.4288631 f44ff0dc-6bf2-4... 0.6548764
      ---
    6578: finished dominating_vult... 0.4156856 9845e169-8bfa-4... 0.6447369
    6579: finished stilllife_black... 0.8857373 b2772024-4da5-4... 0.9411362
    6580: finished dominating_vult... 0.9408875 dd23544c-e5e6-4... 0.9699936
    6581: finished stilllife_black... 0.0824808 8c157e16-be83-4... 0.2871947
    6582: finished dominating_vult... 0.1668255 30b34a02-b7f4-4... 0.4084428

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

    [1] 6581

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
    [1] 0.8696739


    $key
    [1] "7b23988a-0d7a-4a87-9d6b-0236ab768b6d"

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
