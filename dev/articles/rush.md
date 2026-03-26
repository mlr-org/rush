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
       1: welleducated_in... 0.67884731 0.8239219 5b9afb3e-85c3-4...
       2: welleducated_in... 0.85920411 0.9269326 c89ed041-4299-4...
       3: photophobic_coc... 0.86495238 0.9300282 0519c215-c868-4...
       4: welleducated_in... 0.09671071 0.3109835 6de0864e-3fd9-4...
       5: photophobic_coc... 0.79657201 0.8925088 01471e45-0db2-4...
      ---
    6282: photophobic_coc... 0.03558461 0.1886388 fc7e9d76-1e4c-4...
    6283: welleducated_in... 0.38090583 0.6171757 a7152280-57cd-4...
    6284: photophobic_coc... 0.61803390 0.7861513 59c4fbf4-ad7d-4...
    6285: welleducated_in... 0.59256097 0.7697798 83a8e3c2-15fe-4...
    6286: welleducated_in... 0.73382649 0.8566367 017729cc-d556-4...

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
       1: 0.86495238 0.9300282 photophobic_coc... 0519c215-c868-4...
       2: 0.67884731 0.8239219 welleducated_in... 5b9afb3e-85c3-4...
       3: 0.85920411 0.9269326 welleducated_in... c89ed041-4299-4...
       4: 0.09671071 0.3109835 welleducated_in... 6de0864e-3fd9-4...
       5: 0.79657201 0.8925088 photophobic_coc... 01471e45-0db2-4...
      ---
    6668: 0.52326508 0.7233706 photophobic_coc... bfab0d37-d6f8-4...
    6669: 0.18198179 0.4265932 welleducated_in... da60b00a-f7df-4...
    6670: 0.41905660 0.6473458 photophobic_coc... 3206e83f-f764-4...
    6671: 0.20150728 0.4488956 welleducated_in... cdb5bd4e-90af-4...
    6672: 0.02629261        NA photophobic_coc... a5af1ecf-b792-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

                x          worker_id               keys
            <num>             <char>             <char>
    1: 0.02629261 photophobic_coc... a5af1ecf-b792-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running photophobic_coc... 0.02629261 a5af1ecf-b792-4...        NA
       2: finished welleducated_in... 0.67884731 5b9afb3e-85c3-4... 0.8239219
       3: finished welleducated_in... 0.85920411 c89ed041-4299-4... 0.9269326
       4: finished photophobic_coc... 0.86495238 0519c215-c868-4... 0.9300282
       5: finished welleducated_in... 0.09671071 6de0864e-3fd9-4... 0.3109835
      ---
    6668: finished welleducated_in... 0.90490370 23655b93-3c25-4... 0.9512643
    6669: finished photophobic_coc... 0.52326508 bfab0d37-d6f8-4... 0.7233706
    6670: finished photophobic_coc... 0.41905660 3206e83f-f764-4... 0.6473458
    6671: finished welleducated_in... 0.18198179 da60b00a-f7df-4... 0.4265932
    6672: finished welleducated_in... 0.20150728 cdb5bd4e-90af-4... 0.4488956

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

    [1] 6671

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
    [1] 0.3797997


    $key
    [1] "c8f20225-3270-4509-91c1-126f7dc3d7ea"

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
