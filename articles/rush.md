# rush - Quick Reference

A quick reference cheatsheet for `rush`. See the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) for a detailed
introduction.

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
       1: entertaining_ti... 0.6820267 0.8258491 ccf294fd-c701-4...
       2: light_urutu_17b... 0.6893773 0.8302875 13c788ba-98a2-4...
       3: entertaining_ti... 0.2345821 0.4843367 4978e5d7-d1b9-4...
       4: entertaining_ti... 0.1993941 0.4465356 bd914da4-1102-4...
       5: light_urutu_17b... 0.2318826 0.4815419 ce13bb26-de8c-4...
      ---
    7260: entertaining_ti... 0.5533006 0.7438418 016397d2-fc38-4...
    7261: light_urutu_17b... 0.8346250 0.9135781 653b90d1-a58e-4...
    7262: entertaining_ti... 0.3693656 0.6077546 395fd1c2-7b9f-4...
    7263: entertaining_ti... 0.2343231 0.4840693 00aba0f0-e941-4...
    7264: light_urutu_17b... 0.1930876 0.4394173 ac663241-80a7-4...

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
       1: 0.68937734 0.8302875 light_urutu_17b...    [NULL] 13c788ba-98a2-4...
       2: 0.68202667 0.8258491 entertaining_ti...    [NULL] ccf294fd-c701-4...
       3: 0.23458206 0.4843367 entertaining_ti...    [NULL] 4978e5d7-d1b9-4...
       4: 0.23188261 0.4815419 light_urutu_17b...    [NULL] ce13bb26-de8c-4...
       5: 0.19939408 0.4465356 entertaining_ti...    [NULL] bd914da4-1102-4...
      ---
    7707: 0.99636395 0.9981803 entertaining_ti...    [NULL] 2864def3-6175-4...
    7708: 0.04043386 0.2010817 light_urutu_17b...    [NULL] 8caff164-0905-4...
    7709: 0.01165548 0.1079606 entertaining_ti...    [NULL] 0038b736-5c36-4...
    7710: 0.77813677 0.8821206 light_urutu_17b...    [NULL] 61ce5bb1-25df-4...
    7711: 0.08852670        NA entertaining_ti... <list[1]> bbe9626f-39db-4...

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
    1: 0.0885267 entertaining_ti... <list[1]> bbe9626f-39db-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished entertaining_ti... 0.68202667 0.8258491 ccf294fd-c701-4...
       2: finished light_urutu_17b... 0.68937734 0.8302875 13c788ba-98a2-4...
       3: finished entertaining_ti... 0.23458206 0.4843367 4978e5d7-d1b9-4...
       4: finished entertaining_ti... 0.19939408 0.4465356 bd914da4-1102-4...
       5: finished light_urutu_17b... 0.23188261 0.4815419 ce13bb26-de8c-4...
      ---
    7706: finished light_urutu_17b... 0.32984433 0.5743208 ae84e224-2907-4...
    7707: finished entertaining_ti... 0.99636395 0.9981803 2864def3-6175-4...
    7708: finished light_urutu_17b... 0.04043386 0.2010817 8caff164-0905-4...
    7709: finished entertaining_ti... 0.01165548 0.1079606 0038b736-5c36-4...
    7710: finished light_urutu_17b... 0.77813677 0.8821206 61ce5bb1-25df-4...

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

    [1] 7710

``` r

rush$n_failed_tasks
```

    [1] 1

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
    [1] 0.755584


    $key
    [1] "a0357a96-c2a8-43c6-9795-b43812c1e82d"

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
