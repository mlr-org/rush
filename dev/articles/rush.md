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
       1: boiled_sardine_... 0.7570773 0.8701019 2f5bd8d8-96fd-4...
       2: halfwitted_impe... 0.5239834 0.7238670 928da2ac-0632-4...
       3: boiled_sardine_... 0.4950305 0.7035840 d6174100-2888-4...
       4: boiled_sardine_... 0.3959649 0.6292574 b7cfd607-b4fa-4...
       5: boiled_sardine_... 0.6616153 0.8133974 7c2ab750-88a3-4...
      ---
    6147: boiled_sardine_... 0.3768896 0.6139133 f8f30952-f469-4...
    6148: halfwitted_impe... 0.9088267 0.9533240 b09b9d4e-2358-4...
    6149: boiled_sardine_... 0.1758632 0.4193605 b4d4bc2c-dda0-4...
    6150: halfwitted_impe... 0.9741136 0.9869719 348d4c78-3a2e-4...
    6151: boiled_sardine_... 0.1602382 0.4002977 949bbfa9-3b0b-4...

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
       1: 0.75707731 0.8701019 boiled_sardine_...    [NULL] 2f5bd8d8-96fd-4...
       2: 0.52398339 0.7238670 halfwitted_impe...    [NULL] 928da2ac-0632-4...
       3: 0.49503050 0.7035840 boiled_sardine_...    [NULL] d6174100-2888-4...
       4: 0.46755678 0.6837812 halfwitted_impe...    [NULL] 161db1d2-c3d6-4...
       5: 0.39596486 0.6292574 boiled_sardine_...    [NULL] b7cfd607-b4fa-4...
      ---
    6567: 0.08225595 0.2868030 halfwitted_impe...    [NULL] d6c12854-d7be-4...
    6568: 0.76151386 0.8726476 boiled_sardine_...    [NULL] 56431bff-d21e-4...
    6569: 0.88350674 0.9399504 halfwitted_impe...    [NULL] 776a76de-fee8-4...
    6570: 0.94992393 0.9746404 halfwitted_impe...    [NULL] a9a67d34-bde4-4...
    6571: 0.77799413        NA boiled_sardine_... <list[1]> bd41bd05-2d25-4...

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
    1: 0.7779941 boiled_sardine_... <list[1]> bd41bd05-2d25-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished boiled_sardine_... 0.75707731 0.8701019 2f5bd8d8-96fd-4...
       2: finished halfwitted_impe... 0.52398339 0.7238670 928da2ac-0632-4...
       3: finished boiled_sardine_... 0.49503050 0.7035840 d6174100-2888-4...
       4: finished boiled_sardine_... 0.39596486 0.6292574 b7cfd607-b4fa-4...
       5: finished boiled_sardine_... 0.66161530 0.8133974 7c2ab750-88a3-4...
      ---
    6566: finished boiled_sardine_... 0.64501966 0.8031312 9ba4ad67-e15a-4...
    6567: finished halfwitted_impe... 0.08225595 0.2868030 d6c12854-d7be-4...
    6568: finished boiled_sardine_... 0.76151386 0.8726476 56431bff-d21e-4...
    6569: finished halfwitted_impe... 0.88350674 0.9399504 776a76de-fee8-4...
    6570: finished halfwitted_impe... 0.94992393 0.9746404 a9a67d34-bde4-4...

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

    [1] 6570

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
    [1] 0.0007645539


    $key
    [1] "b231946d-927c-485f-92fb-8571a4251006"

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
