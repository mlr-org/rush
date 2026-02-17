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
     1: -4.725383926  1.9399631 old_americ... Random Err... 791d0c49-a...
     2:  0.007392108  5.0208139 grand_achi... Random Err... b18329eb-b...
     3: -0.032403045 10.6611245 bottlegree... Random Err... 9e796a0d-3...
     4:  5.501409615  6.5537378 grand_achi... Random Err... 9737defb-d...
     5:  2.135925858 13.1642222 old_americ... Random Err... 929f480d-6...
     6: -4.606072480 13.2953966 grand_achi... Random Err... 2a195648-4...
     7:  7.615385449 11.2930386 grand_achi... Random Err... 4eb41b5f-4...
     8:  5.004154907  2.0817228 statued_bl... Random Err... 8897476a-4...
     9:  1.944819104 13.3812302 bottlegree... Random Err... f4e0505d-7...
    10:  8.835772586 13.8916484 grand_achi... Random Err... b4b89ec0-8...
    11: -0.054570267  1.1926881 old_americ... Random Err... e086303b-a...
    12:  9.558668602  0.5821565 grand_achi... Random Err... 59f2f58c-9...
    13:  8.880134880 13.0142312 bottlegree... Random Err... 2824c4bb-8...
    14: -2.816315939  6.2241219 old_americ... Random Err... 139f5f44-8...
    15:  0.971578187 10.2408828 grand_achi... Random Err... 8fc8cf30-c...
    16:  8.997185368 12.8343520 bottlegree... Random Err... 7c15d6f7-a...
    17:  1.741060556  6.4893536 old_americ... Random Err... 86284107-1...
    18:  8.149738677  3.1032361 bottlegree... Random Err... 7a646792-4...
    19:  0.180336869  9.4058284 statued_bl... Random Err... f3f86842-9...
    20:  8.466383209  7.9316488 grand_achi... Random Err... 3c44a3de-0...
    21: -4.774707173  0.5095697 bottlegree... Random Err... faf73083-1...
    22:  5.219195434 11.3293475 statued_bl... Random Err... ee451504-f...
    23:  4.019416111  5.5953445 grand_achi... Random Err... 3f9cb754-d...
    24:  3.975853565  6.1343036 statued_bl... Random Err... 03fa6a30-8...
    25:  3.231917431 11.3067743 old_americ... Random Err... 3d6c23ad-a...
    26:  6.148820143  9.7070120 bottlegree... Random Err... 7b771e79-1...
    27:  8.893907943  0.2569303 old_americ... Random Err... 448883b4-2...
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

    [1] "gimmicky_galapagosmockingbird" "hardshell_drake"              

This method works for workers started with `$start_local_workers()` and
`$start_remote_workers()`. Workers started with `$worker_script()` must
be started with a heartbeat mechanism (see
[vignette](https://rush.mlr-org.com/dev/articles/controller.html#sec-script-error-handling)).

When a worker fails, the status of the task that caused the failure is
set to `"failed"`.

``` r
rush$fetch_failed_tasks()
```

              x1        x2     worker_id       message          keys
           <num>     <num>        <char>        <char>        <char>
    1: -3.402880  9.985569 gimmicky_g... Worker has... 652fd16d-d...
    2:  1.070723 10.788235 hardshell_... Worker has... b0606a16-0...

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

    [1] "temptuous_falcon"

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

     [1] "Debug message logging on worker astounding_zooplankton started"
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

    [1] "[1] \"Debug output logging on worker astounding_zooplankton started\""
