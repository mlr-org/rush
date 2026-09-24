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
       1: nonscholastical... 0.14481181 0.3805415 4519a28a-e341-4...
       2: unsolicited_kak... 0.16808257 0.4099787 eaf94505-a607-4...
       3: nonscholastical... 0.85660787 0.9255311 681cd8d5-a8e1-4...
       4: nonscholastical... 0.10821871 0.3289661 992f920c-71df-4...
       5: nonscholastical... 0.57948061 0.7612362 8b083f02-2c40-4...
      ---
    6271: nonscholastical... 0.08467371 0.2909875 31f48a0f-c9b4-4...
    6272: unsolicited_kak... 0.81392486 0.9021778 93d051ce-5f0d-4...
    6273: nonscholastical... 0.98397012 0.9919527 866dafbf-95e6-4...
    6274: unsolicited_kak... 0.55258081 0.7433578 da9e47d2-780f-4...
    6275: nonscholastical... 0.40549749 0.6367868 230d6e50-0fb3-4...

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
       1: 0.1680826 0.4099787 unsolicited_kak...    [NULL] eaf94505-a607-4...
       2: 0.1448118 0.3805415 nonscholastical...    [NULL] 4519a28a-e341-4...
       3: 0.8566079 0.9255311 nonscholastical...    [NULL] 681cd8d5-a8e1-4...
       4: 0.1082187 0.3289661 nonscholastical...    [NULL] 992f920c-71df-4...
       5: 0.5794806 0.7612362 nonscholastical...    [NULL] 8b083f02-2c40-4...
      ---
    6694: 0.7360843 0.8579536 nonscholastical...    [NULL] 54125a41-06b0-4...
    6695: 0.9017309 0.9495951 unsolicited_kak...    [NULL] 0d96af04-6054-4...
    6696: 0.6087846 0.7802465 nonscholastical...    [NULL] 14eb31f8-dc9d-4...
    6697: 0.4393553 0.6628388 unsolicited_kak...    [NULL] b487e9dd-b58e-4...
    6698: 0.8133508        NA nonscholastical... <list[1]> 42725706-5271-4...

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
    1: 0.8133508 nonscholastical... <list[1]> 42725706-5271-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished nonscholastical... 0.1448118 0.3805415 4519a28a-e341-4...
       2: finished unsolicited_kak... 0.1680826 0.4099787 eaf94505-a607-4...
       3: finished nonscholastical... 0.8566079 0.9255311 681cd8d5-a8e1-4...
       4: finished nonscholastical... 0.1082187 0.3289661 992f920c-71df-4...
       5: finished nonscholastical... 0.5794806 0.7612362 8b083f02-2c40-4...
      ---
    6693: finished nonscholastical... 0.9463692 0.9728151 b94dbd9c-aec7-4...
    6694: finished nonscholastical... 0.7360843 0.8579536 54125a41-06b0-4...
    6695: finished unsolicited_kak... 0.9017309 0.9495951 0d96af04-6054-4...
    6696: finished nonscholastical... 0.6087846 0.7802465 14eb31f8-dc9d-4...
    6697: finished unsolicited_kak... 0.4393553 0.6628388 b487e9dd-b58e-4...

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

    [1] 6697

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
    [1] 0.6949151


    $key
    [1] "6cc90283-4f6a-4f6e-8fa6-db63d8cd69ca"

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
