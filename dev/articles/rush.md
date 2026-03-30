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
       1: cowlike_alligat... 0.9364304 0.9676933 24912f1a-b30b-4...
       2: cowlike_alligat... 0.9711078 0.9854480 a4b878f4-bc70-4...
       3:    crashing_quahog 0.5164107 0.7186172 aa48144c-4165-4...
       4: cowlike_alligat... 0.8370538 0.9149064 725be09f-998c-4...
       5: cowlike_alligat... 0.5474524 0.7399003 13791a22-7fd6-4...
      ---
    5768:    crashing_quahog 0.3352732 0.5790278 3ababc9a-109b-4...
    5769: cowlike_alligat... 0.1165544 0.3414006 7b21d390-737c-4...
    5770:    crashing_quahog 0.7886385 0.8880532 7fc7472f-dd61-4...
    5771: cowlike_alligat... 0.7582097 0.8707524 67438d56-c452-4...
    5772:    crashing_quahog 0.6124828 0.7826128 d3768699-9e81-4...

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
       1: 0.9364304 0.9676933 cowlike_alligat... 24912f1a-b30b-4...
       2: 0.5164107 0.7186172    crashing_quahog aa48144c-4165-4...
       3: 0.9711078 0.9854480 cowlike_alligat... a4b878f4-bc70-4...
       4: 0.8370538 0.9149064 cowlike_alligat... 725be09f-998c-4...
       5: 0.6752911 0.8217610    crashing_quahog 30c91aec-447e-4...
      ---
    6124: 0.2464640 0.4964514    crashing_quahog b4fb51ca-0a0d-4...
    6125: 0.5538178 0.7441894 cowlike_alligat... a78d7bf9-43d1-4...
    6126: 0.6667819 0.8165671    crashing_quahog 45e02752-2e64-4...
    6127: 0.6291922        NA cowlike_alligat... fd263dbf-954b-4...
    6128: 0.4289211 0.6549207    crashing_quahog 14a52bf6-f848-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.6291922 cowlike_alligat... fd263dbf-954b-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running cowlike_alligat... 0.6291922 fd263dbf-954b-4...        NA
       2: finished cowlike_alligat... 0.9364304 24912f1a-b30b-4... 0.9676933
       3: finished cowlike_alligat... 0.9711078 a4b878f4-bc70-4... 0.9854480
       4: finished    crashing_quahog 0.5164107 aa48144c-4165-4... 0.7186172
       5: finished cowlike_alligat... 0.8370538 725be09f-998c-4... 0.9149064
      ---
    6124: finished    crashing_quahog 0.6532131 a5a89e2d-c533-4... 0.8082160
    6125: finished    crashing_quahog 0.2464640 b4fb51ca-0a0d-4... 0.4964514
    6126: finished cowlike_alligat... 0.5538178 a78d7bf9-43d1-4... 0.7441894
    6127: finished    crashing_quahog 0.6667819 45e02752-2e64-4... 0.8165671
    6128: finished    crashing_quahog 0.4289211 14a52bf6-f848-4... 0.6549207

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

    [1] 6127

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
    [1] 0.2061912


    $key
    [1] "92cae9c9-0fb1-4715-a1fd-34c29271e501"

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
