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

                   worker_id           x          y               keys
                      <char>       <num>      <num>             <char>
       1: astrophilic_cha... 0.527050627 0.72598253 497c7348-57c5-4...
       2: credible_dogfis... 0.648016378 0.80499464 fe8b9b34-cadc-4...
       3: astrophilic_cha... 0.004258051 0.06525374 d5e47883-8c86-4...
       4: astrophilic_cha... 0.270631802 0.52022284 b3fac308-e907-4...
       5: astrophilic_cha... 0.691437105 0.83152697 04c22d45-fd69-4...
      ---
    7452: astrophilic_cha... 0.213979414 0.46257909 b871ddee-b459-4...
    7453: credible_dogfis... 0.318449001 0.56431286 266bdfba-bb09-4...
    7454: astrophilic_cha... 0.534605123 0.73116696 54530711-5a64-4...
    7455: credible_dogfis... 0.401171643 0.63338112 130ef17c-0dbc-4...
    7456: astrophilic_cha... 0.316063772 0.56219549 bcee0439-4ea9-4...

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

                    x          y          worker_id condition               keys
                <num>      <num>             <char>    <list>             <char>
       1: 0.527050627 0.72598253 astrophilic_cha...    [NULL] 497c7348-57c5-4...
       2: 0.648016378 0.80499464 credible_dogfis...    [NULL] fe8b9b34-cadc-4...
       3: 0.004258051 0.06525374 astrophilic_cha...    [NULL] d5e47883-8c86-4...
       4: 0.270631802 0.52022284 astrophilic_cha...    [NULL] b3fac308-e907-4...
       5: 0.691437105 0.83152697 astrophilic_cha...    [NULL] 04c22d45-fd69-4...
      ---
    7946: 0.871810698 0.93370804 credible_dogfis...    [NULL] cb7b24e9-4df4-4...
    7947: 0.889867067 0.94332766 astrophilic_cha...    [NULL] 365f9d57-6bc5-4...
    7948: 0.128355911 0.35826793 credible_dogfis...    [NULL] 029c466f-c4bc-4...
    7949: 0.819587740 0.90531085 credible_dogfis...    [NULL] ae18e6f4-ce5c-4...
    7950: 0.907136465         NA astrophilic_cha... <list[1]> d5796b3b-69b1-4...

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
    1: 0.9071365 astrophilic_cha... <list[1]> d5796b3b-69b1-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x          y               keys
            <char>             <char>       <num>      <num>             <char>
       1: finished astrophilic_cha... 0.527050627 0.72598253 497c7348-57c5-4...
       2: finished credible_dogfis... 0.648016378 0.80499464 fe8b9b34-cadc-4...
       3: finished astrophilic_cha... 0.004258051 0.06525374 d5e47883-8c86-4...
       4: finished astrophilic_cha... 0.270631802 0.52022284 b3fac308-e907-4...
       5: finished astrophilic_cha... 0.691437105 0.83152697 04c22d45-fd69-4...
      ---
    7945: finished astrophilic_cha... 0.983962420 0.99194880 5d7ef195-ede2-4...
    7946: finished credible_dogfis... 0.871810698 0.93370804 cb7b24e9-4df4-4...
    7947: finished astrophilic_cha... 0.889867067 0.94332766 365f9d57-6bc5-4...
    7948: finished credible_dogfis... 0.128355911 0.35826793 029c466f-c4bc-4...
    7949: finished credible_dogfis... 0.819587740 0.90531085 ae18e6f4-ce5c-4...

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

    [1] 7949

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
    [1] 0.05650479


    $key
    [1] "19a06cf0-c02c-47c9-9ba7-7f1fc3c54499"

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
