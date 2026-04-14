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
    1: maritime_g...  9121 runnervm35...     FALSE running
    2: sulky_plai...  9123 runnervm35...     FALSE running

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
    1: sulky_plai...  9123 runnervm35...     FALSE    running
    2: maritime_g...  9121 runnervm35...     FALSE terminated

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
     1: paraffin_a...  4.0812049  2.6916755   5.4058104 e40611e6-3...
     2: paraffin_a... -2.9299561  6.5392200  27.9959219 7519f754-4...
     3: paraffin_a...  1.3117152 14.4385742 118.6315670 27e0bb4b-9...
     4: paraffin_a...  9.6490228  0.7976611   4.1463948 26e3a680-b...
     5: paraffin_a...  6.7598640  6.0424129  42.5209932 0dd6837f-a...
     6: paraffin_a... -4.5445050  0.6338617 241.4746474 9ed6ddf6-3...
     7: paraffin_a...  4.5050380  8.1109690  52.3670090 0c4d0686-9...
     8: paraffin_a...  6.4206095 13.3868769 170.3115294 ed2d0bbe-f...
     9: paraffin_a...  1.5530303  5.7494846  13.8172641 5f666711-6...
    10: paraffin_a...  5.5007380  8.1205117  65.3394491 23100feb-6...
    11: paraffin_a...  0.5828338 11.1442279  54.3530851 576f1a16-c...
    12: paraffin_a...  0.9406427  2.4533456  20.3405977 3895ba28-8...
    13: paraffin_a...  1.5087155  2.1801111  13.5292244 fede028b-d...
    14: paraffin_a... -1.6613798  6.5954590  14.9167776 f4fa8fad-c...
    15: paraffin_a... -1.9892578  0.1886124  96.1315057 df863c23-3...
    16: paraffin_a...  5.0089060 11.6651780 120.8818700 f2314306-8...
    17: paraffin_a...  0.7377459  0.1111956  40.0012428 b3cc583e-f...
    18: paraffin_a... -1.3036559  5.6941299  19.2960345 c69d6fe1-f...
    19: paraffin_a...  4.6028893  1.3807443   8.9516023 2db135d1-b...
    20: paraffin_a...  6.1611639  4.0246915  28.0960099 a72fe2e6-f...
    21: paraffin_a...  7.9911033  6.6220706  34.6044898 9d6d206e-a...
    22: paraffin_a... -2.8028750  5.1572931  40.8670135 6ec01170-b...
    23: paraffin_a... -3.4236216 13.4534395   1.0177140 b42e9dbf-a...
    24: paraffin_a...  9.6231969  0.3736142   5.7566454 693e87f6-d...
    25: paraffin_a...  4.0694543  1.7254367   4.2470305 bf3e853c-4...
    26: paraffin_a... -4.0108447  5.6734406  81.0351344 0e8c1f92-d...
    27: paraffin_a...  9.3676518  3.0649973   0.8202923 5f5abfdb-7...
    28: paraffin_a...  5.9253363  7.6843412  62.2795697 82de3e72-5...
    29: paraffin_a...  5.3891564  8.1513473  64.6858175 69cde1ef-f...
    30: paraffin_a...  6.1315138  7.2073651  56.8144623 3a3b1113-3...
    31: paraffin_a... -1.5141990  3.0783295  42.2151514 38f43182-e...
    32: paraffin_a... -3.3131142  6.8185214  35.0248845 5527faff-e...
    33: paraffin_a... -2.1625905  7.4617588  11.3219586 4f439a8e-8...
    34: decontamin...  1.5337383  2.0453002  13.6593033 17737167-8...
    35: paraffin_a...  7.6255829 12.3286094 132.1441657 be1cc71f-c...
    36: decontamin...  2.0348858 12.7073335  94.2695471 10c2e1a7-a...
    37: paraffin_a... -2.5320452  1.6963729  86.0645770 67994b2c-e...
    38: decontamin...  0.6058242  1.9706189  27.5815054 4f3ce990-c...
    39: paraffin_a... -1.0052895 12.2764032  35.8102622 3637dbec-2...
    40: decontamin... -2.7168196  9.9136708   3.1111742 67ca5acd-a...
    41: paraffin_a...  7.0509570  0.6661787  17.1939317 3058cc5e-d...
    42: decontamin...  6.2576622  5.4874819  38.8553741 9c6d1be3-f...
    43: paraffin_a... -2.9852829 13.0267517   1.7788785 fb43c051-9...
    44: decontamin... -4.5152742  6.6844952  91.5780101 80f913b9-e...
    45: paraffin_a...  7.3726225  9.7289121  85.6945658 eb3db858-e...
    46: decontamin...  4.9593713  5.8577226  33.2641163 705741b0-4...
    47: paraffin_a...  8.3665498  9.9177033  72.3781063 fa200f51-e...
    48: decontamin... -0.5708004 10.5525909  31.0545979 3aa403da-e...
    49: paraffin_a... -0.8130932  3.1791574  34.2418465 1fcf4e0a-9...
    50: decontamin...  6.3659492  3.0337487  23.2950301 6f6e23a6-8...
    51: paraffin_a... -2.8482866  7.7046158  15.8360912 d9c99d47-a...
    52: decontamin...  3.6260312  4.3305486   7.2772705 e4da79fe-a...
    53: paraffin_a...  4.4836560  7.8265628  48.3424313 cb3c892d-d...
    54: decontamin...  3.4455527  3.8369667   4.0317050 2b24539f-9...
    55: paraffin_a...  3.7104925 13.9829676 148.5579961 418e0fc1-e...
    56: decontamin...  4.9213985 14.9308417 197.8952373 3037fe74-7...
    57: paraffin_a...  0.5680993  5.2139044  18.0996945 a1a35352-8...
    58: decontamin... -0.4780430 10.4545940  31.9523630 5c08b75b-a...
    59: paraffin_a...  0.2764758  6.2148351  19.6534631 08d9893d-b...
    60: decontamin...  8.3542261 13.6661283 148.1038785 069ec7a5-8...
    61: paraffin_a...  5.8697395  5.9074588  41.8190111 018fa54a-a...
    62: decontamin... -1.2082382 13.0812078  38.1029585 28d65b70-a...
    63: paraffin_a...  1.9836135  6.2819392  14.7364411 be7bed61-0...
    64: decontamin... -4.1261603  8.3713006  45.5849286 9f63f2c4-4...
    65: paraffin_a...  5.5557302  9.6635332  89.7333919 da71d2ab-4...
    66: decontamin...  1.8622750 12.3893944  86.5446011 48c3492b-4...
    67: paraffin_a... -1.6580349  6.8163797  13.9053438 568a9f47-6...
    68: decontamin...  8.5130679 12.6123100 120.7376129 befcfc25-c...
    69: paraffin_a...  4.1604535  8.8836048  57.8046325 ed7c45d7-5...
    70: decontamin...  4.4233090 12.1547536 121.0494890 193314d1-8...
    71: paraffin_a...  3.5275750  1.2507309   1.6556353 ff918010-1...
    72: decontamin... -1.4770547  6.4005414  15.8810918 c9b980cc-7...
    73: paraffin_a... -3.3138248 10.6359503   4.7703667 5670fb5d-1...
    74: decontamin... -0.2874693 12.9534366  61.2664144 9f76b770-1...
    75: paraffin_a...  6.3541260 11.3522587 124.6271453 4c6af419-a...
    76: decontamin...  7.6506270  4.1848563  19.7779029 af570918-a...
    77: paraffin_a...  7.9695333  6.3629919  32.3373377 2cfb7023-5...
    78: decontamin...  5.0719566  3.4819159  18.3558157 153b9387-f...
    79: paraffin_a...  8.1989091 10.8089994  90.9139346 85d513be-6...
    80: decontamin...  3.3681500 14.3758737 151.2188839 6e5b74fa-6...
    81: paraffin_a...  7.5333251  0.6280925  13.5357072 0835d485-a...
    82: decontamin...  7.6043478  9.1837826  73.4658169 4a594520-0...
    83: paraffin_a... -0.8296195 11.4097806  32.4868216 0542b7b8-8...
    84: decontamin... -3.8970277 10.6800153  15.1495633 b9580ca1-2...
    85: paraffin_a...  7.1226844  4.2045148  25.3333027 4f258392-d...
    86: decontamin...  9.0991559  4.5946331   6.5697396 3fbcf37f-d...
    87: paraffin_a... -2.0861714  7.8908543   9.2340250 2a496fdf-4...
    88: decontamin... -3.8518418  8.0680665  38.4681244 b3825a5d-3...
    89: paraffin_a...  2.2053622  5.4593989   9.7880544 086072d4-3...
    90: decontamin... -1.8939966  6.5181446  15.7099195 96467172-6...
    91: paraffin_a... -3.0148351  5.3710759  44.0530228 a87ed2a3-5...
    92: decontamin...  5.5728452  5.4926690  36.2030776 3e254f40-b...
    93: paraffin_a...  3.6432963 11.6960915  97.2263431 27c63d30-b...
    94: decontamin...  2.7757492  6.9169577  19.8633873 2e5d2775-3...
    95: paraffin_a... -2.9999436  8.4129698  12.9140825 49090896-d...
    96: decontamin... -4.2370212  3.1236603 148.1435859 2e2c87fc-f...
    97: paraffin_a...  5.7128522  5.6353483  38.4357663 624d74bb-e...
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
    1: decontamin...  9123 runnervm35...     FALSE terminated
    2: paraffin_a...  9121 runnervm35...     FALSE terminated

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

    [1] "paralyzing_snoutbutterfly" "fishable_ichthyosaurs"    

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
    1: falconifor...  9411 runnervm35...     FALSE running
    2: egotistica...  9413 runnervm35...     FALSE running

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
    1: falconifor...  9411 runnervm35...     FALSE running
    2: egotistica...  9413 runnervm35...     FALSE running

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
