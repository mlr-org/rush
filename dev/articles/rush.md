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
       1: idiocratic_hove... 0.2725025 0.5220177 6e4c643f-59e0-4...
       2: idiocratic_hove... 0.4071053 0.6380480 b2ba599a-31fc-4...
       3: idiocratic_hove... 0.9786674 0.9892762 6d956f2b-af6f-4...
       4: villainous_flyi... 0.3946381 0.6282023 0f994495-4caf-4...
       5: idiocratic_hove... 0.4342084 0.6589449 91b1092e-7ef5-4...
      ---
    8591: idiocratic_hove... 0.7148037 0.8454606 5f03d99c-bf44-4...
    8592: villainous_flyi... 0.9668505 0.9832856 147845ae-acd3-4...
    8593: idiocratic_hove... 0.2570659 0.5070167 db42beeb-8841-4...
    8594: villainous_flyi... 0.2668497 0.5165750 0eb15d46-1feb-4...
    8595: idiocratic_hove... 0.5057738 0.7111777 50e956ff-1e28-4...

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

                    x          y          worker_id               keys
                <num>      <num>             <char>             <char>
       1: 0.394638070 0.62820225 villainous_flyi... 0f994495-4caf-4...
       2: 0.272502451 0.52201767 idiocratic_hove... 6e4c643f-59e0-4...
       3: 0.407105278 0.63804802 idiocratic_hove... b2ba599a-31fc-4...
       4: 0.978667413 0.98927621 idiocratic_hove... 6d956f2b-af6f-4...
       5: 0.434208391 0.65894491 idiocratic_hove... 91b1092e-7ef5-4...
      ---
    9296: 0.323227320 0.56853084 villainous_flyi... 11648534-e44d-4...
    9297: 0.705800767 0.84011950 idiocratic_hove... d5236a00-c5be-4...
    9298: 0.639853937 0.79990871 villainous_flyi... dacb2c39-636f-4...
    9299: 0.112496254 0.33540461 idiocratic_hove... 4da37574-80ca-4...
    9300: 0.005240936 0.07239431 villainous_flyi... ce0882ee-6bb8-4...

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

             state          worker_id           x          y               keys
            <char>             <char>       <num>      <num>             <char>
       1: finished idiocratic_hove... 0.272502451 0.52201767 6e4c643f-59e0-4...
       2: finished idiocratic_hove... 0.407105278 0.63804802 b2ba599a-31fc-4...
       3: finished idiocratic_hove... 0.978667413 0.98927621 6d956f2b-af6f-4...
       4: finished villainous_flyi... 0.394638070 0.62820225 0f994495-4caf-4...
       5: finished idiocratic_hove... 0.434208391 0.65894491 91b1092e-7ef5-4...
      ---
    9296: finished villainous_flyi... 0.323227320 0.56853084 11648534-e44d-4...
    9297: finished idiocratic_hove... 0.705800767 0.84011950 d5236a00-c5be-4...
    9298: finished villainous_flyi... 0.639853937 0.79990871 dacb2c39-636f-4...
    9299: finished idiocratic_hove... 0.112496254 0.33540461 4da37574-80ca-4...
    9300: finished villainous_flyi... 0.005240936 0.07239431 ce0882ee-6bb8-4...

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

    [1] 9300

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
    [1] 0.9416826


    $key
    [1] "b7d291b5-a2ab-4996-92a4-c56f7e2ecd78"

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
