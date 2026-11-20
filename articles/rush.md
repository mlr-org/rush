# rush - Quick Reference

A quick reference cheatsheet for `rush`. See the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) for a detailed
introduction.

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
       1: crass_arieltouc... 0.19640351 0.4431744 e9bf5a9c-3868-4...
       2: dogmatic_ibizan... 0.59262200 0.7698195 e84595a9-22b5-4...
       3: crass_arieltouc... 0.19115175 0.4372090 48c59097-4493-4...
       4: crass_arieltouc... 0.34442505 0.5868774 08c4473e-408a-4...
       5: crass_arieltouc... 0.12797011 0.3577291 843ad215-0bdb-4...
      ---
    8566: dogmatic_ibizan... 0.74204743 0.8614217 51cfe21d-cbef-4...
    8567: crass_arieltouc... 0.07448096 0.2729120 145657ee-93f1-4...
    8568: dogmatic_ibizan... 0.13892697 0.3727291 1d48d199-6115-4...
    8569: crass_arieltouc... 0.27345729 0.5229314 23755487-a74d-4...
    8570: dogmatic_ibizan... 0.77544256 0.8805922 ad3fbdb7-c973-4...

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
       1: 0.1964035 0.4431744 crass_arieltouc... e9bf5a9c-3868-4...
       2: 0.5926220 0.7698195 dogmatic_ibizan... e84595a9-22b5-4...
       3: 0.1911517 0.4372090 crass_arieltouc... 48c59097-4493-4...
       4: 0.3957422 0.6290804 dogmatic_ibizan... 6b667ee6-de10-4...
       5: 0.3444250 0.5868774 crass_arieltouc... 08c4473e-408a-4...
      ---
    9251: 0.6606496 0.8128035 dogmatic_ibizan... b612cbcd-c012-4...
    9252: 0.5106060 0.7145670 crass_arieltouc... 02beb073-f727-4...
    9253: 0.6003599 0.7748290 dogmatic_ibizan... f2048f55-cf01-4...
    9254: 0.8828224 0.9395863 crass_arieltouc... f84caba9-4a02-4...
    9255: 0.5156097 0.7180597 dogmatic_ibizan... 317c847e-a62a-4...

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

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished crass_arieltouc... 0.1964035 0.4431744 e9bf5a9c-3868-4...
       2: finished dogmatic_ibizan... 0.5926220 0.7698195 e84595a9-22b5-4...
       3: finished crass_arieltouc... 0.1911517 0.4372090 48c59097-4493-4...
       4: finished crass_arieltouc... 0.3444250 0.5868774 08c4473e-408a-4...
       5: finished crass_arieltouc... 0.1279701 0.3577291 843ad215-0bdb-4...
      ---
    9251: finished dogmatic_ibizan... 0.6606496 0.8128035 b612cbcd-c012-4...
    9252: finished crass_arieltouc... 0.5106060 0.7145670 02beb073-f727-4...
    9253: finished dogmatic_ibizan... 0.6003599 0.7748290 f2048f55-cf01-4...
    9254: finished crass_arieltouc... 0.8828224 0.9395863 f84caba9-4a02-4...
    9255: finished dogmatic_ibizan... 0.5156097 0.7180597 317c847e-a62a-4...

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

    [1] 9255

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
    [1] 0.4691135


    $key
    [1] "75512f6e-d5f8-4583-8350-ca036618c06e"

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

    Rscript -e 'rush::start_worker(network_id = "my_network", config = list(scheme = "redis", host = "127.0.0.1", port = "6379"))'

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
