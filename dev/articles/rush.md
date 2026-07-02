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

                   worker_id           x         y               keys
                      <char>       <num>     <num>             <char>
       1: myrmecophagous_... 0.416218074 0.6451497 383f8e17-2666-4...
       2:    improved_scoter 0.442682080 0.6653436 03dd92eb-4088-4...
       3: myrmecophagous_... 0.765982757 0.8752044 c342820e-dc0b-4...
       4: myrmecophagous_... 0.948365533 0.9738406 15aa8c9c-d62c-4...
       5: myrmecophagous_... 0.704057240 0.8390812 c681b920-9566-4...
      ---
    6306: myrmecophagous_... 0.313733932 0.5601196 278c7e47-838b-4...
    6307:    improved_scoter 0.003527397 0.0593919 f6ac8ca7-e835-4...
    6308: myrmecophagous_... 0.309257421 0.5561092 94898e3e-60e6-4...
    6309:    improved_scoter 0.862711927 0.9288229 35ced3a2-eaff-4...
    6310: myrmecophagous_... 0.244803110 0.4947758 cb9d071a-7ec0-4...

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
       1: 0.41621807 0.6451497 myrmecophagous_...    [NULL] 383f8e17-2666-4...
       2: 0.44268208 0.6653436    improved_scoter    [NULL] 03dd92eb-4088-4...
       3: 0.76598276 0.8752044 myrmecophagous_...    [NULL] c342820e-dc0b-4...
       4: 0.06275228 0.2505040    improved_scoter    [NULL] 58635e18-a198-4...
       5: 0.94836553 0.9738406 myrmecophagous_...    [NULL] 15aa8c9c-d62c-4...
      ---
    6726: 0.95553774 0.9775161 myrmecophagous_...    [NULL] 5dc2cf87-b98d-4...
    6727: 0.21306896 0.4615939    improved_scoter    [NULL] 6ec9cb0b-43d5-4...
    6728: 0.79486391 0.8915514 myrmecophagous_...    [NULL] 1e4b4497-db3f-4...
    6729: 0.91032281        NA    improved_scoter <list[1]> 3a8fee23-f1c7-4...
    6730: 0.51948085        NA myrmecophagous_... <list[1]> 83b183a8-98eb-4...

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
    1: 0.9103228    improved_scoter <list[1]> 3a8fee23-f1c7-4...
    2: 0.5194809 myrmecophagous_... <list[1]> 83b183a8-98eb-4...

``` r

rush$fetch_tasks_with_state(states = c("running", "finished"))
```

             state          worker_id         x         y               keys
            <char>             <char>     <num>     <num>             <char>
       1: finished myrmecophagous_... 0.4162181 0.6451497 383f8e17-2666-4...
       2: finished    improved_scoter 0.4426821 0.6653436 03dd92eb-4088-4...
       3: finished myrmecophagous_... 0.7659828 0.8752044 c342820e-dc0b-4...
       4: finished myrmecophagous_... 0.9483655 0.9738406 15aa8c9c-d62c-4...
       5: finished myrmecophagous_... 0.7040572 0.8390812 c681b920-9566-4...
      ---
    6724: finished myrmecophagous_... 0.5734908 0.7572917 c19e19c9-49ce-4...
    6725: finished    improved_scoter 0.4565638 0.6756950 acf8a5f7-9dd0-4...
    6726: finished myrmecophagous_... 0.9555377 0.9775161 5dc2cf87-b98d-4...
    6727: finished    improved_scoter 0.2130690 0.4615939 6ec9cb0b-43d5-4...
    6728: finished myrmecophagous_... 0.7948639 0.8915514 1e4b4497-db3f-4...

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

    [1] 6728

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
    [1] 0.39871


    $key
    [1] "7ccdea71-182e-4243-b3c1-0d60cbfa587e"

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
