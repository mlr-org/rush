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
       1:     sketchy_duiker 0.06201210 0.2490223 8e2cd4c9-f3f6-4...
       2:     sketchy_duiker 0.52068818 0.7215873 819dff5c-64a7-4...
       3:     sketchy_duiker 0.74503120 0.8631519 ca1ffad5-b70f-4...
       4: resolvable_verd... 0.96863668 0.9841934 3f0c801c-4cb3-4...
       5:     sketchy_duiker 0.14073776 0.3751503 12c30dfa-c4cf-4...
      ---
    5723: resolvable_verd... 0.11795597 0.3434472 7a9bec5f-117d-4...
    5724:     sketchy_duiker 0.38849987 0.6232976 36757864-52d3-4...
    5725: resolvable_verd... 0.33463860 0.5784796 450318a6-a2fb-4...
    5726:     sketchy_duiker 0.08694542 0.2948651 dd84b3eb-e057-4...
    5727: resolvable_verd... 0.52156871 0.7221971 372d1ff0-4773-4...

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
       1: 0.0620121 0.2490223     sketchy_duiker 8e2cd4c9-f3f6-4...
       2: 0.9686367 0.9841934 resolvable_verd... 3f0c801c-4cb3-4...
       3: 0.5206882 0.7215873     sketchy_duiker 819dff5c-64a7-4...
       4: 0.7450312 0.8631519     sketchy_duiker ca1ffad5-b70f-4...
       5: 0.1407378 0.3751503     sketchy_duiker 12c30dfa-c4cf-4...
      ---
    6102: 0.5314239 0.7289883 resolvable_verd... 792867fe-e08a-4...
    6103: 0.2032230 0.4508027     sketchy_duiker 83f2b542-4aa3-4...
    6104: 0.1789895 0.4230715 resolvable_verd... 719045b5-e371-4...
    6105: 0.6249918 0.7905642     sketchy_duiker 7484e5d4-5899-4...
    6106: 0.1657578        NA resolvable_verd... 9a7474a5-ddad-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.1657578 resolvable_verd... 9a7474a5-ddad-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running resolvable_verd... 0.1657578 9a7474a5-ddad-4...        NA
       2: finished     sketchy_duiker 0.0620121 8e2cd4c9-f3f6-4... 0.2490223
       3: finished     sketchy_duiker 0.5206882 819dff5c-64a7-4... 0.7215873
       4: finished     sketchy_duiker 0.7450312 ca1ffad5-b70f-4... 0.8631519
       5: finished resolvable_verd... 0.9686367 3f0c801c-4cb3-4... 0.9841934
      ---
    6102: finished     sketchy_duiker 0.3288138 4456101b-ee61-4... 0.5734229
    6103: finished resolvable_verd... 0.5314239 792867fe-e08a-4... 0.7289883
    6104: finished     sketchy_duiker 0.2032230 83f2b542-4aa3-4... 0.4508027
    6105: finished resolvable_verd... 0.1789895 719045b5-e371-4... 0.4230715
    6106: finished     sketchy_duiker 0.6249918 7484e5d4-5899-4... 0.7905642

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

    [1] 6105

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
    [1] 0.9376399


    $key
    [1] "8c32fee1-00ff-4e5c-8be3-6e4426fdf7ef"

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
