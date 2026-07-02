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
       1: antiromance_ane... 0.39658258 0.6297480 eb6f04e7-7cce-4...
       2:     inodorous_hind 0.04417126 0.2101696 03f64cf2-ad35-4...
       3: antiromance_ane... 0.94767746 0.9734873 fab0efca-0786-4...
       4: antiromance_ane... 0.47491230 0.6891388 3866bb9b-438c-4...
       5:     inodorous_hind 0.41312019 0.6427443 c016caf7-e815-4...
      ---
    8265:     inodorous_hind 0.63062722 0.7941204 60c08b3b-9ef3-4...
    8266: antiromance_ane... 0.28370240 0.5326372 bf91de53-f277-4...
    8267:     inodorous_hind 0.04678533 0.2162992 d59d098f-c022-4...
    8268: antiromance_ane... 0.83012696 0.9111130 fccf36d1-e74e-4...
    8269:     inodorous_hind 0.65205550 0.8074995 cb821603-6620-4...

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

                   x         y          worker_id condition               keys
               <num>     <num>             <char>    <list>             <char>
       1: 0.04417126 0.2101696     inodorous_hind    [NULL] 03f64cf2-ad35-4...
       2: 0.39658258 0.6297480 antiromance_ane...    [NULL] eb6f04e7-7cce-4...
       3: 0.94767746 0.9734873 antiromance_ane...    [NULL] fab0efca-0786-4...
       4: 0.41312019 0.6427443     inodorous_hind    [NULL] c016caf7-e815-4...
       5: 0.47491230 0.6891388 antiromance_ane...    [NULL] 3866bb9b-438c-4...
      ---
    8951: 0.02889579 0.1699876     inodorous_hind    [NULL] 08775aef-ebc2-4...
    8952: 0.54180109 0.7360714 antiromance_ane...    [NULL] cddd75eb-5c19-4...
    8953: 0.91426393 0.9561715     inodorous_hind    [NULL] bc1cb1d3-3ce1-4...
    8954: 0.49264041 0.7018835 antiromance_ane...    [NULL] a31d6145-cb19-4...
    8955: 0.66726651        NA     inodorous_hind <list[1]> 6e46b780-c901-4...

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

               x      worker_id condition               keys
           <num>         <char>    <list>             <char>
    1: 0.6672665 inodorous_hind <list[1]> 6e46b780-c901-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished antiromance_ane... 0.39658258 0.6297480 eb6f04e7-7cce-4...
       2: finished     inodorous_hind 0.04417126 0.2101696 03f64cf2-ad35-4...
       3: finished antiromance_ane... 0.94767746 0.9734873 fab0efca-0786-4...
       4: finished antiromance_ane... 0.47491230 0.6891388 3866bb9b-438c-4...
       5: finished     inodorous_hind 0.41312019 0.6427443 c016caf7-e815-4...
      ---
    8950: finished antiromance_ane... 0.62547127 0.7908674 59536428-d405-4...
    8951: finished     inodorous_hind 0.02889579 0.1699876 08775aef-ebc2-4...
    8952: finished antiromance_ane... 0.54180109 0.7360714 cddd75eb-5c19-4...
    8953: finished     inodorous_hind 0.91426393 0.9561715 bc1cb1d3-3ce1-4...
    8954: finished antiromance_ane... 0.49264041 0.7018835 a31d6145-cb19-4...

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

    [1] 8954

``` r

rush$n_failed_tasks
```

    [1] 1

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
    [1] 0.4380968


    $key
    [1] "e7eb6f2c-386d-47cf-8f60-934551d2ce43"

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
