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
       1: doused_newfound... 0.23933633 0.4892201 25b1a85b-0f05-4...
       2: doused_newfound... 0.27365388 0.5231194 3b7c2321-0a04-4...
       3: doused_newfound... 0.87389594 0.9348240 8275d00e-b2c7-4...
       4: doused_newfound... 0.32897037 0.5735594 5228b954-6737-4...
       5: emptyheaded_ame... 0.08663653 0.2943408 8057d0b4-915f-4...
      ---
    6003: emptyheaded_ame... 0.37855782 0.6152705 375eccdf-7dba-4...
    6004: doused_newfound... 0.71429565 0.8451601 c8275489-dcd6-4...
    6005: emptyheaded_ame... 0.38203626 0.6180908 4fa61ef5-1182-4...
    6006: doused_newfound... 0.54602204 0.7389330 a2a1badb-dd52-4...
    6007: emptyheaded_ame... 0.13093095 0.3618438 154bf781-8dec-4...

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
       1: 0.08663653 0.2943408 emptyheaded_ame... 8057d0b4-915f-4...
       2: 0.23933633 0.4892201 doused_newfound... 25b1a85b-0f05-4...
       3: 0.27365388 0.5231194 doused_newfound... 3b7c2321-0a04-4...
       4: 0.87389594 0.9348240 doused_newfound... 8275d00e-b2c7-4...
       5: 0.32897037 0.5735594 doused_newfound... 5228b954-6737-4...
      ---
    6408: 0.53071864 0.7285044 emptyheaded_ame... 5854d935-c45e-4...
    6409: 0.94725236 0.9732689 doused_newfound... 75c99038-d96c-4...
    6410: 0.66577341 0.8159494 emptyheaded_ame... 5eb353f5-b352-4...
    6411: 0.24878445 0.4987830 doused_newfound... c96aa316-e5fb-4...
    6412: 0.45408095        NA emptyheaded_ame... f65a1619-c1c9-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

              x          worker_id               keys
          <num>             <char>             <char>
    1: 0.454081 emptyheaded_ame... f65a1619-c1c9-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running emptyheaded_ame... 0.4540810 f65a1619-c1c9-4...        NA
       2: finished doused_newfound... 0.2393363 25b1a85b-0f05-4... 0.4892201
       3: finished doused_newfound... 0.2736539 3b7c2321-0a04-4... 0.5231194
       4: finished doused_newfound... 0.8738959 8275d00e-b2c7-4... 0.9348240
       5: finished doused_newfound... 0.3289704 5228b954-6737-4... 0.5735594
      ---
    6408: finished doused_newfound... 0.3081873 d90037af-9a52-4... 0.5551462
    6409: finished emptyheaded_ame... 0.5307186 5854d935-c45e-4... 0.7285044
    6410: finished doused_newfound... 0.9472524 75c99038-d96c-4... 0.9732689
    6411: finished emptyheaded_ame... 0.6657734 5eb353f5-b352-4... 0.8159494
    6412: finished doused_newfound... 0.2487844 c96aa316-e5fb-4... 0.4987830

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

    [1] 6411

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
    [1] 0.1789001


    $key
    [1] "f500841d-edc4-411c-bc23-9aa5ace863c2"

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
