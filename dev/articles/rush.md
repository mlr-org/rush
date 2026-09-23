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
       1: prepubescent_do... 0.7142977 0.8451614 d20c758f-1fcd-4...
       2: foldable_bunny_... 0.1938301 0.4402614 3ac42071-eda0-4...
       3: prepubescent_do... 0.9803706 0.9901366 fa6d52b1-8414-4...
       4: prepubescent_do... 0.9513354 0.9753642 aa03580a-78cb-4...
       5: prepubescent_do... 0.2196943 0.4687156 5fdd6531-8e0e-4...
      ---
    6895: foldable_bunny_... 0.6262433 0.7913554 77beec9c-036e-4...
    6896: prepubescent_do... 0.8424988 0.9178773 a0958486-e744-4...
    6897: foldable_bunny_... 0.7150615 0.8456131 1be043d3-86d3-4...
    6898: prepubescent_do... 0.2906767 0.5391444 2d02bc94-4330-4...
    6899: foldable_bunny_... 0.5418900 0.7361318 b41d7be4-9d81-4...

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
       1: 0.7142977 0.8451614 prepubescent_do...    [NULL] d20c758f-1fcd-4...
       2: 0.1938301 0.4402614 foldable_bunny_...    [NULL] 3ac42071-eda0-4...
       3: 0.9803706 0.9901366 prepubescent_do...    [NULL] fa6d52b1-8414-4...
       4: 0.9513354 0.9753642 prepubescent_do...    [NULL] aa03580a-78cb-4...
       5: 0.2196943 0.4687156 prepubescent_do...    [NULL] 5fdd6531-8e0e-4...
      ---
    7353: 0.4407072 0.6638578 prepubescent_do...    [NULL] e7de459f-57af-4...
    7354: 0.6745384 0.8213029 prepubescent_do...    [NULL] a9c87fbd-8bf5-4...
    7355: 0.6142179 0.7837206 foldable_bunny_...    [NULL] 7aced8aa-8477-4...
    7356: 0.4142102        NA prepubescent_do... <list[1]> ccfa7331-325b-4...
    7357: 0.2970094 0.5449857 foldable_bunny_...    [NULL] 919b01e5-10a3-4...

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
    1: 0.4142102 prepubescent_do... <list[1]> ccfa7331-325b-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished prepubescent_do... 0.7142977 0.8451614 d20c758f-1fcd-4...
       2: finished foldable_bunny_... 0.1938301 0.4402614 3ac42071-eda0-4...
       3: finished prepubescent_do... 0.9803706 0.9901366 fa6d52b1-8414-4...
       4: finished prepubescent_do... 0.9513354 0.9753642 aa03580a-78cb-4...
       5: finished prepubescent_do... 0.2196943 0.4687156 5fdd6531-8e0e-4...
      ---
    7352: finished foldable_bunny_... 0.9137442 0.9558997 5554f944-a6d6-4...
    7353: finished prepubescent_do... 0.4407072 0.6638578 e7de459f-57af-4...
    7354: finished prepubescent_do... 0.6745384 0.8213029 a9c87fbd-8bf5-4...
    7355: finished foldable_bunny_... 0.6142179 0.7837206 7aced8aa-8477-4...
    7356: finished foldable_bunny_... 0.2970094 0.5449857 919b01e5-10a3-4...

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

    [1] 7356

``` r

rush$n_failed_tasks
```

    [1] 1

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
    [1] 0.3604779


    $key
    [1] "5b8986cd-b490-4f4a-9ec8-9a76d2aaa1f8"

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

    Rscript -e 'rush::start_worker(network_id = "my_network", config = list(scheme = "redis", host = "127.0.0.1", port = "6379"))'

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
