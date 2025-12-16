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
     1:  6.3125859 12.7079934  9622 proscience... Random Err... 159d000b-d...
     2:  3.2226492  5.3535278  9602 semiacadem... Random Err... 89ff5691-2...
     3: -0.1480509  1.6670305  9602 semiacadem... Random Err... 6da6a4c2-b...
     4:  3.3369730  5.3629120  9622 proscience... Random Err... a7667c99-e...
     5:  5.5640487 13.9392465  9636 psychasthe... Random Err... 3b9f6070-d...
     6: -4.6438714 10.1099275  9602 semiacadem... Random Err... 392f8bee-9...
     7: -4.6850117 12.8258884  9602 semiacadem... Random Err... 7b37c2bd-6...
     8:  7.7214536 10.2690532  9613 prettied_i... Random Err... c4fb071c-1...
     9:  4.5116874  6.5037865  9602 semiacadem... Random Err... 2a2f466e-1...
    10: -1.8152292  9.7261335  9622 proscience... Random Err... b98c4902-d...
    11:  5.1737003  3.4507462  9602 semiacadem... Random Err... db8758d5-2...
    12:  3.8521812 13.4355716  9622 proscience... Random Err... ff75f20e-a...
    13:  3.3215510  0.3706892  9602 semiacadem... Random Err... efbca517-a...
    14:  8.6453986 13.9117479  9602 semiacadem... Random Err... 6efdbf76-1...
    15:  8.4008070  3.5394110  9636 psychasthe... Random Err... af4679de-9...
    16: -3.4826911 14.4426876  9636 psychasthe... Random Err... 93ec0ea0-7...
    17: -2.0463214  2.3034248  9602 semiacadem... Random Err... 026874de-7...
    18:  8.7911363  2.9358724  9622 proscience... Random Err... c183bc73-2...
    19:  1.1078010  6.0656373  9602 semiacadem... Random Err... 1eeabaa4-d...
    20: -2.1954401  6.8227889  9613 prettied_i... Random Err... 10de2c85-2...
    21:  2.7437787  4.3538350  9622 proscience... Random Err... 3c825fdd-5...
    22:  9.8825918  8.9921175  9636 psychasthe... Random Err... 15bb9cf1-b...
    23:  0.3657190 11.3621052  9622 proscience... Random Err... e1ec08f1-0...
    24:  8.0288467  5.9893753  9613 prettied_i... Random Err... 69863cd5-a...
    25:  1.7567280  1.0686974  9602 semiacadem... Random Err... 7425c3b1-2...
    26:  5.6037374  9.5680948  9622 proscience... Random Err... 28799deb-8...
    27: -1.3160203  3.6521221  9613 prettied_i... Random Err... 55ecd1ee-4...
    28:  5.7535385  6.4567338  9636 psychasthe... Random Err... 46b441c1-1...
    29:  9.8883413 10.5512635  9622 proscience... Random Err... d3c35699-2...
    30:  0.2263622 14.6157362  9602 semiacadem... Random Err... 45d5cb61-1...
    31: -0.7255917 10.5429805  9636 psychasthe... Random Err... 870638c1-6...
    32:  7.1470078  1.6405869  9622 proscience... Random Err... 1e7294db-0...
    33:  1.5679593 14.5598127  9602 semiacadem... Random Err... 8a022141-7...
    34: -3.2573868  2.7524527  9613 prettied_i... Random Err... 6aa32a9e-3...
    35:  0.2223506 12.6566135  9613 prettied_i... Random Err... baa5a2d3-a...
    36:  2.4289496  4.7817571  9636 psychasthe... Random Err... fa2f7575-0...
    37:  1.0664201 13.7640702  9613 prettied_i... Random Err... 0c2f6fcb-a...
    38:  8.4944937  5.1485687  9636 psychasthe... Random Err... 154f9105-f...
    39:  3.7151739  1.4396294  9613 prettied_i... Random Err... 6d20a3da-e...
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

              x1        x2   pid     worker_id       message          keys
           <num>     <num> <int>        <char>        <char>        <char>
    1:  1.929506 11.859180  9755 swindled_s... Worker has... 5e0095b1-7...
    2: -2.410268  7.031201  9757 pernicious... Worker has... d2cebd29-6...

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

    [1] "Debug message logging on worker mammalian_quokka started"
    [2] "Error in start_args$worker_loop(rush = rush) : Unexpected error"
    [3] "Calls: <Anonymous> ... <Anonymous> -> eval.parent -> eval -> eval -> <Anonymous>"
    [4] "Execution halted"                                                                

``` r
readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))
```

    [1] "[1] \"Debug output logging on worker mammalian_quokka started\""
