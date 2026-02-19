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
     1:  9.44367625  3.70576620 scintillat... Random Err... e3a3610d-b...
     2: -4.05680679  6.43716583 scintillat... Random Err... daf56933-a...
     3:  5.35213864  4.98719712 commercial... Random Err... 52c6baf4-1...
     4:  1.52582881  3.65313539 scintillat... Random Err... a56cd03a-5...
     5: -1.09741147 13.15967391 scintillat... Random Err... b82057db-8...
     6: -3.69054800  4.93437948 scintillat... Random Err... dbbfb5cd-b...
     7:  2.24188526  3.89746292 scintillat... Random Err... 50089d6d-f...
     8:  1.72852978  6.04032320 scintillat... Random Err... 392f23aa-9...
     9: -1.82891750 11.33935123 paramilita... Random Err... e3090237-c...
    10: -2.59279348  3.93906738 scintillat... Random Err... b6748aac-e...
    11: -1.11640556 11.16187828 stout_leve... Random Err... 28cd5174-5...
    12:  0.87853596 10.41449991 scintillat... Random Err... 86ae4846-4...
    13:  6.05560105 12.61288288 commercial... Random Err... 00215580-0...
    14:  8.57641870  8.07292871 paramilita... Random Err... b2ef991d-1...
    15:  6.41401235  4.00690051 scintillat... Random Err... d1ef89b3-8...
    16: -2.16791895 13.09032629 commercial... Random Err... bd21b198-5...
    17:  5.61743453  8.35975150 scintillat... Random Err... e7e0af4b-7...
    18: -3.72509273 12.55716669 scintillat... Random Err... fb522ed2-b...
    19:  1.57851664  5.40853089 commercial... Random Err... 3441811b-c...
    20:  0.47547469  5.03143163 commercial... Random Err... 7172ff4a-c...
    21: -4.81648775  5.21477177 scintillat... Random Err... 40f9d6af-f...
    22:  5.73179931  0.07336938 commercial... Random Err... 88878207-f...
    23:  9.00593723  7.05390794 paramilita... Random Err... e94a2da0-4...
    24: -4.14547678  8.44644504 stout_leve... Random Err... 651ee3c6-4...
    25:  9.08975432  9.50402880 commercial... Random Err... c432f53f-2...
    26: -0.06503199 14.96512089 stout_leve... Random Err... 22bf0d25-6...
    27:  2.92804695  0.24452460 commercial... Random Err... 7a5a48d6-2...
    28:  2.64854804  1.24291407 paramilita... Random Err... c03aa3ba-b...
    29: -1.23269077  0.87646318 paramilita... Random Err... 88c1ecc3-a...
    30:  2.90079567  6.78661167 stout_leve... Random Err... 1004b9bb-3...
    31:  7.13551417  4.18775919 paramilita... Random Err... 3bbc1a6c-c...
    32:  7.77414661  9.03244944 scintillat... Random Err... 79af5e93-f...
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

    [1] "configurational_apisdorsatalaboriosa"
    [2] "spongy_ynambu"                       

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
    1: 4.111307 1.740443 configurat... Worker has... 515e6ad3-1...
    2: 9.597039 7.071388 spongy_yna... Worker has... 4958464a-7...

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

    [1] "unoperatable_elkhound"

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

     [1] "Debug message logging on worker lowcost_waterdogs started"
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

    [1] "[1] \"Debug output logging on worker lowcost_waterdogs started\""
