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
       1: hairraising_neo... 0.92428685 0.9613984 731a327d-a117-4...
       2: hairraising_neo... 0.03235575 0.1798770 41f17d21-21f1-4...
       3: hairraising_neo... 0.94425559 0.9717281 9f7e075b-9376-4...
       4: hairraising_neo... 0.49344083 0.7024534 68241974-e60a-4...
       5: hairraising_neo... 0.65712165 0.8106304 8ebdde41-3316-4...
      ---
    7994: silty_indochina... 0.56557190 0.7520451 9c0e0bc8-c6c8-4...
    7995: hairraising_neo... 0.58521602 0.7649941 7d555a49-5338-4...
    7996: silty_indochina... 0.33806877 0.5814368 2efce603-38de-4...
    7997: hairraising_neo... 0.01573884 0.1254545 eb679dc7-91b6-4...
    7998: silty_indochina... 0.28685206 0.5355857 3240ea1f-5ffd-4...

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
       1: 0.92428685 0.9613984 hairraising_neo... 731a327d-a117-4...
       2: 0.40541295 0.6367205 silty_indochina... 5332602b-2dcd-4...
       3: 0.03235575 0.1798770 hairraising_neo... 41f17d21-21f1-4...
       4: 0.94425559 0.9717281 hairraising_neo... 9f7e075b-9376-4...
       5: 0.49344083 0.7024534 hairraising_neo... 68241974-e60a-4...
      ---
    8588: 0.93602536 0.9674840 silty_indochina... d5bd3637-aa82-4...
    8589: 0.12663806 0.3558624 hairraising_neo... 7a484b54-5143-4...
    8590: 0.35877723 0.5989802 silty_indochina... 478e67bd-0277-4...
    8591: 0.92503280 0.9617863 hairraising_neo... 7bf2b0a9-eb8c-4...
    8592: 0.91068155 0.9542964 silty_indochina... 9b590833-8133-4...

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
       1: finished hairraising_neo... 0.92428685 0.9613984 731a327d-a117-4...
       2: finished hairraising_neo... 0.03235575 0.1798770 41f17d21-21f1-4...
       3: finished hairraising_neo... 0.94425559 0.9717281 9f7e075b-9376-4...
       4: finished hairraising_neo... 0.49344083 0.7024534 68241974-e60a-4...
       5: finished hairraising_neo... 0.65712165 0.8106304 8ebdde41-3316-4...
      ---
    8588: finished silty_indochina... 0.93602536 0.9674840 d5bd3637-aa82-4...
    8589: finished hairraising_neo... 0.12663806 0.3558624 7a484b54-5143-4...
    8590: finished silty_indochina... 0.35877723 0.5989802 478e67bd-0277-4...
    8591: finished hairraising_neo... 0.92503280 0.9617863 7bf2b0a9-eb8c-4...
    8592: finished silty_indochina... 0.91068155 0.9542964 9b590833-8133-4...

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

    [1] 8592

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
    [1] 0.9329867


    $key
    [1] "a32f03ec-084f-4cb4-97e7-62bda7ea7278"

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
