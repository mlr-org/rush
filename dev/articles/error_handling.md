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
      1:  0.5763868  3.259638 whited_wis... Random Err... cfa1cd0d-c...
      2: -4.5794014  4.669155 unwilling_... Random Err... 36aecff1-1...
      3: -1.9539668  7.722016 decasyllab... Random Err... aac7a1b6-c...
      4:  6.0675405 11.924167 creamy_fre... Random Err... 55374dab-d...
      5:  4.8171092 10.463291 whited_wis... Random Err... cc786451-f...
     ---
     96: -3.9673868  9.994292 creamy_fre... Random Err... b40dc73e-c...
     97:  9.0434251  3.982545 whited_wis... Random Err... 6ba63f51-d...
     98:  9.2443778  7.633309 decasyllab... Random Err... 084aee24-0...
     99:  9.9704956 14.205146 decasyllab... Random Err... 7c554dd2-0...
    100:  9.0626921 12.822416 unwilling_... Random Err... 1b2d44a5-0...

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

    [1] "rust_tenrec"     "adjacent_kitfox"

When a worker fails, the state of any task it was evaluating is set to
`"failed"`.

``` r
rush$fetch_failed_tasks()
```

               x1       x2     worker_id       message          keys
            <num>    <num>        <char>        <char>        <char>
    1:  0.3344047 7.379934 rust_tenre... Worker has... 42eb2437-0...
    2: -2.3540195 5.280691 adjacent_k... Worker has... b5106050-a...

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

    [1] "palaeoclimatologic_smew"

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

    [1] "Debug message logging on worker mega_zethusspinipes started"

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker mega_zethusspinipes started\""
