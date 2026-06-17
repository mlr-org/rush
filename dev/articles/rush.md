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
       1: inflammable_per... 0.10147027 0.3185440 481c6917-9110-4...
       2: lovecraftian_hy... 0.24660645 0.4965949 a4b409aa-5f9f-4...
       3: inflammable_per... 0.26036732 0.5102620 5283698c-60d8-4...
       4: lovecraftian_hy... 0.72502796 0.8514857 2da30365-e748-4...
       5: inflammable_per... 0.32895275 0.5735440 f48a40f2-d66c-4...
      ---
    6818: inflammable_per... 0.49798544 0.7056808 8ccddc1c-a4d3-4...
    6819: lovecraftian_hy... 0.24358684 0.4935452 c8c47e0d-2449-4...
    6820: inflammable_per... 0.51213327 0.7156349 794978a1-9788-4...
    6821: lovecraftian_hy... 0.01592543 0.1261960 874c2dd7-c77f-4...
    6822: inflammable_per... 0.98570483 0.9928267 5ad3541b-2793-4...

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
       1: 0.1014703 0.3185440 inflammable_per... 481c6917-9110-4...
       2: 0.2466064 0.4965949 lovecraftian_hy... a4b409aa-5f9f-4...
       3: 0.2603673 0.5102620 inflammable_per... 5283698c-60d8-4...
       4: 0.7250280 0.8514857 lovecraftian_hy... 2da30365-e748-4...
       5: 0.3289527 0.5735440 inflammable_per... f48a40f2-d66c-4...
      ---
    7242: 0.3675780 0.6062821 lovecraftian_hy... af3f613e-84ad-4...
    7243: 0.2040311 0.4516980 inflammable_per... d0321639-4671-4...
    7244: 0.1344793 0.3667142 lovecraftian_hy... 62f28c66-a247-4...
    7245: 0.9932558        NA lovecraftian_hy... fe5669b4-e1e0-4...
    7246: 0.6195916        NA inflammable_per... 122a278d-3916-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.9932558 lovecraftian_hy... fe5669b4-e1e0-4...
    2: 0.6195916 inflammable_per... 122a278d-3916-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running lovecraftian_hy... 0.9932558 fe5669b4-e1e0-4...        NA
       2:  running inflammable_per... 0.6195916 122a278d-3916-4...        NA
       3: finished inflammable_per... 0.1014703 481c6917-9110-4... 0.3185440
       4: finished lovecraftian_hy... 0.2466064 a4b409aa-5f9f-4... 0.4965949
       5: finished inflammable_per... 0.2603673 5283698c-60d8-4... 0.5102620
      ---
    7242: finished lovecraftian_hy... 0.4444817 c8c64617-053d-4... 0.6666946
    7243: finished lovecraftian_hy... 0.3675780 af3f613e-84ad-4... 0.6062821
    7244: finished inflammable_per... 0.1358393 af6b75bc-555a-4... 0.3685639
    7245: finished lovecraftian_hy... 0.1344793 62f28c66-a247-4... 0.3667142
    7246: finished inflammable_per... 0.2040311 d0321639-4671-4... 0.4516980

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

    [1] 7244

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
    [1] 0.18864


    $key
    [1] "34d8d44d-b117-412d-bcdd-85c79d82d8a1"

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
