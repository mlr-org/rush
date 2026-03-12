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
    1: sharp_warb...  9008 runnervm0k...     FALSE running
    2: pyroxene_f...  9010 runnervm0k...     FALSE running

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
    1: sharp_warb...  9008 runnervm0k...     FALSE    running
    2: pyroxene_f...  9010 runnervm0k...     FALSE terminated

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

            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>
     1: grandiose_...  3.3914329  0.6254064   2.8358483 9f31982e-4...
     2: grandiose_... -4.6663204  1.7019225 220.9022642 3c668fd2-a...
     3: grandiose_...  9.5742983  6.5738270  16.2644556 aca51a45-6...
     4: grandiose_...  1.7149469 10.6652738  57.8274875 a701b077-f...
     5: grandiose_...  1.2625083 14.4902177 118.8728064 50441855-4...
     6: grandiose_...  4.8511392  7.6317291  51.1742486 4949a121-c...
     7: grandiose_...  1.1093707  3.8302003  14.5922611 2c70c36e-d...
     8: grandiose_...  8.9558913  5.9082868  15.8772705 8748e874-e...
     9: grandiose_...  3.8304202 14.4360682 162.2800257 43e9cf6b-d...
    10: grandiose_...  7.7082167  8.7566735  65.4021564 6af8e1e6-0...
    11: grandiose_... -1.5287216 10.0196825  12.0544539 1af11a1c-3...
    12: grandiose_...  1.0217262  8.2473221  28.9883500 32a39553-b...
    13: grandiose_...  0.7156914  0.2471291  39.1483747 e6a0fc44-3...
    14: grandiose_...  3.1568119  2.6844864   0.5765144 2afc2d5a-e...
    15: grandiose_...  3.4932718 13.4770984 132.3259185 91479090-e...
    16: grandiose_...  9.5961376 11.5995331  81.1105851 5c3d7390-a...
    17: grandiose_... -1.3628988  7.0068141  13.9482562 89606d7a-7...
    18: grandiose_... -4.9496209  7.8257332  97.2040290 793ef01c-f...
    19: grandiose_...  7.9719282  5.4502350  24.2997865 48d03be0-d...
    20: grandiose_...  2.0950757  8.3502448  31.3833843 1c28207f-6...
    21: grandiose_...  0.6693324  9.4978458  37.8275642 86e0748d-c...
    22: grandiose_... -1.6820539  0.8759813  75.6271356 f8451605-4...
    23: grandiose_...  7.6421098 10.6569094  98.0465544 f60b230f-2...
    24: grandiose_...  4.9756015  5.0166069  26.4661141 9e175cfb-0...
    25: grandiose_...  8.4505106 12.2332710 113.9643461 8426d97e-0...
    26: grandiose_...  0.2426260 12.2877866  63.7608690 3896be79-e...
    27: grandiose_...  5.5129987  3.2306115  21.2123601 4c196227-e...
    28: grandiose_...  7.7842040  1.9979364  10.9820587 a82b921e-e...
    29: grandiose_...  5.4551621  7.2852263  53.9854947 dc73e6ec-2...
    30: grandiose_... -3.4972347  2.4510074 115.3823187 68a5ebba-b...
    31: grandiose_... -3.1513845  5.8401833  42.1087782 705c0213-c...
    32: grandiose_...  2.2933775  9.8083447  49.6035501 f8145f40-c...
    33: grandiose_...  3.8264714 10.6998353  81.7438231 ae35e57d-1...
    34: grandiose_...  1.0412170  4.7118179  14.9031034 49e43c96-1...
    35: grandiose_...  1.9660957  1.8600181   8.5831099 4d1d68b5-6...
    36: grandiose_...  2.7739753 14.8334183 151.2065771 26a04bc5-4...
    37: grandiose_...  2.8893150  0.8679360   3.3004591 7dda34f4-a...
    38: grandiose_...  0.1325587  5.6162611  19.5485102 57588ac5-3...
    39: grandiose_... -4.2059309 10.3096504  27.1468922 a3d335c2-3...
    40: grandiose_... -3.9219159  4.7709368  92.6302061 837871c9-a...
    41: pericardia...  4.1351641  1.0695901   5.0715898 4ac17058-9...
    42: grandiose_...  4.1175214  4.6307695  13.5819212 5bceb377-d...
    43: pericardia... -3.6753928  3.6354119 100.9203568 6b6a0d70-a...
    44: grandiose_...  5.0483286  7.5062752  52.2103034 ce89c2b6-f...
    45: pericardia...  1.0579202  2.3948588  18.9799372 ab652592-9...
    46: grandiose_...  5.7309845  3.6869098  24.7546843 ea812426-c...
    47: pericardia... -1.8935961  4.9476269  27.4689342 4037e7db-b...
    48: grandiose_... -2.7791409 10.2895756   2.3016573 22807c70-d...
    49: grandiose_... -3.3880790  9.7144476  10.6785511 65a755bc-e...
    50: pericardia...  6.1668250  0.1155713  20.5024360 f66e9be6-4...
    51: grandiose_... -1.1855319  8.9206217  14.3347969 a08d83ee-3...
    52: pericardia...  6.7647617 13.3188578 166.7058022 b341bcab-9...
    53: grandiose_...  7.5439058  0.1494873  14.3602462 797f7ade-9...
    54: pericardia... -2.8602065  5.8224395  34.2596946 aea130ca-4...
    55: grandiose_...  4.9384610  1.9486033  12.5850330 6cc93b68-b...
    56: pericardia... -1.4001251  4.0602464  31.1793618 f443fc4b-7...
    57: grandiose_...  2.2061367 10.8205617  63.6376859 168dc490-3...
    58: pericardia... -1.4855218 14.2176879  41.8240720 670415fc-a...
    59: grandiose_...  9.5459012 10.5294687  63.6771523 a72c5826-f...
    60: pericardia... -2.3373041  2.1298192  72.1608656 55d73661-7...
    61: grandiose_...  7.0044825  9.7297938  90.1358722 95b2c8c2-2...
    62: pericardia...  2.5110759  3.5280763   2.7482595 3cfff143-6...
    63: grandiose_... -4.0610988  3.1234057 135.7540232 46af8b3b-e...
    64: pericardia... -4.8600801  6.0438193 126.8169983 72a88d36-1...
    65: pericardia...  0.3014407 10.5192905  44.0424098 8f0b55e7-e...
    66: grandiose_... -3.1217198  3.9149408  69.4949637 31dd4202-4...
    67: pericardia...  5.6438410  2.5703394  19.7730844 46288fa8-b...
    68: grandiose_... -1.7825065 11.9044552  15.0421829 257d708b-f...
    69: pericardia...  3.3512628  2.6325650   0.8738134 ae455f8f-3...
    70: grandiose_... -4.1313004  3.1884294 139.0945995 a78a1024-e...
    71: pericardia...  2.9271303  4.4295723   4.5437299 7c9153d5-3...
    72: grandiose_...  6.3905124  1.1218442  19.5471488 db75ee56-5...
    73: grandiose_...  3.4280542  0.5466931   3.0859413 6982b2c4-2...
    74: pericardia...  3.6567618 11.8991438 101.4765764 f3e9f828-2...
    75: pericardia... -3.8777115  4.1927353 101.3169756 f860856f-e...
    76: grandiose_...  8.7004996 11.0914509  86.7070081 c989e517-1...
    77: grandiose_...  7.2034587  7.2136093  51.5146055 ee97dd73-0...
    78: pericardia...  3.9854015  4.7867430  13.0911662 ffbcf545-4...
    79: pericardia... -1.9741085 10.7940454   7.5510197 c268c7a8-8...
    80: grandiose_... -2.7624194 13.1331613   4.1453301 dd1a1c03-0...
    81: pericardia...  0.9672398 14.6868603 117.5692505 70ab5c18-5...
    82: grandiose_... -4.0242951 12.4650625   8.0308004 53434558-7...
    83: pericardia... -0.3005245  3.0506542  31.0006305 22893671-0...
    84: grandiose_...  2.2519066  8.6149909  34.6888683 49b5fdc9-d...
    85: pericardia... -0.6111513  8.3501755  19.6309112 2060f075-8...
    86: grandiose_...  8.5135487 14.9812606 177.5026773 e692d86e-b...
    87: grandiose_...  1.6898580 12.8680776  93.2910808 c8ae0a9c-f...
    88: pericardia...  2.8569913 14.1791292 137.0131127 bc976dba-7...
    89: pericardia...  3.3614636 12.1933947 102.3084030 de8951d0-1...
    90: grandiose_...  4.2525604 11.6026296 106.4314747 b00b27c0-f...
    91: pericardia...  0.6030480 13.6689593  91.5550062 341c620f-4...
    92: grandiose_... -2.7441058 12.0743598   1.6855569 4ee63a91-5...
    93: grandiose_...  3.7582144  2.9091264   3.3023566 559a620a-5...
    94: pericardia...  2.1687005  7.9164945  27.2572204 610cba77-4...
    95: grandiose_...  6.8765271  8.8707983  77.3499777 ffd44cc5-3...
    96: pericardia... -1.3660778 11.9089345  24.1577861 d24ab529-2...
            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>

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
    1: grandiose_...  9010 runnervm0k...     FALSE terminated
    2: pericardia...  9008 runnervm0k...     FALSE terminated

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

    [1] "bored_fiddlercrab"   "smallminded_swallow"

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
    1: fibered_gr...  9298 runnervm0k...     FALSE running
    2: nondemocra...  9300 runnervm0k...     FALSE running

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
    1: fibered_gr...  9298 runnervm0k...     FALSE running
    2: nondemocra...  9300 runnervm0k...     FALSE running

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
