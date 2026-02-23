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

                x1         x2     worker_id       message          keys
             <num>      <num>        <char>        <char>        <char>
     1:  2.2947277  0.4745478 chemical_l... Random Err... ad4e4324-0...
     2:  5.7000978  9.3530923 political_... Random Err... cd9562d6-1...
     3:  1.6782707 13.8619338 semitheatr... Random Err... ed7c907e-2...
     4:  8.2418556 14.1884747 chemical_l... Random Err... ef51015c-4...
     5:  3.3143802  9.1981312 smartaleck... Random Err... eb0c01d2-4...
     6:  1.8940152  5.6957241 chemical_l... Random Err... eee6c19d-c...
     7:  6.5758297 13.1252159 chemical_l... Random Err... 16337c70-f...
     8: -1.6382504 12.8092796 chemical_l... Random Err... ab32c9c0-0...
     9:  7.7332666  6.3234991 chemical_l... Random Err... fa49b40c-e...
    10:  6.0014508  0.5649495 political_... Random Err... 2480b563-1...
    11:  4.6499698  1.9147231 smartaleck... Random Err... e32a1b55-d...
    12: -1.0399205  4.8643585 chemical_l... Random Err... a51a7670-0...
    13:  6.7979786  6.5948989 political_... Random Err... 21264c88-2...
    14:  7.7065164  2.8239539 smartaleck... Random Err... 7866ada0-8...
    15:  9.8413241 11.4920877 political_... Random Err... 88dd4f9b-a...
    16: -2.0238387  3.8540434 chemical_l... Random Err... 44452283-2...
    17: -3.8184796 12.3012716 semitheatr... Random Err... 30c6005d-b...
    18:  3.7320727  4.8962709 chemical_l... Random Err... 286ec4ca-f...
    19:  2.6426119  2.3469309 political_... Random Err... 4967d6fd-0...
    20:  1.6218938 12.0269512 smartaleck... Random Err... dbbe1459-5...
    21: -3.8117844  4.2623595 semitheatr... Random Err... d0bdf6f8-3...
    22: -0.6292267  8.6332977 political_... Random Err... ab31007a-c...
    23:  9.0176113  3.6672953 semitheatr... Random Err... 02dbba2b-3...
    24:  1.4434629 11.7992394 semitheatr... Random Err... acc19b71-6...
                x1         x2     worker_id       message          keys
             <num>      <num>        <char>        <char>        <char>

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

    [1] "overjoyful_dogfish" "ancestral_topi"    

This method works for workers started with `$start_local_workers()` and
`$start_remote_workers()`. Workers started with `$worker_script()` must
be started with a heartbeat mechanism (see
[vignette](https://rush.mlr-org.com/dev/articles/controller.html#sec-script-error-handling)).

When a worker fails, the status of the task that caused the failure is
set to `"failed"`.

``` r
rush$fetch_failed_tasks()
```

             x1       x2     worker_id       message          keys
          <num>    <num>        <char>        <char>        <char>
    1: 5.535459 7.026065 overjoyful... Worker has... 16eadab4-c...
    2: 9.287910 4.126489 ancestral_... Worker has... 8d06c20a-2...

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
```

    Error in `initialize()`:
    ! unused argument (remote = FALSE)

``` r
wl_error(rush_worker)
```

    Error:
    ! object 'rush_worker' not found

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

    [1] "burning_leafwing"

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

     [1] "Debug message logging on worker itchy_wireworm started"
     [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
     [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
     [4] "In addition: Warning message:"
     [5] ""
     [6] "✖ $push_results() is deprecated. Use $finish_tasks() instead. is deprecated and"
     [7] "  will be removed in the future."
     [8] "→ Class: Mlr3WarningDeprecated"
     [9] " "
    [10] "Error in close.connection(message_log) : "
    [11] "  cannot close 'message' sink connection"
    [12] "Calls: <Anonymous> -> close -> close.connection"
    [13] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker itchy_wireworm started\""
