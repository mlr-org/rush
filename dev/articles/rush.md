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
       1: marginal_ground... 0.4952647 0.7037505 febf1fe0-a5e4-4...
       2: weighable_furse... 0.2374408 0.4872790 3180852d-1216-4...
       3: marginal_ground... 0.9120541 0.9550152 649bdf45-3910-4...
       4: marginal_ground... 0.8987621 0.9480306 7ab93685-61ce-4...
       5: marginal_ground... 0.7590525 0.8712362 b7315350-fa74-4...
      ---
    7105: marginal_ground... 0.1670061 0.4086638 2ba25dfd-88d0-4...
    7106: weighable_furse... 0.6344724 0.7965377 9aa8575b-8e0a-4...
    7107: marginal_ground... 0.4188326 0.6471728 f41fa93f-6be9-4...
    7108: weighable_furse... 0.2398651 0.4897602 ac2f54f1-ea95-4...
    7109: marginal_ground... 0.2961516 0.5441981 ec3eb2a3-9c5f-4...

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

                    x          y          worker_id condition               keys
                <num>      <num>             <char>    <list>             <char>
       1: 0.495264725 0.70375047 marginal_ground...    [NULL] febf1fe0-a5e4-4...
       2: 0.237440817 0.48727899 weighable_furse...    [NULL] 3180852d-1216-4...
       3: 0.912054085 0.95501523 marginal_ground...    [NULL] 649bdf45-3910-4...
       4: 0.655870201 0.80985814 weighable_furse...    [NULL] cd575b08-4e07-4...
       5: 0.898762055 0.94803062 marginal_ground...    [NULL] 7ab93685-61ce-4...
      ---
    7594: 0.602373617 0.77612732 marginal_ground...    [NULL] f479eb75-c886-4...
    7595: 0.349472887 0.59116232 weighable_furse...    [NULL] cc01a81d-b5f4-4...
    7596: 0.003433513 0.05859618 marginal_ground...    [NULL] 96cdafcd-42a2-4...
    7597: 0.032734196 0.18092594 weighable_furse...    [NULL] f641c8fb-6a27-4...
    7598: 0.592444138         NA marginal_ground... <list[1]> 020da457-f022-4...

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
    1: 0.5924441 marginal_ground... <list[1]> 020da457-f022-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x          y               keys
            <char>             <char>       <num>      <num>             <char>
       1: finished marginal_ground... 0.495264725 0.70375047 febf1fe0-a5e4-4...
       2: finished weighable_furse... 0.237440817 0.48727899 3180852d-1216-4...
       3: finished marginal_ground... 0.912054085 0.95501523 649bdf45-3910-4...
       4: finished marginal_ground... 0.898762055 0.94803062 7ab93685-61ce-4...
       5: finished marginal_ground... 0.759052463 0.87123617 b7315350-fa74-4...
      ---
    7593: finished weighable_furse... 0.470854741 0.68618856 93330a0f-48fe-4...
    7594: finished marginal_ground... 0.602373617 0.77612732 f479eb75-c886-4...
    7595: finished weighable_furse... 0.349472887 0.59116232 cc01a81d-b5f4-4...
    7596: finished marginal_ground... 0.003433513 0.05859618 96cdafcd-42a2-4...
    7597: finished weighable_furse... 0.032734196 0.18092594 f641c8fb-6a27-4...

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

    [1] 7597

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
    [1] 0.5071075


    $key
    [1] "64f51488-1c27-4662-85c3-f26c578e4315"

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
