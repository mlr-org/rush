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
       1:     seclusive_calf 0.7153993 0.8458128 accc900f-4104-4...
       2:     seclusive_calf 0.6233273 0.7895108 cfa09dcc-c5e3-4...
       3:     seclusive_calf 0.0245289 0.1566171 2f96cf0a-112a-4...
       4:     seclusive_calf 0.4335900 0.6584755 0d45a2a6-8ce6-4...
       5:     seclusive_calf 0.6703455 0.8187463 91372794-67a7-4...
      ---
    5983:     seclusive_calf 0.1670322 0.4086957 f58a60d5-ebeb-4...
    5984: befuddling_shel... 0.2236963 0.4729654 00efc3b0-92e6-4...
    5985:     seclusive_calf 0.5218355 0.7223818 fb3977b3-6548-4...
    5986: befuddling_shel... 0.1839632 0.4289093 4c10580f-ffd0-4...
    5987:     seclusive_calf 0.9571974 0.9783646 b06bb392-89fe-4...

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
       1: 0.598034354 0.7733268 befuddling_shel... 3a0c506b-fb4e-4...
       2: 0.715399331 0.8458128     seclusive_calf accc900f-4104-4...
       3: 0.623327262 0.7895108     seclusive_calf cfa09dcc-c5e3-4...
       4: 0.024528904 0.1566171     seclusive_calf 2f96cf0a-112a-4...
       5: 0.433589960 0.6584755     seclusive_calf 0d45a2a6-8ce6-4...
      ---
    6343: 0.266440239 0.5161785 befuddling_shel... 6619c118-7a4f-4...
    6344: 0.173542441 0.4165843     seclusive_calf 94f14f2a-fe54-4...
    6345: 0.523835790 0.7237650 befuddling_shel... 46305152-d00c-4...
    6346: 0.006811007        NA     seclusive_calf fe12b40a-7904-4...
    6347: 0.953694421        NA befuddling_shel... 41bd4f5b-6748-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

                 x          worker_id               keys
             <num>             <char>             <char>
    1: 0.006811007     seclusive_calf fe12b40a-7904-4...
    2: 0.953694421 befuddling_shel... 41bd4f5b-6748-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x               keys         y
            <char>             <char>       <num>             <char>     <num>
       1:  running     seclusive_calf 0.006811007 fe12b40a-7904-4...        NA
       2:  running befuddling_shel... 0.953694421 41bd4f5b-6748-4...        NA
       3: finished     seclusive_calf 0.715399331 accc900f-4104-4... 0.8458128
       4: finished     seclusive_calf 0.623327262 cfa09dcc-c5e3-4... 0.7895108
       5: finished     seclusive_calf 0.024528904 2f96cf0a-112a-4... 0.1566171
      ---
    6343: finished befuddling_shel... 0.047409420 ca4ddcca-a22d-4... 0.2177370
    6344: finished     seclusive_calf 0.354688947 3c4dc955-b121-4... 0.5955577
    6345: finished befuddling_shel... 0.266440239 6619c118-7a4f-4... 0.5161785
    6346: finished     seclusive_calf 0.173542441 94f14f2a-fe54-4... 0.4165843
    6347: finished befuddling_shel... 0.523835790 46305152-d00c-4... 0.7237650

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

    [1] 6345

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
    [1] 0.1646907


    $key
    [1] "6031d0e7-2abd-432c-9eff-05de8c3ddd58"

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
