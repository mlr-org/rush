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
       1: powellite_mosas... 0.16203116 0.4025309 7030fde8-0fb9-4...
       2:    soaplike_chital 0.74639977 0.8639443 0b726f8b-72f6-4...
       3: powellite_mosas... 0.83172358 0.9119888 786251b1-1739-4...
       4:    soaplike_chital 0.36544669 0.6045219 7902d664-682b-4...
       5:    soaplike_chital 0.22470675 0.4740324 96865b89-375c-4...
      ---
    7173: powellite_mosas... 0.69317036 0.8325685 f4105771-4550-4...
    7174:    soaplike_chital 0.61340370 0.7832009 18851b46-aabf-4...
    7175: powellite_mosas... 0.24732085 0.4973136 1bc61d79-2d37-4...
    7176:    soaplike_chital 0.05716314 0.2390881 968fc8b6-1669-4...
    7177: powellite_mosas... 0.48266018 0.6947375 907be0a6-5539-4...

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

                  x         y          worker_id condition               keys
              <num>     <num>             <char>    <list>             <char>
       1: 0.7463998 0.8639443    soaplike_chital    [NULL] 0b726f8b-72f6-4...
       2: 0.1620312 0.4025309 powellite_mosas...    [NULL] 7030fde8-0fb9-4...
       3: 0.8317236 0.9119888 powellite_mosas...    [NULL] 786251b1-1739-4...
       4: 0.3654467 0.6045219    soaplike_chital    [NULL] 7902d664-682b-4...
       5: 0.8879530 0.9423126 powellite_mosas...    [NULL] 18ac5acc-b6d9-4...
      ---
    7644: 0.3408828 0.5838517 powellite_mosas...    [NULL] fe63ebf9-030a-4...
    7645: 0.9529058 0.9761690    soaplike_chital    [NULL] b2fde4b0-8dc2-4...
    7646: 0.7233203 0.8504824 powellite_mosas...    [NULL] 96dd6b40-75d1-4...
    7647: 0.2363599 0.4861686    soaplike_chital <list[1]> 24258249-f2f0-4...
    7648: 0.2398915        NA powellite_mosas... <list[1]> abccc410-f513-4...

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

               x          worker_id condition               keys
           <num>             <char>    <list>             <char>
    1: 0.2363599    soaplike_chital <list[1]> 24258249-f2f0-4...
    2: 0.2398915 powellite_mosas... <list[1]> abccc410-f513-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished powellite_mosas... 0.1620312 0.4025309 7030fde8-0fb9-4...
       2: finished    soaplike_chital 0.7463998 0.8639443 0b726f8b-72f6-4...
       3: finished powellite_mosas... 0.8317236 0.9119888 786251b1-1739-4...
       4: finished    soaplike_chital 0.3654467 0.6045219 7902d664-682b-4...
       5: finished    soaplike_chital 0.2247068 0.4740324 96865b89-375c-4...
      ---
    7642: finished powellite_mosas... 0.6021337 0.7759728 77e89e75-aca5-4...
    7643: finished    soaplike_chital 0.1091042 0.3303092 349cccb6-a91f-4...
    7644: finished powellite_mosas... 0.3408828 0.5838517 fe63ebf9-030a-4...
    7645: finished    soaplike_chital 0.9529058 0.9761690 b2fde4b0-8dc2-4...
    7646: finished powellite_mosas... 0.7233203 0.8504824 96dd6b40-75d1-4...

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

    [1] 7646

``` r

rush$n_failed_tasks
```

    [1] 2

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
    [1] 0.6675789


    $key
    [1] "38fcc768-baa4-414e-a2de-e4cdd3c8d773"

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

    character(0)

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
