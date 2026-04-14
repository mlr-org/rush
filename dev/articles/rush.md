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
       1: proportionable_... 0.50013991 0.7072057 76bc5c97-398e-4...
       2: proportionable_... 0.08353179 0.2890187 10d828f2-2217-4...
       3: proportionable_... 0.94376269 0.9714745 a906b3bc-eae6-4...
       4: proportionable_... 0.11191563 0.3345379 5f6b5d04-d8e9-4...
       5: proportionable_... 0.39420319 0.6278560 70a5480d-d208-4...
      ---
    6184: proportionable_... 0.86588282 0.9305282 72fe5941-3939-4...
    6185: dirgeful_isabel... 0.85659227 0.9255227 c8375319-f112-4...
    6186: proportionable_... 0.21883393 0.4677969 9a70c6d9-37ba-4...
    6187: dirgeful_isabel... 0.70594681 0.8402064 e286ee0a-f677-4...
    6188: proportionable_... 0.36944800 0.6078223 a9230456-716e-4...

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
       1: 0.50013991 0.7072057 proportionable_... 76bc5c97-398e-4...
       2: 0.31528264 0.5615003 dirgeful_isabel... e1e74918-caca-4...
       3: 0.08353179 0.2890187 proportionable_... 10d828f2-2217-4...
       4: 0.94376269 0.9714745 proportionable_... a906b3bc-eae6-4...
       5: 0.11191563 0.3345379 proportionable_... 5f6b5d04-d8e9-4...
      ---
    6535: 0.60323934 0.7766848 dirgeful_isabel... a6f7e8eb-9fff-4...
    6536: 0.80874714 0.8993037 proportionable_... ebf73bb8-f869-4...
    6537: 0.75934378 0.8714033 dirgeful_isabel... e3089486-6e9a-4...
    6538: 0.12430624 0.3525709 proportionable_... f82db4cd-e76e-4...
    6539: 0.07119628 0.2668263 dirgeful_isabel... 1bbfc4b0-9973-4...

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
       1: finished proportionable_... 0.50013991 0.7072057 76bc5c97-398e-4...
       2: finished proportionable_... 0.08353179 0.2890187 10d828f2-2217-4...
       3: finished proportionable_... 0.94376269 0.9714745 a906b3bc-eae6-4...
       4: finished proportionable_... 0.11191563 0.3345379 5f6b5d04-d8e9-4...
       5: finished proportionable_... 0.39420319 0.6278560 70a5480d-d208-4...
      ---
    6535: finished dirgeful_isabel... 0.60323934 0.7766848 a6f7e8eb-9fff-4...
    6536: finished proportionable_... 0.80874714 0.8993037 ebf73bb8-f869-4...
    6537: finished dirgeful_isabel... 0.75934378 0.8714033 e3089486-6e9a-4...
    6538: finished proportionable_... 0.12430624 0.3525709 f82db4cd-e76e-4...
    6539: finished dirgeful_isabel... 0.07119628 0.2668263 1bbfc4b0-9973-4...

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

    [1] 6539

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
    [1] 0.3822224


    $key
    [1] "07c32abd-c6f5-4c0b-9f5c-34defa9a4ad5"

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
