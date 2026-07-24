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
       1: slothful_kid_40... 0.58897078 0.7674443 187cebb3-f02a-4...
       2: horrorstruck_zi... 0.45576652 0.6751048 3dfa2f30-ead5-4...
       3: slothful_kid_40... 0.07489818 0.2736753 4e97cb87-fba0-4...
       4: slothful_kid_40... 0.27166633 0.5212162 64d307d7-9368-4...
       5: slothful_kid_40... 0.76704311 0.8758100 eb47129c-6706-4...
      ---
    7143: horrorstruck_zi... 0.66295892 0.8142229 7fc32771-d785-4...
    7144: slothful_kid_40... 0.16606639 0.4075124 af9337a3-cb43-4...
    7145: horrorstruck_zi... 0.22761786 0.4770931 f824fc76-d751-4...
    7146: horrorstruck_zi... 0.76861166 0.8767050 15e620ce-9f56-4...
    7147: slothful_kid_40... 0.27181982 0.5213634 9f3c0fff-7393-4...

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
       1: 0.58897078 0.7674443 slothful_kid_40...    [NULL] 187cebb3-f02a-4...
       2: 0.45576652 0.6751048 horrorstruck_zi...    [NULL] 3dfa2f30-ead5-4...
       3: 0.07489818 0.2736753 slothful_kid_40...    [NULL] 4e97cb87-fba0-4...
       4: 0.11929312 0.3453884 horrorstruck_zi...    [NULL] 1bb12f89-5109-4...
       5: 0.27166633 0.5212162 slothful_kid_40...    [NULL] 64d307d7-9368-4...
      ---
    7628: 0.72832001 0.8534167 horrorstruck_zi...    [NULL] a94db452-5535-4...
    7629: 0.25024646 0.5002464 slothful_kid_40...    [NULL] d31a11a8-471c-4...
    7630: 0.77091802 0.8780194 horrorstruck_zi...    [NULL] a5a5baea-ce9f-4...
    7631: 0.88830364 0.9424986 slothful_kid_40...    [NULL] 07aecac2-82b6-4...
    7632: 0.36306361        NA horrorstruck_zi... <list[1]> 4465c90d-3a62-4...

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
    1: 0.3630636 horrorstruck_zi... <list[1]> 4465c90d-3a62-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished slothful_kid_40... 0.58897078 0.7674443 187cebb3-f02a-4...
       2: finished horrorstruck_zi... 0.45576652 0.6751048 3dfa2f30-ead5-4...
       3: finished slothful_kid_40... 0.07489818 0.2736753 4e97cb87-fba0-4...
       4: finished slothful_kid_40... 0.27166633 0.5212162 64d307d7-9368-4...
       5: finished slothful_kid_40... 0.76704311 0.8758100 eb47129c-6706-4...
      ---
    7627: finished slothful_kid_40... 0.29458139 0.5427535 8d80a22d-0ead-4...
    7628: finished horrorstruck_zi... 0.72832001 0.8534167 a94db452-5535-4...
    7629: finished slothful_kid_40... 0.25024646 0.5002464 d31a11a8-471c-4...
    7630: finished horrorstruck_zi... 0.77091802 0.8780194 a5a5baea-ce9f-4...
    7631: finished slothful_kid_40... 0.88830364 0.9424986 07aecac2-82b6-4...

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

    [1] 7631

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
    [1] 0.4813547


    $key
    [1] "6a50d8c2-a06c-4243-b3e0-37871b727b54"

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
