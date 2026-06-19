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
       1: annoying_killde... 0.6660531 0.8161208 e4c33196-571d-4...
       2: excess_waterdra... 0.9287457 0.9637145 c19e3168-a8b3-4...
       3: annoying_killde... 0.5572180 0.7464704 b1717c6f-a9d9-4...
       4: excess_waterdra... 0.5354902 0.7317720 18934bac-72d5-4...
       5: annoying_killde... 0.5284882 0.7269719 f3f4c4e3-a8cb-4...
      ---
    6291: annoying_killde... 0.9385967 0.9688120 b6b54069-f5fb-4...
    6292: excess_waterdra... 0.3032882 0.5507161 0cfa19eb-b889-4...
    6293: annoying_killde... 0.3176211 0.5635788 4dc7e360-1130-4...
    6294: excess_waterdra... 0.2293580 0.4789134 40c22895-44d7-4...
    6295: annoying_killde... 0.8276951 0.9097775 f2767b37-37e9-4...

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
       1: 0.66605310 0.8161208 annoying_killde... e4c33196-571d-4...
       2: 0.92874573 0.9637145 excess_waterdra... c19e3168-a8b3-4...
       3: 0.55721803 0.7464704 annoying_killde... b1717c6f-a9d9-4...
       4: 0.53549020 0.7317720 excess_waterdra... 18934bac-72d5-4...
       5: 0.52848817 0.7269719 annoying_killde... f3f4c4e3-a8cb-4...
      ---
    6734: 0.73328500 0.8563206 excess_waterdra... ae4ed1aa-19f4-4...
    6735: 0.18107190 0.4255254 annoying_killde... 1e5aa539-ee6d-4...
    6736: 0.28699841 0.5357223 excess_waterdra... acc7b026-49a0-4...
    6737: 0.84115595 0.9171455 annoying_killde... 2c0a871c-1178-4...
    6738: 0.04031863 0.2007950 excess_waterdra... 7bd7e71f-e38f-4...

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
       1: finished annoying_killde... 0.66605310 0.8161208 e4c33196-571d-4...
       2: finished excess_waterdra... 0.92874573 0.9637145 c19e3168-a8b3-4...
       3: finished annoying_killde... 0.55721803 0.7464704 b1717c6f-a9d9-4...
       4: finished excess_waterdra... 0.53549020 0.7317720 18934bac-72d5-4...
       5: finished annoying_killde... 0.52848817 0.7269719 f3f4c4e3-a8cb-4...
      ---
    6734: finished excess_waterdra... 0.73328500 0.8563206 ae4ed1aa-19f4-4...
    6735: finished annoying_killde... 0.18107190 0.4255254 1e5aa539-ee6d-4...
    6736: finished excess_waterdra... 0.28699841 0.5357223 acc7b026-49a0-4...
    6737: finished annoying_killde... 0.84115595 0.9171455 2c0a871c-1178-4...
    6738: finished excess_waterdra... 0.04031863 0.2007950 7bd7e71f-e38f-4...

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

    [1] 6738

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
    [1] 0.8594568


    $key
    [1] "618c20d4-66b0-4745-9ab2-69a9e3f3fc08"

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
