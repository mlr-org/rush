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

                   worker_id           x         y               keys
                      <char>       <num>     <num>             <char>
       1: discontented_lo... 0.906820693 0.9522713 c15eb505-98f2-4...
       2: ultramodern_swa... 0.201622160 0.4490236 91d2bb2c-76cd-4...
       3: discontented_lo... 0.007821988 0.0884420 4111ae98-5925-4...
       4: ultramodern_swa... 0.966794567 0.9832571 b88ea12c-4276-4...
       5: discontented_lo... 0.431174701 0.6566389 a907cbc1-3556-4...
      ---
    6330: discontented_lo... 0.977784855 0.9888300 40429e14-2c65-4...
    6331: ultramodern_swa... 0.951120318 0.9752540 ca1b6e81-611b-4...
    6332: discontented_lo... 0.310713023 0.5574164 893a5623-f448-4...
    6333: ultramodern_swa... 0.662648675 0.8140324 c28fc5ab-289c-4...
    6334: discontented_lo... 0.936407986 0.9676818 09e22d15-5494-4...

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
       1: 0.906820693 0.9522713 discontented_lo... c15eb505-98f2-4...
       2: 0.201622160 0.4490236 ultramodern_swa... 91d2bb2c-76cd-4...
       3: 0.007821988 0.0884420 discontented_lo... 4111ae98-5925-4...
       4: 0.966794567 0.9832571 ultramodern_swa... b88ea12c-4276-4...
       5: 0.431174701 0.6566389 discontented_lo... a907cbc1-3556-4...
      ---
    6712: 0.781173737 0.8838403 ultramodern_swa... e82d0aad-5791-4...
    6713: 0.211081138 0.4594357 discontented_lo... c2ce797a-bee8-4...
    6714: 0.544350148 0.7378009 ultramodern_swa... 217fc580-c983-4...
    6715: 0.929941763        NA discontented_lo... aed5001d-aa2f-4...
    6716: 0.520015488 0.7211210 ultramodern_swa... 81488a53-7f1c-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.9299418 discontented_lo... aed5001d-aa2f-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x               keys         y
            <char>             <char>       <num>             <char>     <num>
       1:  running discontented_lo... 0.929941763 aed5001d-aa2f-4...        NA
       2: finished discontented_lo... 0.906820693 c15eb505-98f2-4... 0.9522713
       3: finished ultramodern_swa... 0.201622160 91d2bb2c-76cd-4... 0.4490236
       4: finished discontented_lo... 0.007821988 4111ae98-5925-4... 0.0884420
       5: finished ultramodern_swa... 0.966794567 b88ea12c-4276-4... 0.9832571
      ---
    6712: finished discontented_lo... 0.112270208 087d73d2-ce0a-4... 0.3350675
    6713: finished ultramodern_swa... 0.781173737 e82d0aad-5791-4... 0.8838403
    6714: finished discontented_lo... 0.211081138 c2ce797a-bee8-4... 0.4594357
    6715: finished ultramodern_swa... 0.544350148 217fc580-c983-4... 0.7378009
    6716: finished ultramodern_swa... 0.520015488 81488a53-7f1c-4... 0.7211210

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

    [1] 6715

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
    [1] 0.5738996


    $key
    [1] "c45e0bf7-604a-4596-a4b6-33313c10c0f3"

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
