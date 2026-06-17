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
       1: undespondent_or... 0.6968623 0.8347828 806ad799-932c-4...
       2: undespondent_or... 0.9667971 0.9832584 cc020291-ef4c-4...
       3: undespondent_or... 0.8520761 0.9230797 c530758b-e2f3-4...
       4: undespondent_or... 0.3368620 0.5803982 8dccef58-c4af-4...
       5: undespondent_or... 0.5410021 0.7355285 810c996c-30f5-4...
      ---
    6131: prismatic_hecto... 0.1716146 0.4142640 5cc82f0b-cd1f-4...
    6132: prismatic_hecto... 0.9204643 0.9594083 96e2e602-3643-4...
    6133: undespondent_or... 0.1586086 0.3982570 d2c5a250-fd0f-4...
    6134: undespondent_or... 0.5575695 0.7467057 aaf0bc35-652b-4...
    6135: prismatic_hecto... 0.1968033 0.4436252 5c62e7b4-5a67-4...

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
       1: 0.6968623 0.8347828 undespondent_or... 806ad799-932c-4...
       2: 0.5729035 0.7569039 prismatic_hecto... d8ff9da8-d71a-4...
       3: 0.9667971 0.9832584 undespondent_or... cc020291-ef4c-4...
       4: 0.8520761 0.9230797 undespondent_or... c530758b-e2f3-4...
       5: 0.3368620 0.5803982 undespondent_or... 8dccef58-c4af-4...
      ---
    6545: 0.3589090 0.5990901 prismatic_hecto... 9bdde2f6-d591-4...
    6546: 0.9538628 0.9766590 undespondent_or... 285a5323-8bb8-4...
    6547: 0.5098418 0.7140321 prismatic_hecto... 4dad545b-d856-4...
    6548: 0.9051747 0.9514067 undespondent_or... 9e24db7a-0ee8-4...
    6549: 0.6699385        NA prismatic_hecto... 7883a39c-5e26-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.6699385 prismatic_hecto... 7883a39c-5e26-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x               keys         y
            <char>             <char>     <num>             <char>     <num>
       1:  running prismatic_hecto... 0.6699385 7883a39c-5e26-4...        NA
       2: finished undespondent_or... 0.6968623 806ad799-932c-4... 0.8347828
       3: finished undespondent_or... 0.9667971 cc020291-ef4c-4... 0.9832584
       4: finished undespondent_or... 0.8520761 c530758b-e2f3-4... 0.9230797
       5: finished undespondent_or... 0.3368620 8dccef58-c4af-4... 0.5803982
      ---
    6545: finished undespondent_or... 0.7689574 2b42f25b-6856-4... 0.8769022
    6546: finished prismatic_hecto... 0.3589090 9bdde2f6-d591-4... 0.5990901
    6547: finished undespondent_or... 0.9538628 285a5323-8bb8-4... 0.9766590
    6548: finished prismatic_hecto... 0.5098418 4dad545b-d856-4... 0.7140321
    6549: finished undespondent_or... 0.9051747 9e24db7a-0ee8-4... 0.9514067

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

    [1] 6548

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
    [1] 0.2955619


    $key
    [1] "24d7f35c-cf24-479f-b79e-ef9b2406532a"

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
