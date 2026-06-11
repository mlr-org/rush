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
       1:       marginal_eft 0.4220824 0.6496787 21ccfd4c-788c-4...
       2:       marginal_eft 0.3545553 0.5954455 55413284-5a3a-4...
       3: lightsome_manti... 0.3018042 0.5493670 cfc37361-fec9-4...
       4:       marginal_eft 0.4179300 0.6464751 46ce8e01-0636-4...
       5: lightsome_manti... 0.6309562 0.7943275 7c0d2fae-a0a6-4...
      ---
    8786:       marginal_eft 0.4001658 0.6325866 1eed34d4-13d4-4...
    8787:       marginal_eft 0.2961140 0.5441636 918c5959-a35c-4...
    8788: lightsome_manti... 0.1587533 0.3984386 e8233622-e0c7-4...
    8789:       marginal_eft 0.2542064 0.5041889 409933dd-6a19-4...
    8790: lightsome_manti... 0.3301672 0.5746017 f985cc36-8b31-4...

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
       1: 0.42208243 0.6496787       marginal_eft 21ccfd4c-788c-4...
       2: 0.30180415 0.5493670 lightsome_manti... cfc37361-fec9-4...
       3: 0.35455531 0.5954455       marginal_eft 55413284-5a3a-4...
       4: 0.41793005 0.6464751       marginal_eft 46ce8e01-0636-4...
       5: 0.63095620 0.7943275 lightsome_manti... 7c0d2fae-a0a6-4...
      ---
    9347: 0.67133493 0.8193503       marginal_eft e53c7c2b-0611-4...
    9348: 0.33483642 0.5786505 lightsome_manti... 9e0a9961-df81-4...
    9349: 0.53662018 0.7325436       marginal_eft 954d2c1c-0458-4...
    9350: 0.09760684 0.3124209       marginal_eft 7db8732c-d548-4...
    9351: 0.14521599 0.3810722 lightsome_manti... 89ac9444-f174-4...

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
       1: finished       marginal_eft 0.42208243 0.6496787 21ccfd4c-788c-4...
       2: finished       marginal_eft 0.35455531 0.5954455 55413284-5a3a-4...
       3: finished lightsome_manti... 0.30180415 0.5493670 cfc37361-fec9-4...
       4: finished       marginal_eft 0.41793005 0.6464751 46ce8e01-0636-4...
       5: finished lightsome_manti... 0.63095620 0.7943275 7c0d2fae-a0a6-4...
      ---
    9347: finished       marginal_eft 0.67133493 0.8193503 e53c7c2b-0611-4...
    9348: finished       marginal_eft 0.53662018 0.7325436 954d2c1c-0458-4...
    9349: finished lightsome_manti... 0.33483642 0.5786505 9e0a9961-df81-4...
    9350: finished       marginal_eft 0.09760684 0.3124209 7db8732c-d548-4...
    9351: finished lightsome_manti... 0.14521599 0.3810722 89ac9444-f174-4...

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

    [1] 9351

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
    [1] 0.3987268


    $key
    [1] "0447e0e8-985d-4bb3-a73b-1ccda445d5f3"

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
