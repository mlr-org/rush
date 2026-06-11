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
       1:     blameable_duck 0.82479509 0.9081823 3928a04c-e32c-4...
       2: castiron_weaver... 0.87178139 0.9336923 0e60b351-e7bb-4...
       3: castiron_weaver... 0.16574223 0.4071145 4cedcbed-af37-4...
       4:     blameable_duck 0.23352826 0.4832476 62892624-c9a6-4...
       5: castiron_weaver... 0.61629835 0.7850467 7094e402-b6aa-4...
      ---
    5677: castiron_weaver... 0.28751635 0.5362055 8489c31e-09a4-4...
    5678:     blameable_duck 0.60963970 0.7807943 66e5799d-6ca9-4...
    5679: castiron_weaver... 0.10841083 0.3292580 01a73eb2-aa91-4...
    5680:     blameable_duck 0.95599287 0.9777489 bf7ae54e-cfa3-4...
    5681: castiron_weaver... 0.03837924 0.1959062 2309191e-a671-4...

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
       1: 0.8717814 0.9336923 castiron_weaver... 0e60b351-e7bb-4...
       2: 0.8247951 0.9081823     blameable_duck 3928a04c-e32c-4...
       3: 0.2335283 0.4832476     blameable_duck 62892624-c9a6-4...
       4: 0.1657422 0.4071145 castiron_weaver... 4cedcbed-af37-4...
       5: 0.4790185 0.6921116     blameable_duck fa34f15d-f788-4...
      ---
    6049: 0.5721705 0.7564195     blameable_duck 009e0a99-4ea5-4...
    6050: 0.1954338 0.4420789 castiron_weaver... cfcb96cb-93c3-4...
    6051: 0.2296091 0.4791755     blameable_duck 631a7052-a35f-4...
    6052: 0.2022799        NA castiron_weaver... a7163267-5480-4...
    6053: 0.5759012        NA     blameable_duck 7268aa08-cd9b-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.2022799 castiron_weaver... a7163267-5480-4...
    2: 0.5759012     blameable_duck 7268aa08-cd9b-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running castiron_weaver... 0.2022799 a7163267-5480-4...        NA
       2:  running     blameable_duck 0.5759012 7268aa08-cd9b-4...        NA
       3: finished     blameable_duck 0.8247951 3928a04c-e32c-4... 0.9081823
       4: finished castiron_weaver... 0.8717814 0e60b351-e7bb-4... 0.9336923
       5: finished castiron_weaver... 0.1657422 4cedcbed-af37-4... 0.4071145
      ---
    6049: finished     blameable_duck 0.8997008 e211531b-fd69-4... 0.9485256
    6050: finished castiron_weaver... 0.5865437 1aafdb22-1ca5-4... 0.7658614
    6051: finished     blameable_duck 0.5721705 009e0a99-4ea5-4... 0.7564195
    6052: finished castiron_weaver... 0.1954338 cfcb96cb-93c3-4... 0.4420789
    6053: finished     blameable_duck 0.2296091 631a7052-a35f-4... 0.4791755

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

    [1] 6051

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
    [1] 0.1257596


    $key
    [1] "7f9de3df-28b3-4c0d-81be-eb328f9387ac"

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
