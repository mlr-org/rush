# rush - Quick Reference

A quick reference cheatsheet for `rush`. See the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) for a detailed
introduction.

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
       1: sepia_cooter_c8... 0.1044781 0.3232307 a28b675a-e74b-4...
       2: planispherical_... 0.8733927 0.9345548 1f1bdaea-8095-4...
       3: sepia_cooter_c8... 0.1179299 0.3434092 f701b000-de0d-4...
       4: sepia_cooter_c8... 0.6052017 0.7779471 21f71525-6823-4...
       5: sepia_cooter_c8... 0.5554222 0.7452665 f6deb5f3-8acf-4...
      ---
    9262: planispherical_... 0.6335940 0.7959862 6b713ebe-f593-4...
    9263: sepia_cooter_c8... 0.9756652 0.9877577 ecb1bfc3-b53f-4...
    9264: planispherical_... 0.3979743 0.6308521 57790e5d-e639-4...
    9265: sepia_cooter_c8... 0.2576491 0.5075914 db092889-7c13-4...
    9266: planispherical_... 0.6751113 0.8216516 63b5fcec-7e42-4...

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
       1: 0.10447806 0.3232307 sepia_cooter_c8... a28b675a-e74b-4...
       2: 0.87339269 0.9345548 planispherical_... 1f1bdaea-8095-4...
       3: 0.11792990 0.3434092 sepia_cooter_c8... f701b000-de0d-4...
       4: 0.60520165 0.7779471 sepia_cooter_c8... 21f71525-6823-4...
       5: 0.55542217 0.7452665 sepia_cooter_c8... f6deb5f3-8acf-4...
      ---
    9895: 0.04395289 0.2096494 sepia_cooter_c8... e0f4d280-cf2b-4...
    9896: 0.84056835 0.9168251 sepia_cooter_c8... b0f0437d-9ed7-4...
    9897: 0.51864834 0.7201724 planispherical_... 58d8378c-f4b9-4...
    9898: 0.26764171 0.5173410 sepia_cooter_c8... 0d78262c-24ac-4...
    9899: 0.57308201 0.7570218 planispherical_... e0aa1872-7c55-4...

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
       1: finished sepia_cooter_c8... 0.1044781 0.3232307 a28b675a-e74b-4...
       2: finished planispherical_... 0.8733927 0.9345548 1f1bdaea-8095-4...
       3: finished sepia_cooter_c8... 0.1179299 0.3434092 f701b000-de0d-4...
       4: finished sepia_cooter_c8... 0.6052017 0.7779471 21f71525-6823-4...
       5: finished sepia_cooter_c8... 0.5554222 0.7452665 f6deb5f3-8acf-4...
      ---
    9895: finished planispherical_... 0.8697150 0.9325851 39224561-b5b5-4...
    9896: finished sepia_cooter_c8... 0.8405684 0.9168251 b0f0437d-9ed7-4...
    9897: finished planispherical_... 0.5186483 0.7201724 58d8378c-f4b9-4...
    9898: finished sepia_cooter_c8... 0.2676417 0.5173410 0d78262c-24ac-4...
    9899: finished planispherical_... 0.5730820 0.7570218 e0aa1872-7c55-4...

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

    [1] 9899

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
    [1] 0.6147076


    $key
    [1] "e3991f07-0a02-4ea1-9384-fd02c94c8b04"

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
