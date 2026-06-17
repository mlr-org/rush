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
       1:     ketonic_hoopoe 0.3851759 0.6206254 dad416c2-ff29-4...
       2:     ketonic_hoopoe 0.5654938 0.7519932 d1cba198-cea3-4...
       3:     ketonic_hoopoe 0.1297749 0.3602429 af656b83-bc12-4...
       4:     ketonic_hoopoe 0.7208498 0.8490288 2180b640-8d11-4...
       5:     ketonic_hoopoe 0.4066428 0.6376855 c58cecc1-ed26-4...
      ---
    7218:     ketonic_hoopoe 0.3618546 0.6015435 62a9efe3-8a02-4...
    7219: precarnival_afr... 0.7876710 0.8875083 345e0c1a-ff9c-4...
    7220:     ketonic_hoopoe 0.2734345 0.5229097 5ed994f2-c033-4...
    7221: precarnival_afr... 0.7368663 0.8584091 323f4bb5-4b70-4...
    7222:     ketonic_hoopoe 0.9507351 0.9750564 348cff9b-97be-4...

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
       1: 0.38517586 0.6206254     ketonic_hoopoe dad416c2-ff29-4...
       2: 0.33042202 0.5748235 precarnival_afr... b4f1a472-d0b4-4...
       3: 0.56549380 0.7519932     ketonic_hoopoe d1cba198-cea3-4...
       4: 0.12977495 0.3602429     ketonic_hoopoe af656b83-bc12-4...
       5: 0.72084982 0.8490288     ketonic_hoopoe 2180b640-8d11-4...
      ---
    7718: 0.66814111 0.8173990 precarnival_afr... 246e7705-fc7e-4...
    7719: 0.65574775 0.8097825     ketonic_hoopoe caf53a0e-79fa-4...
    7720: 0.02832562 0.1683022 precarnival_afr... 2dba4a2e-413f-4...
    7721: 0.28473496 0.5336056     ketonic_hoopoe 1dcffc94-5e22-4...
    7722: 0.49002723        NA precarnival_afr... ab221c99-07df-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.4900272 precarnival_afr... ab221c99-07df-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running precarnival_afr... 0.49002723 ab221c99-07df-4...        NA
       2: finished     ketonic_hoopoe 0.38517586 dad416c2-ff29-4... 0.6206254
       3: finished     ketonic_hoopoe 0.56549380 d1cba198-cea3-4... 0.7519932
       4: finished     ketonic_hoopoe 0.12977495 af656b83-bc12-4... 0.3602429
       5: finished     ketonic_hoopoe 0.72084982 2180b640-8d11-4... 0.8490288
      ---
    7718: finished     ketonic_hoopoe 0.56033880 712a6a78-e237-4... 0.7485578
    7719: finished precarnival_afr... 0.66814111 246e7705-fc7e-4... 0.8173990
    7720: finished     ketonic_hoopoe 0.65574775 caf53a0e-79fa-4... 0.8097825
    7721: finished precarnival_afr... 0.02832562 2dba4a2e-413f-4... 0.1683022
    7722: finished     ketonic_hoopoe 0.28473496 1dcffc94-5e22-4... 0.5336056

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

    [1] 7721

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
    [1] 0.1845962


    $key
    [1] "11a07820-c3e3-45f4-9828-2f04a8f005fa"

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
