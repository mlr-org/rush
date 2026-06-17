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
       1: jocund_whapuku 0.7190515 0.8479690 33804842-a60e-4...
       2:  deathful_deer 0.7382791 0.8592317 3a500418-9a8f-4...
       3: jocund_whapuku 0.3302085 0.5746377 ce1f415e-0aab-4...
       4:  deathful_deer 0.7330019 0.8561553 8f61ee21-ce5e-4...
       5: jocund_whapuku 0.8750066 0.9354179 2c8c2c5f-8d84-4...
      ---
    8518: jocund_whapuku 0.4478556 0.6692201 eb1caed3-6b9d-4...
    8519:  deathful_deer 0.8275167 0.9096795 dc0d7ca2-0f60-4...
    8520: jocund_whapuku 0.6735821 0.8207205 216e4037-dc8a-4...
    8521:  deathful_deer 0.3945993 0.6281714 0b75f705-a84a-4...
    8522: jocund_whapuku 0.6109590 0.7816387 3b8b03d2-e60e-4...

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

                    x          y      worker_id               keys
                <num>      <num>         <char>             <char>
       1: 0.719051497 0.84796904 jocund_whapuku 33804842-a60e-4...
       2: 0.738279129 0.85923171  deathful_deer 3a500418-9a8f-4...
       3: 0.330208465 0.57463768 jocund_whapuku ce1f415e-0aab-4...
       4: 0.733001891 0.85615530  deathful_deer 8f61ee21-ce5e-4...
       5: 0.875006602 0.93541788 jocund_whapuku 2c8c2c5f-8d84-4...
      ---
    9096: 0.318863129 0.56467967  deathful_deer 6aecc341-feb5-4...
    9097: 0.003718078 0.06097605 jocund_whapuku 510e67fd-a129-4...
    9098: 0.046756196 0.21623181  deathful_deer 1b7bc4ea-acb6-4...
    9099: 0.485539059 0.69680633 jocund_whapuku 439bc4f0-fc50-4...
    9100: 0.543053596         NA  deathful_deer 97b6a0b1-cc40-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x     worker_id               keys
           <num>        <char>             <char>
    1: 0.5430536 deathful_deer 97b6a0b1-cc40-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state      worker_id           x               keys          y
            <char>         <char>       <num>             <char>      <num>
       1:  running  deathful_deer 0.543053596 97b6a0b1-cc40-4...         NA
       2: finished jocund_whapuku 0.719051497 33804842-a60e-4... 0.84796904
       3: finished  deathful_deer 0.738279129 3a500418-9a8f-4... 0.85923171
       4: finished jocund_whapuku 0.330208465 ce1f415e-0aab-4... 0.57463768
       5: finished  deathful_deer 0.733001891 8f61ee21-ce5e-4... 0.85615530
      ---
    9096: finished jocund_whapuku 0.369934246 8989978d-a062-4... 0.60822220
    9097: finished  deathful_deer 0.318863129 6aecc341-feb5-4... 0.56467967
    9098: finished jocund_whapuku 0.003718078 510e67fd-a129-4... 0.06097605
    9099: finished  deathful_deer 0.046756196 1b7bc4ea-acb6-4... 0.21623181
    9100: finished jocund_whapuku 0.485539059 439bc4f0-fc50-4... 0.69680633

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

    [1] 9099

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
    [1] 0.04614681


    $key
    [1] "261eb578-b901-4e17-9101-088580bb4f90"

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
