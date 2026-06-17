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

              worker_id           x          y               keys
                 <char>       <num>      <num>             <char>
       1:  handmade_pug 0.429305965 0.65521444 ffcbf31a-2256-4...
       2:  handmade_pug 0.894670770 0.94587038 450af631-629b-4...
       3:  handmade_pug 0.036750538 0.19170430 c306d0bf-8720-4...
       4:  handmade_pug 0.796400798 0.89241291 cb52a7fa-1da9-4...
       5:  handmade_pug 0.165488122 0.40680231 28964c45-fa5d-4...
      ---
    7408: plastic_gecko 0.636475933 0.79779442 0da91078-bf50-4...
    7409:  handmade_pug 0.852511690 0.92331560 92ff4fef-78b6-4...
    7410: plastic_gecko 0.001842657 0.04292618 bd1ad0bc-ee9a-4...
    7411:  handmade_pug 0.800212262 0.89454584 a58fc065-c6d3-4...
    7412: plastic_gecko 0.556646887 0.74608772 50f244f3-5f6b-4...

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

                    x         y     worker_id               keys
                <num>     <num>        <char>             <char>
       1: 0.429305965 0.6552144  handmade_pug ffcbf31a-2256-4...
       2: 0.325455914 0.5704874 plastic_gecko f9726b0f-a498-4...
       3: 0.894670770 0.9458704  handmade_pug 450af631-629b-4...
       4: 0.036750538 0.1917043  handmade_pug c306d0bf-8720-4...
       5: 0.796400798 0.8924129  handmade_pug cb52a7fa-1da9-4...
      ---
    7892: 0.747172925 0.8643916  handmade_pug 67fefc65-5751-4...
    7893: 0.192814295 0.4391062 plastic_gecko 7655c70f-6e78-4...
    7894: 0.798969153 0.8938507  handmade_pug cf5ba37f-c869-4...
    7895: 0.006926568        NA plastic_gecko 46911439-1623-4...
    7896: 0.188229661        NA  handmade_pug be66b9c7-fd32-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

                 x     worker_id               keys
             <num>        <char>             <char>
    1: 0.006926568 plastic_gecko 46911439-1623-4...
    2: 0.188229661  handmade_pug be66b9c7-fd32-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state     worker_id           x               keys         y
            <char>        <char>       <num>             <char>     <num>
       1:  running plastic_gecko 0.006926568 46911439-1623-4...        NA
       2:  running  handmade_pug 0.188229661 be66b9c7-fd32-4...        NA
       3: finished  handmade_pug 0.429305965 ffcbf31a-2256-4... 0.6552144
       4: finished  handmade_pug 0.894670770 450af631-629b-4... 0.9458704
       5: finished  handmade_pug 0.036750538 c306d0bf-8720-4... 0.1917043
      ---
    7892: finished  handmade_pug 0.973467582 44c44400-7fa4-4... 0.9866446
    7893: finished plastic_gecko 0.120897098 772d44d6-3c58-4... 0.3477026
    7894: finished  handmade_pug 0.747172925 67fefc65-5751-4... 0.8643916
    7895: finished plastic_gecko 0.192814295 7655c70f-6e78-4... 0.4391062
    7896: finished  handmade_pug 0.798969153 cf5ba37f-c869-4... 0.8938507

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

    [1] 7894

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
    [1] 0.1811741


    $key
    [1] "e9e2a147-6983-4da0-a5bd-f65c1eee29fb"

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
