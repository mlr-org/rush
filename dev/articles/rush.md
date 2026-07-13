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
       1:       abyssal_oryx 0.85997845 0.9273502 f05ae7a8-8e76-4...
       2: resistant_mamma... 0.24994856 0.4999486 c6c5c857-6cb1-4...
       3:       abyssal_oryx 0.19558649 0.4422516 ec89bb63-a2b1-4...
       4:       abyssal_oryx 0.77072355 0.8779086 3e9ef75a-4c99-4...
       5:       abyssal_oryx 0.50333918 0.7094640 eea1ff90-188b-4...
      ---
    5902:       abyssal_oryx 0.84902994 0.9214282 07d8244b-e4ad-4...
    5903: resistant_mamma... 0.81634871 0.9035202 6ca687e4-20b4-4...
    5904:       abyssal_oryx 0.89958591 0.9484650 b66451b7-c6dc-4...
    5905: resistant_mamma... 0.80765471 0.8986961 aab79bcc-e9ef-4...
    5906:       abyssal_oryx 0.07385473 0.2717623 e452c4d8-f54e-4...

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
       1: 0.85997845 0.9273502       abyssal_oryx    [NULL] f05ae7a8-8e76-4...
       2: 0.24994856 0.4999486 resistant_mamma...    [NULL] c6c5c857-6cb1-4...
       3: 0.19558649 0.4422516       abyssal_oryx    [NULL] ec89bb63-a2b1-4...
       4: 0.30288148 0.5503467 resistant_mamma...    [NULL] 11d3bb04-5fcb-4...
       5: 0.77072355 0.8779086       abyssal_oryx    [NULL] 3e9ef75a-4c99-4...
      ---
    6314: 0.01523781 0.1234415 resistant_mamma...    [NULL] fef50827-7238-4...
    6315: 0.18501795 0.4301371 resistant_mamma...    [NULL] 3db247c1-109e-4...
    6316: 0.69660113 0.8346263       abyssal_oryx    [NULL] 8cc9e66e-2970-4...
    6317: 0.75397155 0.8683154 resistant_mamma...    [NULL] dce474b0-f38b-4...
    6318: 0.08573930        NA       abyssal_oryx <list[1]> b4e146f1-7519-4...

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

               x    worker_id condition               keys
           <num>       <char>    <list>             <char>
    1: 0.0857393 abyssal_oryx <list[1]> b4e146f1-7519-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished       abyssal_oryx 0.85997845 0.9273502 f05ae7a8-8e76-4...
       2: finished resistant_mamma... 0.24994856 0.4999486 c6c5c857-6cb1-4...
       3: finished       abyssal_oryx 0.19558649 0.4422516 ec89bb63-a2b1-4...
       4: finished       abyssal_oryx 0.77072355 0.8779086 3e9ef75a-4c99-4...
       5: finished       abyssal_oryx 0.50333918 0.7094640 eea1ff90-188b-4...
      ---
    6313: finished       abyssal_oryx 0.90871074 0.9532632 5698b122-be6b-4...
    6314: finished resistant_mamma... 0.01523781 0.1234415 fef50827-7238-4...
    6315: finished resistant_mamma... 0.18501795 0.4301371 3db247c1-109e-4...
    6316: finished       abyssal_oryx 0.69660113 0.8346263 8cc9e66e-2970-4...
    6317: finished resistant_mamma... 0.75397155 0.8683154 dce474b0-f38b-4...

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

    [1] 6317

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
    [1] 0.1687818


    $key
    [1] "60104bf7-3606-4766-8954-d2592b7e9394"

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
