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
       1: ignitable_elver... 0.12794038 0.3576875 c94283c8-e7e2-4...
       2: agrostologic_ti... 0.03249436 0.1802619 d8d39dc3-0e24-4...
       3: ignitable_elver... 0.68689834 0.8287933 919cfaa8-7fbd-4...
       4: agrostologic_ti... 0.81666232 0.9036937 97e25b08-05d2-4...
       5: ignitable_elver... 0.25618450 0.5061467 b8f7a178-20e5-4...
      ---
    6519: ignitable_elver... 0.34837914 0.5902365 f315f838-721d-4...
    6520: agrostologic_ti... 0.69934889 0.8362708 35b5cc4b-82e0-4...
    6521: ignitable_elver... 0.01760375 0.1326791 4f1a5281-6dec-4...
    6522: agrostologic_ti... 0.34691015 0.5889908 e09736ce-5404-4...
    6523: ignitable_elver... 0.68360104 0.8268017 4c572828-504f-4...

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

                   x         y          worker_id condition               keys
               <num>     <num>             <char>    <list>             <char>
       1: 0.03249436 0.1802619 agrostologic_ti...    [NULL] d8d39dc3-0e24-4...
       2: 0.12794038 0.3576875 ignitable_elver...    [NULL] c94283c8-e7e2-4...
       3: 0.81666232 0.9036937 agrostologic_ti...    [NULL] 97e25b08-05d2-4...
       4: 0.68689834 0.8287933 ignitable_elver...    [NULL] 919cfaa8-7fbd-4...
       5: 0.25618450 0.5061467 ignitable_elver...    [NULL] b8f7a178-20e5-4...
      ---
    6954: 0.98757110 0.9937661 agrostologic_ti...    [NULL] 3524c91b-080b-4...
    6955: 0.17482383 0.4181194 ignitable_elver...    [NULL] 67e6867d-6cde-4...
    6956: 0.68583403 0.8281510 ignitable_elver...    [NULL] 650df2ab-c7f6-4...
    6957: 0.50401244 0.7099383 agrostologic_ti...    [NULL] e0842413-55a5-4...
    6958: 0.50928629        NA ignitable_elver... <list[1]> cddf2943-a6d6-4...

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

               x          worker_id condition               keys
           <num>             <char>    <list>             <char>
    1: 0.5092863 ignitable_elver... <list[1]> cddf2943-a6d6-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished ignitable_elver... 0.12794038 0.3576875 c94283c8-e7e2-4...
       2: finished agrostologic_ti... 0.03249436 0.1802619 d8d39dc3-0e24-4...
       3: finished ignitable_elver... 0.68689834 0.8287933 919cfaa8-7fbd-4...
       4: finished agrostologic_ti... 0.81666232 0.9036937 97e25b08-05d2-4...
       5: finished ignitable_elver... 0.25618450 0.5061467 b8f7a178-20e5-4...
      ---
    6953: finished ignitable_elver... 0.87621721 0.9360647 d96f8f7d-c905-4...
    6954: finished ignitable_elver... 0.17482383 0.4181194 67e6867d-6cde-4...
    6955: finished agrostologic_ti... 0.98757110 0.9937661 3524c91b-080b-4...
    6956: finished ignitable_elver... 0.68583403 0.8281510 650df2ab-c7f6-4...
    6957: finished agrostologic_ti... 0.50401244 0.7099383 e0842413-55a5-4...

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

    [1] 6957

``` r

rush$n_failed_tasks
```

    [1] 1

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
    [1] 0.03545567


    $key
    [1] "e688c2fb-c9dc-42ca-90b2-c4f47123fd65"

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

    Rscript -e 'rush::start_worker(network_id = "my_network", config = list(scheme = "redis", host = "127.0.0.1", port = "6379"))'

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

    character(0)

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
