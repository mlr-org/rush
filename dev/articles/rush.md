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
       1:    gauzy_bumblebee 0.29769069 0.5456104 65211ed4-3fe3-4...
       2:    gauzy_bumblebee 0.10490765 0.3238945 2e15b38b-4fc6-4...
       3:    gauzy_bumblebee 0.52604902 0.7252924 96e31e45-ee23-4...
       4: preoccupied_kou... 0.05934008 0.2435982 772c3546-c862-4...
       5:    gauzy_bumblebee 0.75175731 0.8670394 585608ef-ee02-4...
      ---
    5698: preoccupied_kou... 0.58581127 0.7653831 522a022e-60ed-4...
    5699:    gauzy_bumblebee 0.79418975 0.8911732 f022f4e5-2d5b-4...
    5700: preoccupied_kou... 0.07472130 0.2733520 f1a38b8f-92c4-4...
    5701:    gauzy_bumblebee 0.44449250 0.6667027 ecb28acb-e082-4...
    5702: preoccupied_kou... 0.96585258 0.9827780 21a7e607-136a-4...

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
       1: 0.059340077 0.24359819 preoccupied_kou... 772c3546-c862-4...
       2: 0.297690689 0.54561038    gauzy_bumblebee 65211ed4-3fe3-4...
       3: 0.104907648 0.32389450    gauzy_bumblebee 2e15b38b-4fc6-4...
       4: 0.526049022 0.72529237    gauzy_bumblebee 96e31e45-ee23-4...
       5: 0.751757312 0.86703939    gauzy_bumblebee 585608ef-ee02-4...
      ---
    6067: 0.967117539 0.98342134    gauzy_bumblebee f32728a8-5066-4...
    6068: 0.007715907 0.08784024 preoccupied_kou... 503d6a4d-6f2e-4...
    6069: 0.158045563 0.39754945    gauzy_bumblebee 5d542e4f-1a35-4...
    6070: 0.423647458 0.65088206 preoccupied_kou... 2de625d4-f8bf-4...
    6071: 0.794024336         NA    gauzy_bumblebee e8295c84-930d-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x       worker_id               keys
           <num>          <char>             <char>
    1: 0.7940243 gauzy_bumblebee e8295c84-930d-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x               keys          y
            <char>             <char>       <num>             <char>      <num>
       1:  running    gauzy_bumblebee 0.794024336 e8295c84-930d-4...         NA
       2: finished    gauzy_bumblebee 0.297690689 65211ed4-3fe3-4... 0.54561038
       3: finished    gauzy_bumblebee 0.104907648 2e15b38b-4fc6-4... 0.32389450
       4: finished    gauzy_bumblebee 0.526049022 96e31e45-ee23-4... 0.72529237
       5: finished preoccupied_kou... 0.059340077 772c3546-c862-4... 0.24359819
      ---
    6067: finished preoccupied_kou... 0.082383435 fa018a9d-8384-4... 0.28702515
    6068: finished    gauzy_bumblebee 0.967117539 f32728a8-5066-4... 0.98342134
    6069: finished preoccupied_kou... 0.007715907 503d6a4d-6f2e-4... 0.08784024
    6070: finished    gauzy_bumblebee 0.158045563 5d542e4f-1a35-4... 0.39754945
    6071: finished preoccupied_kou... 0.423647458 2de625d4-f8bf-4... 0.65088206

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

    [1] 6070

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
    [1] 0.06081533


    $key
    [1] "5d7a23e2-6822-4bbc-afa4-d073ad1871ae"

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
