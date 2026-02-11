# Error Handling and Debugging

*rush* is equipped with an advanced error-handling mechanism designed to
manage and mitigate errors encountered during the execution of tasks. It
adeptly handles a range of error scenarios, from standard R errors to
more complex issues such as segmentation faults and network errors.t If
all of this fails, the user can manually debug the worker loop.

## Simple R Errors

To illustrate the error-handling mechanism in rush, we employ the random
search example from the main
[vignette](https://rush.mlr-org.com/dev/articles/rush.md). This time we
introduce a random error with a 50% probability. Within the worker loop,
users are responsible for catching errors and marking the corresponding
task as `"failed"` using the `$push_failed()` method.

``` r
library(rush)

branin = function(x1, x2) {
  (x2 - 5.1 / (4 * pi^2) * x1^2 + 5 / pi * x1 - 6)^2 + 10 * (1 - 1 / (8 * pi)) * cos(x1) + 10
}

wl_random_search = function(rush, branin) {

  while(rush$n_finished_tasks < 100) {

    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))

    tryCatch({
      if (runif(1) < 0.5) stop("Random Error")
      ys = list(y = branin(xs$x1, xs$x2))
      rush$push_results(key, yss = list(ys))
    }, error = function(e) {
      condition = list(message = e$message)
      rush$push_failed(key, conditions = list(condition))
    })

    ys = list(y = branin(xs$x1, xs$x2))
    rush$push_results(key, yss = list(ys))
  }
}
```

We start the workers.

``` r
rush = rsh(
  network = "test-simply-error",
  config = redux::redis_config())

rush$start_local_workers(
  worker_loop = wl_random_search,
  n_workers = 4,
  branin = branin)
```

When an error occurs, the task is marked as `"failed"`, and the error
message is stored in the `"message"` column. This approach ensures that
errors do not interrupt the overall execution process. It allows for
subsequent inspection of errors and the reevaluation of failed tasks as
necessary.

``` r
rush$fetch_failed_tasks()
```

                x1         x2   pid     worker_id       message          keys
             <num>      <num> <int>        <char>        <char>        <char>
     1:  2.3678329  5.9660036 14599 comic_arro... Random Err... 2f2f86e1-8...
     2:  2.7340237  0.5174293 14625 amaranth_v... Random Err... ce66dc67-f...
     3:  4.6960345  1.5054621 14615 enigmatic_... Random Err... 9b6b89a2-5...
     4:  0.8826973 10.2830161 14610 welldramat... Random Err... 2b8f9a8b-3...
     5: -3.4029876  9.2062413 14615 enigmatic_... Random Err... e304536a-b...
     6: -0.6011327  4.6334311 14625 amaranth_v... Random Err... 147db3fe-d...
     7:  9.4883781 12.4612021 14625 amaranth_v... Random Err... 57bd8b0b-0...
     8:  9.1785284  0.3708526 14615 enigmatic_... Random Err... 557fe7df-8...
     9:  9.7945202  6.0112272 14615 enigmatic_... Random Err... 8f75d629-e...
    10:  1.2142390  1.0207224 14625 amaranth_v... Random Err... c8a74b3c-1...
    11:  1.1105903  7.7952723 14625 amaranth_v... Random Err... f55cdf00-0...
    12:  1.6390918  5.9203344 14599 comic_arro... Random Err... b0bfa57c-e...
    13: -3.4377651 10.3194099 14599 comic_arro... Random Err... 978e438d-d...
    14:  9.8806009  3.6898906 14610 welldramat... Random Err... b22a0eb7-7...
    15: -2.5432259 10.3907515 14615 enigmatic_... Random Err... a2ec15b1-2...
    16: -4.9208101  6.7116962 14625 amaranth_v... Random Err... 410d5f63-f...
    17:  0.5112151 11.4835854 14615 enigmatic_... Random Err... 1cba0bfc-9...
    18: -2.3235158  9.6261105 14599 comic_arro... Random Err... f32ebfd0-b...
    19: -4.7114814 12.8890827 14625 amaranth_v... Random Err... eac4a437-7...
    20: -3.7033226  4.5346952 14599 comic_arro... Random Err... ef638e93-8...
    21:  7.1699749  4.8266574 14625 amaranth_v... Random Err... 25c98574-e...
    22:  5.5435110  0.6533227 14610 welldramat... Random Err... 438839d9-3...
    23: -0.2203526  4.4501146 14610 welldramat... Random Err... 411652b6-8...
    24:  0.3658877 14.2548589 14615 enigmatic_... Random Err... fc359610-5...
    25:  5.0690309 14.7806222 14599 comic_arro... Random Err... 2a9d26fb-b...
    26: -1.3042877  7.3930531 14599 comic_arro... Random Err... 5fa6cf83-6...
                x1         x2   pid     worker_id       message          keys
             <num>      <num> <int>        <char>        <char>        <char>

## Handling Failing Workers

The rush package provides mechanisms to address situations in which
workers fail due to crashes or lost connections. Such failures may
result in tasks remaining in the “running” state indefinitely. To
illustrate this, we define a function that simulates a segmentation
fault by terminating the worker process.

``` r
wl_failed_worker = function(rush) {
  xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
  key = rush$push_running_tasks(xss = list(xs))

  tools::pskill(Sys.getpid(), tools::SIGKILL)
}

rush = rsh(network = "test-failed-workers")

worker_ids =  rush$start_local_workers(
  worker_loop = wl_failed_worker,
  n_workers = 2)
```

The package offers the `$detect_lost_workers()` method, which is
designed to identify and manage these occurrences.

``` r
rush$detect_lost_workers()
```

This method works for workers started with `$start_local_workers()` and
`$start_remote_workers()`. Workers started with `$worker_script()` must
be started with a heartbeat mechanism (see
[vignette](https://rush.mlr-org.com/dev/articles/controller.html#sec-script-error-handling)).

The `$detect_lost_workers()` method also supports automatic restarting
of lost workers when the option `restart_workers = TRUE` is specified.
Alternatively, lost workers may be restarted manually using the
`$restart_workers()` method. Automatic restarting is only available for
local workers. When a worker fails, the status of the task that caused
the failure is set to `"failed"`.

``` r
rush$fetch_failed_tasks()
```

              x1       x2   pid     worker_id       message          keys
           <num>    <num> <int>        <char>        <char>        <char>
    1: -1.980996  8.24235 14753 rejectable... Worker has... 3dcafa28-a...
    2: -2.445488 11.38589 14755 masculine_... Worker has... bcfb54f3-2...

## Debugging

When the worker loop fails unexpectedly due to an uncaught error, it is
necessary to debug the worker loop. Consider the following example, in
which the worker loop randomly generates an error.

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

    rush$push_results(key, yss = list(list(y = x1 + x2)))
  }
}
```

To begin debugging, the worker loop is executed locally. This requires
the initialization of a `RushWorker` instance. Although the rush worker
is typically created during worker initialization, it can also be
instantiated manually. The worker instance is then passed as an argument
to the worker loop.

``` r
rush_worker = RushWorker$new("test", remote = FALSE)

wl_error(rush_worker)
```

    Error in `wl_error()`:
    ! Unexpected error

When an error is raised in the main process, the
[`traceback()`](https://rdrr.io/r/base/traceback.html) function can be
invoked to examine the stack trace. Breakpoints may also be set within
the worker loop to inspect the program state. This approach provides
substantial control over the debugging process. Certain errors, such as
missing packages or undefined global variables, may not be encountered
when running locally. However, such issues can be readily identified
using the `$detect_lost_workers()` method.

``` r
rush = rsh("test-error")

rush$start_local_workers(
  worker_loop = wl_error,
  n_workers = 1
)
```

The `$detect_lost_workers()` method can be used to identify lost
workers.

``` r
rush$detect_lost_workers()
```

Output and message logs can be written to files by specifying the
`message_log` and `output_log` arguments.

``` r
rush = rsh("test-error")

message_log = tempdir()
output_log = tempdir()

worker_ids = rush$start_local_workers(
  worker_loop = wl_error,
  n_workers = 1,
  message_log = message_log,
  output_log = output_log
)

Sys.sleep(5)

readLines(file.path(message_log, sprintf("message_%s.log", worker_ids[1])))
```

    [1] "Debug message logging on worker judgmental_takin started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker judgmental_takin started\""
