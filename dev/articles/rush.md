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
       1: superduper_wyve... 0.9454659 0.9723507 3ec718b9-c86b-4...
       2: superduper_wyve... 0.8513006 0.9226595 6854875d-9e7d-4...
       3: superduper_wyve... 0.5511727 0.7424100 44b2b33e-7efc-4...
       4: superduper_wyve... 0.6172671 0.7856635 48744b41-e715-4...
       5: superduper_wyve... 0.3731811 0.6108855 c77ec839-b9e1-4...
      ---
    5797:    sienna_queenbee 0.4146990 0.6439712 2461c9ac-23f6-4...
    5798: superduper_wyve... 0.6940715 0.8331096 05fb6386-517c-4...
    5799: superduper_wyve... 0.9770411 0.9884539 f9caa345-d2e0-4...
    5800:    sienna_queenbee 0.8508050 0.9223909 0e370a05-2c9f-4...
    5801: superduper_wyve... 0.4076254 0.6384554 5e269a62-2c6b-4...

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
       1: 0.94546587 0.9723507 superduper_wyve... 3ec718b9-c86b-4...
       2: 0.67587337 0.8221152    sienna_queenbee a64a3705-dc6f-4...
       3: 0.85130057 0.9226595 superduper_wyve... 6854875d-9e7d-4...
       4: 0.55117266 0.7424100 superduper_wyve... 44b2b33e-7efc-4...
       5: 0.61726713 0.7856635 superduper_wyve... 48744b41-e715-4...
      ---
    6188: 0.60517629 0.7779308    sienna_queenbee a20e6d1b-1439-4...
    6189: 0.16168347 0.4020988 superduper_wyve... 2004c6cf-c387-4...
    6190: 0.02088636 0.1445211    sienna_queenbee f5f314bb-9349-4...
    6191: 0.86434642        NA superduper_wyve... aec6e2ed-cc24-4...
    6192: 0.52902383 0.7273402    sienna_queenbee 241ba8c7-798c-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.8643464 superduper_wyve... aec6e2ed-cc24-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running superduper_wyve... 0.86434642 aec6e2ed-cc24-4...        NA
       2: finished superduper_wyve... 0.94546587 3ec718b9-c86b-4... 0.9723507
       3: finished superduper_wyve... 0.85130057 6854875d-9e7d-4... 0.9226595
       4: finished superduper_wyve... 0.55117266 44b2b33e-7efc-4... 0.7424100
       5: finished superduper_wyve... 0.61726713 48744b41-e715-4... 0.7856635
      ---
    6188: finished superduper_wyve... 0.50715449 b1bce93a-a8ba-4... 0.7121478
    6189: finished    sienna_queenbee 0.60517629 a20e6d1b-1439-4... 0.7779308
    6190: finished superduper_wyve... 0.16168347 2004c6cf-c387-4... 0.4020988
    6191: finished    sienna_queenbee 0.02088636 f5f314bb-9349-4... 0.1445211
    6192: finished    sienna_queenbee 0.52902383 241ba8c7-798c-4... 0.7273402

## Task Counts

``` r
rush$n_queued_tasks
```

    [1] 0

``` r
rush$n_running_tasks
```

    [1] 1

``` r
rush$n_finished_tasks
```

    [1] 6191

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
    [1] 0.9702355


    $key
    [1] "f239c718-6d61-4ff1-8bbc-32ec0c546b90"

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
