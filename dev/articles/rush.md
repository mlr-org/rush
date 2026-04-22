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
       1: amaranth_woolly... 0.5993274 0.7741624 a0d9fe6d-9dac-4...
       2: amaranth_woolly... 0.1506323 0.3881138 7c14e57b-5397-4...
       3: amaranth_woolly... 0.9157165 0.9569308 4a9a828b-1790-4...
       4: amaranth_woolly... 0.9116383 0.9547975 ec2e8817-db93-4...
       5:     eccentric_tick 0.1060173 0.3256030 d3994813-25f4-4...
      ---
    5781:     eccentric_tick 0.9456801 0.9724609 6d1e27eb-7758-4...
    5782: amaranth_woolly... 0.3110789 0.5577444 b5cbd153-1c19-4...
    5783:     eccentric_tick 0.5984548 0.7735986 19ababc7-4d72-4...
    5784: amaranth_woolly... 0.8325514 0.9124425 a26d1a84-b941-4...
    5785:     eccentric_tick 0.8988136 0.9480578 4a3fcbaa-7189-4...

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
       1: 0.5993274 0.7741624 amaranth_woolly... a0d9fe6d-9dac-4...
       2: 0.1060173 0.3256030     eccentric_tick d3994813-25f4-4...
       3: 0.1506323 0.3881138 amaranth_woolly... 7c14e57b-5397-4...
       4: 0.9157165 0.9569308 amaranth_woolly... 4a9a828b-1790-4...
       5: 0.9116383 0.9547975 amaranth_woolly... ec2e8817-db93-4...
      ---
    6162: 0.9880601 0.9940121 amaranth_woolly... 4db94129-bf09-4...
    6163: 0.1279828 0.3577469     eccentric_tick f66ee2ac-abd9-4...
    6164: 0.4222416 0.6498012 amaranth_woolly... abf0778f-97d8-4...
    6165: 0.6445744 0.8028539     eccentric_tick 3815641d-500c-4...
    6166: 0.6390959        NA amaranth_woolly... 45d9b50e-59e6-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.6390959 amaranth_woolly... 45d9b50e-59e6-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running amaranth_woolly... 0.6390959 45d9b50e-59e6-4...        NA
       2: finished amaranth_woolly... 0.5993274 a0d9fe6d-9dac-4... 0.7741624
       3: finished amaranth_woolly... 0.1506323 7c14e57b-5397-4... 0.3881138
       4: finished amaranth_woolly... 0.9157165 4a9a828b-1790-4... 0.9569308
       5: finished amaranth_woolly... 0.9116383 ec2e8817-db93-4... 0.9547975
      ---
    6162: finished     eccentric_tick 0.5596490 22068987-6cc7-4... 0.7480969
    6163: finished amaranth_woolly... 0.9880601 4db94129-bf09-4... 0.9940121
    6164: finished     eccentric_tick 0.1279828 f66ee2ac-abd9-4... 0.3577469
    6165: finished amaranth_woolly... 0.4222416 abf0778f-97d8-4... 0.6498012
    6166: finished     eccentric_tick 0.6445744 3815641d-500c-4... 0.8028539

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

    [1] 6165

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
    [1] 0.9148768


    $key
    [1] "0e134ca7-7573-4d91-a9ca-7a13e72db1e4"

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
