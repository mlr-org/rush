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

wl_random_search = function(rush) {

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
  globals = "branin")
```

When an error occurs, the task is marked as `"failed"`, and the error
message is stored in the `"message"` column. This approach ensures that
errors do not interrupt the overall execution process. It allows for
subsequent inspection of errors and the reevaluation of failed tasks as
necessary.

``` r
rush$fetch_failed_tasks()
```

                x1        x2   pid     worker_id       message          keys
             <num>     <num> <int>        <char>        <char>        <char>
     1:  8.2135400  4.283180 26189     bald_puma Random Err... 662fa56d-c...
     2: -2.0641610  9.264693 26189     bald_puma Random Err... e2d0ccfc-6...
     3:  0.8510085 12.279394 26189     bald_puma Random Err... 27927e39-0...
     4:  7.6457805  3.735802 26189     bald_puma Random Err... 67ff879b-b...
     5: -1.9543367  2.204665 26189     bald_puma Random Err... 90745d29-8...
     6:  7.7866962  5.227676 26189     bald_puma Random Err... 06b7fabf-9...
     7: -2.3417084  4.610571 26189     bald_puma Random Err... b4ca4e41-0...
     8:  0.8096287  2.662267 26189     bald_puma Random Err... 15992b7e-1...
     9:  2.5533459  1.428291 26189     bald_puma Random Err... 879fd85d-7...
    10:  9.6136422  7.477862 26189     bald_puma Random Err... ed841f17-3...
    11:  3.5284898  6.743623 26189     bald_puma Random Err... 937cd42e-5...
    12:  7.9243194 14.768302 26189     bald_puma Random Err... c43612bc-0...
    13:  5.1594435  5.498672 26189     bald_puma Random Err... b4edf40a-8...
    14: -4.4976390 10.898838 26189     bald_puma Random Err... 2d04f26d-8...
    15:  6.1842984  3.971071 26189     bald_puma Random Err... 14e9d5af-2...
    16:  2.7056746  3.331872 26178 declarator... Random Err... 91218bd6-c...
    17:  4.7477532  7.509744 26189     bald_puma Random Err... 9b63f729-5...
    18:  0.9028434  9.696765 26189     bald_puma Random Err... 6692a6d9-6...
    19: -3.2521479  1.909146 26189     bald_puma Random Err... ac4a6971-6...
    20: -3.4626804  5.605526 26178 declarator... Random Err... 7c0ef0e8-a...
    21:  4.0929070  6.429045 26189     bald_puma Random Err... 52fa9a3f-f...
    22: -2.4395825  4.586502 26178 declarator... Random Err... cba030ea-b...
    23:  9.2101615  4.327580 26189     bald_puma Random Err... 2d4ee7a1-7...
    24:  6.3234703  1.180609 26189     bald_puma Random Err... e7694746-1...
    25:  5.0515209 14.931357 26189     bald_puma Random Err... 76b00d58-9...
    26: -2.3756527 13.132992 26178 declarator... Random Err... d37de440-9...
    27:  1.0050251  8.263974 26189     bald_puma Random Err... 390a6694-0...
    28:  6.8969489  2.882438 26189     bald_puma Random Err... 48c86cfe-2...
    29:  1.3447518  3.105214 26178 declarator... Random Err... d70501a0-6...
                x1        x2   pid     worker_id       message          keys

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
    1: 5.947612 11.30537 26327 ittybitty_... Worker has... d348d7d5-2...
    2: 9.226573 11.44294 26325 snoopy_mus... Worker has... 6d9c7b67-6...

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

    Error in wl_error(rush_worker): Unexpected error

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

    [1] "Debug message logging on worker orthoclase_northernhairynosedwombat started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker orthoclase_northernhairynosedwombat started\""
