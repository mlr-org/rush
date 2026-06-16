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
       1: discountable_gu... 0.8098488 0.8999160 4f971dcf-5c85-4...
       2: discountable_gu... 0.7435351 0.8622848 9a6ba1d9-234f-4...
       3: choosy_owlbutte... 0.7804606 0.8834368 3bc7ff78-f5f4-4...
       4: discountable_gu... 0.1551503 0.3938913 e5ce05ee-e21f-4...
       5: choosy_owlbutte... 0.7372445 0.8586294 cbfbeb65-1b24-4...
      ---
    6694: discountable_gu... 0.7589608 0.8711835 314c584c-efba-4...
    6695: choosy_owlbutte... 0.7131634 0.8444900 f4c8c4b5-69c8-4...
    6696: discountable_gu... 0.8064150 0.8980061 c2a296ae-590f-4...
    6697: choosy_owlbutte... 0.4502479 0.6710051 0926539d-d8fc-4...
    6698: choosy_owlbutte... 0.5547078 0.7447871 20093b9a-8b3e-4...

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
       1: 0.78046062 0.8834368 choosy_owlbutte... 3bc7ff78-f5f4-4...
       2: 0.80984883 0.8999160 discountable_gu... 4f971dcf-5c85-4...
       3: 0.74353508 0.8622848 discountable_gu... 9a6ba1d9-234f-4...
       4: 0.15515033 0.3938913 discountable_gu... e5ce05ee-e21f-4...
       5: 0.73724452 0.8586294 choosy_owlbutte... cbfbeb65-1b24-4...
      ---
    7129: 0.06596554 0.2568376 discountable_gu... 72fe288f-9a25-4...
    7130: 0.18433424 0.4293416 choosy_owlbutte... 3076c659-ffbf-4...
    7131: 0.87092948 0.9332360 discountable_gu... 51eebc0f-65a7-4...
    7132: 0.73168516        NA choosy_owlbutte... 52064305-6b1b-4...
    7133: 0.78699676        NA discountable_gu... 82b4be39-71c6-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.7316852 choosy_owlbutte... 52064305-6b1b-4...
    2: 0.7869968 discountable_gu... 82b4be39-71c6-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running choosy_owlbutte... 0.73168516 52064305-6b1b-4...        NA
       2:  running discountable_gu... 0.78699676 82b4be39-71c6-4...        NA
       3: finished discountable_gu... 0.80984883 4f971dcf-5c85-4... 0.8999160
       4: finished discountable_gu... 0.74353508 9a6ba1d9-234f-4... 0.8622848
       5: finished choosy_owlbutte... 0.78046062 3bc7ff78-f5f4-4... 0.8834368
      ---
    7129: finished discountable_gu... 0.06584885 f8725813-1c25-4... 0.2566103
    7130: finished choosy_owlbutte... 0.59022709 659b4c42-196e-4... 0.7682624
    7131: finished discountable_gu... 0.06596554 72fe288f-9a25-4... 0.2568376
    7132: finished choosy_owlbutte... 0.18433424 3076c659-ffbf-4... 0.4293416
    7133: finished discountable_gu... 0.87092948 51eebc0f-65a7-4... 0.9332360

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

    [1] 7131

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
    [1] 0.7058225


    $key
    [1] "db623c17-9506-4fab-987b-2eed72e6e129"

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
