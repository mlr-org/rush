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
       1:        worthy_kudu 0.9673095 0.9835190 06ae06a2-d3b6-4...
       2:        worthy_kudu 0.5569310 0.7462781 bd161e33-bf9d-4...
       3: lovable_thoroug... 0.3861745 0.6214294 13ad5af7-a18e-4...
       4:        worthy_kudu 0.9201372 0.9592378 6eced5a3-e872-4...
       5: lovable_thoroug... 0.2751289 0.5245274 702e8d3f-9eed-4...
      ---
    7194: lovable_thoroug... 0.2795891 0.5287618 141381e2-58b0-4...
    7195:        worthy_kudu 0.2481611 0.4981578 c4ef1031-8c5a-4...
    7196: lovable_thoroug... 0.2906622 0.5391310 73bd6d6f-192c-4...
    7197:        worthy_kudu 0.7098905 0.8425500 deb59bb1-55f6-4...
    7198: lovable_thoroug... 0.8644203 0.9297421 b3d0b9de-9ec2-4...

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
       1: 0.3861745 0.6214294 lovable_thoroug... 13ad5af7-a18e-4...
       2: 0.9673095 0.9835190        worthy_kudu 06ae06a2-d3b6-4...
       3: 0.5569310 0.7462781        worthy_kudu bd161e33-bf9d-4...
       4: 0.9201372 0.9592378        worthy_kudu 6eced5a3-e872-4...
       5: 0.2751289 0.5245274 lovable_thoroug... 702e8d3f-9eed-4...
      ---
    7680: 0.0508633 0.2255289        worthy_kudu ded95d4d-3a44-4...
    7681: 0.2935162 0.5417714 lovable_thoroug... 7b1f8c8d-e0d0-4...
    7682: 0.5840586 0.7642373        worthy_kudu 56e372d8-5241-4...
    7683: 0.7652523 0.8747870 lovable_thoroug... 5ee8bbbf-8978-4...
    7684: 0.4312386 0.6566876 lovable_thoroug... 92ccd7e2-1b9b-4...

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

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished        worthy_kudu 0.9673095 0.9835190 06ae06a2-d3b6-4...
       2: finished        worthy_kudu 0.5569310 0.7462781 bd161e33-bf9d-4...
       3: finished lovable_thoroug... 0.3861745 0.6214294 13ad5af7-a18e-4...
       4: finished        worthy_kudu 0.9201372 0.9592378 6eced5a3-e872-4...
       5: finished lovable_thoroug... 0.2751289 0.5245274 702e8d3f-9eed-4...
      ---
    7680: finished        worthy_kudu 0.0508633 0.2255289 ded95d4d-3a44-4...
    7681: finished lovable_thoroug... 0.2935162 0.5417714 7b1f8c8d-e0d0-4...
    7682: finished        worthy_kudu 0.5840586 0.7642373 56e372d8-5241-4...
    7683: finished lovable_thoroug... 0.7652523 0.8747870 5ee8bbbf-8978-4...
    7684: finished lovable_thoroug... 0.4312386 0.6566876 92ccd7e2-1b9b-4...

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

    [1] 7684

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
    [1] 0.3252124


    $key
    [1] "d50859a2-d2dc-4046-ad18-151f4f67ac44"

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
