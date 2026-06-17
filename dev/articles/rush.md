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
       1:       svelte_steed 0.18241988 0.4271064 46739354-bf71-4...
       2: zoisite_interme... 0.46133704 0.6792180 bcca2118-37e9-4...
       3:       svelte_steed 0.04572898 0.2138433 cc49abce-0eaa-4...
       4: zoisite_interme... 0.35425587 0.5951940 7a2c68d3-4858-4...
       5:       svelte_steed 0.78214261 0.8843883 fc333d1c-2f7b-4...
      ---
    7356:       svelte_steed 0.74262347 0.8617560 896d217a-c3c1-4...
    7357: zoisite_interme... 0.76235692 0.8731305 5eaab2b0-86a4-4...
    7358:       svelte_steed 0.18111947 0.4255813 dd7a0051-1650-4...
    7359: zoisite_interme... 0.80370510 0.8964960 c92b676a-26a0-4...
    7360:       svelte_steed 0.77297312 0.8791889 8470f5ba-3bae-4...

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
       1: 0.18241988 0.4271064       svelte_steed 46739354-bf71-4...
       2: 0.46133704 0.6792180 zoisite_interme... bcca2118-37e9-4...
       3: 0.04572898 0.2138433       svelte_steed cc49abce-0eaa-4...
       4: 0.35425587 0.5951940 zoisite_interme... 7a2c68d3-4858-4...
       5: 0.78214261 0.8843883       svelte_steed fc333d1c-2f7b-4...
      ---
    7829: 0.25205276 0.5020486       svelte_steed 2a08bc3d-627f-4...
    7830: 0.36048601 0.6004049       svelte_steed cff36318-03ee-4...
    7831: 0.38182683 0.6179214 zoisite_interme... 2aef5109-9341-4...
    7832: 0.06455216 0.2540712       svelte_steed 69327cde-0df6-4...
    7833: 0.58055005 0.7619383 zoisite_interme... 2b719340-4bfa-4...

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
       1: finished       svelte_steed 0.18241988 0.4271064 46739354-bf71-4...
       2: finished zoisite_interme... 0.46133704 0.6792180 bcca2118-37e9-4...
       3: finished       svelte_steed 0.04572898 0.2138433 cc49abce-0eaa-4...
       4: finished zoisite_interme... 0.35425587 0.5951940 7a2c68d3-4858-4...
       5: finished       svelte_steed 0.78214261 0.8843883 fc333d1c-2f7b-4...
      ---
    7829: finished       svelte_steed 0.25205276 0.5020486 2a08bc3d-627f-4...
    7830: finished       svelte_steed 0.36048601 0.6004049 cff36318-03ee-4...
    7831: finished zoisite_interme... 0.38182683 0.6179214 2aef5109-9341-4...
    7832: finished       svelte_steed 0.06455216 0.2540712 69327cde-0df6-4...
    7833: finished zoisite_interme... 0.58055005 0.7619383 2b719340-4bfa-4...

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

    [1] 7833

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
    [1] 0.937419


    $key
    [1] "a604feac-44e4-4dd7-87a0-2cb1b46545e2"

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
