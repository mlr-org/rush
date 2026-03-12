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
    1: activated_...  8980 runnervm0k...     FALSE running
    2: thermodyna...  8982 runnervm0k...     FALSE running

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
    1: thermodyna...  8982 runnervm0k...     FALSE    running
    2: activated_...  8980 runnervm0k...     FALSE terminated

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

            worker_id          x1          x2          y          keys
               <char>       <num>       <num>      <num>        <char>
     1: ignitable_... -4.02817943  0.01118109 214.066148 50352949-c...
     2: ignitable_... -1.30719042  2.00343343  52.163847 27f7c653-a...
     3: ignitable_...  1.00117794  5.61009633  16.332066 42501a0a-7...
     4: ignitable_...  8.80635720 14.49128061 158.139522 6be4a89c-6...
     5: ignitable_... -4.67746434  1.59720029 224.979285 e04983ae-7...
     6: ignitable_... -3.31891588  9.27883753  12.288498 6f4875b1-0...
     7: ignitable_...  7.30861418 14.27563732 184.167107 bf08e24c-7...
     8: ignitable_... -1.22880878  4.63167368  25.604239 a230153f-8...
     9: ignitable_...  7.34762707  4.43352471  24.600075 f9e9adb0-7...
    10: ignitable_...  7.87016595  1.02122769  10.051300 fb327406-0...
    11: ignitable_...  7.57790550 11.77674046 121.172433 db3eff6a-c...
    12: ignitable_...  7.98847710 11.91108697 116.480407 3c6a19b9-6...
    13: ignitable_...  1.37251989  7.01464218  20.627681 48ef0e22-9...
    14: ignitable_... -0.46746794 11.93046816  45.179359 b3f105ef-b...
    15: ignitable_...  6.69389034  5.84434212  40.982783 e446c247-5...
    16: ignitable_...  3.26570302  8.11745999  35.722786 b0eb74ff-9...
    17: ignitable_...  3.57936271 12.45073787 111.393404 faefb6ef-b...
    18: ignitable_... -2.11274808 12.84084581  13.466782 1c4edae3-a...
    19: ignitable_... -2.67115615  4.68633512  43.518018 08ae49b0-e...
    20: ignitable_...  4.18988115  2.76878321   6.575371 7cdef017-6...
    21: ignitable_... -1.36321674  1.65859545  57.556307 89feb551-5...
    22: ignitable_... -3.82922272  0.66520261 180.093470 3110772b-0...
    23: ignitable_...  2.12876365 13.63071507 113.770426 7f1820a3-4...
    24: ignitable_...  6.57081600  3.36104082  24.230612 45313ef9-e...
    25: ignitable_...  3.10922549 11.94895901  93.498048 6d22f9a2-3...
    26: ignitable_...  7.60958520  0.92432071  12.521615 f214d87a-a...
    27: ignitable_...  9.71185907 13.89931571 125.593492 600e093e-d...
    28: ignitable_... -2.63130889 13.43642412   7.163020 2def763e-6...
    29: ignitable_...  7.24950638  9.81388491  88.773519 f01bed8b-2...
    30: ignitable_...  0.25635998  5.48861422  19.300823 61d8a3cb-5...
    31: ignitable_... -0.82174437  7.13779897  16.604702 07ebef5c-5...
    32: ignitable_...  7.69520139 10.78243808  99.501230 85cd2447-8...
    33: ignitable_...  0.50055394  6.45461969  19.909833 94ef15bc-6...
    34: ignitable_...  7.51360842 13.46659599 160.387408 8f1021c7-2...
    35: ignitable_...  2.05390116  6.14970613  13.797244 bf22235a-9...
    36: ignitable_...  5.74147175 10.98864327 115.604312 9cca0024-6...
    37: ignitable_... -4.56506011  3.65475826 159.952691 a0e11e60-9...
    38: ignitable_...  3.56057822  7.14699674  28.020133 d7c390b6-e...
    39: ignitable_...  8.13590930 13.74915776 154.872075 4f340266-8...
    40: ignitable_...  4.73309271 13.40654838 155.292530 0c0b9b6f-c...
    41: ignitable_...  8.26157942  7.62060158  41.619902 108e844d-5...
    42: ignitable_... -2.16581703  2.41398530  62.971989 add39c5a-2...
    43: revengeful... -1.54771297  2.85912633  45.192128 150aa1f0-2...
    44: ignitable_...  8.68668620 10.58762055  77.976244 c41d9b53-4...
    45: revengeful...  9.41515604  3.40681451   1.281779 9139b903-6...
    46: ignitable_...  2.78186866  7.14485701  21.921208 05d2dcb6-f...
    47: revengeful...  4.48178663 10.50446581  89.573874 bfe01524-a...
    48: ignitable_... -0.70584253 10.78136985  30.221976 f16411a7-9...
    49: ignitable_... -1.81127482 11.92234020  14.555442 47585029-6...
    50: revengeful...  6.05487110  1.94902949  20.074689 e3915906-1...
    51: revengeful...  4.42710027  9.47275681  71.086457 c2a2f797-0...
    52: ignitable_...  5.48521789  8.81285850  75.318181 52c1fd6c-1...
    53: ignitable_...  5.03609519  0.92481378  13.167430 4fb1fee9-1...
    54: revengeful...  1.24555967  5.33717991  14.320645 fba1e87b-c...
    55: revengeful...  2.13106449 10.33631167  55.895803 197e4200-b...
    56: ignitable_...  2.62178740  2.56893719   1.687590 822730eb-9...
    57: revengeful...  0.22103535  7.45158413  22.597932 54b7953e-8...
    58: ignitable_... -4.91860227 10.30059239  56.227446 10abfbeb-e...
    59: revengeful... -0.62414815  0.14346183  65.404862 1f886273-f...
    60: ignitable_...  5.73617161 13.72474642 177.049284 7ed7820e-3...
    61: ignitable_... -0.68124455 12.21190831  43.140609 1ecd4524-b...
    62: revengeful... -2.75007950 12.78441891   3.170832 108e7fbd-f...
    63: ignitable_... -2.87665695  9.99500017   3.463216 5c20b421-5...
    64: revengeful...  7.36236195  3.14852413  18.006178 f8f428d3-3...
    65: ignitable_... -4.22417320  9.42139741  36.931260 427a90ab-e...
    66: revengeful...  8.56513745  6.97436276  30.039481 cd9f6595-a...
    67: revengeful...  6.31566489 12.40062690 147.274772 24f78aa8-6...
    68: ignitable_...  5.93390748  4.51604523  30.660010 a626f3a6-5...
    69: revengeful...  5.95458652 14.62440329 201.903470 67e64656-9...
    70: ignitable_... -1.48167961  6.48527254  15.505078 c4b4e5b9-3...
    71: revengeful... -4.55542742 14.27393140  11.244942 23fdf382-0...
    72: ignitable_... -2.62718969  4.51025477  44.709497 2f679479-3...
    73: revengeful...  0.29439446  4.38370120  20.532180 c56d5a7c-4...
    74: ignitable_... -1.00616477  4.75284176  24.014372 0e059f1a-1...
    75: revengeful...  6.61375322 13.35491186 168.661812 0f2c4065-e...
    76: ignitable_...  0.01492534  4.08220356  23.188547 387f7b10-4...
    77: revengeful...  4.06111953 10.99916830  91.266212 777acaeb-7...
    78: ignitable_... -3.55246043 12.92457852   1.326370 7fc713a7-1...
    79: revengeful...  0.99024230  3.05672755  17.498459 209e4d82-6...
    80: ignitable_...  2.69820641 11.61986397  81.853458 ff973f66-8...
    81: revengeful...  8.63135714  8.96877470  53.415703 c03c3e19-6...
    82: ignitable_...  5.50949970 10.34813434 101.424765 8f202263-1...
    83: revengeful...  0.15475274  9.95530763  37.114855 1fbeec66-3...
    84: ignitable_... -3.29580602  8.62434372  16.707153 032689fc-7...
            worker_id          x1          x2          y          keys
               <char>       <num>       <num>      <num>        <char>

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
    1: revengeful...  8982 runnervm0k...     FALSE terminated
    2: ignitable_...  8980 runnervm0k...     FALSE terminated

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

    [1] "equivalent_westafricanantelope" "plaid_anemone"                 

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
    1: ichthyopha...  9271 runnervm0k...     FALSE running
    2: ultramicro...  9273 runnervm0k...     FALSE running

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
    1: ichthyopha...  9271 runnervm0k...     FALSE running
    2: ultramicro...  9273 runnervm0k...     FALSE running

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
