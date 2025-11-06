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

                x1         x2   pid     worker_id       message          keys
             <num>      <num> <int>        <char>        <char>        <char>
     1:  1.5765885 14.0709928  9913 disposable... Random Err... 20709b0d-3...
     2:  9.2568421 12.8240345  9932 pseudonobl... Random Err... 696d9de7-6...
     3:  7.4184356 10.9452448  9913 disposable... Random Err... 33d8b21e-6...
     4:  2.1683014 12.7266089  9932 pseudonobl... Random Err... bb6ce5be-4...
     5:  5.2432553  0.5117456  9913 disposable... Random Err... c90c6270-f...
     6:  7.4443898 14.4772479  9924 drooly_kak... Random Err... 19ec9ef9-8...
     7:  8.5290771  9.0425620  9913 disposable... Random Err... 184f2135-6...
     8:  7.5189506  2.6773243  9939 incorporea... Random Err... efad0939-9...
     9:  1.5648773  3.2334680  9913 disposable... Random Err... e7d10821-c...
    10:  0.4276391  7.8751543  9913 disposable... Random Err... a008b324-4...
    11:  3.0648579  8.5439035  9913 disposable... Random Err... 4757a001-0...
    12: -2.7389752  6.3220074  9913 disposable... Random Err... 54cd30b9-6...
    13:  9.6495290  5.5594178  9913 disposable... Random Err... fed77a2c-e...
    14: -1.9857087 12.1890719  9913 disposable... Random Err... c6bfcc31-5...
    15:  4.3916087 13.4062069  9932 pseudonobl... Random Err... 4f4f47ff-6...
    16:  6.2589083  5.4901779  9939 incorporea... Random Err... c992c432-3...
    17:  7.4168355 13.5318558  9932 pseudonobl... Random Err... 2a614487-c...
    18:  1.9118968 11.2844426  9913 disposable... Random Err... 79b203a1-3...
    19: -4.2073131  0.2628450  9932 pseudonobl... Random Err... 78309efa-0...
    20: -0.5492028  3.2628791  9913 disposable... Random Err... 430da6db-8...
    21:  3.7769350 12.6236158  9913 disposable... Random Err... b751a058-4...
    22:  2.5887357  7.4308369  9932 pseudonobl... Random Err... 418003dd-d...
    23:  3.0678376 13.7015678  9932 pseudonobl... Random Err... 2d8134f0-d...
    24:  6.4211826  4.8965601  9913 disposable... Random Err... 36ccec78-c...
    25:  1.0451545 13.3636796  9924 drooly_kak... Random Err... 623f45ec-c...
    26:  2.3312640 13.7347257  9939 incorporea... Random Err... cc3fb15f-e...
    27:  3.7256586  7.2790835  9939 incorporea... Random Err... d010d2a8-4...
    28:  9.0783312 13.1414523  9913 disposable... Random Err... 54babc1c-e...
    29: -2.5271494 12.4415067  9939 incorporea... Random Err... db102fb1-8...
    30:  2.0360685  8.0610794  9913 disposable... Random Err... 307a963b-5...
    31: -2.7066209 14.1178345  9939 incorporea... Random Err... 9a37fb93-3...
    32:  6.5063987  4.4318896  9932 pseudonobl... Random Err... f1065180-7...
    33: -3.1478113 11.1746346  9913 disposable... Random Err... e63c8f8a-9...
    34:  0.4760971 12.0409904  9939 incorporea... Random Err... 9c00b551-5...
    35: -1.1702986 14.8055621  9939 incorporea... Random Err... 49da1079-a...
                x1         x2   pid     worker_id       message          keys

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
    1: 8.707884 2.692881 10066 subsimian_... Worker has... de30b6d3-a...
    2: 8.086107 4.724479 10068 quasiproph... Worker has... 05be3142-9...

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

    [1] "Debug message logging on worker salaried_billygoat started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker salaried_billygoat started\""
