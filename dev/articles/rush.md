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
       1:     fancy_bactrian 0.36437564 0.6036353 2dcb8c99-ca6b-4...
       2: obeliskoid_wood... 0.82732145 0.9095721 93378540-efed-4...
       3: obeliskoid_wood... 0.44643063 0.6681546 c234f5d3-788d-4...
       4:     fancy_bactrian 0.46618422 0.6827768 a91c486f-a764-4...
       5:     fancy_bactrian 0.23583045 0.4856238 8eabe610-fb26-4...
      ---
    5782:     fancy_bactrian 0.59380837 0.7705896 606406ea-4aa4-4...
    5783: obeliskoid_wood... 0.05830209 0.2414583 a6b4fe94-f0c5-4...
    5784:     fancy_bactrian 0.74378727 0.8624310 176a3008-1be6-4...
    5785: obeliskoid_wood... 0.05124252 0.2263681 9c349b56-1b1a-4...
    5786:     fancy_bactrian 0.80952349 0.8997352 274df949-de6a-4...

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
       1: 0.8273214 0.9095721 obeliskoid_wood... 93378540-efed-4...
       2: 0.3643756 0.6036353     fancy_bactrian 2dcb8c99-ca6b-4...
       3: 0.4464306 0.6681546 obeliskoid_wood... c234f5d3-788d-4...
       4: 0.4661842 0.6827768     fancy_bactrian a91c486f-a764-4...
       5: 0.2358304 0.4856238     fancy_bactrian 8eabe610-fb26-4...
      ---
    6143: 0.2575482 0.5074921     fancy_bactrian c6db77e7-82a5-4...
    6144: 0.1809129 0.4253386 obeliskoid_wood... 6103847b-390a-4...
    6145: 0.8940657 0.9455505     fancy_bactrian e0c4edc8-fdfd-4...
    6146: 0.5091031 0.7135146 obeliskoid_wood... 61f13c67-f06a-4...
    6147: 0.7735748        NA     fancy_bactrian 8e54f55e-ac19-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x      worker_id               keys
           <num>         <char>             <char>
    1: 0.7735748 fancy_bactrian 8e54f55e-ac19-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running     fancy_bactrian 0.7735748 8e54f55e-ac19-4...        NA
       2: finished     fancy_bactrian 0.3643756 2dcb8c99-ca6b-4... 0.6036353
       3: finished obeliskoid_wood... 0.8273214 93378540-efed-4... 0.9095721
       4: finished obeliskoid_wood... 0.4464306 c234f5d3-788d-4... 0.6681546
       5: finished     fancy_bactrian 0.4661842 a91c486f-a764-4... 0.6827768
      ---
    6143: finished obeliskoid_wood... 0.9871937 e3590ec4-d060-4... 0.9935762
    6144: finished     fancy_bactrian 0.2575482 c6db77e7-82a5-4... 0.5074921
    6145: finished obeliskoid_wood... 0.1809129 6103847b-390a-4... 0.4253386
    6146: finished     fancy_bactrian 0.8940657 e0c4edc8-fdfd-4... 0.9455505
    6147: finished obeliskoid_wood... 0.5091031 61f13c67-f06a-4... 0.7135146

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

    [1] 6146

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
    [1] 0.4708909


    $key
    [1] "3527aa43-b4c8-41b3-9305-9f98bdc07b10"

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
