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

                   worker_id           x          y               keys
                      <char>       <num>      <num>             <char>
       1: regenerable_auk... 0.473969116 0.68845415 4d4d7c26-433c-4...
       2: regenerable_auk... 0.222289165 0.47147552 4d9ddf5a-b09f-4...
       3: regenerable_auk... 0.115128837 0.33930641 985b762b-de78-4...
       4: regenerable_auk... 0.375224576 0.61255577 6bda18a6-3e2e-4...
       5: regenerable_auk... 0.007651642 0.08747367 109a5994-8d02-4...
      ---
    7973: plagihedral_uri... 0.223411257 0.47266400 e0ad9450-da7b-4...
    7974: regenerable_auk... 0.997334604 0.99866641 5b045ee0-059d-4...
    7975: plagihedral_uri... 0.477518175 0.69102690 7b503990-2d3d-4...
    7976: plagihedral_uri... 0.361486935 0.60123784 4f4522b7-4026-4...
    7977: regenerable_auk... 0.413930544 0.64337434 30304857-a34c-4...

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
       1: 0.4739691 0.6884541 regenerable_auk... 4d4d7c26-433c-4...
       2: 0.5939722 0.7706959 plagihedral_uri... 06c2c3d6-55a8-4...
       3: 0.2222892 0.4714755 regenerable_auk... 4d9ddf5a-b09f-4...
       4: 0.1151288 0.3393064 regenerable_auk... 985b762b-de78-4...
       5: 0.3752246 0.6125558 regenerable_auk... 6bda18a6-3e2e-4...
      ---
    8587: 0.1513649 0.3890564 plagihedral_uri... 212863af-4543-4...
    8588: 0.1189678 0.3449170 regenerable_auk... 2111dfa4-0a8a-4...
    8589: 0.6931343 0.8325469 plagihedral_uri... 37f7a0de-8d92-4...
    8590: 0.1775094        NA plagihedral_uri... ab13e759-3460-4...
    8591: 0.2467322        NA regenerable_auk... 9e2c5af5-89f6-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.2467322 regenerable_auk... 9e2c5af5-89f6-4...
    2: 0.1775094 plagihedral_uri... ab13e759-3460-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x               keys          y
            <char>             <char>       <num>             <char>      <num>
       1:  running regenerable_auk... 0.246732198 9e2c5af5-89f6-4...         NA
       2:  running plagihedral_uri... 0.177509367 ab13e759-3460-4...         NA
       3: finished regenerable_auk... 0.473969116 4d4d7c26-433c-4... 0.68845415
       4: finished regenerable_auk... 0.222289165 4d9ddf5a-b09f-4... 0.47147552
       5: finished regenerable_auk... 0.115128837 985b762b-de78-4... 0.33930641
      ---
    8587: finished plagihedral_uri... 0.312835718 4a8d2b49-d997-4... 0.55931719
    8588: finished regenerable_auk... 0.006743969 00b33915-cd94-4... 0.08212167
    8589: finished plagihedral_uri... 0.151364869 212863af-4543-4... 0.38905638
    8590: finished regenerable_auk... 0.118967753 2111dfa4-0a8a-4... 0.34491702
    8591: finished plagihedral_uri... 0.693134320 37f7a0de-8d92-4... 0.83254689

## Task Counts

``` r
rush$n_queued_tasks
```

    [1] 0

``` r
rush$n_running_tasks
```

    [1] 2

``` r
rush$n_finished_tasks
```

    [1] 8589

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
    [1] 0.019777


    $key
    [1] "dcf0a6f9-a393-46d7-ac6b-d7454dd69e47"

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
