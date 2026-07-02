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
       1: condemnable_afr... 0.40093900 0.6331974 8ff89a67-c5a6-4...
       2: parsimonious_po... 0.07967203 0.2822623 b9463fcf-801f-4...
       3: condemnable_afr... 0.63247747 0.7952845 bc0f95cb-d755-4...
       4: condemnable_afr... 0.23417275 0.4839140 67935f92-8cfa-4...
       5: condemnable_afr... 0.47781452 0.6912413 796652a0-5569-4...
      ---
    7243: condemnable_afr... 0.68253861 0.8261590 b30f92ad-a0ce-4...
    7244: condemnable_afr... 0.55771537 0.7468034 2edd1bc7-c7b6-4...
    7245: parsimonious_po... 0.47616010 0.6900435 467eaf7c-a84a-4...
    7246: parsimonious_po... 0.39305785 0.6269433 0a991d17-2540-4...
    7247: condemnable_afr... 0.94952514 0.9744358 f2d9b974-b679-4...

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
       1: 0.40093900 0.6331974 condemnable_afr... 8ff89a67-c5a6-4...
       2: 0.07967203 0.2822623 parsimonious_po... b9463fcf-801f-4...
       3: 0.63247747 0.7952845 condemnable_afr... bc0f95cb-d755-4...
       4: 0.73490720 0.8572673 parsimonious_po... 7653b848-a7b0-4...
       5: 0.23417275 0.4839140 condemnable_afr... 67935f92-8cfa-4...
      ---
    7711: 0.21904602 0.4680235 condemnable_afr... d5023fa7-8c59-4...
    7712: 0.05058361 0.2249080 parsimonious_po... 60796ca9-8c4c-4...
    7713: 0.02031555 0.1425326 condemnable_afr... 1d41a39e-34d2-4...
    7714: 0.60431473 0.7773768 parsimonious_po... 2ebbfe09-de59-4...
    7715: 0.57887875 0.7608408 parsimonious_po... bbf885a0-a94e-4...

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
       1: finished condemnable_afr... 0.40093900 0.6331974 8ff89a67-c5a6-4...
       2: finished parsimonious_po... 0.07967203 0.2822623 b9463fcf-801f-4...
       3: finished condemnable_afr... 0.63247747 0.7952845 bc0f95cb-d755-4...
       4: finished condemnable_afr... 0.23417275 0.4839140 67935f92-8cfa-4...
       5: finished condemnable_afr... 0.47781452 0.6912413 796652a0-5569-4...
      ---
    7711: finished condemnable_afr... 0.21904602 0.4680235 d5023fa7-8c59-4...
    7712: finished parsimonious_po... 0.05058361 0.2249080 60796ca9-8c4c-4...
    7713: finished parsimonious_po... 0.60431473 0.7773768 2ebbfe09-de59-4...
    7714: finished condemnable_afr... 0.02031555 0.1425326 1d41a39e-34d2-4...
    7715: finished parsimonious_po... 0.57887875 0.7608408 bbf885a0-a94e-4...

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

    [1] 7715

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
    [1] 0.9020621


    $key
    [1] "440d857f-038d-4c27-b24d-1683ae68de66"

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
