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
    1: marginal_b...  9652 runnervm0k...     FALSE running
    2: semineurot...  9654 runnervm0k...     FALSE running

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
    1: semineurot...  9654 runnervm0k...     FALSE    running
    2: marginal_b...  9652 runnervm0k...     FALSE terminated

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

            worker_id           x1         x2           y          keys
               <char>        <num>      <num>       <num>        <char>
     1: synecologi... -0.016484700 13.9584239  82.5198523 2fe27d3c-3...
     2: synecologi... -0.006570061 13.9488726  82.6202666 5d225706-1...
     3: synecologi...  2.066941439  2.9918570   5.5021423 905c9e55-3...
     4: synecologi...  5.877044144  7.8633611  64.4507548 85c6fc8c-2...
     5: synecologi...  2.679337264  4.7234748   5.6507907 83b61b48-1...
     6: synecologi... -2.895931914 14.5368465   8.7769660 ccad0c77-c...
     7: synecologi... -0.809231499 11.0345995  30.0367439 8e97415e-0...
     8: synecologi...  6.737606578  0.4563682  19.0965581 e56e2be1-e...
     9: synecologi...  3.025088362 13.9928820 135.6099195 6b6a2158-0...
    10: synecologi...  2.111613266 10.3560552  56.0470763 c681291f-c...
    11: synecologi...  0.212067853  6.5778752  20.2143430 3bf2042d-5...
    12: synecologi...  6.421365158  9.4667248  89.3978440 3962ef29-9...
    13: synecologi...  9.841183830  4.5315294   4.0504948 e30e5bc7-1...
    14: synecologi... -0.023320977 12.1004007  56.3620650 f2abe3b9-d...
    15: synecologi... -3.840203137  0.4599387 186.4406189 77eaf625-2...
    16: synecologi... -0.129785716  0.4585022  52.5865487 84440d90-7...
    17: synecologi... -0.742727887  7.0603125  17.1104343 5f304d89-d...
    18: synecologi...  3.027856249 12.5291155 103.7616600 6629fb0d-1...
    19: synecologi...  6.439447711  4.8158725  33.2324852 b22ba7fa-3...
    20: synecologi... -3.460646480  6.6184315  42.3107771 138d7fcf-5...
    21: synecologi...  8.309745676 13.9178740 155.1707941 2fbda321-7...
    22: synecologi...  9.885244965 13.7750677 119.8651761 60689b7a-d...
    23: synecologi...  9.556933569  3.0834964   0.7264079 ae2b9f35-3...
    24: synecologi... -0.419125291 14.9354182  86.7620167 abdefc2e-6...
    25: synecologi... -3.929110090  3.8370796 111.6059372 b127c589-c...
    26: synecologi...  1.905620906 11.1149296  65.8071455 9b139ee6-b...
    27: synecologi...  7.165323289  7.8137412  59.4661592 18cd49e1-c...
    28: synecologi... -3.401009928 12.7275941   0.7514129 ce80fd12-b...
    29: synecologi... -2.342022271  4.2200610  41.9454560 f68d8d6e-1...
    30: synecologi... -1.898326240 12.4910544  15.9364057 7b57217d-0...
    31: synecologi...  0.194584205  9.7897758  36.1864464 e025b226-9...
    32: synecologi... -3.101872072  8.2377302  15.9449475 e73487c9-a...
    33: synecologi...  4.284713725  0.8687782   6.4847110 5c5b345d-e...
    34: synecologi...  6.947850299  5.1218401  33.1101243 8e708155-d...
    35: synecologi...  7.036292642  1.2078042  17.0054986 175bb9fd-5...
    36: synecologi...  1.114168319 12.3961456  78.3784234 b706ac31-8...
    37: synecologi... -2.519874600  5.5035124  30.5746012 cfb47d7b-9...
    38: synecologi...  5.047450592 14.4952946 188.3851191 295f3e3b-d...
    39: synecologi... -3.617868175  1.0563170 155.0428360 fd097137-1...
    40: synecologi... -2.311993543  1.2579160  86.5503515 d0b3a422-f...
    41: synecologi... -1.180688056 12.6485089  34.7132402 442f5350-e...
    42: synecologi...  6.432049871 14.8616757 208.6704772 63bf7634-7...
    43: synecologi...  7.198177742  3.9864636  23.4133469 06a0d02d-9...
    44: encephalit...  1.289753818 11.9392919  73.1465786 2b874f3e-3...
    45: synecologi...  7.285112066 10.5545884 101.5325615 152a5f4c-2...
    46: encephalit...  0.898425633  1.4336924  26.4826911 71316d08-7...
    47: synecologi...  8.808650512  2.1129116   2.1752918 7fffa0a0-f...
    48: encephalit...  9.761734930 11.6859370  80.3623004 4c32b768-f...
    49: synecologi...  9.926117543  6.9220980  17.5134999 9a502822-4...
    50: encephalit...  4.837913532  1.1779606  11.2234183 bfae0971-6...
    51: synecologi...  2.962801403 10.7629313  70.1794569 784c64db-6...
    52: encephalit... -0.878236641 12.3388742  39.5709397 80d192ff-4...
    53: synecologi... -0.974288887  9.7077326  19.5331446 82f706b1-9...
    54: encephalit... -0.936920433  3.5284526  32.3016820 8ff05524-3...
    55: synecologi... -0.615376391  2.1105925  42.0247338 f03ca774-0...
    56: encephalit...  4.165137041 12.6534734 126.9151262 64a753b3-8...
    57: synecologi... -3.474915857  5.4569558  59.1959854 4773982f-f...
    58: encephalit...  9.160169583  2.4323211   0.7614939 e93f0527-a...
    59: synecologi... -2.121400948 14.6967006  27.4343816 65113780-1...
    60: encephalit...  8.982738322 14.2821669 149.0598548 3766aaf8-4...
    61: synecologi...  5.880814038  1.3338120  18.8861823 1f3f6d70-5...
    62: encephalit...  2.292172730  9.8743965  50.4956358 a52161ea-4...
    63: synecologi...  1.196886552  7.4425341  23.5078726 ec81f500-2...
    64: encephalit...  0.197610987  2.3537422  30.5494400 b6184525-e...
    65: synecologi...  0.060789756 14.1679645  87.8819896 23b62afa-8...
    66: encephalit...  2.567443101  9.9322326  53.3018750 333346c2-d...
    67: synecologi...  1.331500542  2.1888928  15.9660761 c67cfb97-6...
    68: synecologi... -4.963647957  5.7492321 140.8351072 ceafe15c-d...
    69: encephalit...  2.763006707  6.7925374  18.7495794 a78f3c50-f...
    70: synecologi...  8.865819149  7.7702038  34.6501751 dbb5af65-d...
    71: encephalit... -3.779070541  1.6834518 150.5401372 1ce99f65-6...
    72: synecologi... -0.587567009 11.6712070  40.0016132 558f193a-5...
    73: encephalit...  7.204430754  6.6376783  44.9537705 44faad9e-9...
    74: encephalit... -3.013812659 13.1549818   1.8802976 d3f5bd23-2...
    75: synecologi... -1.819066737  6.7900559  14.0543078 afa9e95e-5...
    76: encephalit... -4.388217123 12.4749356  15.9220914 5bce0428-1...
    77: synecologi... -4.810795996  7.7238685  90.5555770 112350d3-4...
    78: encephalit...  6.615503624  6.5634915  48.6556477 c7872e10-b...
    79: synecologi...  9.635872004  7.8904455  27.9809495 7ceee500-2...
    80: synecologi...  6.828106410  1.9152713  18.7883618 ec6189a7-5...
    81: encephalit...  4.286625648 12.3630880 122.9265678 702bb29f-0...
    82: synecologi...  1.577271247  5.4413905  12.5957461 355567c6-4...
    83: encephalit...  3.499292773  3.9946148   4.9341457 4dbb6db1-e...
    84: encephalit... -2.954460718 13.3201707   2.7867244 fff71fea-5...
    85: synecologi...  0.962698499 11.8550522  68.3024267 91125af2-4...
    86: encephalit...  9.104715024  0.2674375   4.6912089 106a067c-e...
    87: synecologi... -0.118546586  2.0860204  36.3813769 e2fd6152-0...
    88: encephalit...  3.322687220  6.3271546  18.1038551 abaa5235-0...
    89: synecologi... -3.031092952  7.4516868  21.2439698 fde5ac46-9...
    90: encephalit... -4.477011710  8.1522807  64.9510666 226f3649-7...
    91: synecologi...  2.521058883 12.1961464  90.3126830 1831f4d7-2...
            worker_id           x1         x2           y          keys
               <char>        <num>      <num>       <num>        <char>

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
    1: synecologi...  9652 runnervm0k...     FALSE terminated
    2: encephalit...  9654 runnervm0k...     FALSE terminated

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

    [1] "gangrene_iguanodon"         "primatological_gardensnake"

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
    1: malodorous...  9943 runnervm0k...     FALSE running
    2: talkative_...  9945 runnervm0k...     FALSE running

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
    1: malodorous...  9943 runnervm0k...     FALSE running
    2: talkative_...  9945 runnervm0k...     FALSE running

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
