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
       1: organoactinoid_... 0.09884535 0.3143968 591a9781-8cdb-4...
       2: compulsory_gour... 0.94945174 0.9743981 8c07ed10-b94b-4...
       3: organoactinoid_... 0.35397952 0.5949618 5afa7204-4f48-4...
       4: compulsory_gour... 0.44168288 0.6645923 e09e3cb5-7935-4...
       5: organoactinoid_... 0.84044077 0.9167556 f12d2d59-431d-4...
      ---
    5737: organoactinoid_... 0.43997879 0.6633090 990eea89-0dba-4...
    5738: compulsory_gour... 0.08810711 0.2968284 fac45cd5-4365-4...
    5739: organoactinoid_... 0.60420697 0.7773075 ff99be41-6d96-4...
    5740: compulsory_gour... 0.74725926 0.8644416 76e0bf66-9fbc-4...
    5741: organoactinoid_... 0.53487755 0.7313532 40e2de7f-fbda-4...

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
       1: 0.09884535 0.3143968 organoactinoid_... 591a9781-8cdb-4...
       2: 0.94945174 0.9743981 compulsory_gour... 8c07ed10-b94b-4...
       3: 0.35397952 0.5949618 organoactinoid_... 5afa7204-4f48-4...
       4: 0.44168288 0.6645923 compulsory_gour... e09e3cb5-7935-4...
       5: 0.84044077 0.9167556 organoactinoid_... f12d2d59-431d-4...
      ---
    6118: 0.46843265 0.6844214 organoactinoid_... e37c0671-b251-4...
    6119: 0.38949425 0.6240947 compulsory_gour... 6b9b9c26-7f57-4...
    6120: 0.71618815 0.8462790 organoactinoid_... 169d1df4-39b3-4...
    6121: 0.04617218 0.2148771 organoactinoid_... 4bdbe159-3505-4...
    6122: 0.85632784 0.9253798 compulsory_gour... 3b5c965b-0260-4...

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
       1: finished organoactinoid_... 0.09884535 0.3143968 591a9781-8cdb-4...
       2: finished compulsory_gour... 0.94945174 0.9743981 8c07ed10-b94b-4...
       3: finished organoactinoid_... 0.35397952 0.5949618 5afa7204-4f48-4...
       4: finished compulsory_gour... 0.44168288 0.6645923 e09e3cb5-7935-4...
       5: finished organoactinoid_... 0.84044077 0.9167556 f12d2d59-431d-4...
      ---
    6118: finished compulsory_gour... 0.71205535 0.8438337 a7b23152-5b32-4...
    6119: finished organoactinoid_... 0.71618815 0.8462790 169d1df4-39b3-4...
    6120: finished compulsory_gour... 0.38949425 0.6240947 6b9b9c26-7f57-4...
    6121: finished organoactinoid_... 0.04617218 0.2148771 4bdbe159-3505-4...
    6122: finished compulsory_gour... 0.85632784 0.9253798 3b5c965b-0260-4...

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

    [1] 6122

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
    [1] 0.7230097


    $key
    [1] "260d23bd-6724-4dbb-b70e-a44863dcddcf"

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
