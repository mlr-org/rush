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

                   worker_id           x          y               keys
                      <char>       <num>      <num>             <char>
       1: photodramatic_s... 0.533183005 0.73019381 0eb8228b-12b0-4...
       2: photodramatic_s... 0.289699194 0.53823712 343b2c70-4d5a-4...
       3: photodramatic_s... 0.309398069 0.55623562 874a3648-bed5-4...
       4: inferior_rainbo... 0.391084959 0.62536786 7154d4e7-1bc9-4...
       5: photodramatic_s... 0.892131758 0.94452727 71dda56a-f7d6-4...
      ---
    7540: photodramatic_s... 0.012910456 0.11362419 9a114cab-3040-4...
    7541: inferior_rainbo... 0.008243177 0.09079195 b57167ce-b68a-4...
    7542: photodramatic_s... 0.375026604 0.61239416 2f18431c-00ac-4...
    7543: inferior_rainbo... 0.234845641 0.48460875 d44a616d-8f86-4...
    7544: photodramatic_s... 0.661488105 0.81331919 99bd68dc-33fb-4...

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
       1: 0.53318301 0.7301938 photodramatic_s... 0eb8228b-12b0-4...
       2: 0.39108496 0.6253679 inferior_rainbo... 7154d4e7-1bc9-4...
       3: 0.28969919 0.5382371 photodramatic_s... 343b2c70-4d5a-4...
       4: 0.30939807 0.5562356 photodramatic_s... 874a3648-bed5-4...
       5: 0.89213176 0.9445273 photodramatic_s... 71dda56a-f7d6-4...
      ---
    8117: 0.30553075 0.5527484 inferior_rainbo... 4b69e2ec-aa49-4...
    8118: 0.84361372 0.9184845 photodramatic_s... 4b056ebb-d8fd-4...
    8119: 0.09120919 0.3020086 inferior_rainbo... 0f0f28b8-2609-4...
    8120: 0.21058671 0.4588973 photodramatic_s... 736a5fde-2efc-4...
    8121: 0.25787869        NA inferior_rainbo... 07621ec8-cdc3-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.2578787 inferior_rainbo... 07621ec8-cdc3-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running inferior_rainbo... 0.25787869 07621ec8-cdc3-4...        NA
       2: finished photodramatic_s... 0.53318301 0eb8228b-12b0-4... 0.7301938
       3: finished photodramatic_s... 0.28969919 343b2c70-4d5a-4... 0.5382371
       4: finished photodramatic_s... 0.30939807 874a3648-bed5-4... 0.5562356
       5: finished inferior_rainbo... 0.39108496 7154d4e7-1bc9-4... 0.6253679
      ---
    8117: finished photodramatic_s... 0.64125929 165e2b76-4d85-4... 0.8007867
    8118: finished inferior_rainbo... 0.30553075 4b69e2ec-aa49-4... 0.5527484
    8119: finished photodramatic_s... 0.84361372 4b056ebb-d8fd-4... 0.9184845
    8120: finished inferior_rainbo... 0.09120919 0f0f28b8-2609-4... 0.3020086
    8121: finished photodramatic_s... 0.21058671 736a5fde-2efc-4... 0.4588973

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

    [1] 8120

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
    [1] 0.9840326


    $key
    [1] "0b949e43-096d-48ad-9f59-c570d6a33952"

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
