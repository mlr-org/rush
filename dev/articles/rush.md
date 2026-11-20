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
       1: psychoanalytic_... 0.4242751 0.6513640 fc5b6068-042f-4...
       2: segregated_afri... 0.9647157 0.9821994 7c47c91e-f728-4...
       3: psychoanalytic_... 0.3353674 0.5791091 35c2b492-88dc-4...
       4: psychoanalytic_... 0.7882114 0.8878127 3043233a-8888-4...
       5: psychoanalytic_... 0.3166484 0.5627152 832dc01d-579f-4...
      ---
    6787: psychoanalytic_... 0.5093914 0.7137166 df84f83e-bfdb-4...
    6788: segregated_afri... 0.5447699 0.7380853 4bf1e7d9-a461-4...
    6789: psychoanalytic_... 0.8434525 0.9183967 ed09d2dd-d5cf-4...
    6790: segregated_afri... 0.7408705 0.8607384 48dd18f2-44ff-4...
    6791: psychoanalytic_... 0.8898295 0.9433077 36f7e284-45a7-4...

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
       1: 0.42427510 0.6513640 psychoanalytic_...    [NULL] fc5b6068-042f-4...
       2: 0.96471567 0.9821994 segregated_afri...    [NULL] 7c47c91e-f728-4...
       3: 0.33536741 0.5791091 psychoanalytic_...    [NULL] 35c2b492-88dc-4...
       4: 0.78821142 0.8878127 psychoanalytic_...    [NULL] 3043233a-8888-4...
       5: 0.31664842 0.5627152 psychoanalytic_...    [NULL] 832dc01d-579f-4...
      ---
    7293: 0.27718776 0.5264862 segregated_afri...    [NULL] e4e9bba0-2345-4...
    7294: 0.57529339 0.7584810 psychoanalytic_...    [NULL] d6c55797-b7fc-4...
    7295: 0.23809907 0.4879540 segregated_afri...    [NULL] 65d543e5-88a3-4...
    7296: 0.03958991        NA psychoanalytic_... <list[1]> 5e46360d-7eda-4...
    7297: 0.58167842        NA segregated_afri... <list[1]> a0c10589-72b3-4...

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
    1: 0.03958991 psychoanalytic_... <list[1]> 5e46360d-7eda-4...
    2: 0.58167842 segregated_afri... <list[1]> a0c10589-72b3-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished psychoanalytic_... 0.4242751 0.6513640 fc5b6068-042f-4...
       2: finished segregated_afri... 0.9647157 0.9821994 7c47c91e-f728-4...
       3: finished psychoanalytic_... 0.3353674 0.5791091 35c2b492-88dc-4...
       4: finished psychoanalytic_... 0.7882114 0.8878127 3043233a-8888-4...
       5: finished psychoanalytic_... 0.3166484 0.5627152 832dc01d-579f-4...
      ---
    7291: finished segregated_afri... 0.9493607 0.9743514 630983dc-97f1-4...
    7292: finished psychoanalytic_... 0.7238945 0.8508199 76e46faa-3498-4...
    7293: finished segregated_afri... 0.2771878 0.5264862 e4e9bba0-2345-4...
    7294: finished psychoanalytic_... 0.5752934 0.7584810 d6c55797-b7fc-4...
    7295: finished segregated_afri... 0.2380991 0.4879540 65d543e5-88a3-4...

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

    [1] 7295

``` r

rush$n_failed_tasks
```

    [1] 2

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
    [1] 0.8626476


    $key
    [1] "349554d2-9767-4c40-9eab-d7f25d12b30b"

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
