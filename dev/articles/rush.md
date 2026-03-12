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
       1:    trilinear_gecko 0.35426146 0.5951987 757e921a-53ed-4...
       2: interuniversity... 0.09890123 0.3144857 8b66952f-edb1-4...
       3:    trilinear_gecko 0.77855048 0.8823551 878cb51b-b869-4...
       4: interuniversity... 0.49646684 0.7046040 e4dd7453-8c0f-4...
       5:    trilinear_gecko 0.67453447 0.8213005 5f790140-7feb-4...
      ---
    5984:    trilinear_gecko 0.07721747 0.2778803 bfd62615-0294-4...
    5985: interuniversity... 0.89580183 0.9464681 ca4d144c-33ba-4...
    5986:    trilinear_gecko 0.22458570 0.4739047 db4caee0-16d7-4...
    5987: interuniversity... 0.19914394 0.4462555 56c924a3-039e-4...
    5988:    trilinear_gecko 0.17458100 0.4178289 538fc78d-9d0c-4...

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
       1: 0.35426146 0.5951987    trilinear_gecko 757e921a-53ed-4...
       2: 0.09890123 0.3144857 interuniversity... 8b66952f-edb1-4...
       3: 0.77855048 0.8823551    trilinear_gecko 878cb51b-b869-4...
       4: 0.49646684 0.7046040 interuniversity... e4dd7453-8c0f-4...
       5: 0.67453447 0.8213005    trilinear_gecko 5f790140-7feb-4...
      ---
    6357: 0.48704375 0.6978852 interuniversity... 4f72b80f-23a1-4...
    6358: 0.30812764 0.5550925    trilinear_gecko 4c28221c-b42a-4...
    6359: 0.55577851 0.7455055 interuniversity... 6d06f243-2a53-4...
    6360: 0.76727299 0.8759412    trilinear_gecko b49ab8dc-85cf-4...
    6361: 0.90779738 0.9527840 interuniversity... 53190e42-a932-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x       worker_id               keys
           <num>          <char>             <char>
    1: 0.4911294 trilinear_gecko 7a0090c9-ba79-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running    trilinear_gecko 0.49112943 7a0090c9-ba79-4...        NA
       2: finished    trilinear_gecko 0.35426146 757e921a-53ed-4... 0.5951987
       3: finished interuniversity... 0.09890123 8b66952f-edb1-4... 0.3144857
       4: finished    trilinear_gecko 0.77855048 878cb51b-b869-4... 0.8823551
       5: finished interuniversity... 0.49646684 e4dd7453-8c0f-4... 0.7046040
      ---
    6358: finished interuniversity... 0.48704375 4f72b80f-23a1-4... 0.6978852
    6359: finished    trilinear_gecko 0.30812764 4c28221c-b42a-4... 0.5550925
    6360: finished interuniversity... 0.55577851 6d06f243-2a53-4... 0.7455055
    6361: finished    trilinear_gecko 0.76727299 b49ab8dc-85cf-4... 0.8759412
    6362: finished interuniversity... 0.90779738 53190e42-a932-4... 0.9527840

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

    [1] 6361

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
    [1] 0.8035427


    $key
    [1] "0a7f16f0-9173-4255-b2cf-39b3a6c33e90"

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
