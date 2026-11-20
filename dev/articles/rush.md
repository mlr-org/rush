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
       1: triliteral_pipi... 0.84389379 0.9186369 0672280c-ec2c-4...
       2: germlike_duckbi... 0.73717160 0.8585870 4d4fe117-5b36-4...
       3: triliteral_pipi... 0.55215211 0.7430694 8f4f946d-ca46-4...
       4: triliteral_pipi... 0.78979101 0.8887019 bb581fa8-87d8-4...
       5: triliteral_pipi... 0.19086344 0.4368792 62e9515f-c031-4...
      ---
    9649: germlike_duckbi... 0.81747068 0.9041409 2d6a0ba7-53f4-4...
    9650: triliteral_pipi... 0.46728114 0.6835797 463952d1-3f8b-4...
    9651: germlike_duckbi... 0.26198844 0.5118481 1ded177b-6941-4...
    9652: germlike_duckbi... 0.05532661 0.2352161 e3b1c814-feb2-4...
    9653: triliteral_pipi... 0.93082922 0.9647949 e03e5cf8-9b75-4...

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
        1: 0.8438938 0.9186369 triliteral_pipi...    [NULL] 0672280c-ec2c-4...
        2: 0.7371716 0.8585870 germlike_duckbi...    [NULL] 4d4fe117-5b36-4...
        3: 0.5521521 0.7430694 triliteral_pipi...    [NULL] 8f4f946d-ca46-4...
        4: 0.7897910 0.8887019 triliteral_pipi...    [NULL] bb581fa8-87d8-4...
        5: 0.1908634 0.4368792 triliteral_pipi...    [NULL] 62e9515f-c031-4...
       ---
    10312: 0.1173081 0.3425027 triliteral_pipi...    [NULL] 4a078fa5-bfa6-4...
    10313: 0.4831553 0.6950938 germlike_duckbi...    [NULL] 42f8113e-261f-4...
    10314: 0.8325054 0.9124173 triliteral_pipi...    [NULL] c8d6a71c-0ac7-4...
    10315: 0.3409497 0.5839090 germlike_duckbi...    [NULL] 158c8d71-3ed9-4...
    10316: 0.4581277        NA triliteral_pipi... <list[1]> 97d13aab-c057-4...

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
    1: 0.4581277 triliteral_pipi... <list[1]> 97d13aab-c057-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

              state          worker_id         x         y               keys
             <char>             <char>     <num>     <num>             <char>
        1: finished triliteral_pipi... 0.8438938 0.9186369 0672280c-ec2c-4...
        2: finished germlike_duckbi... 0.7371716 0.8585870 4d4fe117-5b36-4...
        3: finished triliteral_pipi... 0.5521521 0.7430694 8f4f946d-ca46-4...
        4: finished triliteral_pipi... 0.7897910 0.8887019 bb581fa8-87d8-4...
        5: finished triliteral_pipi... 0.1908634 0.4368792 62e9515f-c031-4...
       ---
    10311: finished germlike_duckbi... 0.2162693 0.4650477 322a51fc-e29e-4...
    10312: finished triliteral_pipi... 0.1173081 0.3425027 4a078fa5-bfa6-4...
    10313: finished germlike_duckbi... 0.4831553 0.6950938 42f8113e-261f-4...
    10314: finished triliteral_pipi... 0.8325054 0.9124173 c8d6a71c-0ac7-4...
    10315: finished germlike_duckbi... 0.3409497 0.5839090 158c8d71-3ed9-4...

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

    [1] 10315

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
    [1] 0.00318895


    $key
    [1] "4eaf7884-c0f0-4f16-a8e7-df180cd87a41"

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
