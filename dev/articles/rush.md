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
       1: torrential_zere... 0.7500503 0.8660545 03162b08-86b0-4...
       2: overjoyful_ratt... 0.6325816 0.7953500 bf9c3108-9130-4...
       3: torrential_zere... 0.8461500 0.9198641 ee3085b0-3449-4...
       4: overjoyful_ratt... 0.7064952 0.8405327 03a322fc-c9f9-4...
       5: torrential_zere... 0.1906672 0.4366546 0cffdb4a-8d1a-4...
      ---
    6764: overjoyful_ratt... 0.6903488 0.8308723 70a68002-1606-4...
    6765: torrential_zere... 0.5160684 0.7183790 d324ea0f-a46f-4...
    6766: torrential_zere... 0.3948392 0.6283623 cfec9bb8-7f38-4...
    6767: overjoyful_ratt... 0.9252221 0.9618847 b757d6e9-3ada-4...
    6768: torrential_zere... 0.2029776 0.4505304 62c05c02-ed1b-4...

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
       1: 0.63258156 0.7953500 overjoyful_ratt... bf9c3108-9130-4...
       2: 0.75005034 0.8660545 torrential_zere... 03162b08-86b0-4...
       3: 0.84615004 0.9198641 torrential_zere... ee3085b0-3449-4...
       4: 0.70649519 0.8405327 overjoyful_ratt... 03a322fc-c9f9-4...
       5: 0.12617469 0.3552108 overjoyful_ratt... 3b50ed87-8ad9-4...
      ---
    7183: 0.01796958 0.1340507 torrential_zere... bb2ed736-5602-4...
    7184: 0.58215276 0.7629894 overjoyful_ratt... abd8e5a5-7608-4...
    7185: 0.41278119 0.6424805 torrential_zere... f26d9e88-06bb-4...
    7186: 0.45569659 0.6750530 overjoyful_ratt... 0e65e75a-c635-4...
    7187: 0.02776758 0.1666361 torrential_zere... 4c354970-d14b-4...

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

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished torrential_zere... 0.75005034 0.8660545 03162b08-86b0-4...
       2: finished overjoyful_ratt... 0.63258156 0.7953500 bf9c3108-9130-4...
       3: finished torrential_zere... 0.84615004 0.9198641 ee3085b0-3449-4...
       4: finished overjoyful_ratt... 0.70649519 0.8405327 03a322fc-c9f9-4...
       5: finished torrential_zere... 0.19066722 0.4366546 0cffdb4a-8d1a-4...
      ---
    7183: finished torrential_zere... 0.01796958 0.1340507 bb2ed736-5602-4...
    7184: finished overjoyful_ratt... 0.58215276 0.7629894 abd8e5a5-7608-4...
    7185: finished torrential_zere... 0.41278119 0.6424805 f26d9e88-06bb-4...
    7186: finished overjoyful_ratt... 0.45569659 0.6750530 0e65e75a-c635-4...
    7187: finished torrential_zere... 0.02776758 0.1666361 4c354970-d14b-4...

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

    [1] 7187

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
    [1] 0.3102218


    $key
    [1] "6330578b-e5f3-4d07-98ba-fa99d6c77483"

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
