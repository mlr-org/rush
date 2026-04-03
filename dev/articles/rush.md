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
       1: incensed_mergan... 0.1093980 0.3307537 ceb1ebe1-b64b-4...
       2: incensed_mergan... 0.7747276 0.8801861 684f6c39-970e-4...
       3: incensed_mergan... 0.6021302 0.7759705 048c6361-3d2f-4...
       4: incensed_mergan... 0.5105775 0.7145471 c4b439e2-5562-4...
       5: semispheric_jav... 0.3775906 0.6144840 c58efb8d-8ed3-4...
      ---
    5868: semispheric_jav... 0.4662421 0.6828192 fa697d85-49b4-4...
    5869: incensed_mergan... 0.8897236 0.9432516 b4bc5507-b31a-4...
    5870: semispheric_jav... 0.1237372 0.3517630 f1800554-54bc-4...
    5871: incensed_mergan... 0.7771058 0.8815360 b4539c9e-2a29-4...
    5872: semispheric_jav... 0.7293147 0.8539992 1580c84b-3a47-4...

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
       1: 0.3775906 0.6144840 semispheric_jav... c58efb8d-8ed3-4...
       2: 0.1093980 0.3307537 incensed_mergan... ceb1ebe1-b64b-4...
       3: 0.7747276 0.8801861 incensed_mergan... 684f6c39-970e-4...
       4: 0.6021302 0.7759705 incensed_mergan... 048c6361-3d2f-4...
       5: 0.5105775 0.7145471 incensed_mergan... c4b439e2-5562-4...
      ---
    6239: 0.4040373 0.6356393 semispheric_jav... 5d4ca0fe-bc21-4...
    6240: 0.4497027 0.6705988 incensed_mergan... 08e13ea8-afa4-4...
    6241: 0.6575656 0.8109042 semispheric_jav... a12effa8-5ecb-4...
    6242: 0.6189069 0.7867063 incensed_mergan... 048d9ae8-16cc-4...
    6243: 0.3103346        NA semispheric_jav... 232509be-f108-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3103346 semispheric_jav... 232509be-f108-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running semispheric_jav... 0.3103346 232509be-f108-4...        NA
       2: finished incensed_mergan... 0.1093980 ceb1ebe1-b64b-4... 0.3307537
       3: finished incensed_mergan... 0.7747276 684f6c39-970e-4... 0.8801861
       4: finished incensed_mergan... 0.6021302 048c6361-3d2f-4... 0.7759705
       5: finished incensed_mergan... 0.5105775 c4b439e2-5562-4... 0.7145471
      ---
    6239: finished incensed_mergan... 0.6417066 d55c05d0-c5fe-4... 0.8010659
    6240: finished semispheric_jav... 0.4040373 5d4ca0fe-bc21-4... 0.6356393
    6241: finished incensed_mergan... 0.4497027 08e13ea8-afa4-4... 0.6705988
    6242: finished semispheric_jav... 0.6575656 a12effa8-5ecb-4... 0.8109042
    6243: finished incensed_mergan... 0.6189069 048d9ae8-16cc-4... 0.7867063

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

    [1] 6242

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
    [1] 0.9585528


    $key
    [1] "60aa5353-ea20-4aa8-99ac-1bfd0d25b4a1"

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
