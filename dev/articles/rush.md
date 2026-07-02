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
       1:    downtrodden_cat 0.07914503 0.2813273 db4e4a8b-c779-4...
       2: chickenhearted_... 0.50131372 0.7080351 a1db9ea5-76f9-4...
       3:    downtrodden_cat 0.63040045 0.7939776 ca1ee344-7e53-4...
       4: chickenhearted_... 0.68352328 0.8267547 b85fb986-e36e-4...
       5: chickenhearted_... 0.76691993 0.8757396 608c9824-a9d9-4...
      ---
    7235:    downtrodden_cat 0.89880256 0.9480520 056ab69e-a6ed-4...
    7236: chickenhearted_... 0.54356182 0.7372665 fe715e2b-2882-4...
    7237:    downtrodden_cat 0.42493414 0.6518697 4b34c25d-1d80-4...
    7238: chickenhearted_... 0.99296995 0.9964788 2c50e438-a37a-4...
    7239:    downtrodden_cat 0.79232313 0.8901253 8ec9bcda-d030-4...

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
       1: 0.50131372 0.7080351 chickenhearted_...    [NULL] a1db9ea5-76f9-4...
       2: 0.07914503 0.2813273    downtrodden_cat    [NULL] db4e4a8b-c779-4...
       3: 0.63040045 0.7939776    downtrodden_cat    [NULL] ca1ee344-7e53-4...
       4: 0.68352328 0.8267547 chickenhearted_...    [NULL] b85fb986-e36e-4...
       5: 0.76691993 0.8757396 chickenhearted_...    [NULL] 608c9824-a9d9-4...
      ---
    7713: 0.68505784 0.8276822    downtrodden_cat    [NULL] a78649b9-2498-4...
    7714: 0.50942049 0.7137370 chickenhearted_...    [NULL] 58a0bebf-1d62-4...
    7715: 0.89975551 0.9485544    downtrodden_cat    [NULL] 133619f2-33ed-4...
    7716: 0.04199223 0.2049201 chickenhearted_...    [NULL] 65929f1d-63d3-4...
    7717: 0.83341367        NA    downtrodden_cat <list[1]> 0f52c825-3a7d-4...

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

               x       worker_id condition               keys
           <num>          <char>    <list>             <char>
    1: 0.8334137 downtrodden_cat <list[1]> 0f52c825-3a7d-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished    downtrodden_cat 0.07914503 0.2813273 db4e4a8b-c779-4...
       2: finished chickenhearted_... 0.50131372 0.7080351 a1db9ea5-76f9-4...
       3: finished    downtrodden_cat 0.63040045 0.7939776 ca1ee344-7e53-4...
       4: finished chickenhearted_... 0.68352328 0.8267547 b85fb986-e36e-4...
       5: finished chickenhearted_... 0.76691993 0.8757396 608c9824-a9d9-4...
      ---
    7712: finished chickenhearted_... 0.57556877 0.7586625 5bd3dcef-e76b-4...
    7713: finished    downtrodden_cat 0.68505784 0.8276822 a78649b9-2498-4...
    7714: finished chickenhearted_... 0.50942049 0.7137370 58a0bebf-1d62-4...
    7715: finished    downtrodden_cat 0.89975551 0.9485544 133619f2-33ed-4...
    7716: finished chickenhearted_... 0.04199223 0.2049201 65929f1d-63d3-4...

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

    [1] 7716

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
    [1] 0.9274033


    $key
    [1] "a96b3510-fceb-42fb-865c-e82c6691bb27"

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
