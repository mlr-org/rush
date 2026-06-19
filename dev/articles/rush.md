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
       1: constuctive_tad... 0.5238830 0.7237976 684c92f0-f31d-4...
       2: constuctive_tad... 0.3283978 0.5730601 75d5317d-e2dd-4...
       3: connectible_neo... 0.8184082 0.9046592 c48efef6-6f5c-4...
       4: constuctive_tad... 0.3271275 0.5719506 9cce3ce0-c82d-4...
       5: connectible_neo... 0.4416060 0.6645344 b5ec5638-e167-4...
      ---
    6596: connectible_neo... 0.5212238 0.7219583 5d9bda9f-98db-4...
    6597: constuctive_tad... 0.5348011 0.7313010 c082defe-2fab-4...
    6598: connectible_neo... 0.4298311 0.6556151 05eca3d2-ed8f-4...
    6599: connectible_neo... 0.6558557 0.8098492 aaa1e961-573e-4...
    6600: constuctive_tad... 0.1876890 0.4332309 ce069eab-eca2-4...

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
       1: 0.5238830 0.7237976 constuctive_tad... 684c92f0-f31d-4...
       2: 0.8184082 0.9046592 connectible_neo... c48efef6-6f5c-4...
       3: 0.3283978 0.5730601 constuctive_tad... 75d5317d-e2dd-4...
       4: 0.3271275 0.5719506 constuctive_tad... 9cce3ce0-c82d-4...
       5: 0.4416060 0.6645344 connectible_neo... b5ec5638-e167-4...
      ---
    7035: 0.3732693 0.6109577 connectible_neo... a38f6c8e-9e95-4...
    7036: 0.4745529 0.6888780 constuctive_tad... 011cdca2-8b78-4...
    7037: 0.3933518 0.6271777 connectible_neo... 93328e21-6234-4...
    7038: 0.1921168        NA constuctive_tad... 9e6a0711-6a82-4...
    7039: 0.7416923        NA connectible_neo... 88d3c51a-8fb3-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.1921168 constuctive_tad... 9e6a0711-6a82-4...
    2: 0.7416923 connectible_neo... 88d3c51a-8fb3-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running constuctive_tad... 0.1921168 9e6a0711-6a82-4...        NA
       2:  running connectible_neo... 0.7416923 88d3c51a-8fb3-4...        NA
       3: finished constuctive_tad... 0.5238830 684c92f0-f31d-4... 0.7237976
       4: finished constuctive_tad... 0.3283978 75d5317d-e2dd-4... 0.5730601
       5: finished connectible_neo... 0.8184082 c48efef6-6f5c-4... 0.9046592
      ---
    7035: finished connectible_neo... 0.0972309 beb0969d-4bca-4... 0.3118187
    7036: finished constuctive_tad... 0.4929756 f9fa5402-2598-4... 0.7021222
    7037: finished connectible_neo... 0.3732693 a38f6c8e-9e95-4... 0.6109577
    7038: finished constuctive_tad... 0.4745529 011cdca2-8b78-4... 0.6888780
    7039: finished connectible_neo... 0.3933518 93328e21-6234-4... 0.6271777

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

    [1] 7037

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
    [1] 0.9320255


    $key
    [1] "0ce26157-1237-4ebe-91e4-f7d037c7e02a"

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
