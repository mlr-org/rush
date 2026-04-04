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
       1: nonirrational_i... 0.6381224 0.7988257 c6df3e3e-2247-4...
       2: nonirrational_i... 0.5126596 0.7160025 6b1b827e-cb38-4...
       3:      agreed_ocelot 0.7028887 0.8383846 58daf3fc-1d59-4...
       4: nonirrational_i... 0.5567195 0.7461364 09766682-cd6f-4...
       5: nonirrational_i... 0.1414600 0.3761117 4507abaa-a6f9-4...
      ---
    5926:      agreed_ocelot 0.7072937 0.8410075 ecb4baa9-acfe-4...
    5927: nonirrational_i... 0.2638684 0.5136812 f8cded18-5167-4...
    5928:      agreed_ocelot 0.5406039 0.7352577 b806471b-2ac0-4...
    5929: nonirrational_i... 0.1744121 0.4176267 79adc730-c0f0-4...
    5930:      agreed_ocelot 0.3351238 0.5788987 2afe2f28-ff4d-4...

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
       1: 0.638122438 0.79882566 nonirrational_i... c6df3e3e-2247-4...
       2: 0.702888720 0.83838459      agreed_ocelot 58daf3fc-1d59-4...
       3: 0.512659566 0.71600249 nonirrational_i... 6b1b827e-cb38-4...
       4: 0.556719539 0.74613641 nonirrational_i... 09766682-cd6f-4...
       5: 0.141460000 0.37611169 nonirrational_i... 4507abaa-a6f9-4...
      ---
    6323: 0.204651803 0.45238457      agreed_ocelot a506e3e7-a6ac-4...
    6324: 0.004786388 0.06918373 nonirrational_i... 76ce31ef-bba2-4...
    6325: 0.024907413 0.15782083      agreed_ocelot e59c101a-0f15-4...
    6326: 0.323995475         NA nonirrational_i... cd9db225-1247-4...
    6327: 0.088952438 0.29824895      agreed_ocelot 76aab164-2888-4...

``` r
rush$fetch_queued_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_running_tasks()
```

               x          worker_id               keys
           <num>             <char>             <char>
    1: 0.3239955 nonirrational_i... cd9db225-1247-4...

``` r
rush$fetch_failed_tasks()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id           x               keys          y
            <char>             <char>       <num>             <char>      <num>
       1:  running nonirrational_i... 0.323995475 cd9db225-1247-4...         NA
       2: finished nonirrational_i... 0.638122438 c6df3e3e-2247-4... 0.79882566
       3: finished nonirrational_i... 0.512659566 6b1b827e-cb38-4... 0.71600249
       4: finished      agreed_ocelot 0.702888720 58daf3fc-1d59-4... 0.83838459
       5: finished nonirrational_i... 0.556719539 09766682-cd6f-4... 0.74613641
      ---
    6323: finished nonirrational_i... 0.994264466 1da91b68-fb0c-4... 0.99712811
    6324: finished      agreed_ocelot 0.204651803 a506e3e7-a6ac-4... 0.45238457
    6325: finished      agreed_ocelot 0.024907413 e59c101a-0f15-4... 0.15782083
    6326: finished nonirrational_i... 0.004786388 76ce31ef-bba2-4... 0.06918373
    6327: finished      agreed_ocelot 0.088952438 76aab164-2888-4... 0.29824895

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

    [1] 6326

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
    [1] 0.1647099


    $key
    [1] "a56a6a01-b38a-47cc-b0be-a77def7224e6"

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
