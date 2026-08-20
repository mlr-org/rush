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
       1: gallant_arrowwo... 0.24341590 0.4933720 9dfce297-ac91-4...
       2: unalphabetised_... 0.36997131 0.6082527 6c61edd7-1395-4...
       3: gallant_arrowwo... 0.05789373 0.2406112 2fab862d-6f57-4...
       4: unalphabetised_... 0.53463083 0.7311845 e62e638a-cf17-4...
       5: gallant_arrowwo... 0.09149795 0.3024863 4b87aca9-0b3b-4...
      ---
    6469: gallant_arrowwo... 0.26355075 0.5133719 8df5857a-f19d-4...
    6470: unalphabetised_... 0.24165929 0.4915885 c9b53353-1994-4...
    6471: gallant_arrowwo... 0.74628246 0.8638764 2009df0e-97b1-4...
    6472: unalphabetised_... 0.07145227 0.2673056 93f8357b-a3c1-4...
    6473: gallant_arrowwo... 0.32720508 0.5720184 8d83264b-99a8-4...

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
       1: 0.24341590 0.4933720 gallant_arrowwo...    [NULL] 9dfce297-ac91-4...
       2: 0.36997131 0.6082527 unalphabetised_...    [NULL] 6c61edd7-1395-4...
       3: 0.05789373 0.2406112 gallant_arrowwo...    [NULL] 2fab862d-6f57-4...
       4: 0.53463083 0.7311845 unalphabetised_...    [NULL] e62e638a-cf17-4...
       5: 0.09149795 0.3024863 gallant_arrowwo...    [NULL] 4b87aca9-0b3b-4...
      ---
    6918: 0.68356931 0.8267825 unalphabetised_...    [NULL] ae1bb72d-0bb9-4...
    6919: 0.70169904 0.8376748 gallant_arrowwo...    [NULL] 07d40f1e-fdef-4...
    6920: 0.64112962 0.8007057 unalphabetised_...    [NULL] 645bdca9-1913-4...
    6921: 0.90721029        NA gallant_arrowwo... <list[1]> 54d7b52b-d7f3-4...
    6922: 0.72807026        NA unalphabetised_... <list[1]> 6e3c84f6-e740-4...

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
    1: 0.9072103 gallant_arrowwo... <list[1]> 54d7b52b-d7f3-4...
    2: 0.7280703 unalphabetised_... <list[1]> 6e3c84f6-e740-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished gallant_arrowwo... 0.24341590 0.4933720 9dfce297-ac91-4...
       2: finished unalphabetised_... 0.36997131 0.6082527 6c61edd7-1395-4...
       3: finished gallant_arrowwo... 0.05789373 0.2406112 2fab862d-6f57-4...
       4: finished unalphabetised_... 0.53463083 0.7311845 e62e638a-cf17-4...
       5: finished gallant_arrowwo... 0.09149795 0.3024863 4b87aca9-0b3b-4...
      ---
    6916: finished unalphabetised_... 0.13584128 0.3685665 5acd27d5-e371-4...
    6917: finished gallant_arrowwo... 0.35726772 0.5977188 8d68033f-a614-4...
    6918: finished unalphabetised_... 0.68356931 0.8267825 ae1bb72d-0bb9-4...
    6919: finished gallant_arrowwo... 0.70169904 0.8376748 07d40f1e-fdef-4...
    6920: finished unalphabetised_... 0.64112962 0.8007057 645bdca9-1913-4...

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

    [1] 6920

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
    [1] 0.7829191


    $key
    [1] "487fbe1d-90ba-4d8c-b22e-24fd73acc833"

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
