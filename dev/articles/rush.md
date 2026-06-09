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
       1: beamlike_africa... 0.49505454 0.7036011 e4211b19-dd2f-4...
       2: beamlike_africa... 0.43314128 0.6581347 793e8a25-e605-4...
       3: beamlike_africa... 0.04702792 0.2168592 50dea008-9949-4...
       4: sour_acornwoodp... 0.53893556 0.7341223 3e81011b-e210-4...
       5: beamlike_africa... 0.67493639 0.8215451 1d40973a-1be6-4...
      ---
    6791: beamlike_africa... 0.33248264 0.5766131 cffb727b-9035-4...
    6792: sour_acornwoodp... 0.19983054 0.4470241 87a935bd-fa27-4...
    6793: beamlike_africa... 0.07267642 0.2695856 b833eeac-88d7-4...
    6794: sour_acornwoodp... 0.30251977 0.5500180 78c2d40c-33ac-4...
    6795: beamlike_africa... 0.66624347 0.8162374 33cbacad-3bf2-4...

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
       1: 0.53893556 0.7341223 sour_acornwoodp... 3e81011b-e210-4...
       2: 0.49505454 0.7036011 beamlike_africa... e4211b19-dd2f-4...
       3: 0.43314128 0.6581347 beamlike_africa... 793e8a25-e605-4...
       4: 0.04702792 0.2168592 beamlike_africa... 50dea008-9949-4...
       5: 0.67493639 0.8215451 beamlike_africa... 1d40973a-1be6-4...
      ---
    7228: 0.22776361 0.4772459 beamlike_africa... b9e274f9-3898-4...
    7229: 0.20639754 0.4543100 sour_acornwoodp... 8892681b-6ea9-4...
    7230: 0.06359068 0.2521719 beamlike_africa... d95c1a39-c0c0-4...
    7231: 0.52675705 0.7257803 sour_acornwoodp... 82ea5d41-2c20-4...
    7232: 0.41194203        NA beamlike_africa... 3cb34be1-7e7b-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

              x          worker_id               keys
          <num>             <char>             <char>
    1: 0.411942 beamlike_africa... 3cb34be1-7e7b-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running beamlike_africa... 0.41194203 3cb34be1-7e7b-4...        NA
       2: finished beamlike_africa... 0.49505454 e4211b19-dd2f-4... 0.7036011
       3: finished beamlike_africa... 0.43314128 793e8a25-e605-4... 0.6581347
       4: finished beamlike_africa... 0.04702792 50dea008-9949-4... 0.2168592
       5: finished sour_acornwoodp... 0.53893556 3e81011b-e210-4... 0.7341223
      ---
    7228: finished sour_acornwoodp... 0.81933604 822ab3e3-ddd7-4... 0.9051718
    7229: finished sour_acornwoodp... 0.20639754 8892681b-6ea9-4... 0.4543100
    7230: finished beamlike_africa... 0.22776361 b9e274f9-3898-4... 0.4772459
    7231: finished sour_acornwoodp... 0.52675705 82ea5d41-2c20-4... 0.7257803
    7232: finished beamlike_africa... 0.06359068 d95c1a39-c0c0-4... 0.2521719

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

    [1] 7231

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
    [1] 0.6030423


    $key
    [1] "9a52c8df-3d1d-405a-a08f-8cce9f3edc09"

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
