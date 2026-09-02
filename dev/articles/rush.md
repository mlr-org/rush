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
       1: open_bedlington... 0.4367700 0.6608858 15088782-f913-4...
       2: phantasmagoric_... 0.6659666 0.8160677 6c6efe0f-bd11-4...
       3: open_bedlington... 0.7950699 0.8916669 f2d5f693-cb61-4...
       4: open_bedlington... 0.4132461 0.6428422 bf669b50-e82d-4...
       5: open_bedlington... 0.3134494 0.5598656 4c2abb73-3667-4...
      ---
    6281: open_bedlington... 0.6276240 0.7922272 697b22e3-7583-4...
    6282: phantasmagoric_... 0.8172635 0.9040263 5f9b458b-2bdd-4...
    6283: open_bedlington... 0.7471444 0.8643752 11d25a2f-b05b-4...
    6284: phantasmagoric_... 0.7094462 0.8422863 d612fe32-de8f-4...
    6285: open_bedlington... 0.2624161 0.5122657 e3223bf9-20af-4...

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
       1: 0.4367700 0.6608858 open_bedlington... 15088782-f913-4...
       2: 0.6659666 0.8160677 phantasmagoric_... 6c6efe0f-bd11-4...
       3: 0.7950699 0.8916669 open_bedlington... f2d5f693-cb61-4...
       4: 0.4132461 0.6428422 open_bedlington... bf669b50-e82d-4...
       5: 0.3134494 0.5598656 open_bedlington... 4c2abb73-3667-4...
      ---
    6713: 0.7807791 0.8836171 open_bedlington... ffffc98f-55d4-4...
    6714: 0.4763690 0.6901949 open_bedlington... 694d70c6-760c-4...
    6715: 0.2211833 0.4703013 phantasmagoric_... 5e24603d-344c-4...
    6716: 0.5577383 0.7468188 open_bedlington... 24fc1920-329b-4...
    6717: 0.5718259 0.7561917 phantasmagoric_... 1652959e-57c7-4...

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
       1: finished open_bedlington... 0.4367700 0.6608858 15088782-f913-4...
       2: finished phantasmagoric_... 0.6659666 0.8160677 6c6efe0f-bd11-4...
       3: finished open_bedlington... 0.7950699 0.8916669 f2d5f693-cb61-4...
       4: finished open_bedlington... 0.4132461 0.6428422 bf669b50-e82d-4...
       5: finished open_bedlington... 0.3134494 0.5598656 4c2abb73-3667-4...
      ---
    6713: finished open_bedlington... 0.7807791 0.8836171 ffffc98f-55d4-4...
    6714: finished open_bedlington... 0.4763690 0.6901949 694d70c6-760c-4...
    6715: finished phantasmagoric_... 0.2211833 0.4703013 5e24603d-344c-4...
    6716: finished open_bedlington... 0.5577383 0.7468188 24fc1920-329b-4...
    6717: finished phantasmagoric_... 0.5718259 0.7561917 1652959e-57c7-4...

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

    [1] 6717

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
    [1] 0.02261626


    $key
    [1] "977b89ba-3759-4d8b-ace2-b841a18b202d"

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

    Rscript -e 'rush::start_worker(network_id = "my_network", config = list(scheme = "redis", host = "127.0.0.1", port = "6379"))'

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
