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
       1: riotous_praying... 0.98324258 0.9915859 03ad68a4-4c51-4...
       2: riotous_praying... 0.32517417 0.5702404 90964148-1a8d-4...
       3: riotous_praying... 0.85995082 0.9273353 76470d4c-bd42-4...
       4: riotous_praying... 0.79548150 0.8918977 67abba88-2528-4...
       5: riotous_praying... 0.09541388 0.3088914 9606836e-1bec-4...
      ---
    5823: subhexagonal_so... 0.68854099 0.8297837 61f45daf-ed38-4...
    5824: riotous_praying... 0.71294453 0.8443604 2e6ce1c4-37fe-4...
    5825: subhexagonal_so... 0.66963060 0.8183096 9d4d4e80-c3dc-4...
    5826: riotous_praying... 0.54054884 0.7352203 1f123096-45af-4...
    5827: subhexagonal_so... 0.72631054 0.8522385 9318145d-0aae-4...

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
       1: 0.9832426 0.9915859 riotous_praying... 03ad68a4-4c51-4...
       2: 0.5293767 0.7275828 subhexagonal_so... 88a572e9-52ad-4...
       3: 0.3251742 0.5702404 riotous_praying... 90964148-1a8d-4...
       4: 0.8599508 0.9273353 riotous_praying... 76470d4c-bd42-4...
       5: 0.7954815 0.8918977 riotous_praying... 67abba88-2528-4...
      ---
    6209: 0.8233994 0.9074136 riotous_praying... 1ec36db5-74d0-4...
    6210: 0.7883416 0.8878860 subhexagonal_so... 01ac72f9-a53a-4...
    6211: 0.6377668 0.7986030 riotous_praying... 9cf45fbf-2ebe-4...
    6212: 0.0181148 0.1345912 subhexagonal_so... 7a3d3904-4590-4...
    6213: 0.4209900        NA riotous_praying... a74b2b21-828c-4...

``` r

rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_running_tasks()
```

             x          worker_id               keys
         <num>             <char>             <char>
    1: 0.42099 riotous_praying... a74b2b21-828c-4...

``` r

rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x               keys         y
            <char>             <char>      <num>             <char>     <num>
       1:  running riotous_praying... 0.42099002 a74b2b21-828c-4...        NA
       2: finished riotous_praying... 0.98324258 03ad68a4-4c51-4... 0.9915859
       3: finished riotous_praying... 0.32517417 90964148-1a8d-4... 0.5702404
       4: finished riotous_praying... 0.85995082 76470d4c-bd42-4... 0.9273353
       5: finished riotous_praying... 0.79548150 67abba88-2528-4... 0.8918977
      ---
    6209: finished subhexagonal_so... 0.05233528 08a6c772-4b22-4... 0.2287691
    6210: finished riotous_praying... 0.82339938 1ec36db5-74d0-4... 0.9074136
    6211: finished subhexagonal_so... 0.78834155 01ac72f9-a53a-4... 0.8878860
    6212: finished riotous_praying... 0.63776675 9cf45fbf-2ebe-4... 0.7986030
    6213: finished subhexagonal_so... 0.01811480 7a3d3904-4590-4... 0.1345912

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

    [1] 6212

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
    [1] 0.4717276


    $key
    [1] "b8e559c0-3ebb-4e30-ac22-faf9a3a1e50b"

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
