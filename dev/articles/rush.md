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
       1:    candid_redstart 0.73055767 0.8547267 a6fa37b0-0987-4...
       2:    candid_redstart 0.60611042 0.7785309 ff5712c5-f0e5-4...
       3:    candid_redstart 0.01501035 0.1225167 e62ce3eb-dd97-4...
       4:    candid_redstart 0.90721679 0.9524793 6e7e7f9a-d39c-4...
       5:    candid_redstart 0.12232708 0.3497529 e3626dd3-3215-4...
      ---
    6634:    candid_redstart 0.05355089 0.2314107 95507f0c-81f8-4...
    6635:    candid_redstart 0.26627734 0.5160207 a7993cba-aec6-4...
    6636: antimonarchical... 0.22387316 0.4731524 e06a413e-17e7-4...
    6637:    candid_redstart 0.84204482 0.9176300 536a578a-759c-4...
    6638: antimonarchical... 0.45143989 0.6718928 17d982d1-7f76-4...

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
       1: 0.95625208 0.9778814 antimonarchical... 0f686c82-3652-4...
       2: 0.73055767 0.8547267    candid_redstart a6fa37b0-0987-4...
       3: 0.60611042 0.7785309    candid_redstart ff5712c5-f0e5-4...
       4: 0.01501035 0.1225167    candid_redstart e62ce3eb-dd97-4...
       5: 0.90721679 0.9524793    candid_redstart 6e7e7f9a-d39c-4...
      ---
    7064: 0.46503230 0.6819328    candid_redstart 6703759a-d3fa-4...
    7065: 0.80271115 0.8959415 antimonarchical... d55d7762-ac2b-4...
    7066: 0.91857208 0.9584217    candid_redstart 1ad636a0-ee11-4...
    7067: 0.81399559 0.9022170 antimonarchical... eb409e6c-4dad-4...
    7068: 0.28245273        NA    candid_redstart 52199f06-26b2-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x       worker_id               keys
           <num>          <char>             <char>
    1: 0.2824527 candid_redstart 52199f06-26b2-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running    candid_redstart 0.28245273 52199f06-26b2-4...        NA
       2: finished    candid_redstart 0.73055767 a6fa37b0-0987-4... 0.8547267
       3: finished    candid_redstart 0.60611042 ff5712c5-f0e5-4... 0.7785309
       4: finished    candid_redstart 0.01501035 e62ce3eb-dd97-4... 0.1225167
       5: finished    candid_redstart 0.90721679 6e7e7f9a-d39c-4... 0.9524793
      ---
    7064: finished antimonarchical... 0.55314707 2f7a8edb-c627-4... 0.7437386
    7065: finished    candid_redstart 0.46503230 6703759a-d3fa-4... 0.6819328
    7066: finished antimonarchical... 0.80271115 d55d7762-ac2b-4... 0.8959415
    7067: finished    candid_redstart 0.91857208 1ad636a0-ee11-4... 0.9584217
    7068: finished antimonarchical... 0.81399559 eb409e6c-4dad-4... 0.9022170

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

    [1] 7067

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
    [1] 0.3385776


    $key
    [1] "c74e8e91-ff6a-4719-9059-67dbdadc03dd"

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
