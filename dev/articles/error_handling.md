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

                x1          x2     worker_id       message          keys
             <num>       <num>        <char>        <char>        <char>
     1: -2.3359504  7.59636374 exothermic... Random Err... 9ee0958a-9...
     2:  4.9262539  2.70097739 grand_arge... Random Err... 2934c9ed-3...
     3:  1.6724041  7.25551257 exothermic... Random Err... 33aac0cc-6...
     4:  1.9272280  6.33770062 exothermic... Random Err... 0d50f62f-c...
     5:  1.2286659  7.61399860 semiphilos... Random Err... 363e3055-7...
     6:  1.5415215  2.02591131 exothermic... Random Err... 79339481-2...
     7:  3.4902575  5.87107743 grand_arge... Random Err... 5ec334b0-b...
     8: -0.1319639  7.03906977 herby_porc... Random Err... 371bc8b5-e...
     9:  4.1536931  4.34293997 exothermic... Random Err... 813f3f2d-0...
    10:  9.6751496  2.96619577 exothermic... Random Err... 4047a7bd-d...
    11:  7.6497927  5.70541654 exothermic... Random Err... 75380c9b-9...
    12: -2.8858427  3.77172604 exothermic... Random Err... 4f875396-5...
    13:  1.6355314  6.39318252 exothermic... Random Err... e40e0555-3...
    14: -0.5283026  2.33106426 semiphilos... Random Err... b448094e-5...
    15: -4.7921112  7.22501644 grand_arge... Random Err... 8227eb1e-b...
    16: -3.6317642  5.89680865 herby_porc... Random Err... 28a14682-e...
    17: -3.5600679  7.94482385 semiphilos... Random Err... 7a512fb9-2...
    18:  7.1906004  7.39964078 herby_porc... Random Err... 836d99d3-9...
    19: -2.8669851 10.01685460 exothermic... Random Err... a168cb0a-3...
    20:  1.0242583  6.40299734 exothermic... Random Err... 5c482194-b...
    21: -0.6268863 13.19120557 grand_arge... Random Err... a08e4d4c-0...
    22: -2.2770377  0.07020926 herby_porc... Random Err... 8b3f0b1e-e...
    23:  4.1306053  0.33685570 grand_arge... Random Err... 3b277938-2...
    24:  7.7676157  3.55298856 herby_porc... Random Err... de6dcc03-9...
    25:  2.4367740 13.96679017 semiphilos... Random Err... fb03eeee-e...
    26:  1.6096422  3.38671085 exothermic... Random Err... 5720b8cc-f...
    27:  7.7889102  0.15724540 herby_porc... Random Err... 4457893a-a...
    28:  8.8623086  7.33308476 grand_arge... Random Err... 2a170de9-0...
    29: -1.4659704  9.35244924 herby_porc... Random Err... b2b47489-f...
                x1          x2     worker_id       message          keys
             <num>       <num>        <char>        <char>        <char>

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

    [1] "waterproof_starfish"   "tzaristic_mockingbird"

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
    1: 5.877511 4.331116 waterproof... Worker has... 60120879-6...
    2: 2.008322 9.600499 tzaristic_... Worker has... 110c2534-4...

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

    [1] "natatorial_antelopegroundsquirrel"

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

     [1] "Debug message logging on worker epitaphic_hylaeosaurus started"
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

    [1] "[1] \"Debug output logging on worker epitaphic_hylaeosaurus started\""
