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

                   worker_id          x          y               keys
                      <char>      <num>      <num>             <char>
       1: gnomological_lu... 0.03625529 0.19040823 4a90b988-b7aa-4...
       2: gnomological_lu... 0.85988749 0.92730118 c8dd172c-b17e-4...
       3: gnomological_lu... 0.36945998 0.60783219 ed7e098f-c709-4...
       4: gnomological_lu... 0.30660489 0.55371914 ac5aa0d5-7ccb-4...
       5: gnomological_lu... 0.79377316 0.89093948 0564ebb8-4092-4...
      ---
    7304: gnomological_lu... 0.00682256 0.08259879 7b8166be-9379-4...
    7305: soured_riogrand... 0.04898453 0.22132449 57b59ba2-7bb8-4...
    7306: gnomological_lu... 0.82741592 0.90962405 aa688f70-9c3a-4...
    7307: soured_riogrand... 0.57895786 0.76089281 26104f33-6c12-4...
    7308: gnomological_lu... 0.83260590 0.91247241 fa1a434d-19db-4...

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
       1: 0.03625529 0.1904082 gnomological_lu... 4a90b988-b7aa-4...
       2: 0.02040422 0.1428433 soured_riogrand... 2daf2f18-0627-4...
       3: 0.85988749 0.9273012 gnomological_lu... c8dd172c-b17e-4...
       4: 0.36945998 0.6078322 gnomological_lu... ed7e098f-c709-4...
       5: 0.30660489 0.5537191 gnomological_lu... ac5aa0d5-7ccb-4...
      ---
    7790: 0.55603477 0.7456774 soured_riogrand... 91af54fd-dbbd-4...
    7791: 0.49660668 0.7047033 gnomological_lu... 35896961-afc9-4...
    7792: 0.53357687 0.7304635 soured_riogrand... 6cc77b01-2491-4...
    7793: 0.41537525        NA gnomological_lu... b5278222-ccc4-4...
    7794: 0.55522301        NA soured_riogrand... 25865aa7-84c7-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.4153753 gnomological_lu... b5278222-ccc4-4...
    2: 0.5552230 soured_riogrand... 25865aa7-84c7-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running gnomological_lu... 0.41537525 b5278222-ccc4-4...        NA
       2:  running soured_riogrand... 0.55522301 25865aa7-84c7-4...        NA
       3: finished gnomological_lu... 0.03625529 4a90b988-b7aa-4... 0.1904082
       4: finished gnomological_lu... 0.85988749 c8dd172c-b17e-4... 0.9273012
       5: finished gnomological_lu... 0.36945998 ed7e098f-c709-4... 0.6078322
      ---
    7790: finished soured_riogrand... 0.93408205 c62ba471-6104-4... 0.9664792
    7791: finished gnomological_lu... 0.42252953 7d6193d0-226a-4... 0.6500227
    7792: finished soured_riogrand... 0.55603477 91af54fd-dbbd-4... 0.7456774
    7793: finished gnomological_lu... 0.49660668 35896961-afc9-4... 0.7047033
    7794: finished soured_riogrand... 0.53357687 6cc77b01-2491-4... 0.7304635

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

    [1] 7792

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
    [1] 0.2498058


    $key
    [1] "e4f06511-4767-4c3e-96ab-dfd1e97fb815"

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
