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
       1:       wearing_mole 0.97078280 0.9852831 c7281177-c358-4...
       2: timbrophilic_hi... 0.49184519 0.7013168 ae315100-8f43-4...
       3: timbrophilic_hi... 0.68857025 0.8298013 ac5c5286-8e54-4...
       4:       wearing_mole 0.88757722 0.9421132 b43b2339-f768-4...
       5: timbrophilic_hi... 0.31665276 0.5627191 c52fb5b7-f44b-4...
      ---
    5780: timbrophilic_hi... 0.60625006 0.7786206 541b9bda-cce6-4...
    5781: timbrophilic_hi... 0.64770187 0.8047993 fbb7a0d0-52d3-4...
    5782:       wearing_mole 0.09938055 0.3152468 1cd014b5-74b8-4...
    5783: timbrophilic_hi... 0.48051912 0.6931949 79aa4a4f-0432-4...
    5784:       wearing_mole 0.05164431 0.2272538 6123a30d-ef66-4...

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
       1: 0.49184519 0.7013168 timbrophilic_hi... ae315100-8f43-4...
       2: 0.97078280 0.9852831       wearing_mole c7281177-c358-4...
       3: 0.88757722 0.9421132       wearing_mole b43b2339-f768-4...
       4: 0.68857025 0.8298013 timbrophilic_hi... ac5c5286-8e54-4...
       5: 0.31665276 0.5627191 timbrophilic_hi... c52fb5b7-f44b-4...
      ---
    6139: 0.70818794 0.8415390 timbrophilic_hi... 871b1ba3-1219-4...
    6140: 0.88454315 0.9405015       wearing_mole 7c644c84-3458-4...
    6141: 0.31231089 0.5588478 timbrophilic_hi... f8d7c722-6d67-4...
    6142: 0.58134172 0.7624577       wearing_mole 544a33e3-f00e-4...
    6143: 0.03571376        NA       wearing_mole 26eaa666-f5fd-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

                x    worker_id               keys
            <num>       <char>             <char>
    1: 0.03571376 wearing_mole 26eaa666-f5fd-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running       wearing_mole 0.03571376 26eaa666-f5fd-4...        NA
       2: finished       wearing_mole 0.97078280 c7281177-c358-4... 0.9852831
       3: finished timbrophilic_hi... 0.49184519 ae315100-8f43-4... 0.7013168
       4: finished timbrophilic_hi... 0.68857025 ac5c5286-8e54-4... 0.8298013
       5: finished       wearing_mole 0.88757722 b43b2339-f768-4... 0.9421132
      ---
    6139: finished       wearing_mole 0.66095783 ef8fd158-a255-4... 0.8129931
    6140: finished timbrophilic_hi... 0.70818794 871b1ba3-1219-4... 0.8415390
    6141: finished       wearing_mole 0.88454315 7c644c84-3458-4... 0.9405015
    6142: finished timbrophilic_hi... 0.31231089 f8d7c722-6d67-4... 0.5588478
    6143: finished       wearing_mole 0.58134172 544a33e3-f00e-4... 0.7624577

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

    [1] 6142

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
    [1] 0.4670582


    $key
    [1] "bd7727e9-d809-4081-ba61-961cd87903b7"

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
