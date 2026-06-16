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
       1: unprophesied_ph... 0.5590802 0.7477167 82874b3e-01dc-4...
       2: unprophesied_ph... 0.4713378 0.6865404 e536006f-3433-4...
       3: dynamitic_irish... 0.2023634 0.4498482 09c3cee7-7ebb-4...
       4: unprophesied_ph... 0.2446662 0.4946375 08f198cf-a045-4...
       5: dynamitic_irish... 0.6327768 0.7954727 b1760b3a-5cb1-4...
      ---
    6711: unprophesied_ph... 0.3456121 0.5878879 463e42cb-f18e-4...
    6712: dynamitic_irish... 0.1412692 0.3758580 2806127c-bbbe-4...
    6713: unprophesied_ph... 0.2872245 0.5359333 0d987934-8dea-4...
    6714: dynamitic_irish... 0.9153846 0.9567573 a7381779-ec14-4...
    6715: unprophesied_ph... 0.8755794 0.9357240 b8f04be0-576d-4...

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
       1: 0.5590802 0.7477167 unprophesied_ph... 82874b3e-01dc-4...
       2: 0.2023634 0.4498482 dynamitic_irish... 09c3cee7-7ebb-4...
       3: 0.4713378 0.6865404 unprophesied_ph... e536006f-3433-4...
       4: 0.2446662 0.4946375 unprophesied_ph... 08f198cf-a045-4...
       5: 0.6327768 0.7954727 dynamitic_irish... b1760b3a-5cb1-4...
      ---
    7142: 0.1012610 0.3182154 dynamitic_irish... 36c48212-dc79-4...
    7143: 0.9779668 0.9889220 dynamitic_irish... 08563242-1f99-4...
    7144: 0.7578362 0.8705379 dynamitic_irish... 4df1ce59-dac2-4...
    7145: 0.3183437        NA dynamitic_irish... 1b9eec9d-ff75-4...
    7146: 0.1382233 0.3717839 unprophesied_ph... 4d2e4095-733d-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3183437 dynamitic_irish... 1b9eec9d-ff75-4...
    2: 0.1382233 unprophesied_ph... 4d2e4095-733d-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1:  running dynamitic_irish... 0.3183437        NA 1b9eec9d-ff75-4...
       2:  running unprophesied_ph... 0.1382233 0.3717839 4d2e4095-733d-4...
       3: finished unprophesied_ph... 0.5590802 0.7477167 82874b3e-01dc-4...
       4: finished unprophesied_ph... 0.4713378 0.6865404 e536006f-3433-4...
       5: finished dynamitic_irish... 0.2023634 0.4498482 09c3cee7-7ebb-4...
      ---
    7142: finished dynamitic_irish... 0.3098469 0.5566390 f85bfaa6-3de8-4...
    7143: finished unprophesied_ph... 0.5095029 0.7137947 065f64f8-e83f-4...
    7144: finished dynamitic_irish... 0.1012610 0.3182154 36c48212-dc79-4...
    7145: finished dynamitic_irish... 0.9779668 0.9889220 08563242-1f99-4...
    7146: finished dynamitic_irish... 0.7578362 0.8705379 4df1ce59-dac2-4...

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

    [1] 7144

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
    [1] 0.8877499


    $key
    [1] "55dd438c-2599-4725-9d3f-e82fa5cea1cb"

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
