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
       1: metalled_cuttle... 0.06374237 0.2524725 63cd4b78-dffb-4...
       2: metalled_cuttle... 0.98704540 0.9935016 0721ab65-05db-4...
       3: metalled_cuttle... 0.63810535 0.7988150 408dffb4-6676-4...
       4: metalled_cuttle... 0.30268153 0.5501650 929642cb-9395-4...
       5: mountainous_pel... 0.56248565 0.7499904 3c086f0a-45f8-4...
      ---
    6190: mountainous_pel... 0.67922596 0.8241517 c28d4d11-943f-4...
    6191: metalled_cuttle... 0.68995802 0.8306371 978bb710-01b2-4...
    6192: mountainous_pel... 0.46592268 0.6825853 21b241f2-8259-4...
    6193: metalled_cuttle... 0.65191564 0.8074129 0872d15f-e3b2-4...
    6194: mountainous_pel... 0.53485124 0.7313352 c4a87fb9-2c1c-4...

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
       1: 0.06374237 0.2524725 metalled_cuttle... 63cd4b78-dffb-4...
       2: 0.56248565 0.7499904 mountainous_pel... 3c086f0a-45f8-4...
       3: 0.98704540 0.9935016 metalled_cuttle... 0721ab65-05db-4...
       4: 0.63810535 0.7988150 metalled_cuttle... 408dffb4-6676-4...
       5: 0.30268153 0.5501650 metalled_cuttle... 929642cb-9395-4...
      ---
    6631: 0.14879935 0.3857452 metalled_cuttle... 5892a9c8-8ec0-4...
    6632: 0.99354590 0.9967677 mountainous_pel... 29989fa6-eeb6-4...
    6633: 0.43111087 0.6565903 metalled_cuttle... 14249d32-c9b9-4...
    6634: 0.58416573 0.7643074 mountainous_pel... 80f9a7f2-c1d8-4...
    6635: 0.74274935 0.8618291 metalled_cuttle... 46a8c361-96f1-4...

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
       1: finished metalled_cuttle... 0.06374237 0.2524725 63cd4b78-dffb-4...
       2: finished metalled_cuttle... 0.98704540 0.9935016 0721ab65-05db-4...
       3: finished metalled_cuttle... 0.63810535 0.7988150 408dffb4-6676-4...
       4: finished metalled_cuttle... 0.30268153 0.5501650 929642cb-9395-4...
       5: finished mountainous_pel... 0.56248565 0.7499904 3c086f0a-45f8-4...
      ---
    6631: finished metalled_cuttle... 0.14879935 0.3857452 5892a9c8-8ec0-4...
    6632: finished mountainous_pel... 0.99354590 0.9967677 29989fa6-eeb6-4...
    6633: finished metalled_cuttle... 0.43111087 0.6565903 14249d32-c9b9-4...
    6634: finished mountainous_pel... 0.58416573 0.7643074 80f9a7f2-c1d8-4...
    6635: finished metalled_cuttle... 0.74274935 0.8618291 46a8c361-96f1-4...

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

    [1] 6635

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
    [1] 0.5716033


    $key
    [1] "747ce0fa-cb1b-4788-9c43-c69dac29d4d6"

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
