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
       1: metallographica... 0.06316454 0.2513256 1af5a927-0c44-4...
       2: pseudoinsane_xe... 0.04345684 0.2084630 02f8af54-2974-4...
       3: pseudoinsane_xe... 0.72836313 0.8534419 6ecd4fd7-19f7-4...
       4: metallographica... 0.12428562 0.3525417 88289ade-8e00-4...
       5: metallographica... 0.69872713 0.8358990 cc303f2b-f731-4...
      ---
    7142: metallographica... 0.92913771 0.9639179 7b29b45d-ae38-4...
    7143: pseudoinsane_xe... 0.21745205 0.4663175 073fd229-314f-4...
    7144: metallographica... 0.87689907 0.9364289 92b31ae1-18ec-4...
    7145: pseudoinsane_xe... 0.84476084 0.9191087 dececfe5-e8a3-4...
    7146: metallographica... 0.68557738 0.8279960 6ab47808-55be-4...

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
       1: 0.06316454 0.2513256 metallographica... 1af5a927-0c44-4...
       2: 0.04345684 0.2084630 pseudoinsane_xe... 02f8af54-2974-4...
       3: 0.12428562 0.3525417 metallographica... 88289ade-8e00-4...
       4: 0.72836313 0.8534419 pseudoinsane_xe... 6ecd4fd7-19f7-4...
       5: 0.84157295 0.9173729 pseudoinsane_xe... 8eda54b4-1734-4...
      ---
    7641: 0.15178834 0.3896002 pseudoinsane_xe... 3a88a969-31ed-4...
    7642: 0.18991778 0.4357956 metallographica... 9e1a9385-c560-4...
    7643: 0.99085190 0.9954154 pseudoinsane_xe... fd8c6749-d519-4...
    7644: 0.72218708        NA metallographica... 7322e71d-00e1-4...
    7645: 0.63753725        NA pseudoinsane_xe... 0c967473-2a65-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.7221871 metallographica... 7322e71d-00e1-4...
    2: 0.6375373 pseudoinsane_xe... 0c967473-2a65-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running metallographica... 0.72218708 7322e71d-00e1-4...        NA
       2:  running pseudoinsane_xe... 0.63753725 0c967473-2a65-4...        NA
       3: finished metallographica... 0.06316454 1af5a927-0c44-4... 0.2513256
       4: finished pseudoinsane_xe... 0.04345684 02f8af54-2974-4... 0.2084630
       5: finished pseudoinsane_xe... 0.72836313 6ecd4fd7-19f7-4... 0.8534419
      ---
    7641: finished pseudoinsane_xe... 0.22348420 652e2efb-eb30-4... 0.4727412
    7642: finished metallographica... 0.38625270 c073348e-ead5-4... 0.6214923
    7643: finished pseudoinsane_xe... 0.15178834 3a88a969-31ed-4... 0.3896002
    7644: finished metallographica... 0.18991778 9e1a9385-c560-4... 0.4357956
    7645: finished pseudoinsane_xe... 0.99085190 fd8c6749-d519-4... 0.9954154

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

    [1] 7643

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
    [1] 0.1854594


    $key
    [1] "8c21af22-a4b5-4bf9-a76b-c25c2dd7abff"

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
