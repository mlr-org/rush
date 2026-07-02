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
       1: genealogic_marm... 0.60986281 0.7809371 c48748cc-0756-4...
       2:     wispy_barnacle 0.45887842 0.6774057 abed51db-9807-4...
       3: genealogic_marm... 0.67021065 0.8186639 8a68ff81-873b-4...
       4: genealogic_marm... 0.18663205 0.4320093 c5ab7f6e-9631-4...
       5: genealogic_marm... 0.69099948 0.8312638 1fb8a487-2552-4...
      ---
    7234:     wispy_barnacle 0.64076459 0.8004777 dd462df9-ac4e-4...
    7235: genealogic_marm... 0.51302917 0.7162605 78c0e400-4191-4...
    7236:     wispy_barnacle 0.22357888 0.4728413 2a127b4e-1214-4...
    7237: genealogic_marm... 0.18948824 0.4353025 556396e6-c9ee-4...
    7238:     wispy_barnacle 0.08136154 0.2852394 b387ebd7-91c9-4...

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
       1: 0.6098628 0.7809371 genealogic_marm...    [NULL] c48748cc-0756-4...
       2: 0.4588784 0.6774057     wispy_barnacle    [NULL] abed51db-9807-4...
       3: 0.6702106 0.8186639 genealogic_marm...    [NULL] 8a68ff81-873b-4...
       4: 0.1866321 0.4320093 genealogic_marm...    [NULL] c5ab7f6e-9631-4...
       5: 0.6909995 0.8312638 genealogic_marm...    [NULL] 1fb8a487-2552-4...
      ---
    7709: 0.5210323 0.7218257 genealogic_marm...    [NULL] cad41a5c-aa55-4...
    7710: 0.8721727 0.9339019     wispy_barnacle    [NULL] 3ce0a099-e756-4...
    7711: 0.8113947 0.9007745 genealogic_marm...    [NULL] 7fca35c7-039b-4...
    7712: 0.6402760 0.8001725     wispy_barnacle    [NULL] 0fc118e8-b585-4...
    7713: 0.1873124        NA genealogic_marm... <list[1]> 109afcf5-3f5e-4...

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
    1: 0.1873124 genealogic_marm... <list[1]> 109afcf5-3f5e-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished genealogic_marm... 0.6098628 0.7809371 c48748cc-0756-4...
       2: finished     wispy_barnacle 0.4588784 0.6774057 abed51db-9807-4...
       3: finished genealogic_marm... 0.6702106 0.8186639 8a68ff81-873b-4...
       4: finished genealogic_marm... 0.1866321 0.4320093 c5ab7f6e-9631-4...
       5: finished genealogic_marm... 0.6909995 0.8312638 1fb8a487-2552-4...
      ---
    7708: finished     wispy_barnacle 0.1966394 0.4434405 f0a8bf73-65f2-4...
    7709: finished genealogic_marm... 0.5210323 0.7218257 cad41a5c-aa55-4...
    7710: finished     wispy_barnacle 0.8721727 0.9339019 3ce0a099-e756-4...
    7711: finished genealogic_marm... 0.8113947 0.9007745 7fca35c7-039b-4...
    7712: finished     wispy_barnacle 0.6402760 0.8001725 0fc118e8-b585-4...

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

    [1] 7712

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
    [1] 0.2315742


    $key
    [1] "7f2bad85-51c5-4b57-82ac-55d7e2f67f33"

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
