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
       1: operose_chinchi... 0.14137770 0.3760023 f56f6b30-0b80-4...
       2: operose_chinchi... 0.39343429 0.6272434 614b02df-a45d-4...
       3:    traumatic_burro 0.11932353 0.3454324 24351256-31ea-4...
       4: operose_chinchi... 0.58674733 0.7659943 a957cd4d-b366-4...
       5: operose_chinchi... 0.04217213 0.2053585 2cc0bf6a-ce9a-4...
      ---
    6104: operose_chinchi... 0.44777450 0.6691595 1e8d5eae-b466-4...
    6105:    traumatic_burro 0.06131867 0.2476261 8771529c-2e8e-4...
    6106: operose_chinchi... 0.01046053 0.1022767 ea0fce79-c395-4...
    6107: operose_chinchi... 0.93103754 0.9649029 48e7538c-08e1-4...
    6108:    traumatic_burro 0.87016929 0.9328287 ce6aca5d-3249-4...

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
       1: 0.14137770 0.3760023 operose_chinchi... f56f6b30-0b80-4...
       2: 0.11932353 0.3454324    traumatic_burro 24351256-31ea-4...
       3: 0.39343429 0.6272434 operose_chinchi... 614b02df-a45d-4...
       4: 0.58674733 0.7659943 operose_chinchi... a957cd4d-b366-4...
       5: 0.04217213 0.2053585 operose_chinchi... 2cc0bf6a-ce9a-4...
      ---
    6504: 0.83434302 0.9134238    traumatic_burro 69912b95-da7c-4...
    6505: 0.38639302 0.6216052 operose_chinchi... 2c549299-d9a5-4...
    6506: 0.27338972 0.5228668    traumatic_burro 86f69675-04d7-4...
    6507: 0.42710673 0.6535340 operose_chinchi... b47c48f3-9090-4...
    6508: 0.90380456 0.9506864    traumatic_burro 959e085f-10a7-4...

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
       1: finished operose_chinchi... 0.14137770 0.3760023 f56f6b30-0b80-4...
       2: finished operose_chinchi... 0.39343429 0.6272434 614b02df-a45d-4...
       3: finished    traumatic_burro 0.11932353 0.3454324 24351256-31ea-4...
       4: finished operose_chinchi... 0.58674733 0.7659943 a957cd4d-b366-4...
       5: finished operose_chinchi... 0.04217213 0.2053585 2cc0bf6a-ce9a-4...
      ---
    6504: finished    traumatic_burro 0.83434302 0.9134238 69912b95-da7c-4...
    6505: finished operose_chinchi... 0.38639302 0.6216052 2c549299-d9a5-4...
    6506: finished    traumatic_burro 0.27338972 0.5228668 86f69675-04d7-4...
    6507: finished operose_chinchi... 0.42710673 0.6535340 b47c48f3-9090-4...
    6508: finished    traumatic_burro 0.90380456 0.9506864 959e085f-10a7-4...

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

    [1] 6508

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
    [1] 0.0866334


    $key
    [1] "a8eb66f0-58a4-42ad-9a43-f44e409a1c03"

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
