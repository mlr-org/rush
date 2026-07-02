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
       1: electrometrical... 0.05477073 0.2340315 418fe754-af19-4...
       2: insomniac_crown... 0.45566846 0.6750322 7452c3be-fb87-4...
       3: insomniac_crown... 0.19635052 0.4431146 1dbc5ca6-698c-4...
       4: electrometrical... 0.58879076 0.7673270 10a49eca-d8c6-4...
       5: insomniac_crown... 0.24894559 0.4989445 669f171e-9874-4...
      ---
    8602: electrometrical... 0.05997827 0.2449046 1153e8e1-fc9e-4...
    8603: insomniac_crown... 0.21371103 0.4622889 6ac7d982-fbd5-4...
    8604: electrometrical... 0.07433061 0.2726364 b746686a-75a9-4...
    8605: insomniac_crown... 0.01109202 0.1053187 7c8ad3f5-aafa-4...
    8606: electrometrical... 0.14708431 0.3835157 435ad334-a9ed-4...

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
       1: 0.05477073 0.2340315 electrometrical...    [NULL] 418fe754-af19-4...
       2: 0.45566846 0.6750322 insomniac_crown...    [NULL] 7452c3be-fb87-4...
       3: 0.19635052 0.4431146 insomniac_crown...    [NULL] 1dbc5ca6-698c-4...
       4: 0.58879076 0.7673270 electrometrical...    [NULL] 10a49eca-d8c6-4...
       5: 0.24894559 0.4989445 insomniac_crown...    [NULL] 669f171e-9874-4...
      ---
    9295: 0.23836897 0.4882304 electrometrical...    [NULL] c54e395e-1b78-4...
    9296: 0.62522847 0.7907139 insomniac_crown...    [NULL] fadd64a4-12f2-4...
    9297: 0.02039594 0.1428144 electrometrical...    [NULL] 9e0d2709-2651-4...
    9298: 0.72363934        NA insomniac_crown... <list[1]> 7a86d00c-ee7d-4...
    9299: 0.07039691        NA electrometrical... <list[1]> 4cde1e82-2c47-4...

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
    1: 0.72363934 insomniac_crown... <list[1]> 7a86d00c-ee7d-4...
    2: 0.07039691 electrometrical... <list[1]> 4cde1e82-2c47-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished electrometrical... 0.05477073 0.2340315 418fe754-af19-4...
       2: finished insomniac_crown... 0.45566846 0.6750322 7452c3be-fb87-4...
       3: finished insomniac_crown... 0.19635052 0.4431146 1dbc5ca6-698c-4...
       4: finished electrometrical... 0.58879076 0.7673270 10a49eca-d8c6-4...
       5: finished insomniac_crown... 0.24894559 0.4989445 669f171e-9874-4...
      ---
    9293: finished electrometrical... 0.47224821 0.6872032 8fef9dab-eff4-4...
    9294: finished insomniac_crown... 0.42769696 0.6539854 f5c1a547-47ac-4...
    9295: finished electrometrical... 0.23836897 0.4882304 c54e395e-1b78-4...
    9296: finished insomniac_crown... 0.62522847 0.7907139 fadd64a4-12f2-4...
    9297: finished electrometrical... 0.02039594 0.1428144 9e0d2709-2651-4...

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

    [1] 9297

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
    [1] 0.2753483


    $key
    [1] "0d15bee4-e126-4fcf-bb73-3ce69b15c3e9"

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
