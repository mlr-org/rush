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
       1: wimpy_hellbende... 0.69530488 0.8338494 3cc0fd57-cd3e-4...
       2: wimpy_hellbende... 0.79410632 0.8911264 73c916a0-c4ee-4...
       3: gunshy_danishsw... 0.03078216 0.1754485 82382dbc-3653-4...
       4: wimpy_hellbende... 0.59889844 0.7738853 cfe6e0c4-6fe1-4...
       5: gunshy_danishsw... 0.64559177 0.8034873 7df50619-a1cc-4...
      ---
    6857: wimpy_hellbende... 0.61429071 0.7837670 e834d8d4-f8b3-4...
    6858: gunshy_danishsw... 0.11885383 0.3447518 ae9c8a49-79e1-4...
    6859: wimpy_hellbende... 0.92556261 0.9620616 7df3fca4-10bd-4...
    6860: gunshy_danishsw... 0.62722937 0.7919781 3aa70ac3-bd8c-4...
    6861: wimpy_hellbende... 0.29680262 0.5447959 45bdb46d-333f-4...

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
       1: 0.69530488 0.8338494 wimpy_hellbende... 3cc0fd57-cd3e-4...
       2: 0.03078216 0.1754485 gunshy_danishsw... 82382dbc-3653-4...
       3: 0.79410632 0.8911264 wimpy_hellbende... 73c916a0-c4ee-4...
       4: 0.59889844 0.7738853 wimpy_hellbende... cfe6e0c4-6fe1-4...
       5: 0.64559177 0.8034873 gunshy_danishsw... 7df50619-a1cc-4...
      ---
    7274: 0.09426801 0.3070310 wimpy_hellbende... e17d2e60-df01-4...
    7275: 0.83572986 0.9141826 gunshy_danishsw... 87ca845f-2d43-4...
    7276: 0.03959666 0.1989891 wimpy_hellbende... 7d57b9e7-fe68-4...
    7277: 0.08387937 0.2896193 gunshy_danishsw... 2b9226a7-b6bd-4...
    7278: 0.87424958        NA gunshy_danishsw... 6b0b23ae-1fed-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.8742496 gunshy_danishsw... 6b0b23ae-1fed-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running gunshy_danishsw... 0.87424958 6b0b23ae-1fed-4...        NA
       2: finished wimpy_hellbende... 0.69530488 3cc0fd57-cd3e-4... 0.8338494
       3: finished wimpy_hellbende... 0.79410632 73c916a0-c4ee-4... 0.8911264
       4: finished gunshy_danishsw... 0.03078216 82382dbc-3653-4... 0.1754485
       5: finished wimpy_hellbende... 0.59889844 cfe6e0c4-6fe1-4... 0.7738853
      ---
    7274: finished wimpy_hellbende... 0.59940699 f1ac0748-9141-4... 0.7742138
    7275: finished gunshy_danishsw... 0.83572986 87ca845f-2d43-4... 0.9141826
    7276: finished wimpy_hellbende... 0.09426801 e17d2e60-df01-4... 0.3070310
    7277: finished wimpy_hellbende... 0.03959666 7d57b9e7-fe68-4... 0.1989891
    7278: finished gunshy_danishsw... 0.08387937 2b9226a7-b6bd-4... 0.2896193

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

    [1] 7277

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
    [1] 0.09427943


    $key
    [1] "a9713156-1b8f-44d3-a357-0315eba4bdf6"

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
