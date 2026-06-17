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

                 x1        x2     worker_id       message          keys
              <num>     <num>        <char>        <char>        <char>
      1:  1.8613958  1.638842 fullgrown_... Random Err... e0547b6b-7...
      2:  6.4075484 10.672259 drippy_upu... Random Err... 5d45c96b-9...
      3: -4.8949011  2.665944 fullgrown_... Random Err... eee97cb7-c...
      4: -2.8321986  3.541099 fullgrown_... Random Err... bb7ccfbf-2...
      5: -3.0215102  8.127955 fullgrown_... Random Err... 6649510c-9...
     ---
    104:  7.1413801  7.540253 fullgrown_... Random Err... 9bbd5742-f...
    105:  1.6100162  7.698380 earthborn_... Random Err... bed38728-b...
    106:  8.3303209  7.010890 blessed_su... Random Err... c2ddedbd-b...
    107:  0.1825968  6.439727 drippy_upu... Random Err... 508d2497-4...
    108: -3.5508597  4.551511 drippy_upu... Random Err... c7e8ebcd-3...

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

    [1] "puzzled_gannet" "hasty_rail"    

When a worker fails, the state of any task it was evaluating is set to
`"failed"`.

``` r

rush$fetch_failed_tasks()
```

              x1        x2     worker_id       message          keys
           <num>     <num>        <char>        <char>        <char>
    1:  8.921344 9.5351634 puzzled_ga... Worker has... c32689d4-5...
    2: -2.644603 0.6116022    hasty_rail Worker has... 9f0fc6e3-7...

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

    [1] "pompous_teal"

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

    [1] "Debug message logging on worker rocky_numbat started"

``` r

readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker rocky_numbat started\""
