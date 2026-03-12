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
       1: flatterable_kil... 0.32310387 0.5684223 a10cd551-8c2b-4...
       2: flatterable_kil... 0.72268405 0.8501083 7abe5c9e-e3e6-4...
       3: flatterable_kil... 0.71905631 0.8479719 5619cb04-b6bb-4...
       4: flatterable_kil... 0.38023804 0.6166344 2e56e83c-989f-4...
       5: flatterable_kil... 0.89990717 0.9486344 a259a9c4-2e24-4...
      ---
    6019: flatterable_kil... 0.20723628 0.4552321 00caa7b3-e1ac-4...
    6020: flatterable_kil... 0.67066217 0.8189397 3f047df6-8be3-4...
    6021: dragonish_hamme... 0.22798731 0.4774802 c91a36be-204e-4...
    6022: flatterable_kil... 0.07939991 0.2817799 6443adc9-098f-4...
    6023: dragonish_hamme... 0.29349815 0.5417547 d654e0c6-a4fc-4...

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
       1: 0.3231039 0.5684223 flatterable_kil... a10cd551-8c2b-4...
       2: 0.5178420 0.7196124 dragonish_hamme... aec4f268-b09f-4...
       3: 0.7226841 0.8501083 flatterable_kil... 7abe5c9e-e3e6-4...
       4: 0.7190563 0.8479719 flatterable_kil... 5619cb04-b6bb-4...
       5: 0.3802380 0.6166344 flatterable_kil... 2e56e83c-989f-4...
      ---
    6389: 0.6303820 0.7939660 dragonish_hamme... 5d570e4a-b850-4...
    6390: 0.8041964 0.8967700 flatterable_kil... 54dd5992-8dd7-4...
    6391: 0.6418515 0.8011564 dragonish_hamme... cd16fdb8-0a59-4...
    6392: 0.3959273 0.6292275 flatterable_kil... 8235989e-9871-4...
    6393: 0.1325882        NA dragonish_hamme... 7fbcf20b-46d7-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.1325882 dragonish_hamme... 7fbcf20b-46d7-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running dragonish_hamme... 0.1325882 7fbcf20b-46d7-4...        NA
       2: finished flatterable_kil... 0.3231039 a10cd551-8c2b-4... 0.5684223
       3: finished flatterable_kil... 0.7226841 7abe5c9e-e3e6-4... 0.8501083
       4: finished flatterable_kil... 0.7190563 5619cb04-b6bb-4... 0.8479719
       5: finished flatterable_kil... 0.3802380 2e56e83c-989f-4... 0.6166344
      ---
    6389: finished flatterable_kil... 0.5886733 9a39643b-190f-4... 0.7672505
    6390: finished dragonish_hamme... 0.6303820 5d570e4a-b850-4... 0.7939660
    6391: finished flatterable_kil... 0.8041964 54dd5992-8dd7-4... 0.8967700
    6392: finished dragonish_hamme... 0.6418515 cd16fdb8-0a59-4... 0.8011564
    6393: finished flatterable_kil... 0.3959273 8235989e-9871-4... 0.6292275

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

    [1] 6392

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
    [1] 0.1683965


    $key
    [1] "5bd1ea18-3927-46ca-a187-7cbd11fdb984"

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
