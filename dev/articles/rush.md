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

                   worker_id           x         y               keys
                      <char>       <num>     <num>             <char>
       1: atypical_crocod... 0.831730371 0.9119925 7a309c10-629c-4...
       2: atypical_crocod... 0.804230416 0.8967889 27c106f6-1e61-4...
       3: atypical_crocod... 0.644053674 0.8025295 cb53f4da-a352-4...
       4: atypical_crocod... 0.057767485 0.2403487 c49e7e23-ab14-4...
       5: atypical_crocod... 0.900569944 0.9489836 2eb66cdb-ed85-4...
      ---
    6261: atypical_crocod... 0.004315504 0.0656925 e7df1a18-94bb-4...
    6262: perfect_norther... 0.268029390 0.5177155 35ed1db7-9a5b-4...
    6263: atypical_crocod... 0.857517268 0.9260223 41dc6c28-04c6-4...
    6264: perfect_norther... 0.714993399 0.8455728 1e0416a9-59f2-4...
    6265: atypical_crocod... 0.831364209 0.9117918 745cfded-a7b1-4...

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
       1: 0.26339021 0.5132156 perfect_norther... 9dffd747-8535-4...
       2: 0.83173037 0.9119925 atypical_crocod... 7a309c10-629c-4...
       3: 0.80423042 0.8967889 atypical_crocod... 27c106f6-1e61-4...
       4: 0.64405367 0.8025295 atypical_crocod... cb53f4da-a352-4...
       5: 0.05776748 0.2403487 atypical_crocod... c49e7e23-ab14-4...
      ---
    6719: 0.80541892 0.8974513 perfect_norther... da6d07c8-1783-4...
    6720: 0.73196943 0.8555521 atypical_crocod... c23d84df-3beb-4...
    6721: 0.57695545 0.7595758 perfect_norther... c10d953c-f38b-4...
    6722: 0.35265483        NA atypical_crocod... 1ce6395e-e6fe-4...
    6723: 0.75850663        NA perfect_norther... 8fffe6ed-2e72-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3526548 atypical_crocod... 1ce6395e-e6fe-4...
    2: 0.7585066 perfect_norther... 8fffe6ed-2e72-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running atypical_crocod... 0.3526548 1ce6395e-e6fe-4...        NA
       2:  running perfect_norther... 0.7585066 8fffe6ed-2e72-4...        NA
       3: finished atypical_crocod... 0.8317304 7a309c10-629c-4... 0.9119925
       4: finished atypical_crocod... 0.8042304 27c106f6-1e61-4... 0.8967889
       5: finished atypical_crocod... 0.6440537 cb53f4da-a352-4... 0.8025295
      ---
    6719: finished perfect_norther... 0.1875027 90417c22-dde7-4... 0.4330158
    6720: finished atypical_crocod... 0.6857804 9f95f651-c6b2-4... 0.8281186
    6721: finished perfect_norther... 0.8054189 da6d07c8-1783-4... 0.8974513
    6722: finished atypical_crocod... 0.7319694 c23d84df-3beb-4... 0.8555521
    6723: finished perfect_norther... 0.5769555 c10d953c-f38b-4... 0.7595758

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

    [1] 6721

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
    [1] 0.6454815


    $key
    [1] "f281f27f-162c-456d-b719-20efbe089095"

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
