# Error Handling and Debugging

`rush` provides error-handling mechanisms for two failure modes:
standard R errors during task evaluation and unexpected worker failures
such as crashes or lost connections. If errors cannot be caught
automatically, the worker loop can be debugged locally.

## Simple R Errors

We use the random search example from the
[tutorial](https://rush.mlr-org.com/dev/articles/tutorial.md) and
introduce a random error with 50% probability. Within the worker loop,
users are responsible for catching errors and marking the corresponding
task as `"failed"` using the `$fail_tasks()` method.

``` r

library(rush)

branin = function(x1, x2) {
  (x2 - 5.1 / (4 * pi^2) * x1^2 + 5 / pi * x1 - 6)^2 + 10 * (1 - 1 / (8 * pi)) * cos(x1) + 10
}

wl_random_search = function(rush, branin) {

  while (rush$n_finished_tasks < 100) {

    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))

    tryCatch({
      if (runif(1) < 0.5) stop("Random Error")
      ys = list(y = branin(xs$x1, xs$x2))
      rush$finish_tasks(key, yss = list(ys))
    }, error = function(e) {
      condition = list(message = e$message)
      rush$fail_tasks(key, conditions = list(condition))
    })
  }
}
```

We initialize the network and start the workers.

``` r

rush = rsh(
  network = "test-simple-error",
  config = redux::redis_config())

mirai::daemons(4)

rush$start_workers(
  worker_loop = wl_random_search,
  n_workers = 4,
  branin = branin)
```

When an error occurs, the task is marked as `"failed"` and the error
message is stored in the `"message"` column. This ensures that errors do
not interrupt the overall execution and allows subsequent inspection and
reevaluation of failed tasks.

``` r

rush$fetch_failed_tasks()
```

                 x1         x2     worker_id condition          keys
              <num>      <num>        <char>    <list>        <char>
      1:  8.3516096 10.8567926 droughty_s... <list[1]> 5f4f972c-1...
      2: -4.1367377  3.7309805 unspecifie... <list[1]> 556d7b16-7...
      3: -4.3831033  6.7461348 droughty_s... <list[1]> bfae7e9a-b...
      4:  0.0501993  9.6252118 ornate_dai... <list[1]> 987c77a3-c...
      5: -4.3223709  2.6495541 ornate_dai... <list[1]> 35aca526-9...
     ---
     97:  4.6272166 14.7760561 specious_n... <list[1]> 30d45158-c...
     98: -1.2574822  5.5466488 ornate_dai... <list[1]> 9453dedd-0...
     99: -4.8183911 11.8845050 ornate_dai... <list[1]> c74a2dff-3...
    100: -4.9057133 10.2201705 unspecifie... <list[1]> 447dfd71-3...
    101: -2.9386339  0.4207523 ornate_dai... <list[1]> bcaa76dd-2...

## Handling Failing Workers

When a worker fails due to a crash or lost connection, its tasks may
remain in the `"running"` state indefinitely. We simulate a segmentation
fault by terminating the worker process.

``` r

wl_failed_worker = function(rush) {
  xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
  key = rush$push_running_tasks(xss = list(xs))

  tools::pskill(Sys.getpid(), tools::SIGKILL)
}

rush = rsh(
  network = "test-failed-workers",
  config = redux::redis_config())

mirai::daemons(2)

worker_ids = rush$start_workers(
  worker_loop = wl_failed_worker,
  n_workers = 2)
```

The `$detect_lost_workers()` method identifies such workers and updates
their state to `"terminated"`. For workers started with
`$start_local_workers()` or `$start_workers()`, lost worker detection
works automatically by checking process status. Workers started via
`$worker_script()` require an additional heartbeat mechanism (see the
[manager
vignette](https://rush.mlr-org.com/dev/articles/manager.html#sec-script-error-handling)).

``` r

rush$detect_lost_workers()
```

    [1] "disorganized_atlanticblackgoby" "antifeministic_dragon"         

When a worker fails, the state of any task it was evaluating is set to
`"failed"`.

``` r

rush$fetch_failed_tasks()
```

             x1        x2     worker_id condition          keys
          <num>     <num>        <char>    <list>        <char>
    1: 5.079767  9.546363 disorganiz... <list[1]> ed7cba85-7...
    2: 4.509444 12.023355 antifemini... <list[1]> e2b3677e-d...

## Debugging

When the worker loop fails due to an uncaught error, the loop can be
executed locally to reproduce and inspect the failure. Consider the
following worker loop, which generates an error for large values of
`x1`.

``` r

wl_error = function(rush) {

  repeat {
    x1 = runif(1)
    x2 = runif(1)

    xss = list(list(x1 = x1, x2 = x2))

    key = rush$push_running_tasks(xss = xss)

    if (x1 > 0.90) {
      stop("Unexpected error")
    }

    rush$finish_tasks(key, yss = list(list(y = x1 + x2)))
  }
}
```

To debug the worker loop locally, a `RushWorker` instance is
instantiated manually and passed as argument to the worker loop.

``` r

rush_worker = RushWorker$new(network_id = "test-error")

wl_error(rush_worker)
```

    Error in `wl_error()`:
    ! Unexpected error

When an error is raised in the main process,
[`traceback()`](https://rdrr.io/r/base/traceback.html) can be called to
examine the stack trace and breakpoints can be set within the worker
loop to inspect the program state. Note that certain errors such as
missing packages may not be reproducible locally but can be identified
by running the worker loop in a separate process and using
`$detect_lost_workers()`.

``` r

rush = rsh(
  network = "test-error",
  config = redux::redis_config())

mirai::daemons(1)

rush$start_workers(
  worker_loop = wl_error,
  n_workers = 1)
```

``` r

rush$detect_lost_workers()
```

    [1] "hyperritualistic_stilt"

Output and message logs can be written to files via the `message_log`
and `output_log` arguments.

``` r

rush = rsh(
  network = "test-error",
  config = redux::redis_config())

message_log = tempdir()
output_log = tempdir()

mirai::daemons(1)

worker_ids = rush$start_workers(
  worker_loop = wl_error,
  n_workers = 1,
  message_log = message_log,
  output_log = output_log)

Sys.sleep(5)

readLines(file.path(message_log, sprintf("message_%s.log", worker_ids[1])))
```

    [1] "Debug message logging on worker passionate_fishingcat started"

``` r

readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker passionate_fishingcat started\""
