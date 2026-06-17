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
        1: antigorite_gees... 0.77100505 0.8780689 4df0d157-1b43-4...
        2: antigorite_gees... 0.59791615 0.7732504 38394f40-71e5-4...
        3: antigorite_gees... 0.90737629 0.9525630 286c9193-32f5-4...
        4:    sizeable_isopod 0.86960777 0.9325276 6532b4ed-f09c-4...
        5: antigorite_gees... 0.55307359 0.7436892 60c14eb1-d426-4...
       ---
    13284: antigorite_gees... 0.78757124 0.8874521 4f304fd6-7e53-4...
    13285:    sizeable_isopod 0.04900082 0.2213613 709ffaf5-1670-4...
    13286: antigorite_gees... 0.66063326 0.8127935 aad5153c-9998-4...
    13287:    sizeable_isopod 0.82421923 0.9078652 531b2c09-9125-4...
    13288: antigorite_gees... 0.46083610 0.6788491 ab5a6414-1448-4...

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
        1: 0.7710050 0.8780689 antigorite_gees... 4df0d157-1b43-4...
        2: 0.8696078 0.9325276    sizeable_isopod 6532b4ed-f09c-4...
        3: 0.5979162 0.7732504 antigorite_gees... 38394f40-71e5-4...
        4: 0.9073763 0.9525630 antigorite_gees... 286c9193-32f5-4...
        5: 0.5530736 0.7436892 antigorite_gees... 60c14eb1-d426-4...
       ---
    14325: 0.1026166 0.3203383 antigorite_gees... 18883aeb-88bf-4...
    14326: 0.1143660 0.3381804    sizeable_isopod 695df35e-f97e-4...
    14327: 0.9456117 0.9724257 antigorite_gees... d97a467f-7ef6-4...
    14328: 0.8122558 0.9012524    sizeable_isopod 9ee77c05-1bba-4...
    14329: 0.8060996        NA    sizeable_isopod 70ca2648-4aa8-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x       worker_id               keys
           <num>          <char>             <char>
    1: 0.8060996 sizeable_isopod 70ca2648-4aa8-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

              state          worker_id         x               keys         y
             <char>             <char>     <num>             <char>     <num>
        1:  running    sizeable_isopod 0.8060996 70ca2648-4aa8-4...        NA
        2: finished antigorite_gees... 0.7710050 4df0d157-1b43-4... 0.8780689
        3: finished antigorite_gees... 0.5979162 38394f40-71e5-4... 0.7732504
        4: finished antigorite_gees... 0.9073763 286c9193-32f5-4... 0.9525630
        5: finished    sizeable_isopod 0.8696078 6532b4ed-f09c-4... 0.9325276
       ---
    14325: finished    sizeable_isopod 0.4261061 03a0277c-5565-4... 0.6527680
    14326: finished antigorite_gees... 0.1026166 18883aeb-88bf-4... 0.3203383
    14327: finished    sizeable_isopod 0.1143660 695df35e-f97e-4... 0.3381804
    14328: finished antigorite_gees... 0.9456117 d97a467f-7ef6-4... 0.9724257
    14329: finished    sizeable_isopod 0.8122558 9ee77c05-1bba-4... 0.9012524

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

    [1] 14328

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
    [1] 0.3733696


    $key
    [1] "992e103f-010b-4b72-bf53-8866b3be871a"

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
