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
       1:     knavish_donkey 0.11415865 0.3378737 ae8fd31a-af37-4...
       2: equivalent_noct... 0.52505138 0.7246043 c99b5ba9-76b8-4...
       3:     knavish_donkey 0.86937055 0.9324004 0737d4e4-7f56-4...
       4:     knavish_donkey 0.54173952 0.7360296 cf031571-5082-4...
       5:     knavish_donkey 0.72986818 0.8543232 55bd2282-c2ff-4...
      ---
    7279: equivalent_noct... 0.08110699 0.2847929 6f2ec5f8-232f-4...
    7280:     knavish_donkey 0.82143382 0.9063299 ccc7a80a-959c-4...
    7281: equivalent_noct... 0.20182983 0.4492548 33b65c24-c59e-4...
    7282:     knavish_donkey 0.30251188 0.5500108 10103c11-d13c-4...
    7283: equivalent_noct... 0.95974770 0.9796671 414b0f4e-8a5c-4...

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
       1: 0.1141586 0.3378737     knavish_donkey ae8fd31a-af37-4...
       2: 0.5250514 0.7246043 equivalent_noct... c99b5ba9-76b8-4...
       3: 0.8693706 0.9324004     knavish_donkey 0737d4e4-7f56-4...
       4: 0.5417395 0.7360296     knavish_donkey cf031571-5082-4...
       5: 0.7298682 0.8543232     knavish_donkey 55bd2282-c2ff-4...
      ---
    7754: 0.7223152 0.8498913     knavish_donkey ffba8588-1f27-4...
    7755: 0.1759494 0.4194632     knavish_donkey 6911e3b3-18cd-4...
    7756: 0.3083300 0.5552748 equivalent_noct... 214a1bd6-c87f-4...
    7757: 0.3727920 0.6105669     knavish_donkey 3d3a813a-40aa-4...
    7758: 0.8143779 0.9024289 equivalent_noct... cc09dd2b-44bd-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished     knavish_donkey 0.1141586 0.3378737 ae8fd31a-af37-4...
       2: finished equivalent_noct... 0.5250514 0.7246043 c99b5ba9-76b8-4...
       3: finished     knavish_donkey 0.8693706 0.9324004 0737d4e4-7f56-4...
       4: finished     knavish_donkey 0.5417395 0.7360296 cf031571-5082-4...
       5: finished     knavish_donkey 0.7298682 0.8543232 55bd2282-c2ff-4...
      ---
    7754: finished     knavish_donkey 0.7223152 0.8498913 ffba8588-1f27-4...
    7755: finished     knavish_donkey 0.1759494 0.4194632 6911e3b3-18cd-4...
    7756: finished equivalent_noct... 0.3083300 0.5552748 214a1bd6-c87f-4...
    7757: finished     knavish_donkey 0.3727920 0.6105669 3d3a813a-40aa-4...
    7758: finished equivalent_noct... 0.8143779 0.9024289 cc09dd2b-44bd-4...

## Task Counts

``` r

rush$n_queued_tasks
```

    [1] 0

``` r

rush$n_running_tasks
```

    [1] 0

``` r

rush$n_finished_tasks
```

    [1] 7758

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
    [1] 0.05592005


    $key
    [1] "7498e1cc-9e06-47ae-b957-e57fd826d396"

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
