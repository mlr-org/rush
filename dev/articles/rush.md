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
       1:      sugary_cattle 0.47157425 0.6867126 6ba02512-133c-4...
       2: seminocturnal_l... 0.56678300 0.7528499 66b1dcd8-d4f2-4...
       3:      sugary_cattle 0.09329921 0.3054492 2a0bb267-7317-4...
       4: seminocturnal_l... 0.73207682 0.8556149 b62c0779-c5cf-4...
       5:      sugary_cattle 0.75873965 0.8710566 c146936a-8bb7-4...
      ---
    5219: seminocturnal_l... 0.15917978 0.3989734 9f2ffc54-eb35-4...
    5220:      sugary_cattle 0.13300001 0.3646917 43b10e5e-0e89-4...
    5221: seminocturnal_l... 0.83618129 0.9144295 d8c4640e-3f5f-4...
    5222:      sugary_cattle 0.94867845 0.9740013 9fe9957f-64a5-4...
    5223: seminocturnal_l... 0.57137739 0.7558951 81114aa8-0087-4...

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
       1: 0.56678300 0.7528499 seminocturnal_l... 66b1dcd8-d4f2-4...
       2: 0.47157425 0.6867126      sugary_cattle 6ba02512-133c-4...
       3: 0.09329921 0.3054492      sugary_cattle 2a0bb267-7317-4...
       4: 0.73207682 0.8556149 seminocturnal_l... b62c0779-c5cf-4...
       5: 0.75873965 0.8710566      sugary_cattle c146936a-8bb7-4...
      ---
    5491: 0.88837353 0.9425357      sugary_cattle 4d5590cd-90c0-4...
    5492: 0.12352604 0.3514627 seminocturnal_l... 29c991d1-d9e6-4...
    5493: 0.11988409 0.3462428      sugary_cattle 1806db3f-9f00-4...
    5494: 0.27427974        NA seminocturnal_l... 3ef1b987-3b6d-4...
    5495: 0.55741434        NA      sugary_cattle b5046d00-e207-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.2742797 seminocturnal_l... 3ef1b987-3b6d-4...
    2: 0.5574143      sugary_cattle b5046d00-e207-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running seminocturnal_l... 0.27427974 3ef1b987-3b6d-4...        NA
       2:  running      sugary_cattle 0.55741434 b5046d00-e207-4...        NA
       3: finished      sugary_cattle 0.47157425 6ba02512-133c-4... 0.6867126
       4: finished seminocturnal_l... 0.56678300 66b1dcd8-d4f2-4... 0.7528499
       5: finished      sugary_cattle 0.09329921 2a0bb267-7317-4... 0.3054492
      ---
    5491: finished      sugary_cattle 0.03585258 36ec2a45-c35f-4... 0.1893478
    5492: finished seminocturnal_l... 0.76454956 b1ab6bc6-f217-4... 0.8743852
    5493: finished      sugary_cattle 0.88837353 4d5590cd-90c0-4... 0.9425357
    5494: finished      sugary_cattle 0.11988409 1806db3f-9f00-4... 0.3462428
    5495: finished seminocturnal_l... 0.12352604 29c991d1-d9e6-4... 0.3514627

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

    [1] 5493

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
    [1] 0.7766237


    $key
    [1] "96a22c5b-1685-4149-8404-19b86e7a9ae7"

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
