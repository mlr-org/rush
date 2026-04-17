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
       1: antinationalist... 0.21708748 0.4659265 a64930fd-37e9-4...
       2: antinationalist... 0.71079384 0.8430859 7f8d8e28-5bbc-4...
       3: antinationalist... 0.61222790 0.7824499 587b79b0-0e4e-4...
       4: antinationalist... 0.94419654 0.9716978 8d5a138e-2936-4...
       5: antinationalist... 0.08535157 0.2921499 598d0467-7735-4...
      ---
    8146: antinationalist... 0.46881571 0.6847012 ddb0008a-55e6-4...
    8147:     weighted_agama 0.97475728 0.9872980 8a20801e-f318-4...
    8148: antinationalist... 0.38858857 0.6233687 5f4c99af-3596-4...
    8149:     weighted_agama 0.01414978 0.1189528 cb35ea08-c4c5-4...
    8150: antinationalist... 0.51811851 0.7198045 b84e332e-f478-4...

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
       1: 0.2170875 0.4659265 antinationalist... a64930fd-37e9-4...
       2: 0.8635256 0.9292608     weighted_agama 49a1abd8-848e-4...
       3: 0.7107938 0.8430859 antinationalist... 7f8d8e28-5bbc-4...
       4: 0.6122279 0.7824499 antinationalist... 587b79b0-0e4e-4...
       5: 0.9441965 0.9716978 antinationalist... 8d5a138e-2936-4...
      ---
    8775: 0.5183994 0.7199996     weighted_agama 742d2ead-3ac5-4...
    8776: 0.6000712 0.7746426 antinationalist... 124c1807-3de2-4...
    8777: 0.4260333 0.6527123     weighted_agama f609a533-923f-4...
    8778: 0.8062632        NA antinationalist... 8bb4ec34-b104-4...
    8779: 0.2453959        NA     weighted_agama cb4c86ec-55be-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.8062632 antinationalist... 8bb4ec34-b104-4...
    2: 0.2453959     weighted_agama cb4c86ec-55be-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running antinationalist... 0.8062632 8bb4ec34-b104-4...        NA
       2:  running     weighted_agama 0.2453959 cb4c86ec-55be-4...        NA
       3: finished antinationalist... 0.2170875 a64930fd-37e9-4... 0.4659265
       4: finished antinationalist... 0.7107938 7f8d8e28-5bbc-4... 0.8430859
       5: finished antinationalist... 0.6122279 587b79b0-0e4e-4... 0.7824499
      ---
    8775: finished     weighted_agama 0.9582145 8548992d-4586-4... 0.9788843
    8776: finished antinationalist... 0.7387893 01d73d89-fa41-4... 0.8595285
    8777: finished     weighted_agama 0.5183994 742d2ead-3ac5-4... 0.7199996
    8778: finished antinationalist... 0.6000712 124c1807-3de2-4... 0.7746426
    8779: finished     weighted_agama 0.4260333 f609a533-923f-4... 0.6527123

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

    [1] 8777

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
    [1] 0.8557513


    $key
    [1] "76f20829-09a3-4120-bef2-a08100aca9a3"

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
