# Error Handling and Debugging

*rush* is equipped with an advanced error-handling mechanism designed to
manage and mitigate errors encountered during the execution of tasks. It
adeptly handles a range of error scenarios, from standard R errors to
more complex issues such as segmentation faults and network errors.t If
all of this fails, the user can manually debug the worker loop.

## Simple R Errors

To illustrate the error-handling mechanism in rush, we employ the random
search example from the main
[vignette](https://rush.mlr-org.com/articles/rush.md). This time we
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
     1:  2.98497051  5.5248805 12078 locomotive... Random Err... 86bad56b-f...
     2:  5.33017047  9.4726440 12104 inborn_meg... Random Err... b1506f33-5...
     3:  9.43024953  2.7554872 12089 anticapita... Random Err... bf772f87-b...
     4:  5.16164193  9.3681602 12078 locomotive... Random Err... a214e64b-2...
     5:  8.92750078 14.3503060 12104 inborn_meg... Random Err... 8db23971-d...
     6:  2.09073824  7.7449449 12078 locomotive... Random Err... da1488fd-f...
     7:  5.24401807  8.4522720 12089 anticapita... Random Err... 17d9662b-1...
     8: -2.04102555 10.7733661 12094 nonhistori... Random Err... f61b0eae-0...
     9:  3.74792764  3.2563954 12078 locomotive... Random Err... f8a963e2-3...
    10:  3.43820948  7.1319115 12089 anticapita... Random Err... 7c52f7cf-e...
    11:  3.94475687 13.9262919 12078 locomotive... Random Err... d3e87ac3-5...
    12: -2.15302796  4.3394605 12078 locomotive... Random Err... 49462eae-2...
    13:  4.72942759  4.2710015 12089 anticapita... Random Err... 6c8fb919-3...
    14:  4.42224405  2.2889010 12089 anticapita... Random Err... 8efcc8ee-8...
    15: -2.78273737  0.2329202 12089 anticapita... Random Err... ef1fcb99-5...
    16: -2.21355150  7.1572012 12104 inborn_meg... Random Err... 255a9c79-b...
    17:  2.90694544  4.2878144 12104 inborn_meg... Random Err... 931aa9e2-b...
    18:  7.23522217  0.5418473 12094 nonhistori... Random Err... 69ddd320-e...
    19: -4.58114995  6.1114275 12089 anticapita... Random Err... ff2fb5b0-a...
    20: -0.03013104 10.8643474 12104 inborn_meg... Random Err... 3fe81c96-b...
    21:  6.36645919 13.6474564 12089 anticapita... Random Err... 7d234267-1...
    22:  1.49611763  8.2212375 12089 anticapita... Random Err... 423b5b7c-8...
    23:  3.26351014  4.4369706 12094 nonhistori... Random Err... 2be228ba-5...
    24: -1.38641228 14.0430645 12089 anticapita... Random Err... 9f09e9c0-4...
    25:  1.36343965 11.7000368 12104 inborn_meg... Random Err... 0a224806-f...
    26: -3.70955110  6.8023031 12094 nonhistori... Random Err... 2d83e703-6...
    27: -1.02541449 11.7543462 12089 anticapita... Random Err... f94fec22-6...
    28: -0.37761404 14.1104002 12078 locomotive... Random Err... e043db6c-2...
    29: -3.73486479 10.0010636 12094 nonhistori... Random Err... e452104d-3...
    30:  3.49342496 10.9155660 12089 anticapita... Random Err... f5f2a5a7-8...
    31:  5.08020835 13.0946294 12094 nonhistori... Random Err... af5c2210-4...
    32: -3.17242667  6.9656445 12089 anticapita... Random Err... 67055138-c...
    33:  1.72435691 12.5944029 12094 nonhistori... Random Err... 40194783-2...
    34:  9.54764985  2.1724000 12078 locomotive... Random Err... 007c787d-6...
    35:  2.49004333  3.9868128 12104 inborn_meg... Random Err... 8234b318-7...
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
[vignette](https://rush.mlr-org.com/articles/controller.html#sec-script-error-handling)).

The `$detect_lost_workers()` method also supports automatic restarting
of lost workers when the option `restart_workers = TRUE` is specified.
Alternatively, lost workers may be restarted manually using the
`$restart_workers()` method. Automatic restarting is only available for
local workers. When a worker fails, the status of the task that caused
the failure is set to `"failed"`.

``` r
rush$fetch_failed_tasks()
```

              x1        x2   pid     worker_id       message          keys
           <num>     <num> <int>        <char>        <char>        <char>
    1: -3.807563 0.4996887 12231 selfdisgra... Worker has... e7f4bc90-f...
    2:  5.497652 5.7813277 12233 disgusting... Worker has... 83b45404-1...

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

    [1] "Debug message logging on worker spherelike_monarch started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker spherelike_monarch started\""
