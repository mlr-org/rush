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
       1: uneducated_muss... 0.12352655 0.3514634 3ed91c19-3973-4...
       2: environmental_g... 0.65676065 0.8104077 9bde20af-dcd2-4...
       3: uneducated_muss... 0.02178153 0.1475857 67e03b94-8f6f-4...
       4: environmental_g... 0.15706948 0.3963199 eb4c90b2-875c-4...
       5: uneducated_muss... 0.37959803 0.6161153 337dd8f8-3c72-4...
      ---
    5695: uneducated_muss... 0.83218999 0.9122445 ce8a67d1-f61b-4...
    5696: environmental_g... 0.17692745 0.4206274 3c8d51a0-3042-4...
    5697: environmental_g... 0.01837614 0.1355586 407cdb00-fbee-4...
    5698: uneducated_muss... 0.97608823 0.9879718 438feb76-f05a-4...
    5699: environmental_g... 0.23494638 0.4847127 b760992c-ac9e-4...

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
       1: 0.65676065 0.8104077 environmental_g... 9bde20af-dcd2-4...
       2: 0.12352655 0.3514634 uneducated_muss... 3ed91c19-3973-4...
       3: 0.02178153 0.1475857 uneducated_muss... 67e03b94-8f6f-4...
       4: 0.15706948 0.3963199 environmental_g... eb4c90b2-875c-4...
       5: 0.37959803 0.6161153 uneducated_muss... 337dd8f8-3c72-4...
      ---
    6060: 0.62849444 0.7927764 environmental_g... 738f61d0-da1b-4...
    6061: 0.63203642 0.7950072 uneducated_muss... 9f07c04e-4ca6-4...
    6062: 0.83237822 0.9123476 environmental_g... 27866dd3-c9f7-4...
    6063: 0.03835900 0.1958545 uneducated_muss... 5ad1c0e0-a4db-4...
    6064: 0.25694487        NA environmental_g... 44d85599-dcba-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.2569449 environmental_g... 44d85599-dcba-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running environmental_g... 0.25694487 44d85599-dcba-4...        NA
       2: finished uneducated_muss... 0.12352655 3ed91c19-3973-4... 0.3514634
       3: finished environmental_g... 0.65676065 9bde20af-dcd2-4... 0.8104077
       4: finished uneducated_muss... 0.02178153 67e03b94-8f6f-4... 0.1475857
       5: finished environmental_g... 0.15706948 eb4c90b2-875c-4... 0.3963199
      ---
    6060: finished uneducated_muss... 0.08254807 3fd09d42-03f2-4... 0.2873118
    6061: finished environmental_g... 0.62849444 738f61d0-da1b-4... 0.7927764
    6062: finished uneducated_muss... 0.63203642 9f07c04e-4ca6-4... 0.7950072
    6063: finished environmental_g... 0.83237822 27866dd3-c9f7-4... 0.9123476
    6064: finished uneducated_muss... 0.03835900 5ad1c0e0-a4db-4... 0.1958545

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

    [1] 6063

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
    [1] 0.4393932


    $key
    [1] "531863a5-d138-4db5-8955-0d30519abea3"

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
