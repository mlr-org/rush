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
       1: soubrettish_cha... 0.0541148 0.2326259 d19fcde8-435e-4...
       2: polonium_anacon... 0.9017112 0.9495848 e8ad2fa7-3a15-4...
       3: soubrettish_cha... 0.9779243 0.9889005 45ad57e0-dddc-4...
       4: polonium_anacon... 0.3764291 0.6135382 f80d3fc5-6f1a-4...
       5: soubrettish_cha... 0.9824464 0.9911844 051ec500-3b2b-4...
      ---
    6297: polonium_anacon... 0.7343275 0.8569291 ae426b09-4da2-4...
    6298: soubrettish_cha... 0.7113194 0.8433976 d5354dc9-4f01-4...
    6299: polonium_anacon... 0.2476734 0.4976680 bc35497c-8fe1-4...
    6300: soubrettish_cha... 0.6908033 0.8311458 d58a309c-9eb1-4...
    6301: polonium_anacon... 0.7213823 0.8493423 6327b729-1a9b-4...

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
       1: 0.90171121 0.9495848 polonium_anacon... e8ad2fa7-3a15-4...
       2: 0.05411480 0.2326259 soubrettish_cha... d19fcde8-435e-4...
       3: 0.97792426 0.9889005 soubrettish_cha... 45ad57e0-dddc-4...
       4: 0.37642914 0.6135382 polonium_anacon... f80d3fc5-6f1a-4...
       5: 0.98244642 0.9911844 soubrettish_cha... 051ec500-3b2b-4...
      ---
    6744: 0.83147242 0.9118511 soubrettish_cha... 54f39158-dfd8-4...
    6745: 0.46449484 0.6815386 polonium_anacon... 1e4f5833-a35e-4...
    6746: 0.43333146 0.6582792 soubrettish_cha... bbea3f40-84f8-4...
    6747: 0.08328175 0.2885858 polonium_anacon... 0214d9a2-57d2-4...
    6748: 0.01597183 0.1263797 soubrettish_cha... e13260d7-67c0-4...

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
       1: finished soubrettish_cha... 0.05411480 0.2326259 d19fcde8-435e-4...
       2: finished polonium_anacon... 0.90171121 0.9495848 e8ad2fa7-3a15-4...
       3: finished soubrettish_cha... 0.97792426 0.9889005 45ad57e0-dddc-4...
       4: finished polonium_anacon... 0.37642914 0.6135382 f80d3fc5-6f1a-4...
       5: finished soubrettish_cha... 0.98244642 0.9911844 051ec500-3b2b-4...
      ---
    6744: finished soubrettish_cha... 0.83147242 0.9118511 54f39158-dfd8-4...
    6745: finished soubrettish_cha... 0.43333146 0.6582792 bbea3f40-84f8-4...
    6746: finished polonium_anacon... 0.46449484 0.6815386 1e4f5833-a35e-4...
    6747: finished polonium_anacon... 0.08328175 0.2885858 0214d9a2-57d2-4...
    6748: finished soubrettish_cha... 0.01597183 0.1263797 e13260d7-67c0-4...

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

    [1] 6748

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
    [1] 0.6203388


    $key
    [1] "91701858-9975-448c-9c1b-4fc4ba031aba"

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
