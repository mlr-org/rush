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
       1: dissident_engli... 0.60025808 0.7747632 8f067a81-9cb5-4...
       2: veryblue_cormor... 0.63436298 0.7964691 e3fb9bbd-a917-4...
       3: dissident_engli... 0.01136716 0.1066169 419bf6eb-51c8-4...
       4: dissident_engli... 0.36489713 0.6040672 b03d469b-d130-4...
       5: dissident_engli... 0.49741008 0.7052731 18808d76-80f2-4...
      ---
    7289: veryblue_cormor... 0.47867517 0.6918635 8c3ea0c4-362a-4...
    7290: dissident_engli... 0.36785744 0.6065125 94216595-dc46-4...
    7291: veryblue_cormor... 0.85066550 0.9223153 f8d22446-0d40-4...
    7292: dissident_engli... 0.88765749 0.9421558 e10ca511-d297-4...
    7293: veryblue_cormor... 0.57519072 0.7584133 270543cd-553c-4...

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
       1: 0.63436298 0.7964691 veryblue_cormor...    [NULL] e3fb9bbd-a917-4...
       2: 0.60025808 0.7747632 dissident_engli...    [NULL] 8f067a81-9cb5-4...
       3: 0.01136716 0.1066169 dissident_engli...    [NULL] 419bf6eb-51c8-4...
       4: 0.93549325 0.9672090 veryblue_cormor...    [NULL] 57c92d19-e41c-4...
       5: 0.36489713 0.6040672 dissident_engli...    [NULL] b03d469b-d130-4...
      ---
    7790: 0.88243844 0.9393819 veryblue_cormor...    [NULL] 464f0b00-5fa3-4...
    7791: 0.96165874 0.9806420 dissident_engli...    [NULL] ac711a16-dfd0-4...
    7792: 0.33614039 0.5797762 veryblue_cormor...    [NULL] 481c5dc2-b5b0-4...
    7793: 0.64964331        NA dissident_engli... <list[1]> f69394a7-c002-4...
    7794: 0.06718296        NA veryblue_cormor... <list[1]> 89d52b37-ad40-4...

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

                x          worker_id condition               keys
            <num>             <char>    <list>             <char>
    1: 0.64964331 dissident_engli... <list[1]> f69394a7-c002-4...
    2: 0.06718296 veryblue_cormor... <list[1]> 89d52b37-ad40-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id          x         y               keys
            <char>             <char>      <num>     <num>             <char>
       1: finished dissident_engli... 0.60025808 0.7747632 8f067a81-9cb5-4...
       2: finished veryblue_cormor... 0.63436298 0.7964691 e3fb9bbd-a917-4...
       3: finished dissident_engli... 0.01136716 0.1066169 419bf6eb-51c8-4...
       4: finished dissident_engli... 0.36489713 0.6040672 b03d469b-d130-4...
       5: finished dissident_engli... 0.49741008 0.7052731 18808d76-80f2-4...
      ---
    7788: finished veryblue_cormor... 0.91867836 0.9584771 aea80f61-646f-4...
    7789: finished dissident_engli... 0.10480949 0.3237429 de35bd03-365e-4...
    7790: finished veryblue_cormor... 0.88243844 0.9393819 464f0b00-5fa3-4...
    7791: finished dissident_engli... 0.96165874 0.9806420 ac711a16-dfd0-4...
    7792: finished veryblue_cormor... 0.33614039 0.5797762 481c5dc2-b5b0-4...

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

    [1] 7792

``` r

rush$n_failed_tasks
```

    [1] 2

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
    [1] 0.6450794


    $key
    [1] "a46d4883-566b-4e0b-ac27-ae52adb1c9e9"

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
