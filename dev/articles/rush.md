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
       1: lexicological_k... 0.8173172 0.9040560 393bd2c6-6c86-4...
       2: helminthologic_... 0.7784897 0.8823206 0efb3280-b831-4...
       3: lexicological_k... 0.3685868 0.6071135 3be379cd-68e9-4...
       4: helminthologic_... 0.6520462 0.8074938 498c7d57-f625-4...
       5: lexicological_k... 0.6663518 0.8163037 5e4fe8e7-e184-4...
      ---
    7303: helminthologic_... 0.8251239 0.9083633 a4756c63-747a-4...
    7304: lexicological_k... 0.6184538 0.7864183 0e7bca2c-482b-4...
    7305: helminthologic_... 0.5745856 0.7580142 8450d0b9-ad18-4...
    7306: lexicological_k... 0.4594880 0.6778554 82049d9e-9722-4...
    7307: helminthologic_... 0.7602726 0.8719361 eebc7911-5ed3-4...

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
       1: 0.77848967 0.8823206 helminthologic_... 0efb3280-b831-4...
       2: 0.81731718 0.9040560 lexicological_k... 393bd2c6-6c86-4...
       3: 0.36858681 0.6071135 lexicological_k... 3be379cd-68e9-4...
       4: 0.65204621 0.8074938 helminthologic_... 498c7d57-f625-4...
       5: 0.66635181 0.8163037 lexicological_k... 5e4fe8e7-e184-4...
      ---
    7808: 0.03182825 0.1784047 lexicological_k... 264fffeb-63f4-4...
    7809: 0.10844699 0.3293129 helminthologic_... d2ec4cb2-346d-4...
    7810: 0.08359630 0.2891302 lexicological_k... 2fe0b82e-e593-4...
    7811: 0.92995136 0.9643399 helminthologic_... 23dc128c-f9d5-4...
    7812: 0.03165952        NA helminthologic_... e115282e-465d-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

                x          worker_id               keys
            <num>             <char>             <char>
    1: 0.03165952 helminthologic_... e115282e-465d-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running helminthologic_... 0.03165952 e115282e-465d-4...        NA
       2: finished lexicological_k... 0.81731718 393bd2c6-6c86-4... 0.9040560
       3: finished helminthologic_... 0.77848967 0efb3280-b831-4... 0.8823206
       4: finished lexicological_k... 0.36858681 3be379cd-68e9-4... 0.6071135
       5: finished helminthologic_... 0.65204621 498c7d57-f625-4... 0.8074938
      ---
    7808: finished helminthologic_... 0.50916079 91c095d8-56a4-4... 0.7135550
    7809: finished lexicological_k... 0.03182825 264fffeb-63f4-4... 0.1784047
    7810: finished helminthologic_... 0.10844699 d2ec4cb2-346d-4... 0.3293129
    7811: finished helminthologic_... 0.92995136 23dc128c-f9d5-4... 0.9643399
    7812: finished lexicological_k... 0.08359630 2fe0b82e-e593-4... 0.2891302

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

    [1] 7811

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
    [1] 0.5204017


    $key
    [1] "0cddecc9-f984-424e-b483-138c29aee7be"

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
