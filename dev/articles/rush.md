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
       1: zombified_heter... 0.33917560 0.5823878 a330847d-74b1-4...
       2: zombified_heter... 0.45842471 0.6770707 82d03d84-0081-4...
       3: zombified_heter... 0.99200077 0.9959924 45103cf3-8ee8-4...
       4: zombified_heter... 0.63826568 0.7989153 651473f6-5ddd-4...
       5: zombified_heter... 0.11460084 0.3385275 2a4b375b-017f-4...
      ---
    8041: zombified_heter... 0.11238803 0.3352432 155e350e-0962-4...
    8042:    tectonic_jackal 0.38377428 0.6194952 2ff965e4-e69f-4...
    8043: zombified_heter... 0.14866380 0.3855694 9bf6b320-1316-4...
    8044:    tectonic_jackal 0.06946905 0.2635698 26e971d0-952c-4...
    8045: zombified_heter... 0.48591227 0.6970741 ae757911-9574-4...

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
       1: 0.33917560 0.5823878 zombified_heter... a330847d-74b1-4...
       2: 0.04987283 0.2233223    tectonic_jackal 9c453df3-63ca-4...
       3: 0.45842471 0.6770707 zombified_heter... 82d03d84-0081-4...
       4: 0.99200077 0.9959924 zombified_heter... 45103cf3-8ee8-4...
       5: 0.63826568 0.7989153 zombified_heter... 651473f6-5ddd-4...
      ---
    8679: 0.48987585 0.6999113 zombified_heter... f5d50b9c-6c73-4...
    8680: 0.12104863 0.3479204    tectonic_jackal e8df4cf0-ffe9-4...
    8681: 0.03013860 0.1736047 zombified_heter... adb99b5a-d28a-4...
    8682: 0.92334577 0.9609088    tectonic_jackal 14226881-23f6-4...
    8683: 0.51179368        NA zombified_heter... 7d100687-97ef-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.5117937 zombified_heter... 7d100687-97ef-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running zombified_heter... 0.5117937 7d100687-97ef-4...        NA
       2: finished zombified_heter... 0.3391756 a330847d-74b1-4... 0.5823878
       3: finished zombified_heter... 0.4584247 82d03d84-0081-4... 0.6770707
       4: finished zombified_heter... 0.9920008 45103cf3-8ee8-4... 0.9959924
       5: finished zombified_heter... 0.6382657 651473f6-5ddd-4... 0.7989153
      ---
    8679: finished    tectonic_jackal 0.7612438 b76328b6-1294-4... 0.8724929
    8680: finished zombified_heter... 0.4898759 f5d50b9c-6c73-4... 0.6999113
    8681: finished    tectonic_jackal 0.1210486 e8df4cf0-ffe9-4... 0.3479204
    8682: finished zombified_heter... 0.0301386 adb99b5a-d28a-4... 0.1736047
    8683: finished    tectonic_jackal 0.9233458 14226881-23f6-4... 0.9609088

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

    [1] 8682

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
    [1] 0.1348551


    $key
    [1] "386473f4-e664-46c2-b89e-e47b73c87781"

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
