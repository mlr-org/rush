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
       1:     pious_javalina 0.05644071 0.2375725 b0ac8acf-90ab-4...
       2:     pious_javalina 0.37748732 0.6144000 afee1516-2c8d-4...
       3: refertilizable_... 0.54254549 0.7365769 ab3c7f2f-aa56-4...
       4:     pious_javalina 0.09793096 0.3129392 66bdc77d-6300-4...
       5:     pious_javalina 0.08389804 0.2896516 98862376-fc5a-4...
      ---
    6144: refertilizable_... 0.14586618 0.3819243 6d218375-cfa7-4...
    6145: refertilizable_... 0.05851080 0.2418901 e9ae4e70-3e8f-4...
    6146:     pious_javalina 0.22472715 0.4740539 6a8aeb76-18c0-4...
    6147:     pious_javalina 0.45870297 0.6772761 6f9de676-dc02-4...
    6148: refertilizable_... 0.30819234 0.5551507 cfa6eb6a-5454-4...

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
       1: 0.05644071 0.2375725     pious_javalina b0ac8acf-90ab-4...
       2: 0.54254549 0.7365769 refertilizable_... ab3c7f2f-aa56-4...
       3: 0.37748732 0.6144000     pious_javalina afee1516-2c8d-4...
       4: 0.09793096 0.3129392     pious_javalina 66bdc77d-6300-4...
       5: 0.24997420 0.4999742 refertilizable_... e21f93e1-301f-4...
      ---
    6572: 0.36146778 0.6012219 refertilizable_... 5ddc73cb-4f50-4...
    6573: 0.72540546 0.8517074     pious_javalina 117ae1ee-e4e0-4...
    6574: 0.93002221 0.9643766 refertilizable_... 007aae54-b030-4...
    6575: 0.31487188 0.5611345     pious_javalina c86f311f-cbef-4...
    6576: 0.77378353 0.8796497 refertilizable_... d62fd7be-e468-4...

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
       1: finished     pious_javalina 0.05644071 0.2375725 b0ac8acf-90ab-4...
       2: finished     pious_javalina 0.37748732 0.6144000 afee1516-2c8d-4...
       3: finished refertilizable_... 0.54254549 0.7365769 ab3c7f2f-aa56-4...
       4: finished     pious_javalina 0.09793096 0.3129392 66bdc77d-6300-4...
       5: finished     pious_javalina 0.08389804 0.2896516 98862376-fc5a-4...
      ---
    6572: finished refertilizable_... 0.36146778 0.6012219 5ddc73cb-4f50-4...
    6573: finished     pious_javalina 0.72540546 0.8517074 117ae1ee-e4e0-4...
    6574: finished refertilizable_... 0.93002221 0.9643766 007aae54-b030-4...
    6575: finished     pious_javalina 0.31487188 0.5611345 c86f311f-cbef-4...
    6576: finished refertilizable_... 0.77378353 0.8796497 d62fd7be-e468-4...

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

    [1] 6576

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
    [1] 0.4295819


    $key
    [1] "8296a4bd-e86b-454c-9379-f5669664650b"

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
