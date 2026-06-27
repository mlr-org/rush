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
       1:       idle_limpkin 0.73394745 0.8567073 127106ad-c0b6-4...
       2:       idle_limpkin 0.41998176 0.6480600 8e0b6e42-73d6-4...
       3:       idle_limpkin 0.52097909 0.7217888 9c70bcef-fcb1-4...
       4:       idle_limpkin 0.08126840 0.2850761 cfc040ac-f05d-4...
       5:       idle_limpkin 0.70698654 0.8408249 331c6ec8-b941-4...
      ---
    6052:       idle_limpkin 0.37799977 0.6148169 9bcd3024-3048-4...
    6053: charcoal_foxhou... 0.71655592 0.8464963 d1702c64-65ff-4...
    6054:       idle_limpkin 0.98952321 0.9947478 9b69de4a-0153-4...
    6055: charcoal_foxhou... 0.19722191 0.4440967 27a042a2-2350-4...
    6056:       idle_limpkin 0.09968848 0.3157348 5dec6a1f-d9c7-4...

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
       1: 0.7339475 0.8567073       idle_limpkin 127106ad-c0b6-4...
       2: 0.6231415 0.7893931 charcoal_foxhou... e1b4d2ec-b15d-4...
       3: 0.4199818 0.6480600       idle_limpkin 8e0b6e42-73d6-4...
       4: 0.5209791 0.7217888       idle_limpkin 9c70bcef-fcb1-4...
       5: 0.0812684 0.2850761       idle_limpkin cfc040ac-f05d-4...
      ---
    6462: 0.2424733 0.4924157 charcoal_foxhou... 1280096b-bbf0-4...
    6463: 0.6536547 0.8084892       idle_limpkin e3b0f1e3-5b95-4...
    6464: 0.4123869 0.6421736 charcoal_foxhou... b529fd27-f2ee-4...
    6465: 0.6943324 0.8332661       idle_limpkin 9c6830f9-582c-4...
    6466: 0.3498338        NA charcoal_foxhou... 5e734944-db0f-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3498338 charcoal_foxhou... 5e734944-db0f-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running charcoal_foxhou... 0.3498338 5e734944-db0f-4...        NA
       2: finished       idle_limpkin 0.7339475 127106ad-c0b6-4... 0.8567073
       3: finished       idle_limpkin 0.4199818 8e0b6e42-73d6-4... 0.6480600
       4: finished       idle_limpkin 0.5209791 9c70bcef-fcb1-4... 0.7217888
       5: finished       idle_limpkin 0.0812684 cfc040ac-f05d-4... 0.2850761
      ---
    6462: finished       idle_limpkin 0.5359251 59594d3e-83f8-4... 0.7320690
    6463: finished charcoal_foxhou... 0.2424733 1280096b-bbf0-4... 0.4924157
    6464: finished       idle_limpkin 0.6536547 e3b0f1e3-5b95-4... 0.8084892
    6465: finished charcoal_foxhou... 0.4123869 b529fd27-f2ee-4... 0.6421736
    6466: finished       idle_limpkin 0.6943324 9c6830f9-582c-4... 0.8332661

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

    [1] 6465

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
    [1] 0.606991


    $key
    [1] "eea9e2aa-12a2-4d1d-b6a5-e6657caa310a"

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
