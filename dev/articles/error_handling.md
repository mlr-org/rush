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
      1:  1.7785368  1.636041 purehearte... Random Err... 8fdf7170-8...
      2: -1.0385828  1.171502 insurrecti... Random Err... acd3428e-2...
      3:  7.8800515  1.093184 spottable_... Random Err... 9fe70229-b...
      4:  0.8468746 11.750028 purehearte... Random Err... d0a5acd4-b...
      5:  2.8468760  8.938673 purehearte... Random Err... 58abc3aa-3...
     ---
    108:  8.2118647  9.098809 insurrecti... Random Err... 8e90deab-a...
    109:  8.5406889 10.524559 insurrecti... Random Err... 60cd9d80-3...
    110:  9.7350251  2.897132 purehearte... Random Err... 3d9cba1a-8...
    111:  9.0475265  9.326379 warmhearte... Random Err... caf258ac-0...
    112:  6.6316475 11.091057 purehearte... Random Err... ea4202c6-6...

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

    [1] "sticky_brahmanbull" "elmy_kawala"       

When a worker fails, the state of any task it was evaluating is set to
`"failed"`.

``` r

rush$fetch_failed_tasks()
```

              x1        x2     worker_id       message          keys
           <num>     <num>        <char>        <char>        <char>
    1: 6.1846118  2.105703 sticky_bra... Worker has... 3ed4208b-1...
    2: 0.7635039 14.674613 elmy_kawal... Worker has... 49f91b16-6...

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

    [1] "alliterative_tapeworm"

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

    [1] "Debug message logging on worker strong_needletail started"

``` r

readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker strong_needletail started\""
