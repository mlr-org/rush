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
       1: disillusive_ber... 0.83017048 0.9111369 0ca81f80-b825-4...
       2: jewel_australia... 0.60661226 0.7788532 cd7dc52b-c9cc-4...
       3: disillusive_ber... 0.54695890 0.7395667 27f38ef1-0dc6-4...
       4: jewel_australia... 0.59370194 0.7705206 5fbf7529-f5d4-4...
       5: disillusive_ber... 0.78333027 0.8850595 b31c490f-4124-4...
      ---
    6009: disillusive_ber... 0.89566468 0.9463956 c9f12221-eea4-4...
    6010: jewel_australia... 0.08764676 0.2960520 50092f04-65db-4...
    6011: jewel_australia... 0.95890971 0.9792394 e9ed77c0-3670-4...
    6012: disillusive_ber... 0.49568545 0.7040493 d216fa91-46be-4...
    6013: jewel_australia... 0.32722598 0.5720367 9d6dc4d1-0216-4...

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
       1: 0.6066123 0.7788532 jewel_australia... cd7dc52b-c9cc-4...
       2: 0.8301705 0.9111369 disillusive_ber... 0ca81f80-b825-4...
       3: 0.5469589 0.7395667 disillusive_ber... 27f38ef1-0dc6-4...
       4: 0.5937019 0.7705206 jewel_australia... 5fbf7529-f5d4-4...
       5: 0.7833303 0.8850595 disillusive_ber... b31c490f-4124-4...
      ---
    6408: 0.3069260 0.5540091 disillusive_ber... aaf1ed93-2bfb-4...
    6409: 0.7979898 0.8933027 jewel_australia... 1da943f5-30e5-4...
    6410: 0.1973896 0.4442855 disillusive_ber... 44ac12aa-086c-4...
    6411: 0.6108311        NA jewel_australia... f2833dde-c09d-4...
    6412: 0.3544056        NA disillusive_ber... 564c756b-8713-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.6108311 jewel_australia... f2833dde-c09d-4...
    2: 0.3544056 disillusive_ber... 564c756b-8713-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running jewel_australia... 0.6108311 f2833dde-c09d-4...        NA
       2:  running disillusive_ber... 0.3544056 564c756b-8713-4...        NA
       3: finished disillusive_ber... 0.8301705 0ca81f80-b825-4... 0.9111369
       4: finished jewel_australia... 0.6066123 cd7dc52b-c9cc-4... 0.7788532
       5: finished disillusive_ber... 0.5469589 27f38ef1-0dc6-4... 0.7395667
      ---
    6408: finished disillusive_ber... 0.9751372 3c343e80-bbbc-4... 0.9874903
    6409: finished jewel_australia... 0.2831200 8ac00735-0df5-4... 0.5320902
    6410: finished disillusive_ber... 0.3069260 aaf1ed93-2bfb-4... 0.5540091
    6411: finished jewel_australia... 0.7979898 1da943f5-30e5-4... 0.8933027
    6412: finished disillusive_ber... 0.1973896 44ac12aa-086c-4... 0.4442855

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

    [1] 6410

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
    [1] 0.3849096


    $key
    [1] "94201c38-ed86-4fe5-8c6e-dfc0ac10a81c"

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
