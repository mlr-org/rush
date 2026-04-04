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
       1: wakeful_amethys... 0.1508612 0.3884086 e663b49a-ad1a-4...
       2: wakeful_amethys... 0.2161227 0.4648900 6e337597-0b90-4...
       3: wakeful_amethys... 0.9206323 0.9594959 acd6508d-df24-4...
       4: wakeful_amethys... 0.5377901 0.7333417 a506e13f-d804-4...
       5: pediophobic_bai... 0.3677968 0.6064626 c4a2d57a-2a55-4...
      ---
    6030: wakeful_amethys... 0.3265871 0.5714780 7ba1f0a3-7ab4-4...
    6031: pediophobic_bai... 0.4401831 0.6634630 8f3aabbe-da59-4...
    6032: wakeful_amethys... 0.8855411 0.9410319 42120247-045a-4...
    6033: pediophobic_bai... 0.9481609 0.9737356 f475b05f-4aec-4...
    6034: wakeful_amethys... 0.4353374 0.6598010 57f78436-f41b-4...

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
       1: 0.1508612 0.3884086 wakeful_amethys... e663b49a-ad1a-4...
       2: 0.3677968 0.6064626 pediophobic_bai... c4a2d57a-2a55-4...
       3: 0.2161227 0.4648900 wakeful_amethys... 6e337597-0b90-4...
       4: 0.9206323 0.9594959 wakeful_amethys... acd6508d-df24-4...
       5: 0.5377901 0.7333417 wakeful_amethys... a506e13f-d804-4...
      ---
    6413: 0.2820424 0.5310766 wakeful_amethys... 76acfbe6-4bc1-4...
    6414: 0.7079486 0.8413968 pediophobic_bai... 2c9f9ccd-c911-4...
    6415: 0.6645669 0.8152097 wakeful_amethys... 98d81fc6-ec71-4...
    6416: 0.2485594 0.4985573 pediophobic_bai... 6cb66aed-f81b-4...
    6417: 0.8014730        NA wakeful_amethys... 1d6d8d51-3e74-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

              x          worker_id               keys
          <num>             <char>             <char>
    1: 0.801473 wakeful_amethys... 1d6d8d51-3e74-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running wakeful_amethys... 0.8014730 1d6d8d51-3e74-4...        NA
       2: finished wakeful_amethys... 0.1508612 e663b49a-ad1a-4... 0.3884086
       3: finished wakeful_amethys... 0.2161227 6e337597-0b90-4... 0.4648900
       4: finished wakeful_amethys... 0.9206323 acd6508d-df24-4... 0.9594959
       5: finished wakeful_amethys... 0.5377901 a506e13f-d804-4... 0.7333417
      ---
    6413: finished pediophobic_bai... 0.4358341 1c7ac2df-0be4-4... 0.6601773
    6414: finished wakeful_amethys... 0.2820424 76acfbe6-4bc1-4... 0.5310766
    6415: finished pediophobic_bai... 0.7079486 2c9f9ccd-c911-4... 0.8413968
    6416: finished wakeful_amethys... 0.6645669 98d81fc6-ec71-4... 0.8152097
    6417: finished pediophobic_bai... 0.2485594 6cb66aed-f81b-4... 0.4985573

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

    [1] 6416

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
    [1] 0.9909729


    $key
    [1] "a58fd878-c6e3-40a0-8c86-d8552938b5ca"

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
