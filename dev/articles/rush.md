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
       1: antipolitical_i... 0.4293818 0.6552723 3a1c978a-f019-4...
       2: antipolitical_i... 0.7822790 0.8844654 c71e66ce-45f8-4...
       3: antipolitical_i... 0.4588248 0.6773660 71b05029-fb5b-4...
       4: antipolitical_i... 0.8382106 0.9155384 28615c58-49ae-4...
       5: antipolitical_i... 0.5082108 0.7128890 1b2119b6-42d9-4...
      ---
    9622: antipolitical_i... 0.2913157 0.5397367 7aa680ba-2b30-4...
    9623: contemnible_que... 0.4126388 0.6423696 17e2692d-91e9-4...
    9624: antipolitical_i... 0.6279545 0.7924358 ef7771d6-2e59-4...
    9625: antipolitical_i... 0.5882791 0.7669936 f969e212-936e-4...
    9626: contemnible_que... 0.9944892 0.9972408 94957708-8e4d-4...

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

                     x          y          worker_id               keys
                 <num>      <num>             <char>             <char>
        1: 0.953436013 0.97644048 contemnible_que... 2cd91158-c6be-4...
        2: 0.429381806 0.65527231 antipolitical_i... 3a1c978a-f019-4...
        3: 0.782278971 0.88446536 antipolitical_i... c71e66ce-45f8-4...
        4: 0.458824755 0.67736604 antipolitical_i... 71b05029-fb5b-4...
        5: 0.838210558 0.91553840 antipolitical_i... 28615c58-49ae-4...
       ---
    10288: 0.052084398 0.22822007 antipolitical_i... 7f31ceda-378c-4...
    10289: 0.844369040 0.91889555 contemnible_que... 5fbd1768-292c-4...
    10290: 0.003541212 0.05950808 antipolitical_i... ac2ff017-11d2-4...
    10291: 0.553882838 0.74423305 antipolitical_i... 620b71d5-6e4a-4...
    10292: 0.383783821 0.61950288 contemnible_que... 3f35b51d-c262-4...

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

              state          worker_id           x          y               keys
             <char>             <char>       <num>      <num>             <char>
        1: finished antipolitical_i... 0.429381806 0.65527231 3a1c978a-f019-4...
        2: finished antipolitical_i... 0.782278971 0.88446536 c71e66ce-45f8-4...
        3: finished antipolitical_i... 0.458824755 0.67736604 71b05029-fb5b-4...
        4: finished antipolitical_i... 0.838210558 0.91553840 28615c58-49ae-4...
        5: finished antipolitical_i... 0.508210790 0.71288904 1b2119b6-42d9-4...
       ---
    10288: finished antipolitical_i... 0.052084398 0.22822007 7f31ceda-378c-4...
    10289: finished contemnible_que... 0.844369040 0.91889555 5fbd1768-292c-4...
    10290: finished antipolitical_i... 0.003541212 0.05950808 ac2ff017-11d2-4...
    10291: finished antipolitical_i... 0.553882838 0.74423305 620b71d5-6e4a-4...
    10292: finished contemnible_que... 0.383783821 0.61950288 3f35b51d-c262-4...

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

    [1] 10292

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
    [1] 0.6849033


    $key
    [1] "8f38332e-9f3e-4395-9430-d6774774f99e"

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
