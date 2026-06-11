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
       1:      gooey_buffalo 0.42074540 0.6486489 b555544b-01fa-4...
       2:      gooey_buffalo 0.01645543 0.1282787 5cbfe8ed-3f8e-4...
       3: deterministic_w... 0.91392845 0.9559961 27e2e037-b666-4...
       4:      gooey_buffalo 0.77142213 0.8783064 b578ea41-f790-4...
       5: deterministic_w... 0.96840736 0.9840769 6b6485bf-f2eb-4...
      ---
    6843:      gooey_buffalo 0.21514341 0.4638355 564cfc0f-8b2c-4...
    6844: deterministic_w... 0.65877203 0.8116477 f101e1c2-7718-4...
    6845:      gooey_buffalo 0.79083666 0.8892900 3f52ea7b-f423-4...
    6846: deterministic_w... 0.31072173 0.5574242 28f3cac9-bf98-4...
    6847:      gooey_buffalo 0.33725885 0.5807399 ad3ff697-1075-4...

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
       1: 0.420745395 0.64864890      gooey_buffalo b555544b-01fa-4...
       2: 0.913928452 0.95599605 deterministic_w... 27e2e037-b666-4...
       3: 0.016455433 0.12827873      gooey_buffalo 5cbfe8ed-3f8e-4...
       4: 0.771422132 0.87830640      gooey_buffalo b578ea41-f790-4...
       5: 0.968407364 0.98407691 deterministic_w... 6b6485bf-f2eb-4...
      ---
    7273: 0.426435169 0.65302004 deterministic_w... 6c970824-783e-4...
    7274: 0.517022572 0.71904282      gooey_buffalo 7ff90ded-bc10-4...
    7275: 0.120040828 0.34646909      gooey_buffalo 96cbe012-03c3-4...
    7276: 0.006406729 0.08004205 deterministic_w... 73fea1c5-02bb-4...
    7277: 0.516527315         NA      gooey_buffalo 7974eba7-dfce-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x     worker_id               keys
           <num>        <char>             <char>
    1: 0.5165273 gooey_buffalo 7974eba7-dfce-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x               keys          y
            <char>             <char>       <num>             <char>      <num>
       1:  running      gooey_buffalo 0.516527315 7974eba7-dfce-4...         NA
       2: finished      gooey_buffalo 0.420745395 b555544b-01fa-4... 0.64864890
       3: finished      gooey_buffalo 0.016455433 5cbfe8ed-3f8e-4... 0.12827873
       4: finished deterministic_w... 0.913928452 27e2e037-b666-4... 0.95599605
       5: finished      gooey_buffalo 0.771422132 b578ea41-f790-4... 0.87830640
      ---
    7273: finished      gooey_buffalo 0.927243656 fa907ee7-c989-4... 0.96293492
    7274: finished deterministic_w... 0.426435169 6c970824-783e-4... 0.65302004
    7275: finished      gooey_buffalo 0.517022572 7ff90ded-bc10-4... 0.71904282
    7276: finished      gooey_buffalo 0.120040828 96cbe012-03c3-4... 0.34646909
    7277: finished deterministic_w... 0.006406729 73fea1c5-02bb-4... 0.08004205

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

    [1] 7276

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
    [1] 0.2153147


    $key
    [1] "111f1a0c-9dc3-408a-a5d1-48d0f6e5021e"

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
