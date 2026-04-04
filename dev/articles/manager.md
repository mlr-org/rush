# Rush Manager

The `Rush` manager class is responsible for starting, monitoring, and
stopping workers within the network. This vignette describes the three
mechanisms for starting workers: `mirai` daemons, local `processx`
processes, and portable R scripts. We advise reading the
[tutorial](https://rush.mlr-org.com/dev/articles/tutorial.md) first. We
use the random search example from this vignette to demonstrate the
manager.

``` r
library(rush)

branin = function(x1, x2) {
  (x2 - 5.1 / (4 * pi^2) * x1^2 + 5 / pi * x1 - 6)^2 +
    10 * (1 - 1 / (8 * pi)) * cos(x1) +
    10
}

wl_random_search = function(rush, branin) {
  while (TRUE) {
    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))
    ys = list(y = branin(xs$x1, xs$x2))
    rush$finish_tasks(key, yss = list(ys))
  }
}

config = redux::redis_config()

rush = rsh(
  network = "random-search-network",
  config = config)
```

## Starting Workers with mirai

The `mirai` package provides a mechanism for launching `rush` workers on
local and remote machines. `mirai` daemons are persistent background
processes that execute arbitrary R code in parallel. Daemons are started
using
[`mirai::daemons()`](https://mirai.r-lib.org/reference/daemons.html).
For local daemons, the number of workers is specified.

``` r
library(mirai)

daemons(n = 2L)
```

After the daemons are started, workers are launched with the
`$start_workers()` method. The `$wait_for_workers()` method blocks until
all workers have registered in the network.

``` r
worker_ids = rush$start_workers(
  worker_loop = wl_random_search,
  n_workers = 2,
  branin = branin)

rush$wait_for_workers(worker_ids = worker_ids)
```

Worker information is accessible through the `$worker_info` field. Each
worker is identified by a `worker_id`. The `pid` field denotes the
process identifier and the `hostname` field indicates the machine name.
The `remote` column specifies whether the worker is remote and the
`heartbeat` column indicates the presence of a heartbeat process. The
`state` column reflects the current worker state, which can be
`"running"` or `"terminated"`.

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat   state
              <char> <int>        <char>    <lgcl>  <char>
    1: curvaceous...  9650 runnervm72...     FALSE running
    2: declinatio...  9648 runnervm72...     FALSE running

### Stopping Workers

Workers can be stopped individually or all at once. To terminate a
specific worker, the `$stop_workers()` method is called with the
corresponding `worker_ids`.

``` r
rush$stop_workers(worker_ids = worker_ids[1])
```

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat      state
              <char> <int>        <char>    <lgcl>     <char>
    1: declinatio...  9648 runnervm72...     FALSE    running
    2: curvaceous...  9650 runnervm72...     FALSE terminated

To stop all workers and reset the network, the `$reset()` method is
used.

``` r
rush$reset()
```

Instead of killing the worker processes, the manager can send a
terminate signal. The worker then terminates after completing its
current task. The worker loop must check the `rush$terminated` flag.

``` r
wl_random_search = function(rush, branin) {
  while (!rush$terminated) {
    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))
    ys = list(y = branin(xs$x1, xs$x2))
    rush$finish_tasks(key, yss = list(ys))
  }
}

rush = rsh(
  network = "random-search-network",
  config = redux::redis_config())

rush$start_workers(
  worker_loop = wl_random_search,
  n_workers = 2,
  branin = branin)

rush$wait_for_workers(2)
```

``` r
rush$fetch_finished_tasks()
```

            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>
     1: retiring_a...  1.36367673  6.79918861  19.4237527 8e46b963-b...
     2: retiring_a...  8.15283349  6.25824577  28.7689903 8f3a453b-5...
     3: retiring_a...  1.02054285 14.22174403 109.3330774 935f311d-5...
     4: retiring_a... -0.25228201  2.48744151  34.6825973 686fd743-c...
     5: retiring_a...  5.02198210  2.16589643  13.7364886 c0b18be0-1...
     6: retiring_a... -2.47279063 11.32929778   2.8310994 ff3257be-b...
     7: retiring_a... -0.80102330  5.90464238  18.7943489 04639e08-0...
     8: retiring_a... -0.88977692  5.41806003  20.4567763 5287c6ba-e...
     9: retiring_a...  0.70366982  9.06136258  34.2736911 fa2c1214-9...
    10: retiring_a... -3.20026050  0.13725694 151.1926835 c1b1cf5b-5...
    11: retiring_a...  6.82268855  5.30455209  35.4589262 5eba604d-0...
    12: retiring_a...  0.07796056  1.83904377  35.8756724 58126598-7...
    13: retiring_a... -2.06387121  0.19679638  98.3503758 fd42ef4e-2...
    14: retiring_a...  6.77356845 12.49418613 147.2365340 29a29e9d-4...
    15: retiring_a... -2.06938843  9.30118531   5.7060108 569840ff-6...
    16: retiring_a...  0.01503537 10.01799420  35.9379387 33212221-3...
    17: retiring_a...  5.58427272 11.27608988 120.0737723 f1a912f5-6...
    18: retiring_a... -0.72868920 12.35137698  43.4091408 6f1d85d3-6...
    19: retiring_a...  0.59728016 11.68216722  61.3240673 4dcaac86-b...
    20: retiring_a...  4.17382822  3.15850475   7.4802203 faf43780-1...
    21: retiring_a...  6.53692163  3.97895253  27.4889075 3ee1e991-d...
    22: retiring_a...  1.35198750 10.61684134  54.7573847 b100da43-9...
    23: retiring_a...  2.89165908 12.76064633 106.4294066 00b98dc8-7...
    24: retiring_a...  3.04821546  1.76161649   0.7846765 698ff230-b...
    25: retiring_a...  2.87929825  5.18909820   8.0198553 27958283-7...
    26: retiring_a... -2.65985529  2.13626538  82.6885284 3382f785-d...
    27: retiring_a...  5.22319113 12.16212011 134.6123174 f085c2e5-5...
    28: retiring_a...  2.85049344  4.05464420   3.1786380 cdd23250-8...
    29: retiring_a... -4.29223700  1.15297443 203.7201646 b72a5587-8...
    30: retiring_a...  9.34287430  3.37141613   1.3606004 41a1e7ac-6...
    31: retiring_a...  2.45494221 12.74812969 100.1237723 572e5602-f...
    32: retiring_a...  5.51209419  1.43426407  16.9656844 a9fcde47-7...
    33: retiring_a... -4.26827082 13.17666090   9.7552552 79520481-7...
    34: retiring_a...  7.16663325  2.76159742  18.4414608 0221de36-3...
    35: retiring_a... -3.25015769  2.65663185  98.0845989 1e9fc6f7-e...
    36: retiring_a...  3.73462864 12.18884296 108.7648493 ed269b03-6...
    37: traumatic_...  6.55014084 11.60216078 129.1858288 cdb88f94-a...
    38: retiring_a...  9.33657278 12.39910795 100.3853387 6995b429-a...
    39: traumatic_...  4.59780950 10.99952856 100.7979722 deba5452-7...
    40: retiring_a... -3.33086875 12.32153039   0.7399216 9fb6fcd1-a...
    41: traumatic_...  6.82037392  3.93688625  25.9920130 a56740e3-3...
    42: retiring_a...  6.25109237 12.25066317 143.9542728 a88517e0-2...
    43: traumatic_...  9.05979226  8.10729370  36.1118163 028b9b22-6...
    44: retiring_a...  8.14786378  9.34818840  67.1208295 cf08ca5c-8...
    45: traumatic_...  3.60816904 14.36857189 155.9120485 13e177a8-d...
    46: retiring_a... -1.81800887  6.92814228  13.3733631 6c744e02-1...
    47: traumatic_...  8.59542143  3.03288000   4.8808407 65dd1aab-4...
    48: retiring_a...  0.71983737  5.69842760  17.8239078 2467f07e-2...
    49: traumatic_...  5.65617248  9.20569969  82.9791586 abc0ca4c-5...
    50: retiring_a...  9.29377563 13.13354056 116.4047226 de2a5f32-5...
    51: traumatic_...  4.08970631  4.02183952  10.0173031 ac3ca3d6-3...
    52: retiring_a...  2.15754764  1.31757322   8.1059798 646fd9aa-c...
    53: traumatic_... -3.41537316  5.22948522  60.2483196 8f3379ed-8...
    54: retiring_a... -2.36523340  8.11548353   8.7736883 6f70a2ae-5...
    55: retiring_a...  9.50003683 12.26283746  94.9739176 386ced4f-3...
    56: traumatic_...  1.42963233  1.67354281  16.7109422 003ac4ff-4...
    57: traumatic_... -1.92097957  0.21867518  93.4819331 92ad8422-1...
    58: retiring_a...  6.08900833  8.03325597  67.5098633 becb59ac-c...
    59: traumatic_...  1.66667264  2.77385746   9.9501626 728a2d2a-7...
    60: retiring_a...  0.51139601 14.16105519  98.3183768 67fb8e47-b...
    61: traumatic_... -1.64935277  3.69488501  37.1414539 4c087d47-9...
    62: retiring_a... -2.67353808  0.54547829 114.4907854 5900c105-1...
    63: traumatic_...  8.26074341  0.93773467   6.7345577 6edb0497-3...
    64: retiring_a...  2.48324886  4.07360849   3.9156039 7cfac4f5-4...
    65: traumatic_...  7.77959038 14.01578098 168.9417593 e3fa090a-7...
    66: retiring_a... -3.81667888  5.68071903  70.9888038 610e5e5f-9...
    67: retiring_a...  4.17702908  0.95184826   5.5294009 fcc60696-e...
    68: traumatic_... -1.40266668  5.51614791  20.4302744 d61941a7-e...
    69: retiring_a...  2.90072758  8.85278783  41.4107776 adc6ff1f-3...
    70: traumatic_... -2.30594503  3.72829554  47.4989334 88e72c58-a...
    71: retiring_a...  5.62036296 14.02146601 183.6130278 7f178621-7...
    72: traumatic_...  5.74133297  1.57157753  18.4299640 1cfbc9b0-9...
    73: retiring_a...  1.60054435  1.98010087  12.9669784 a526e5fc-0...
    74: traumatic_...  5.61513665  0.02928822  18.7636371 8c022aed-e...
    75: retiring_a... -3.90759008 13.29374927   3.8861115 b6663c18-0...
    76: traumatic_... -2.09262382  8.46858884   7.2518194 c6d86822-9...
    77: retiring_a...  1.52078233  8.69880026  33.7165400 b4ee7628-0...
    78: retiring_a... -1.59350932  9.74516010  10.5580458 5abf15ce-5...
    79: traumatic_...  4.00051379 11.91560332 108.0763701 c8fbda43-d...
    80: retiring_a...  1.65570665  6.13485741  15.0220141 a314d8d7-f...
    81: traumatic_... -0.51338170  1.40861378  47.9851688 019a88a3-f...
    82: retiring_a... -0.24629633 12.95256569  62.2506944 14419e25-f...
    83: traumatic_...  7.95333588  5.18858553  22.5537369 35b8041b-5...
    84: retiring_a... -0.25673496 13.96637207  76.2785829 6fe78ad6-e...
    85: traumatic_... -2.86652026  0.11969369 133.1012612 0c7bada9-c...
    86: retiring_a...  0.49693161  2.91245981  23.8628770 d0cb07ad-1...
            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>

The `$stop_workers()` method with `type = "terminate"` sends the
terminate signal.

``` r
rush$stop_workers(type = "terminate")
```

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat      state
              <char> <int>        <char>    <lgcl>     <char>
    1: retiring_a...  9650 runnervm72...     FALSE terminated
    2: traumatic_...  9648 runnervm72...     FALSE terminated

``` r
rush$reset()
```

### Failed Workers

Failed workers started with `mirai` are automatically detected by the
manager. We simulate a worker crash by killing the worker process.

``` r
rush = rsh(network = "random-search-network")

wl_failed_worker = function(rush) {
  tools::pskill(Sys.getpid(), tools::SIGKILL)
}
```

``` r
mirai::daemons(n = 2L)
```

``` r
worker_ids = rush$start_workers(
  worker_loop = wl_failed_worker,
  n_workers = 2L)
```

``` r
rush$detect_lost_workers()
```

    [1] "ferrous_janenschia"     "chronological_stonefly"

``` r
rush$reset()
```

### Remote Workers

Daemons can also be launched on remote machines via SSH.

``` r
mirai::daemons(
  n = 2L,
  url = host_url(port = 5555),
  remote = ssh_config(remotes = "ssh://10.75.32.90")
)
```

On high-performance computing clusters, daemons can be started using a
scheduler.

``` r
mirai::daemons(
  n = 2L,
  url = host_url(),
  remote = remote_config(
    command = "sbatch",
    args = c("--mem 512", "-n 1", "--wrap", "."),
    rscript = file.path(R.home("bin"), "Rscript"),
    quote = TRUE
  )
)
```

### Rush Plan

When `rush` is integrated into a third-party package, worker startup is
typically managed by the package itself. Users can configure worker
options by calling the
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
function, which specifies the number of workers, the worker type, and
the Redis configuration.

``` r
rush_plan(n_workers = 2, config = redux::redis_config(), worker_type = "mirai")
```

### Passing Data to Workers

Arguments required by the worker loop are passed as named arguments to
`$start_workers()`. These arguments are serialized and stored in the
Redis database as part of the worker configuration. Upon initialization,
each worker retrieves and deserializes the configuration before
executing the worker loop.

> **Note**
>
> The maximum size of a Redis string is 512 MiB. If the serialized
> worker configuration exceeds this limit, `rush` raises an error. When
> both the manager and the workers share access to a file system, `rush`
> will instead write large objects to disk. The `large_objects_path`
> argument of
> [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
> specifies the directory used for storing such objects.

### Log Messages

Workers can record messages generated via the `lgr` package to the
database. The `lgr_thresholds` argument of `$start_local_workers()`
specifies the logging level for each logger,
e.g. `c("mlr3/rush" = "debug")`. Logging introduces a minor performance
overhead and is disabled by default.

``` r
rush = rsh(network = "random-search-network")

wl_log_message = function(rush) {
  lg = lgr::get_logger("mlr3/rush")
  lg$info("This is an info message from worker %s", rush$worker_id)
}

rush$start_local_workers(
  worker_loop = wl_log_message,
  n_workers = 2,
  lgr_thresholds = c(rush = "info"))
```

The most recent log messages can be retrieved as follows.

``` r
Sys.sleep(1)
rush$print_log()
```

To retrieve all log entries, use the `$read_log()` method.

``` r
rush$read_log()
```

    Null data.table (0 rows and 0 cols)

``` r
rush$reset()
```

## Starting Local Workers

The `$start_local_workers()` method launches workers using the
`processx` package on the local machine. The `n_workers` argument
specifies the number of workers to launch and `worker_loop` defines the
function executed by each worker. Additional arguments required by the
worker loop are passed as named arguments to `$start_local_workers()`.

``` r
rush = rsh(
  network = "random-search-network",
  config = redux::redis_config())

worker_ids = rush$start_local_workers(
  worker_loop = wl_random_search,
  branin = branin,
  n_workers = 2)

rush$wait_for_workers(worker_ids = worker_ids)
```

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat   state
              <char> <int>        <char>    <lgcl>  <char>
    1: chaseable_...  9941 runnervm72...     FALSE running
    2: adventuref...  9943 runnervm72...     FALSE running

Additional workers can be added to the network at any time.

``` r
rush$start_local_workers(
  worker_loop = wl_random_search,
  branin = branin,
  n_workers = 2)

rush$wait_for_workers(worker_ids = worker_ids)
```

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat   state
              <char> <int>        <char>    <lgcl>  <char>
    1: chaseable_...  9941 runnervm72...     FALSE running
    2: adventuref...  9943 runnervm72...     FALSE running

``` r
rush$reset()
```

## Script Workers

The `$worker_script()` method generates an R script that can be executed
on any machine with access to the Redis database. This is the most
flexible mechanism for starting workers, as it imposes no constraints on
the execution environment.

``` r
rush = rsh(
  network = "random-search-network",
  config = redux::redis_config())

rush$worker_script(
  worker_loop = wl_random_search)
```

### Error Handling

Workers started with `processx` and `mirai` are monitored automatically
by the respective packages. Script workers require an explicit heartbeat
mechanism to detect failures. The heartbeat consists of a Redis key with
a set expiration timeout, refreshed periodically by a background process
linked to the main worker process. If the worker fails, the heartbeat
process also ceases, the key expires, and the manager marks the worker
as `"terminated"`.

The `heartbeat_period` and `heartbeat_expire` arguments configure the
heartbeat at startup. The `heartbeat_period` defines the refresh
interval in seconds; `heartbeat_expire` sets the expiration duration,
which must exceed the heartbeat period.

``` r
rush$worker_script(
  worker_loop = wl_random_search,
  heartbeat_period = 1,
  heartbeat_expire = 3)
```

To kill a script worker, the `$stop_workers(type = "kill")` method
pushes a kill signal to the heartbeat process, which then terminates the
main worker process.
