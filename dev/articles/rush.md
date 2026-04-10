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
       1:      wrinkled_buck 0.7859930 0.8865624 c0407368-37db-4...
       2:      wrinkled_buck 0.1977121 0.4446483 5ca57f92-c791-4...
       3: highlyexplosive... 0.1542799 0.3927848 08de221e-e15a-4...
       4:      wrinkled_buck 0.2334234 0.4831391 73353c0b-b839-4...
       5: highlyexplosive... 0.9750735 0.9874581 3918934d-637b-4...
      ---
    5884: highlyexplosive... 0.7488225 0.8653453 7d8af505-54da-4...
    5885: highlyexplosive... 0.3466241 0.5887479 1ba3d2e9-1aec-4...
    5886:      wrinkled_buck 0.9942554 0.9971235 bcef597e-3db3-4...
    5887:      wrinkled_buck 0.7948857 0.8915636 5cd38887-441d-4...
    5888: highlyexplosive... 0.7372914 0.8586567 e37677a9-6747-4...

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
       1: 0.7859930 0.8865624      wrinkled_buck c0407368-37db-4...
       2: 0.1542799 0.3927848 highlyexplosive... 08de221e-e15a-4...
       3: 0.1977121 0.4446483      wrinkled_buck 5ca57f92-c791-4...
       4: 0.2334234 0.4831391      wrinkled_buck 73353c0b-b839-4...
       5: 0.9750735 0.9874581 highlyexplosive... 3918934d-637b-4...
      ---
    6264: 0.9079431 0.9528605 highlyexplosive... c0d22756-66d1-4...
    6265: 0.9208731 0.9596213      wrinkled_buck 9a660918-7e01-4...
    6266: 0.6240585 0.7899737 highlyexplosive... 0c011169-647e-4...
    6267: 0.8577035        NA      wrinkled_buck 5964e9bf-715a-4...
    6268: 0.2637614        NA highlyexplosive... 6deb3c2d-79e9-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.8577035      wrinkled_buck 5964e9bf-715a-4...
    2: 0.2637614 highlyexplosive... 6deb3c2d-79e9-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running      wrinkled_buck 0.8577035 5964e9bf-715a-4...        NA
       2:  running highlyexplosive... 0.2637614 6deb3c2d-79e9-4...        NA
       3: finished      wrinkled_buck 0.7859930 c0407368-37db-4... 0.8865624
       4: finished      wrinkled_buck 0.1977121 5ca57f92-c791-4... 0.4446483
       5: finished highlyexplosive... 0.1542799 08de221e-e15a-4... 0.3927848
      ---
    6264: finished highlyexplosive... 0.8996908 c610c03c-fea1-4... 0.9485203
    6265: finished      wrinkled_buck 0.6055053 69f6aa29-60fa-4... 0.7781422
    6266: finished highlyexplosive... 0.9079431 c0d22756-66d1-4... 0.9528605
    6267: finished      wrinkled_buck 0.9208731 9a660918-7e01-4... 0.9596213
    6268: finished highlyexplosive... 0.6240585 0c011169-647e-4... 0.7899737

## Task Counts

``` r
rush$n_queued_tasks
```

    [1] 0

``` r
rush$n_running_tasks
```

    [1] 2

``` r
rush$n_finished_tasks
```

    [1] 6266

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
    [1] 0.7494785


    $key
    [1] "1f4ad169-3aab-49e1-a96d-fb98ff4a0ba0"

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
