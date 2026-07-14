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
       1: grandfatherly_b... 0.1401699 0.3743927 253c66d4-ec95-4...
       2: dense_neonredgu... 0.2980853 0.5459719 29d8e3c6-ce75-4...
       3: grandfatherly_b... 0.6244154 0.7901996 b20fcd95-a59b-4...
       4: grandfatherly_b... 0.4876735 0.6983362 845aac73-0e80-4...
       5: grandfatherly_b... 0.9214071 0.9598995 c14a5564-734c-4...
      ---
    6150: grandfatherly_b... 0.8634218 0.9292049 9409f2fa-e65a-4...
    6151: dense_neonredgu... 0.2408166 0.4907307 1969ddd0-de32-4...
    6152: grandfatherly_b... 0.9816815 0.9907984 f427a29b-6417-4...
    6153: dense_neonredgu... 0.6950280 0.8336834 176341dc-67a0-4...
    6154: grandfatherly_b... 0.1037170 0.3220512 801845a7-fc42-4...

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

                  x         y          worker_id condition               keys
              <num>     <num>             <char>    <list>             <char>
       1: 0.1401699 0.3743927 grandfatherly_b...    [NULL] 253c66d4-ec95-4...
       2: 0.2980853 0.5459719 dense_neonredgu...    [NULL] 29d8e3c6-ce75-4...
       3: 0.6244154 0.7901996 grandfatherly_b...    [NULL] b20fcd95-a59b-4...
       4: 0.4876735 0.6983362 grandfatherly_b...    [NULL] 845aac73-0e80-4...
       5: 0.9214071 0.9598995 grandfatherly_b...    [NULL] c14a5564-734c-4...
      ---
    6584: 0.6370586 0.7981595 grandfatherly_b...    [NULL] e493e77f-1f7c-4...
    6585: 0.7094590 0.8422939 dense_neonredgu...    [NULL] 676cbf67-a062-4...
    6586: 0.3307610 0.5751182 grandfatherly_b...    [NULL] fc2221c9-97de-4...
    6587: 0.4702038 0.6857141 grandfatherly_b...    [NULL] 672e946e-07de-4...
    6588: 0.2406341        NA dense_neonredgu... <list[1]> 0daa633e-7a87-4...

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

               x          worker_id condition               keys
           <num>             <char>    <list>             <char>
    1: 0.2406341 dense_neonredgu... <list[1]> 0daa633e-7a87-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished grandfatherly_b... 0.1401699 0.3743927 253c66d4-ec95-4...
       2: finished dense_neonredgu... 0.2980853 0.5459719 29d8e3c6-ce75-4...
       3: finished grandfatherly_b... 0.6244154 0.7901996 b20fcd95-a59b-4...
       4: finished grandfatherly_b... 0.4876735 0.6983362 845aac73-0e80-4...
       5: finished grandfatherly_b... 0.9214071 0.9598995 c14a5564-734c-4...
      ---
    6583: finished grandfatherly_b... 0.9202080 0.9592747 bd3d08fe-62af-4...
    6584: finished grandfatherly_b... 0.6370586 0.7981595 e493e77f-1f7c-4...
    6585: finished dense_neonredgu... 0.7094590 0.8422939 676cbf67-a062-4...
    6586: finished grandfatherly_b... 0.3307610 0.5751182 fc2221c9-97de-4...
    6587: finished grandfatherly_b... 0.4702038 0.6857141 672e946e-07de-4...

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

    [1] 6587

``` r

rush$n_failed_tasks
```

    [1] 1

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
    [1] 0.2460553


    $key
    [1] "64dec7e1-cede-4d3c-a552-5b0fb0458cae"

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

    Rscript -e 'rush::start_worker(network_id = "my_network", config = list(scheme = "redis", host = "127.0.0.1", port = "6379"))'

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
