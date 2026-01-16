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
     1:  0.2446322  3.9837783 10824 decorous_s... Random Err... a5677f91-5...
     2:  7.1155314  1.2689594 10824 decorous_s... Random Err... d6b35f0f-3...
     3:  0.1055042  9.6798370 10850 hemisphero... Random Err... b0f9f76d-7...
     4: -3.6069774  7.5317843 10835 differenti... Random Err... 9b985d73-1...
     5: -4.5075270  8.3931371 10824 decorous_s... Random Err... 8f956593-8...
     6: -4.6554647 14.7593497 10844 nonscienti... Random Err... 36abfbd4-c...
     7: -4.6354716  3.7679620 10824 decorous_s... Random Err... 74fc80b0-c...
     8:  2.9403109 12.8722614 10824 decorous_s... Random Err... 111a367b-6...
     9:  5.0179379  8.6602639 10824 decorous_s... Random Err... 4079cce0-8...
    10:  2.5446479  4.1311194 10824 decorous_s... Random Err... f8cd15ee-6...
    11:  2.9149557  1.8753795 10824 decorous_s... Random Err... 636db50f-7...
    12:  3.1311521 12.9117132 10850 hemisphero... Random Err... 54ec4f87-5...
    13:  3.6777118  3.0378225 10824 decorous_s... Random Err... 86a966a5-2...
    14:  1.4882924  5.2576073 10835 differenti... Random Err... b23411de-5...
    15:  2.2487121  1.2035362 10844 nonscienti... Random Err... fdefd3e5-e...
    16:  6.4540729  9.0545478 10850 hemisphero... Random Err... 8653775e-9...
    17: -0.8274276 10.0896735 10835 differenti... Random Err... 28ae83bf-2...
    18:  0.2502530  6.7248127 10844 nonscienti... Random Err... 8c391d33-7...
    19:  6.2762008 13.1560846 10835 differenti... Random Err... 0a7538b7-a...
    20: -0.5640437  4.9275290 10835 differenti... Random Err... 49bbb6e3-7...
    21: -0.2042061 10.0689210 10844 nonscienti... Random Err... 9c77b53f-1...
    22:  4.3252156  8.1346350 10850 hemisphero... Random Err... 0a1df625-a...
    23: -0.3092031  9.2407619 10835 differenti... Random Err... e65fc3a5-6...
    24:  8.5397578 12.8418520 10844 nonscienti... Random Err... 9652d165-6...
    25:  1.6911500  1.6941788 10824 decorous_s... Random Err... 41b395de-4...
    26:  7.4978237  5.3078999 10850 hemisphero... Random Err... 3605160d-3...
    27: -2.1440945 13.7771960 10835 differenti... Random Err... e3f4ce6b-0...
    28:  5.2509851 12.4344986 10844 nonscienti... Random Err... 613189e4-0...
    29: -4.0864884  0.5197044 10850 hemisphero... Random Err... 01e363cb-b...
    30: -2.6971090  2.9882646 10844 nonscienti... Random Err... 0d8e3180-9...
    31:  7.7008060  6.9345113 10824 decorous_s... Random Err... 89faaaa6-9...
    32:  3.8599304  9.9582867 10835 differenti... Random Err... 83a5e410-e...
    33:  4.2324950 12.0878388 10850 hemisphero... Random Err... 70ffdab9-e...
    34: -3.4266783  0.4217782 10844 nonscienti... Random Err... f9d8bb3c-4...
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

               x1        x2   pid     worker_id       message          keys
            <num>     <num> <int>        <char>        <char>        <char>
    1:  6.6882388  7.048411 10977 humiliated... Worker has... b4731cf6-8...
    2: -0.6384798 12.893347 10979 zippy_xiao... Worker has... d86ece5d-0...

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

    [1] "Debug message logging on worker salaried_drever started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker salaried_drever started\""
