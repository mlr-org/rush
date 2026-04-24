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
    1: cryptic_xe...  8958 runnervmeo...     FALSE running
    2: proportion...  8956 runnervmeo...     FALSE running

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
    1: proportion...  8956 runnervmeo...     FALSE    running
    2: cryptic_xe...  8958 runnervmeo...     FALSE terminated

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

            worker_id         x1          x2           y          keys
               <char>      <num>       <num>       <num>        <char>
     1: privileged...  4.0650720  3.91823135   9.2865742 647d88e7-4...
     2: privileged...  2.1026921  1.40845611   8.4285906 dc36c9b3-6...
     3: privileged... -4.6078416  6.86633295  93.8247512 91b6b056-f...
     4: privileged... -3.7746694  9.91740912  17.7098710 ca27ccea-1...
     5: privileged... -3.5922725  0.85941821 158.2300799 9980d181-e...
     6: privileged...  5.0468749 12.69223054 143.8915393 f4697393-9...
     7: privileged...  2.1757444  9.86239905  49.6123495 7cc33f1a-f...
     8: privileged... -2.4338725  8.54989688   7.0677371 0112dd2c-0...
     9: privileged...  5.1294588 14.81995648 198.4344135 6ae3610d-d...
    10: privileged...  6.8935147  9.11973036  81.1057306 bb72342a-7...
    11: privileged...  2.5450535  9.49706730  47.0922187 f0086de6-4...
    12: privileged...  7.1516018  6.45886547  43.5959608 5e6bd708-6...
    13: privileged...  4.3865741  5.12060524  20.0040450 0f50a042-9...
    14: privileged...  6.6301821  8.44096071  72.5296836 8c4d9828-f...
    15: privileged... -2.3552145 12.84214075   8.8675872 3622f83a-f...
    16: privileged...  9.1846727  5.49417358  11.0048102 de2a656c-7...
    17: privileged...  5.6526318  0.12695871  18.7643245 f0e3cf6a-4...
    18: privileged...  4.1618370  1.60424385   4.9766721 e7dc0bbd-d...
    19: privileged...  9.5808777 14.67351322 146.0473001 3d9a7945-a...
    20: privileged...  7.2103067 10.61184999 103.5838240 d4d4a9e1-3...
    21: privileged...  6.3070830  1.32225471  19.6483978 210914f5-a...
    22: privileged...  3.5481612  7.81272766  35.2096428 4acaf084-5...
    23: privileged... -1.6116694 11.55314905  16.6436296 f21010db-c...
    24: privileged... -2.2445631 13.77866904  16.6504686 219de883-2...
    25: privileged...  9.0111027  3.82991624   4.0361224 04f90448-d...
    26: privileged...  9.0362171  4.02781353   4.5772508 dfca6a42-d...
    27: privileged... -4.0822328  0.58297250 202.2198300 4584d58d-5...
    28: privileged...  6.4884621 12.70069876 153.6989657 294cb146-0...
    29: privileged...  8.4798438 11.19518254  92.7709469 48bc54e1-e...
    30: privileged...  0.4262030  4.93267316  18.9132588 0b2cf3ae-c...
    31: privileged... -4.1745508 10.64229159  23.1689866 8775987d-8...
    32: privileged...  1.0817251  2.90639410  16.8311161 a3b5e487-6...
    33: privileged...  2.7059901  6.42261797  15.6086612 18749e52-d...
    34: privileged...  1.8907650 10.98047618  63.6488877 cb2caf33-5...
    35: theophagou... -0.0122885  9.01552766  28.5771065 4dd7cd2e-4...
    36: privileged... -4.7487868  1.94864624 221.2529904 da3542fc-3...
    37: theophagou... -1.9362376  5.48785686  23.1992773 d9011d12-4...
    38: privileged... -4.2871231  5.91127262  92.2726406 1159d318-9...
    39: theophagou...  2.2910862  0.55101111   9.8203500 f31b5246-f...
    40: privileged... -1.7460061  0.21338615  88.5951360 5b6f97c6-a...
    41: theophagou... -4.2065740 11.02062311  21.0315656 a5087aca-7...
    42: privileged...  7.6271206  2.46291532  13.3408611 e5af9ed9-f...
    43: theophagou...  2.3225540 10.74172418  63.3706669 2078f701-a...
    44: privileged...  9.1028627 13.92566318 137.9875596 48c8cf11-7...
    45: theophagou... -2.9422263 14.05580009   5.6721633 162af775-f...
    46: privileged...  3.5350757  4.48335754   7.3577980 ad65dde4-0...
    47: theophagou...  6.0847537  1.94941037  20.1372785 74982286-5...
    48: privileged...  1.2792423  5.98118328  16.0207930 f7ff73ed-c...
    49: theophagou...  7.5032248 10.18311424  91.6570700 4d90a46e-f...
    50: privileged... -1.5744882  6.92181609  13.5909462 255e756c-2...
    51: privileged...  8.2701592 11.91666805 111.0452555 7c85ea52-3...
    52: theophagou...  0.2237040  0.24163344  48.6179202 55d2f470-5...
    53: theophagou... -2.3544362  0.39825775 104.5276895 8b337989-9...
    54: privileged... -1.3232487  0.24242627  77.7974776 ac9ebafe-3...
    55: theophagou... -0.5388234  5.93180268  19.1695028 6ee173d0-a...
    56: privileged... -4.4442716  8.95703275  51.9163238 2ca8f6f3-6...
    57: theophagou...  1.9577407 11.58337069  73.6834717 1e9f8711-f...
    58: privileged...  6.2615717 11.24657910 122.5656744 a6f47802-4...
    59: theophagou...  2.1502078  1.28235928   8.3250410 ae85e80c-8...
    60: privileged... -4.2608063  4.85777409 111.2577036 c9d6cdda-e...
    61: theophagou...  3.9160149 12.08814016 110.0435924 a05bbb45-e...
    62: privileged...  3.8991807  6.77389033  28.1799318 8989ca67-4...
    63: theophagou...  9.8372690  1.99304686   1.9289617 850916df-8...
    64: privileged...  4.9495413  2.72012555  14.3088182 c705f407-5...
    65: privileged... -1.3577381 12.87407045  32.0561482 c7f68eb3-a...
    66: theophagou...  1.4131349 12.31938355  80.5717388 abe01073-c...
    67: theophagou...  8.9888172  5.60309780  13.3458559 a80cbb51-2...
    68: privileged...  3.2101350  5.24183261   9.5388961 bd2d3fef-5...
    69: privileged... -0.5648683  6.47229016  18.3294848 7ca72c3a-6...
    70: theophagou... -3.9135103  5.57389259  77.6512733 f69afef3-6...
    71: privileged...  4.8924715  8.70307687  66.4427121 c9f3dd8e-1...
    72: theophagou... -2.9902155  1.66263204 105.6016157 d0506c24-f...
    73: theophagou...  0.2211813 13.05624459  74.1569966 23315dad-c...
    74: privileged...  8.2826059  8.84406590  57.3318328 6e956aee-9...
    75: theophagou...  2.5636557  2.19018152   2.2922191 fd54334d-e...
    76: privileged... -0.1732350  3.11673584  29.4620306 7e32fe26-3...
    77: theophagou... -2.5758585 10.46488004   2.1358792 30ef5de7-b...
    78: privileged... -2.6297814  4.39358293  46.3209057 22eed3bf-4...
    79: theophagou... -3.2782965 12.47080863   0.5057318 ae4aa7f6-c...
    80: privileged...  5.9130841 10.62706065 109.6041877 254c2afd-5...
    81: theophagou...  9.7449849  4.22008820   3.0226473 7de0eb64-6...
    82: privileged...  6.8800029 11.27857578 120.2263582 c5773f8e-a...
    83: theophagou...  6.1154156 10.81947132 113.9685482 b2dbbcaf-b...
    84: privileged...  7.2146280 11.70261708 125.1595721 4e450b51-a...
    85: privileged...  8.1863182  7.71451566  43.9071899 7554e663-7...
    86: theophagou...  9.2006306  0.01612667   5.8195936 5271fbb7-b...
    87: privileged...  5.8952190  9.41918009  87.9792418 8a44eb2a-3...
    88: theophagou... -3.9678716  9.06416319  31.4223683 062e53e7-5...
    89: privileged... -1.5792312  9.22593976  10.0713678 d67cfbfe-3...
    90: theophagou... -1.7171457  5.72599420  20.0772085 932c9b5b-f...
    91: privileged... -1.3113376 13.79643027  42.5731337 46ff5c61-b...
    92: theophagou...  8.7366211 10.18655361  70.3300797 6bcf766a-4...
    93: privileged... -4.6405496  7.61624251  82.4367334 b01e2894-f...
    94: theophagou... -4.1641048  6.73143449  71.1892180 8b498066-1...
    95: privileged... -1.1466659  7.77570949  13.9995574 44bcd0c8-9...
    96: theophagou...  0.7812932  5.73867923  17.6334647 9c76b87c-4...
            worker_id         x1          x2           y          keys
               <char>      <num>       <num>       <num>        <char>

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
    1: theophagou...  8956 runnervmeo...     FALSE terminated
    2: privileged...  8958 runnervmeo...     FALSE terminated

``` r
rush$reset()
```

### Failed Workers

Failed workers started with `mirai` are automatically detected by the
manager. We simulate a worker crash by killing the worker process.

``` r
rush = rsh(network_id = "random-search-network")

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

    [1] "broadfaced_cougar" "avoided_alpaca"   

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
rush = rsh(network_id = "random-search-network")

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
    1: beryl_isla...  9226 runnervmeo...     FALSE running
    2: esthetical...  9228 runnervmeo...     FALSE running

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
    1: beryl_isla...  9226 runnervmeo...     FALSE running
    2: esthetical...  9228 runnervmeo...     FALSE running

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
