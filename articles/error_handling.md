# Error Handling and Debugging

`rush` provides error-handling mechanisms for two failure modes:
standard R errors during task evaluation and unexpected worker failures
such as crashes or lost connections. If errors cannot be caught
automatically, the worker loop can be debugged locally.

## Simple R Errors

We use the random search example from the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) and introduce
a random error with 50% probability. Within the worker loop, users are
responsible for catching errors and marking the corresponding task as
`"failed"` using the `$fail_tasks()` method.

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

               x1        x2     worker_id condition          keys
            <num>     <num>        <char>    <list>        <char>
     1: 9.2193749 14.277255 gastroscop... <list[1]> 976f34c2-1...
     2: 2.1842980  6.687857 equanimous... <list[1]> 24cceb75-5...
     3: 4.0781721 10.063647 chromatini... <list[1]> 9089fce7-0...
     4: 6.2996363  1.865234 chromatini... <list[1]> 7c6a0f01-a...
     5: 4.6321272  6.076416 chromatini... <list[1]> e7992b70-0...
    ---
    95: 8.0315142 11.956024 equanimous... <list[1]> 459591ef-b...
    96: 0.9727514  9.968416 alive_newf... <list[1]> 14ace634-7...
    97: 3.4488758  9.076897 equanimous... <list[1]> bd49ad08-2...
    98: 4.5066773  8.042465 gastroscop... <list[1]> 67db126d-e...
    99: 4.1109463  2.403348 alive_newf... <list[1]> 19a447cf-9...

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
vignette](https://rush.mlr-org.com/articles/manager.html#sec-script-error-handling)).

``` r

rush$detect_lost_workers()
```

    [1] "uncontradictable_harpseal_4b65f05c" "zoological_hind_f7b703b0"          

When a worker fails, the state of any task it was evaluating is set to
`"failed"`.

``` r

rush$fetch_failed_tasks()
```

             x1       x2     worker_id condition          keys
          <num>    <num>        <char>    <list>        <char>
    1: 5.520015 10.29036 uncontradi... <list[1]> f5eb1701-e...
    2: 3.161552 10.94930 zoological... <list[1]> ee98533c-f...

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

    [1] "frisky_chihuahua_122d6d2f"

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

    [1] "Debug message logging on worker pinkish_nijssenissdwarfchihlid_cd53191a started"

``` r

readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker pinkish_nijssenissdwarfchihlid_cd53191a started\""
