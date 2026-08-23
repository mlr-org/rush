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
        1: foreknowable_ge... 0.35629290 0.5969028 ed698d95-67f4-4...
        2: bilingual_marte... 0.74539808 0.8633644 476bd951-2707-4...
        3: foreknowable_ge... 0.95378763 0.9766205 1eb23b5b-d5d8-4...
        4: foreknowable_ge... 0.78117446 0.8838407 cfc2dc7e-910f-4...
        5: foreknowable_ge... 0.47160358 0.6867340 dd3d2afc-11ba-4...
       ---
    12607: foreknowable_ge... 0.09468282 0.3077057 6bc0f0e5-32b0-4...
    12608: bilingual_marte... 0.54653642 0.7392810 36ec6e2b-8113-4...
    12609: foreknowable_ge... 0.07106691 0.2665838 f049fdc1-d19e-4...
    12610: bilingual_marte... 0.47951392 0.6924694 34609f88-6d03-4...
    12611: foreknowable_ge... 0.27883306 0.5280465 4040d90a-4c55-4...

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
        1: 0.3562929 0.5969028 foreknowable_ge... ed698d95-67f4-4...
        2: 0.7453981 0.8633644 bilingual_marte... 476bd951-2707-4...
        3: 0.9537876 0.9766205 foreknowable_ge... 1eb23b5b-d5d8-4...
        4: 0.6028024 0.7764035 bilingual_marte... a63144cb-ad7a-4...
        5: 0.7811745 0.8838407 foreknowable_ge... cfc2dc7e-910f-4...
       ---
    13586: 0.9219815 0.9601987 bilingual_marte... 0a180a78-5bdc-4...
    13587: 0.8354342 0.9140209 foreknowable_ge... 54ec1efa-b7b9-4...
    13588: 0.4219639 0.6495875 bilingual_marte... 081d46d6-bafc-4...
    13589: 0.9462771 0.9727677 foreknowable_ge... 4d5dcdfd-a76e-4...
    13590: 0.5599417 0.7482925 bilingual_marte... 554d9ff5-2582-4...

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

              state          worker_id         x         y               keys
             <char>             <char>     <num>     <num>             <char>
        1: finished foreknowable_ge... 0.3562929 0.5969028 ed698d95-67f4-4...
        2: finished bilingual_marte... 0.7453981 0.8633644 476bd951-2707-4...
        3: finished foreknowable_ge... 0.9537876 0.9766205 1eb23b5b-d5d8-4...
        4: finished foreknowable_ge... 0.7811745 0.8838407 cfc2dc7e-910f-4...
        5: finished foreknowable_ge... 0.4716036 0.6867340 dd3d2afc-11ba-4...
       ---
    13586: finished bilingual_marte... 0.9219815 0.9601987 0a180a78-5bdc-4...
    13587: finished foreknowable_ge... 0.8354342 0.9140209 54ec1efa-b7b9-4...
    13588: finished bilingual_marte... 0.4219639 0.6495875 081d46d6-bafc-4...
    13589: finished bilingual_marte... 0.5599417 0.7482925 554d9ff5-2582-4...
    13590: finished foreknowable_ge... 0.9462771 0.9727677 4d5dcdfd-a76e-4...

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

    [1] 13590

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
    [1] 0.8579035


    $key
    [1] "a8ee5f99-d5de-4c46-a19a-1e8b341708f3"

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
