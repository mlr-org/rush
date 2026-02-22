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

                 x1        x2     worker_id       message          keys
              <num>     <num>        <char>        <char>        <char>
     1:  9.76606479  9.872069 selfdeprec... Random Err... d5720ad5-d...
     2:  7.94635296  3.866490 selfdeprec... Random Err... 29c902bb-0...
     3: -0.02805045 10.877380 tired_hera... Random Err... 69f5871e-4...
     4:  2.22275492  8.198654 selfdeprec... Random Err... 59d96f21-0...
     5:  3.99452085  5.519566 selfdeprec... Random Err... 51f7bc0d-4...
     6:  5.68017780  3.816356 scabrous_m... Random Err... b6cd1bb9-8...
     7: -4.05446752 13.223187 psychoneur... Random Err... 2151d19c-5...
     8: -1.82733078  9.523493 selfdeprec... Random Err... f4b93245-0...
     9:  6.44736924  2.851594 selfdeprec... Random Err... 04e97565-1...
    10:  8.69490133 14.072168 tired_hera... Random Err... a7d0b1b1-f...
    11:  3.38401365 10.420461 selfdeprec... Random Err... dea13704-5...
    12:  7.01833257  8.425834 selfdeprec... Random Err... 7be731dd-c...
    13: -4.00883828  7.799076 selfdeprec... Random Err... 0c199682-6...
    14: -0.29971779  4.430645 scabrous_m... Random Err... 0169823a-1...
    15:  3.74029766 12.533279 selfdeprec... Random Err... 7c4e4845-d...
    16: -4.56517739  2.267546 scabrous_m... Random Err... 5a080c05-e...
    17:  7.88529172  2.403446 selfdeprec... Random Err... 3014ff20-9...
    18:  4.28890865 12.558906 psychoneur... Random Err... 7eee2711-1...
    19:  6.39353933 10.231457 selfdeprec... Random Err... eb24d088-b...
    20:  9.83601789  3.549934 tired_hera... Random Err... d7431e15-c...
    21: -2.20103994  7.043137 tired_hera... Random Err... c217bd76-7...
    22:  9.73711860 12.195409 selfdeprec... Random Err... cadef0de-e...
    23:  1.77851803  4.898645 psychoneur... Random Err... 65227c16-b...
    24: -2.41286163  3.279914 psychoneur... Random Err... a02818fd-e...
    25:  8.23130755  4.806778 tired_hera... Random Err... a263d727-4...
    26:  7.98505469  3.997305 selfdeprec... Random Err... bea74f5e-e...
    27:  0.52487257 10.121368 scabrous_m... Random Err... fe4ca6ef-9...
    28:  2.63841609  6.468782 psychoneur... Random Err... 610d7cc0-3...
    29:  1.70633600  7.012123 psychoneur... Random Err... 650fcf8c-1...
    30:  8.29544352 14.085268 scabrous_m... Random Err... f6fb1bdf-e...
    31:  8.35657245  5.362778 selfdeprec... Random Err... 8c1279da-3...
                 x1        x2     worker_id       message          keys
              <num>     <num>        <char>        <char>        <char>

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

    [1] "deferential_brownbutterfly" "desertlike_cattle"         

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
    1:  5.084859 3.315080 deferentia... Worker has... 32f244be-0...
    2: -3.562179 2.684935 desertlike... Worker has... ab9ee5c5-c...

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

    [1] "nonincorporated_gander"

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

     [1] "Debug message logging on worker next_icefish started"
     [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
     [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
     [4] "In addition: Warning message:"
     [5] ""
     [6] "✖ $push_results() is deprecated. Use $finish_tasks() instead. is deprecated and"
     [7] "  will be removed in the future."
     [8] "→ Class: Mlr3WarningDeprecated"
     [9] " "
    [10] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker next_icefish started\""
