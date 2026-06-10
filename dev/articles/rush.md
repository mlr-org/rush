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
       1: anthropological... 0.43979796 0.6631726 213ebd64-d7d1-4...
       2: anthropological... 0.43817261 0.6619461 b51a275c-456f-4...
       3:    venerated_mouse 0.13803605 0.3715320 cc0d597d-8555-4...
       4: anthropological... 0.71616625 0.8462661 81764d39-be65-4...
       5:    venerated_mouse 0.02843668 0.1686318 a32ce44b-3bb3-4...
      ---
    6647:    venerated_mouse 0.47041027 0.6858646 9d1d055a-f55d-4...
    6648: anthropological... 0.22397706 0.4732621 6b4efb3e-d6c2-4...
    6649:    venerated_mouse 0.16177305 0.4022102 fe803665-4e38-4...
    6650: anthropological... 0.70694659 0.8408012 c43e64ec-f510-4...
    6651:    venerated_mouse 0.26250924 0.5123566 5c427b25-272c-4...

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
       1: 0.43979796 0.6631726 anthropological... 213ebd64-d7d1-4...
       2: 0.13803605 0.3715320    venerated_mouse cc0d597d-8555-4...
       3: 0.43817261 0.6619461 anthropological... b51a275c-456f-4...
       4: 0.71616625 0.8462661 anthropological... 81764d39-be65-4...
       5: 0.02843668 0.1686318    venerated_mouse a32ce44b-3bb3-4...
      ---
    7076: 0.10574373 0.3251826    venerated_mouse 527cf897-7077-4...
    7077: 0.59606598 0.7720531 anthropological... 9ea9e547-3df5-4...
    7078: 0.12800264 0.3577746    venerated_mouse 42b26a43-569a-4...
    7079: 0.66560870 0.8158485 anthropological... 641039ad-92c6-4...
    7080: 0.44742670 0.6688996    venerated_mouse fbe84cd9-6a94-4...

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

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished anthropological... 0.43979796 0.6631726 213ebd64-d7d1-4...
       2: finished anthropological... 0.43817261 0.6619461 b51a275c-456f-4...
       3: finished    venerated_mouse 0.13803605 0.3715320 cc0d597d-8555-4...
       4: finished anthropological... 0.71616625 0.8462661 81764d39-be65-4...
       5: finished    venerated_mouse 0.02843668 0.1686318 a32ce44b-3bb3-4...
      ---
    7076: finished    venerated_mouse 0.10574373 0.3251826 527cf897-7077-4...
    7077: finished anthropological... 0.59606598 0.7720531 9ea9e547-3df5-4...
    7078: finished    venerated_mouse 0.12800264 0.3577746 42b26a43-569a-4...
    7079: finished anthropological... 0.66560870 0.8158485 641039ad-92c6-4...
    7080: finished    venerated_mouse 0.44742670 0.6688996 fbe84cd9-6a94-4...

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

    [1] 7080

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
    [1] 0.3774711


    $key
    [1] "a09ae346-e93e-4dc2-84e6-43c8984eceec"

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
