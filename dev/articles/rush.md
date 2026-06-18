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
       1: followable_foxh... 0.8174971 0.9041554 214949de-3d69-4...
       2: followable_foxh... 0.8675363 0.9314163 0e2d7767-ae23-4...
       3: temporary_dorki... 0.9475718 0.9734330 fd5c69b3-89b3-4...
       4: followable_foxh... 0.8894015 0.9430809 ed5abee9-a406-4...
       5: temporary_dorki... 0.7113784 0.8434325 b7bce951-b1ab-4...
      ---
    7213: followable_foxh... 0.7918468 0.8898578 49ba09a4-a588-4...
    7214: followable_foxh... 0.3983847 0.6311773 b390d6e5-1c79-4...
    7215: temporary_dorki... 0.1516791 0.3894600 a66d0dc2-2ec8-4...
    7216: followable_foxh... 0.5126777 0.7160151 db39d799-4622-4...
    7217: temporary_dorki... 0.8394548 0.9162176 a5d93baf-e551-4...

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

                  x          y          worker_id               keys
              <num>      <num>             <char>             <char>
       1: 0.8174971 0.90415544 followable_foxh... 214949de-3d69-4...
       2: 0.9475718 0.97343298 temporary_dorki... fd5c69b3-89b3-4...
       3: 0.8675363 0.93141631 followable_foxh... 0e2d7767-ae23-4...
       4: 0.8894015 0.94308088 followable_foxh... ed5abee9-a406-4...
       5: 0.7113784 0.84343253 temporary_dorki... b7bce951-b1ab-4...
      ---
    7695: 0.6841100 0.82710944 temporary_dorki... 6fda0f3e-d56f-4...
    7696: 0.0066793 0.08172698 followable_foxh... a9190e7a-3e86-4...
    7697: 0.2663731 0.51611341 temporary_dorki... 11fd393c-4072-4...
    7698: 0.2162307         NA followable_foxh... c13ff4c9-9be4-4...
    7699: 0.5717303         NA temporary_dorki... 48e2c661-45ee-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.2162307 followable_foxh... c13ff4c9-9be4-4...
    2: 0.5717303 temporary_dorki... 48e2c661-45ee-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys          y
            <char>             <char>     <num>             <char>      <num>
       1:  running followable_foxh... 0.2162307 c13ff4c9-9be4-4...         NA
       2:  running temporary_dorki... 0.5717303 48e2c661-45ee-4...         NA
       3: finished followable_foxh... 0.8174971 214949de-3d69-4... 0.90415544
       4: finished followable_foxh... 0.8675363 0e2d7767-ae23-4... 0.93141631
       5: finished temporary_dorki... 0.9475718 fd5c69b3-89b3-4... 0.97343298
      ---
    7695: finished temporary_dorki... 0.6729911 e476c801-793e-4... 0.82036038
    7696: finished followable_foxh... 0.6620982 20c0711b-cb34-4... 0.81369420
    7697: finished temporary_dorki... 0.6841100 6fda0f3e-d56f-4... 0.82710944
    7698: finished followable_foxh... 0.0066793 a9190e7a-3e86-4... 0.08172698
    7699: finished temporary_dorki... 0.2663731 11fd393c-4072-4... 0.51611341

## Task Counts

``` r

rush$n_queued_tasks
```

    [1] 0

``` r

rush$n_running_tasks
```

    [1] 2

``` r

rush$n_finished_tasks
```

    [1] 7697

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
    [1] 0.389783


    $key
    [1] "33ea0916-d0a0-430a-b5b0-facc6b208dcc"

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
