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
     1:  3.3787718  8.0349792  9437 skilful_ba... Random Err... 2452dee5-f...
     2:  0.6386574  2.7513843  9453 rutherford... Random Err... 25fa0f07-3...
     3:  2.3257874  7.8005816  9448 complement... Random Err... 43b6b6b0-c...
     4:  6.2615246  6.4556202  9437 skilful_ba... Random Err... 9f5883a1-a...
     5:  2.0175735  4.5783984  9453 rutherford... Random Err... f092ecd8-9...
     6:  7.0024324 10.3361195  9463 rheophilic... Random Err... 6991af1f-7...
     7:  3.9396444 13.9665399  9453 rutherford... Random Err... 6b158d67-2...
     8:  4.2014131  9.1985367  9453 rutherford... Random Err... 8f3dc322-0...
     9: -2.0603255  8.6382597  9453 rutherford... Random Err... 525ed923-a...
    10:  7.4737142  6.7025548  9453 rutherford... Random Err... 29c2ac86-c...
    11:  0.7915639  7.6549000  9463 rheophilic... Random Err... 76c7c54c-6...
    12:  5.5896402  2.6934868  9453 rutherford... Random Err... 83b4bda3-7...
    13:  5.7612488  9.3439463  9453 rutherford... Random Err... b27761fc-9...
    14:  8.5065590 14.9347612  9448 complement... Random Err... ea652de9-3...
    15:  7.7959028  0.8070932  9453 rutherford... Random Err... 5b545cc4-d...
    16:  6.1183395  8.7167578  9437 skilful_ba... Random Err... c3836e93-5...
    17:  3.0537614 11.7233602  9448 complement... Random Err... 0f5fc002-e...
    18: -1.1432659 14.7919083  9437 skilful_ba... Random Err... 57dc19ff-e...
    19:  4.4472544  4.2807116  9453 rutherford... Random Err... 23663f2b-5...
    20:  1.6505032  6.6743747  9448 complement... Random Err... 38f6c6a6-1...
    21:  7.1957258 12.9974418  9463 rheophilic... Random Err... c3bd2743-1...
    22:  8.9146481  3.7526108  9448 complement... Random Err... 6eae8a94-6...
    23: -1.2994594 14.1841268  9453 rutherford... Random Err... 4e0ff4dc-2...
    24:  6.4024578  4.8106441  9448 complement... Random Err... 62b6b141-9...
    25:  9.1670453 10.2973319  9453 rutherford... Random Err... f3bec8a4-0...
    26:  0.5794949  1.5026011  9463 rheophilic... Random Err... 8e85981a-4...
    27:  4.0205976  2.4078140  9437 skilful_ba... Random Err... 92a73ed8-7...
    28: -1.6187236  1.9955190  9453 rutherford... Random Err... 77f19718-3...
    29:  4.5941515 14.8461403  9463 rheophilic... Random Err... 5807cd74-e...
    30:  3.4381155 12.8607256  9448 complement... Random Err... 9cf789ba-1...
    31: -1.6444994  1.8050709  9463 rheophilic... Random Err... 3818f907-2...
    32: -0.5816540 10.2663763  9453 rutherford... Random Err... 3e400c06-4...
    33:  9.6712805  1.9564418  9437 skilful_ba... Random Err... 4dbe9b87-d...
    34:  1.8169576 14.8746356  9448 complement... Random Err... 81237e7b-3...
    35:  7.4163926  1.4271580  9463 rheophilic... Random Err... ccc3e5d5-d...
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
    1: -4.512326 12.080092  9590 brigandish... Worker has... 1dbd3b74-9...
    2:  8.075386  4.128596  9592 ironical_s... Worker has... 6b946f13-4...

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

    [1] "Debug message logging on worker rubellite_bushbaby started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker rubellite_bushbaby started\""
