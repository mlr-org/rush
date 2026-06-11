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
       1:       amber_coyote 0.9607165 0.9801615 8d35d5ea-1ac1-4...
       2:       amber_coyote 0.5859322 0.7654621 7299dd03-fbfd-4...
       3:       amber_coyote 0.7714560 0.8783257 b8e72a8e-8a62-4...
       4:       amber_coyote 0.4778341 0.6912554 d366c0fc-ba6d-4...
       5:       amber_coyote 0.5879568 0.7667834 9eb6e24b-128d-4...
      ---
    6746: thievish_antarc... 0.9340744 0.9664753 b64cf1fa-c2e6-4...
    6747:       amber_coyote 0.4065712 0.6376294 d65d4a72-51c0-4...
    6748: thievish_antarc... 0.8737358 0.9347383 2d8cfe7b-51d0-4...
    6749:       amber_coyote 0.5801304 0.7616629 f4d5e065-e586-4...
    6750: thievish_antarc... 0.1397042 0.3737702 ecb898ba-23d7-4...

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
       1: 0.9607165 0.9801615       amber_coyote 8d35d5ea-1ac1-4...
       2: 0.5463769 0.7391731 thievish_antarc... 6444971a-2f50-4...
       3: 0.5859322 0.7654621       amber_coyote 7299dd03-fbfd-4...
       4: 0.7714560 0.8783257       amber_coyote b8e72a8e-8a62-4...
       5: 0.4778341 0.6912554       amber_coyote d366c0fc-ba6d-4...
      ---
    7187: 0.3969877 0.6300696 thievish_antarc... 00d571fa-c813-4...
    7188: 0.2294566 0.4790163       amber_coyote 521edc72-d60c-4...
    7189: 0.6907659 0.8311233 thievish_antarc... 3a36af7c-30d7-4...
    7190: 0.3934692        NA       amber_coyote 2c33e14e-9871-4...
    7191: 0.8544646        NA thievish_antarc... 772164b5-0ebf-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3934692       amber_coyote 2c33e14e-9871-4...
    2: 0.8544646 thievish_antarc... 772164b5-0ebf-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running       amber_coyote 0.39346916 2c33e14e-9871-4...        NA
       2:  running thievish_antarc... 0.85446464 772164b5-0ebf-4...        NA
       3: finished       amber_coyote 0.96071654 8d35d5ea-1ac1-4... 0.9801615
       4: finished       amber_coyote 0.58593216 7299dd03-fbfd-4... 0.7654621
       5: finished       amber_coyote 0.77145601 b8e72a8e-8a62-4... 0.8783257
      ---
    7187: finished thievish_antarc... 0.02117109 8d0d0b78-92fe-4... 0.1455029
    7188: finished       amber_coyote 0.31678156 44aab096-3e03-4... 0.5628335
    7189: finished thievish_antarc... 0.39698768 00d571fa-c813-4... 0.6300696
    7190: finished       amber_coyote 0.22945663 521edc72-d60c-4... 0.4790163
    7191: finished thievish_antarc... 0.69076595 3a36af7c-30d7-4... 0.8311233

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

    [1] 7189

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
    [1] 0.3665941


    $key
    [1] "ca82c34f-4402-431e-93ec-cb0c274c73cc"

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
