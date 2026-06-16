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

                   worker_id           x          y               keys
                      <char>       <num>      <num>             <char>
       1: sourdough_plain... 0.729513104 0.85411539 0f8f95bd-af10-4...
       2: washedup_fairyb... 0.836881582 0.91481232 855f9bf5-6d74-4...
       3: washedup_fairyb... 0.947692070 0.97349477 4ef59d44-ff9b-4...
       4: sourdough_plain... 0.274312259 0.52374828 93bcaf94-b7ca-4...
       5: washedup_fairyb... 0.004675653 0.06837875 98995a73-0700-4...
      ---
    5759: washedup_fairyb... 0.041620087 0.20401002 7a9e2406-5b1d-4...
    5760: sourdough_plain... 0.944871408 0.97204496 3f46ae94-7833-4...
    5761: washedup_fairyb... 0.729391022 0.85404392 530995d3-cdc5-4...
    5762: sourdough_plain... 0.378105271 0.61490265 915200eb-7524-4...
    5763: washedup_fairyb... 0.514155888 0.71704664 cce43a4b-d87e-4...

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
       1: 0.7295131 0.8541154 sourdough_plain... 0f8f95bd-af10-4...
       2: 0.8368816 0.9148123 washedup_fairyb... 855f9bf5-6d74-4...
       3: 0.2743123 0.5237483 sourdough_plain... 93bcaf94-b7ca-4...
       4: 0.9476921 0.9734948 washedup_fairyb... 4ef59d44-ff9b-4...
       5: 0.5335399 0.7304382 sourdough_plain... a3742773-a8b3-4...
      ---
    6120: 0.7013235 0.8374506 washedup_fairyb... daae80ce-64fc-4...
    6121: 0.3083687 0.5553096 sourdough_plain... de21a105-052a-4...
    6122: 0.6328385 0.7955115 washedup_fairyb... ba24649c-04d3-4...
    6123: 0.4723712        NA sourdough_plain... 5d44de85-7502-4...
    6124: 0.7203816        NA washedup_fairyb... 0e49b09a-fbd1-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.4723712 sourdough_plain... 5d44de85-7502-4...
    2: 0.7203816 washedup_fairyb... 0e49b09a-fbd1-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running sourdough_plain... 0.4723712 5d44de85-7502-4...        NA
       2:  running washedup_fairyb... 0.7203816 0e49b09a-fbd1-4...        NA
       3: finished sourdough_plain... 0.7295131 0f8f95bd-af10-4... 0.8541154
       4: finished washedup_fairyb... 0.8368816 855f9bf5-6d74-4... 0.9148123
       5: finished washedup_fairyb... 0.9476921 4ef59d44-ff9b-4... 0.9734948
      ---
    6120: finished washedup_fairyb... 0.1695755 7eef898e-1a2c-4... 0.4117954
    6121: finished sourdough_plain... 0.3932872 5f615735-a42a-4... 0.6271261
    6122: finished washedup_fairyb... 0.7013235 daae80ce-64fc-4... 0.8374506
    6123: finished sourdough_plain... 0.3083687 de21a105-052a-4... 0.5553096
    6124: finished washedup_fairyb... 0.6328385 ba24649c-04d3-4... 0.7955115

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

    [1] 6122

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
    [1] 0.1899861


    $key
    [1] "3ef7d692-039a-4c4f-8460-42c3a88aabdd"

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
