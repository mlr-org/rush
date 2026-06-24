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
       1: hairraising_gal... 0.15456399 0.3931463 a3b032aa-2259-4...
       2: anatomical_asia... 0.99238442 0.9961849 9ce2102a-c75f-4...
       3: hairraising_gal... 0.94225882 0.9707002 0fcb1d74-52d0-4...
       4: hairraising_gal... 0.04858090 0.2204108 cec4ed09-3c16-4...
       5: anatomical_asia... 0.40991558 0.6402465 05aaf294-cd9b-4...
      ---
    6366: hairraising_gal... 0.54717476 0.7397126 85e60110-72e1-4...
    6367: anatomical_asia... 0.06355413 0.2520995 4cd4c2a6-334a-4...
    6368: hairraising_gal... 0.90609585 0.9518907 0c3beacd-f666-4...
    6369: anatomical_asia... 0.61463355 0.7839857 6a2e8bbb-5b9c-4...
    6370: hairraising_gal... 0.94872947 0.9740274 18e880f2-cb55-4...

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
       1: 0.15456399 0.3931463 hairraising_gal... a3b032aa-2259-4...
       2: 0.99238442 0.9961849 anatomical_asia... 9ce2102a-c75f-4...
       3: 0.94225882 0.9707002 hairraising_gal... 0fcb1d74-52d0-4...
       4: 0.04858090 0.2204108 hairraising_gal... cec4ed09-3c16-4...
       5: 0.40991558 0.6402465 anatomical_asia... 05aaf294-cd9b-4...
      ---
    6800: 0.82749732 0.9096688 anatomical_asia... d144b997-b8f9-4...
    6801: 0.83254382 0.9124384 hairraising_gal... 23e2d15d-d048-4...
    6802: 0.36952962 0.6078895 anatomical_asia... b5a588c8-c8b8-4...
    6803: 0.48930798        NA hairraising_gal... 156bab77-1a08-4...
    6804: 0.03124999        NA anatomical_asia... dc6aa588-bce8-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

                x          worker_id               keys
            <num>             <char>             <char>
    1: 0.48930798 hairraising_gal... 156bab77-1a08-4...
    2: 0.03124999 anatomical_asia... dc6aa588-bce8-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running hairraising_gal... 0.48930798 156bab77-1a08-4...        NA
       2:  running anatomical_asia... 0.03124999 dc6aa588-bce8-4...        NA
       3: finished hairraising_gal... 0.15456399 a3b032aa-2259-4... 0.3931463
       4: finished anatomical_asia... 0.99238442 9ce2102a-c75f-4... 0.9961849
       5: finished hairraising_gal... 0.94225882 0fcb1d74-52d0-4... 0.9707002
      ---
    6800: finished anatomical_asia... 0.75305247 a4cfe999-f665-4... 0.8677860
    6801: finished hairraising_gal... 0.28851475 d97b7de1-4b0c-4... 0.5371357
    6802: finished anatomical_asia... 0.82749732 d144b997-b8f9-4... 0.9096688
    6803: finished hairraising_gal... 0.83254382 23e2d15d-d048-4... 0.9124384
    6804: finished anatomical_asia... 0.36952962 b5a588c8-c8b8-4... 0.6078895

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

    [1] 6802

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
    [1] 0.6030887


    $key
    [1] "89e5c013-98f8-4cc5-893e-ee23a67a5c2a"

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
