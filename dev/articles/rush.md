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
       1: reflectible_sun... 0.033355674 0.18263536 232cf570-e7be-4...
       2: reflectible_sun... 0.157110073 0.39637113 6eb6e990-e19e-4...
       3: reflectible_sun... 0.813017759 0.90167497 266cb91a-2f7f-4...
       4: reflectible_sun... 0.970567015 0.98517360 4173d270-0b75-4...
       5: reflectible_sun... 0.237922440 0.48777294 a12c5599-2090-4...
      ---
    7306:     bigboned_camel 0.450124699 0.67091333 c420bd10-3efc-4...
    7307: reflectible_sun... 0.003052619 0.05525051 754c55c6-bffd-4...
    7308:     bigboned_camel 0.721232280 0.84925395 666d26b4-501a-4...
    7309: reflectible_sun... 0.534504565 0.73109819 3d44b86a-0e7e-4...
    7310:     bigboned_camel 0.510157461 0.71425308 6dcae1b0-9d5d-4...

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
       1: 0.03335567 0.1826354 reflectible_sun... 232cf570-e7be-4...
       2: 0.21577999 0.4645212     bigboned_camel 71710c77-9b51-4...
       3: 0.15711007 0.3963711 reflectible_sun... 6eb6e990-e19e-4...
       4: 0.81301776 0.9016750 reflectible_sun... 266cb91a-2f7f-4...
       5: 0.97056701 0.9851736 reflectible_sun... 4173d270-0b75-4...
      ---
    7818: 0.76787591 0.8762853     bigboned_camel 8ba5a40e-2fb4-4...
    7819: 0.40034923 0.6327316 reflectible_sun... 6c71f938-0e9f-4...
    7820: 0.79972827 0.8942753 reflectible_sun... 72539aa0-77df-4...
    7821: 0.03201939 0.1789396     bigboned_camel a7148a5a-2fa3-4...
    7822: 0.21713298        NA reflectible_sun... 6ba2a025-fcae-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

              x          worker_id               keys
          <num>             <char>             <char>
    1: 0.217133 reflectible_sun... 6ba2a025-fcae-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running reflectible_sun... 0.21713298 6ba2a025-fcae-4...        NA
       2: finished reflectible_sun... 0.03335567 232cf570-e7be-4... 0.1826354
       3: finished reflectible_sun... 0.15711007 6eb6e990-e19e-4... 0.3963711
       4: finished reflectible_sun... 0.81301776 266cb91a-2f7f-4... 0.9016750
       5: finished reflectible_sun... 0.97056701 4173d270-0b75-4... 0.9851736
      ---
    7818: finished reflectible_sun... 0.41267979 8a539e85-e8d2-4... 0.6424016
    7819: finished reflectible_sun... 0.40034923 6c71f938-0e9f-4... 0.6327316
    7820: finished     bigboned_camel 0.76787591 8ba5a40e-2fb4-4... 0.8762853
    7821: finished reflectible_sun... 0.79972827 72539aa0-77df-4... 0.8942753
    7822: finished     bigboned_camel 0.03201939 a7148a5a-2fa3-4... 0.1789396

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

    [1] 7821

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
    [1] 0.83571


    $key
    [1] "af5df0fd-75ef-474b-8dbf-8649a86c219e"

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
