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

                   worker_id          x          y               keys
                      <char>      <num>      <num>             <char>
       1: abandoned_crown... 0.43152271 0.65690388 7baa76ef-774d-4...
       2: authorized_irio... 0.25400053 0.50398465 3d3375d2-3c67-4...
       3: abandoned_crown... 0.60321594 0.77666977 3a909f05-a35f-4...
       4: authorized_irio... 0.89747123 0.94734958 0026051b-33ba-4...
       5: abandoned_crown... 0.60793370 0.77970103 28cd6e46-ad72-4...
      ---
    6271: authorized_irio... 0.57870169 0.76072445 2d344ce8-508b-4...
    6272: abandoned_crown... 0.00397615 0.06305672 a0ba4441-5fdf-4...
    6273: authorized_irio... 0.06645587 0.25779037 46cd7377-d2a5-4...
    6274: authorized_irio... 0.99013749 0.99505652 0c320521-227e-4...
    6275: abandoned_crown... 0.81499534 0.90277092 1b58d05c-33ea-4...

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
       1: 0.4315227 0.6569039 abandoned_crown... 7baa76ef-774d-4...
       2: 0.2540005 0.5039847 authorized_irio... 3d3375d2-3c67-4...
       3: 0.6032159 0.7766698 abandoned_crown... 3a909f05-a35f-4...
       4: 0.8974712 0.9473496 authorized_irio... 0026051b-33ba-4...
       5: 0.6079337 0.7797010 abandoned_crown... 28cd6e46-ad72-4...
      ---
    6683: 0.6083365 0.7799593 authorized_irio... 8aac6420-56b3-4...
    6684: 0.6147776 0.7840776 abandoned_crown... d90c69bd-1b9e-4...
    6685: 0.4657951 0.6824918 authorized_irio... 1ddac7ff-4fcf-4...
    6686: 0.7237675 0.8507453 abandoned_crown... af9c9c0a-189f-4...
    6687: 0.7437853        NA authorized_irio... 05871b7b-c7a1-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.7437853 authorized_irio... 05871b7b-c7a1-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running authorized_irio... 0.7437853 05871b7b-c7a1-4...        NA
       2: finished abandoned_crown... 0.4315227 7baa76ef-774d-4... 0.6569039
       3: finished authorized_irio... 0.2540005 3d3375d2-3c67-4... 0.5039847
       4: finished abandoned_crown... 0.6032159 3a909f05-a35f-4... 0.7766698
       5: finished authorized_irio... 0.8974712 0026051b-33ba-4... 0.9473496
      ---
    6683: finished abandoned_crown... 0.1110038 a76b1da6-e435-4... 0.3331723
    6684: finished authorized_irio... 0.6083365 8aac6420-56b3-4... 0.7799593
    6685: finished abandoned_crown... 0.6147776 d90c69bd-1b9e-4... 0.7840776
    6686: finished authorized_irio... 0.4657951 1ddac7ff-4fcf-4... 0.6824918
    6687: finished abandoned_crown... 0.7237675 af9c9c0a-189f-4... 0.8507453

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

    [1] 6686

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
    [1] 0.5129026


    $key
    [1] "21476c47-e8f4-42e8-ba6a-1fbae0f68e85"

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
