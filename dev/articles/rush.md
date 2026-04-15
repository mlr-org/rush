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
       1: shaven_zebratai... 0.09424457 0.3069928 901ce280-7dcf-4...
       2: shaven_zebratai... 0.04794972 0.2189742 209f28f0-b8b7-4...
       3:    gullible_oyster 0.65564912 0.8097216 8c184cfa-cf1a-4...
       4: shaven_zebratai... 0.93223246 0.9655219 9cecf23a-f9bf-4...
       5:    gullible_oyster 0.13996480 0.3741187 ec188b92-9d24-4...
      ---
    5875: shaven_zebratai... 0.48989297 0.6999235 45649932-fc5e-4...
    5876:    gullible_oyster 0.29770018 0.5456191 b7619446-e63d-4...
    5877: shaven_zebratai... 0.72881753 0.8537081 635f942e-b111-4...
    5878:    gullible_oyster 0.94167573 0.9703998 b2635802-4c06-4...
    5879: shaven_zebratai... 0.98244461 0.9911834 813cb2c7-8da3-4...

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
       1: 0.09424457 0.3069928 shaven_zebratai... 901ce280-7dcf-4...
       2: 0.65564912 0.8097216    gullible_oyster 8c184cfa-cf1a-4...
       3: 0.04794972 0.2189742 shaven_zebratai... 209f28f0-b8b7-4...
       4: 0.93223246 0.9655219 shaven_zebratai... 9cecf23a-f9bf-4...
       5: 0.13996480 0.3741187    gullible_oyster ec188b92-9d24-4...
      ---
    6265: 0.01379096 0.1174349    gullible_oyster 7654bbe1-4f22-4...
    6266: 0.94746170 0.9733764 shaven_zebratai... 97e40ab3-c45c-4...
    6267: 0.67879268 0.8238888    gullible_oyster 511a1e36-b876-4...
    6268: 0.53916911 0.7342814    gullible_oyster 9505bf5b-7012-4...
    6269: 0.18693015 0.4323542 shaven_zebratai... 65a68d6a-8df0-4...

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

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished shaven_zebratai... 0.09424457 0.3069928 901ce280-7dcf-4...
       2: finished shaven_zebratai... 0.04794972 0.2189742 209f28f0-b8b7-4...
       3: finished    gullible_oyster 0.65564912 0.8097216 8c184cfa-cf1a-4...
       4: finished shaven_zebratai... 0.93223246 0.9655219 9cecf23a-f9bf-4...
       5: finished    gullible_oyster 0.13996480 0.3741187 ec188b92-9d24-4...
      ---
    6265: finished    gullible_oyster 0.01379096 0.1174349 7654bbe1-4f22-4...
    6266: finished shaven_zebratai... 0.94746170 0.9733764 97e40ab3-c45c-4...
    6267: finished    gullible_oyster 0.67879268 0.8238888 511a1e36-b876-4...
    6268: finished    gullible_oyster 0.53916911 0.7342814 9505bf5b-7012-4...
    6269: finished shaven_zebratai... 0.18693015 0.4323542 65a68d6a-8df0-4...

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

    [1] 6269

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
    [1] 0.9709325


    $key
    [1] "e78fcaba-e176-47f2-bcf5-bc04bbb47b2c"

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
