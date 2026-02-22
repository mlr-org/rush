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
     1:  0.19465884  6.3318287 despondent... Random Err... 7a9aebcf-e...
     2: -4.42085681 13.4544575 wintry_kar... Random Err... 1a3d5de9-9...
     3:  9.83229678  1.0814297 asthmatic_... Random Err... b5ce2205-9...
     4:  3.39781974  5.2536474 wintry_kar... Random Err... e9c6a554-a...
     5:  4.83414624  4.7557252 asthmatic_... Random Err... d8dd1d95-2...
     6: -4.92432550  8.6762110 despondent... Random Err... c0e73f34-8...
     7:  2.17578744  1.6036152 despondent... Random Err... f8c2d70b-f...
     8: -2.79222325 13.6598424 nonmonarch... Random Err... b8768d6f-d...
     9:  4.42179919 12.0841793 wintry_kar... Random Err... 30782f17-8...
    10:  0.90406556 13.3550369 wintry_kar... Random Err... f28e3c00-4...
    11: -3.40228227  0.2854864 despondent... Random Err... c0ca452c-6...
    12:  4.38686479 10.4384114 wintry_kar... Random Err... 2b4a8c3e-1...
    13: -0.77633334 12.7103622 despondent... Random Err... a9e725d1-a...
    14:  5.38808534  8.0386604 wintry_kar... Random Err... 65810c5b-c...
    15: -0.87061149  7.2640333 despondent... Random Err... 865c3156-2...
    16: -3.86982013  3.6378214 wintry_kar... Random Err... 3bb52912-d...
    17:  7.69567561 13.6110066 asthmatic_... Random Err... 97bed3c0-5...
    18:  1.18109452  7.0747168 despondent... Random Err... aaabc84c-d...
    19: -2.74830248 12.4402124 nonmonarch... Random Err... 575b3992-e...
    20:  9.59347352  5.3017944 wintry_kar... Random Err... d4cc08c2-a...
    21: -1.57533803 13.1755467 despondent... Random Err... 26595d16-f...
    22:  7.43464429 13.6638381 asthmatic_... Random Err... c28024f3-7...
    23: -2.99429204  3.3408197 despondent... Random Err... a94d868b-1...
    24: -4.37253133  8.1700777 wintry_kar... Random Err... a6881987-1...
    25: -1.21740151  0.1766671 nonmonarch... Random Err... e746ead6-e...
    26:  2.39082959  8.7320656 asthmatic_... Random Err... dddc26fc-5...
    27: -1.19595585 14.7671196 nonmonarch... Random Err... 7f263140-7...
    28: -4.86486646 10.6978602 asthmatic_... Random Err... 79e4a137-7...
    29:  6.86706344  3.5956281 nonmonarch... Random Err... bbaede63-b...
    30:  4.15115296  6.1847351 despondent... Random Err... 1883b9a9-1...
    31: -3.33869514  8.8017121 asthmatic_... Random Err... 0bc2d164-1...
    32: -4.38545541 14.3026525 despondent... Random Err... 5a1bcaeb-6...
    33: -4.53351598 14.7530331 nonmonarch... Random Err... 2fa786c5-7...
    34: -0.86746732 12.9068153 wintry_kar... Random Err... 7fb493d3-c...
    35:  6.56295616  4.7093463 asthmatic_... Random Err... 740aa558-e...
    36:  8.05427018  2.6964480 nonmonarch... Random Err... 80136f00-4...
    37: -1.48121071  1.2346599 wintry_kar... Random Err... 2a0aac31-e...
    38: -2.15080421 13.2281533 despondent... Random Err... ba1226b2-b...
    39: -1.13466351  2.7506334 asthmatic_... Random Err... 0825fb52-d...
    40:  3.89806919 12.0037845 wintry_kar... Random Err... 3d88d0ac-3...
    41: -1.98595403 14.6003256 nonmonarch... Random Err... 33c00791-0...
    42: -4.39141406  1.6656387 despondent... Random Err... 645e1ca7-e...
    43:  0.07827042  0.8659348 asthmatic_... Random Err... 27fa070b-3...
    44: -2.00957851 12.2924387 wintry_kar... Random Err... e58c7799-5...
    45:  5.67687674  3.0434902 nonmonarch... Random Err... 59d213a8-a...
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

    [1] "nosophobic_indochinesetiger" "agitable_nubiangoat"        

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
    1:  6.678729 8.255751 nosophobic... Worker has... 1cb6dda0-c...
    2: -2.007227 7.622486 agitable_n... Worker has... d548f939-0...

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

    [1] "blowy_foxterrier"

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

     [1] "Debug message logging on worker angsty_arrowcrab started"
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

    [1] "[1] \"Debug output logging on worker angsty_arrowcrab started\""
