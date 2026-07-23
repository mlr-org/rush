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
       1: sick_banteng_23... 0.3506398 0.5921484 1f885c54-a288-4...
       2: interchurch_anc... 0.9956033 0.9977992 54dfdfac-cbdf-4...
       3: sick_banteng_23... 0.2717282 0.5212755 56a59040-0f47-4...
       4: sick_banteng_23... 0.1569024 0.3961091 318e00ec-61a1-4...
       5: sick_banteng_23... 0.0813234 0.2851726 0becdb8d-81e3-4...
      ---
    9952: interchurch_anc... 0.6806601 0.8250212 76c03217-5c71-4...
    9953: sick_banteng_23... 0.2477854 0.4977805 be5ad985-3d56-4...
    9954: interchurch_anc... 0.3426837 0.5853920 b3ebb1e2-345d-4...
    9955: sick_banteng_23... 0.0367739 0.1917652 d9b97a9f-5cc4-4...
    9956: interchurch_anc... 0.8331464 0.9127685 82d93041-9f35-4...

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
        1: 0.3506398 0.5921484 sick_banteng_23...    [NULL] 1f885c54-a288-4...
        2: 0.9956033 0.9977992 interchurch_anc...    [NULL] 54dfdfac-cbdf-4...
        3: 0.2717282 0.5212755 sick_banteng_23...    [NULL] 56a59040-0f47-4...
        4: 0.1569024 0.3961091 sick_banteng_23...    [NULL] 318e00ec-61a1-4...
        5: 0.0813234 0.2851726 sick_banteng_23...    [NULL] 0becdb8d-81e3-4...
       ---
    10665: 0.8663714 0.9307908 interchurch_anc...    [NULL] 72254365-423b-4...
    10666: 0.6478403 0.8048852 sick_banteng_23...    [NULL] 4dbc360d-3af2-4...
    10667: 0.6606096 0.8127789 interchurch_anc...    [NULL] 0b2d519a-5ef2-4...
    10668: 0.2965117 0.5445289 sick_banteng_23...    [NULL] d2ea5620-bfa7-4...
    10669: 0.2642569        NA interchurch_anc... <list[1]> 415ad7ce-6c02-4...

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
    1: 0.2642569 interchurch_anc... <list[1]> 415ad7ce-6c02-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

              state          worker_id         x         y               keys
             <char>             <char>     <num>     <num>             <char>
        1: finished sick_banteng_23... 0.3506398 0.5921484 1f885c54-a288-4...
        2: finished interchurch_anc... 0.9956033 0.9977992 54dfdfac-cbdf-4...
        3: finished sick_banteng_23... 0.2717282 0.5212755 56a59040-0f47-4...
        4: finished sick_banteng_23... 0.1569024 0.3961091 318e00ec-61a1-4...
        5: finished sick_banteng_23... 0.0813234 0.2851726 0becdb8d-81e3-4...
       ---
    10664: finished sick_banteng_23... 0.1569812 0.3962085 472313d8-35b7-4...
    10665: finished interchurch_anc... 0.8663714 0.9307908 72254365-423b-4...
    10666: finished sick_banteng_23... 0.6478403 0.8048852 4dbc360d-3af2-4...
    10667: finished interchurch_anc... 0.6606096 0.8127789 0b2d519a-5ef2-4...
    10668: finished sick_banteng_23... 0.2965117 0.5445289 d2ea5620-bfa7-4...

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

    [1] 10668

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
    [1] 0.1338371


    $key
    [1] "2ac8b3af-c47b-4893-a642-5ec858e0d874"

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
