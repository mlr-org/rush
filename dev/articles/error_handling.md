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
     1: -3.0300124  1.8693076 pseudoreli... Random Err... 790eed08-4...
     2:  4.4486175  4.7065363 acceptable... Random Err... a8bb84f6-2...
     3:  9.9700761  6.9691463 unsolar_al... Random Err... 6fbf98ba-4...
     4:  3.3016800  9.3489519 pseudoreli... Random Err... c5e37da9-e...
     5: -2.1300272 10.8312649 pseudoreli... Random Err... 43b8f4a0-6...
     6:  3.7501503  9.5376823    peat_horse Random Err... 727ff938-9...
     7: -4.7261224 11.9174340 pseudoreli... Random Err... 4888eae2-4...
     8:  4.7383108 11.6618280 pseudoreli... Random Err... 944d70a3-5...
     9:  1.5426772 11.1807542 acceptable... Random Err... 21a2212b-1...
    10:  3.2610988 14.1515583 pseudoreli... Random Err... 220687ef-2...
    11:  8.1333151  5.6767933 acceptable... Random Err... fe09194c-6...
    12:  1.7670960  4.4651960 pseudoreli... Random Err... 2af229ed-5...
    13:  7.2299680 14.3568826 acceptable... Random Err... 2c9520d4-8...
    14: -4.0674089 12.9699148 pseudoreli... Random Err... 2d817bce-0...
    15: -4.3264113 11.1430131 acceptable... Random Err... 2e91700b-f...
    16: -0.1363757  5.6867024 acceptable... Random Err... 4ae9a49b-3...
    17:  9.1805524  9.0737223 pseudoreli... Random Err... fd4f6f64-7...
    18:  3.0279477  0.9078174    peat_horse Random Err... 995cd368-7...
    19: -3.9675052  3.6200779 pseudoreli... Random Err... b271a023-a...
    20:  2.4646992 13.5841205 acceptable... Random Err... 1a34f570-7...
    21:  8.0009823  2.0472460 acceptable... Random Err... 842de50e-d...
    22:  2.1588757  6.7282555 acceptable... Random Err... 20920c29-9...
    23:  9.3296392  8.7105049 acceptable... Random Err... a68ebf5c-6...
    24:  6.4271390  9.1881637    peat_horse Random Err... 7bd6f72c-f...
    25:  6.1064874 14.1108216 acceptable... Random Err... f6861e2a-7...
    26:  7.1085417 14.5323177    peat_horse Random Err... b53ae193-c...
    27:  5.3292884  4.1312481 acceptable... Random Err... 48d5fe38-2...
    28:  7.8338650  8.0648382 pseudoreli... Random Err... bf20c223-3...
    29:  2.8344024 14.8005202    peat_horse Random Err... d043eabf-d...
    30:  3.8687096  1.5874288 acceptable... Random Err... f52ae40f-0...
    31:  0.6405402  4.7054344 acceptable... Random Err... f52a0e1b-0...
    32:  1.7433093  9.3428377    peat_horse Random Err... ae97ca48-4...
    33:  3.6562281  2.8220693 pseudoreli... Random Err... 1357ae46-2...
    34:  4.9668324 12.0286415 pseudoreli... Random Err... 295930b4-1...
    35: -1.4075478 12.9965320 unsolar_al... Random Err... 2d145758-5...
    36:  2.3545840  7.7924901    peat_horse Random Err... 4efb6953-1...
    37: -4.0490954 12.5030074 pseudoreli... Random Err... 1dcb8ff8-9...
    38: -0.8633519 13.2826612 unsolar_al... Random Err... e0e449c4-a...
    39: -0.5107603  9.9702129 acceptable... Random Err... fba063f7-d...
    40:  9.3126723  8.6791745    peat_horse Random Err... 0f76cca8-9...
    41:  2.2425059 12.5014825 pseudoreli... Random Err... 6e36f9f4-d...
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

    [1] "relaxed_yellowjacket"               "highexplosive_americanblackvulture"

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
    1:  4.730069 10.58037 relaxed_ye... Worker has... 945db780-a...
    2: -2.646597 12.64050 highexplos... Worker has... 96b4f892-0...

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

    [1] "antimonarchical_gelada"

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

     [1] "Debug message logging on worker coulrophobic_illadopsis started"
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

    [1] "[1] \"Debug output logging on worker coulrophobic_illadopsis started\""
