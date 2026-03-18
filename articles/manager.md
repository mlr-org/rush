# Rush Manager

The `Rush` manager class is responsible for starting, monitoring, and
stopping workers within the network. This vignette describes the three
mechanisms for starting workers: `mirai` daemons, local `processx`
processes, and portable R scripts. We advise reading the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) first. We use
the random search example from this vignette to demonstrate the manager.

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
    1: curt_ichid... 13962 runnervm46...     FALSE running
    2: tactical_a... 13964 runnervm46...     FALSE running

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
    1: tactical_a... 13964 runnervm46...     FALSE    running
    2: curt_ichid... 13962 runnervm46...     FALSE terminated

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

            worker_id          x1         x2           y          keys
               <char>       <num>      <num>       <num>        <char>
     1: firstgener... -0.85872641  7.3563796  16.2851896 8d162340-5...
     2: firstgener...  7.59857320 10.0563683  87.9589700 dcac217d-e...
     3: firstgener... -2.01367135  0.7937675  85.7178582 c7f99f6f-e...
     4: firstgener...  1.90861884  6.7257450  17.6601330 81ac4228-6...
     5: firstgener...  8.82339712 14.0109179 145.9979330 918f1fd8-a...
     6: firstgener...  2.17721593 10.1305634  53.2945259 673df14e-b...
     7: firstgener... -0.10379360 11.5829606  48.8875684 85bc3fe5-0...
     8: firstgener...  7.20524566  9.9576929  91.8138304 0b484cb3-3...
     9: firstgener...  8.15836290 14.4694429 172.3861970 5e07ea9a-1...
    10: firstgener...  6.01014576  8.7228915  77.3405583 aef13308-7...
    11: firstgener... -0.99647211 11.4545079  29.2063504 0be1155f-4...
    12: firstgener... -3.22218153 14.5495358   4.7555448 6bba2e0d-3...
    13: firstgener... -4.97730904 13.1691982  28.1387788 d4b9456a-e...
    14: firstgener... -0.95283321 11.1437906  27.8835038 f8f9f07b-a...
    15: firstgener...  6.51237695 10.7415246 112.0386859 c4da58ac-4...
    16: firstgener...  3.71246464 14.0475429 150.1667533 3737d6d0-3...
    17: firstgener...  9.95468086  0.5893560   7.3264591 c8cc78f9-b...
    18: firstgener...  1.39273868 14.2476628 116.0202405 0c920b42-1...
    19: firstgener...  3.24455299  2.2494353   0.4515849 dcfe7295-c...
    20: firstgener...  6.77040429  2.3413734  19.9132938 b0d5f2d2-2...
    21: firstgener... -0.30946607  5.6999855  19.7938682 e334157d-c...
    22: firstgener...  3.52175759  8.1206277  38.5798689 b85612dd-c...
    23: firstgener... -2.08136307  9.6781327   5.3453918 1066a046-e...
    24: firstgener...  5.70569251  2.6557376  20.3890510 f38862c1-b...
    25: firstgener... -2.56756814 13.5523173   8.7712928 58dc6b7b-b...
    26: firstgener... -0.07487345  0.2498168  54.0329579 6a7e5f90-4...
    27: firstgener... -4.67093793 10.1119876  47.3083870 21e70307-f...
    28: firstgener...  4.07661815  7.9765882  44.2133115 803277de-4...
    29: firstgener...  4.83543550  3.7909391  17.2609376 a1a51272-8...
    30: firstgener...  5.29860019  2.3110087  16.5599224 c5e65649-9...
    31: firstgener...  2.45414416  6.0923248  12.9482751 2469cf6c-6...
    32: firstgener...  8.60744611  8.2209149  43.7409917 48e34a80-4...
    33: firstgener... -4.01110811 14.7567811   3.8914519 61a22cff-6...
    34: firstgener...  0.24127153 14.7357815 102.3572144 18b4f007-a...
    35: firstgener... -0.77040855  6.5468331  17.4622410 6b2b5c58-9...
    36: firstgener...  8.81543818  6.1519040  19.2898815 d035b3bc-5...
    37: firstgener...  4.38691198  8.4775147  55.5571825 6c151b11-0...
    38: firstgener... -1.40095259  7.3686262  12.8653745 4d9502ae-7...
    39: firstgener... -4.35711127  7.8504966  63.4595466 eeb29ad7-d...
    40: firstgener... -4.23661635  2.4455720 164.7637916 777a9fbe-e...
    41: firstgener...  5.77108704 13.0777305 161.4155996 f0b15f2f-4...
    42: firstgener...  9.23010712 13.8260185 133.0669973 d7225f38-a...
    43: firstgener... -2.38787638  7.6647988  11.2483099 c732993b-0...
    44: firstgener... -3.09561234 11.9991875   0.4354539 8576ad6d-e...
    45: firstgener...  8.27303400  7.8989662  44.8326376 c9e8bffe-3...
    46: firstgener...  1.96166831  4.7161091   8.1401428 0cffeeab-d...
    47: firstgener...  1.20877610 13.3030406  95.0881734 e168365b-9...
    48: firstgener...  3.70683337 10.7688399  80.9835039 aea9adb2-8...
    49: firstgener... -1.33158107  6.9036920  14.3621215 886cad22-f...
    50: firstgener...  3.58505993 12.2145634 106.5942976 10c51bc7-c...
    51: firstgener...  8.77592536  5.4733697  14.5384457 55452d05-0...
    52: firstgener...  5.73410918 10.1643943  99.9651585 3c89f287-3...
    53: firstgener...  9.80425026  7.6630338  24.5970626 e695c173-3...
    54: overrated_...  4.54027582  2.5049362   9.4960928 2814dc2a-0...
    55: firstgener...  4.82736931  0.4314679  11.9044134 7a4831be-b...
    56: firstgener...  4.43230450  0.4038677   8.5115301 b4a30f94-3...
    57: firstgener...  4.80282591  7.3529552  47.0711707 37296c5e-a...
    58: firstgener...  5.52226513  6.2156587  42.6089203 c7edca47-9...
    59: firstgener... -4.62295184  2.5979088 191.9500120 1b8aba0c-4...
    60: firstgener... -0.44762681 12.6830141  53.9956504 d856cfb2-a...
    61: firstgener...  5.27614805  9.5452355  84.7914674 a693c70e-5...
    62: firstgener...  4.40774575  6.2102548  29.3564631 ec468f7a-5...
    63: firstgener...  9.98430560 11.9051543  81.3881849 f6bd0f2e-f...
    64: firstgener...  7.63611223  0.1157322  13.6726698 0c5c9c8e-5...
    65: firstgener... -0.07001229 14.2063943  85.0968167 96a9c31b-1...
    66: firstgener...  7.85636130  1.8224953  10.1015496 b3ec4361-f...
    67: firstgener... -3.46509280  7.8015027  28.6105558 626f880d-2...
    68: overrated_...  4.07673243  0.8178625   5.0061639 6280e603-b...
    69: firstgener... -2.49833968  7.4436814  13.4650059 c21b8ed4-e...
    70: overrated_... -3.06147753 12.6318605   0.7296121 a654ec41-f...
    71: firstgener... -3.65661933  4.0935870  91.0104764 b2e03c37-b...
    72: overrated_... -2.29816806 12.6599055   8.9976831 dc09b50b-e...
    73: firstgener...  9.44405374  4.6635963   5.1185096 62363662-e...
    74: overrated_... -0.45990693 14.3951228  76.9103514 d7bc1d71-3...
    75: firstgener... -2.26209192  8.9860389   5.5045383 c630226b-5...
    76: overrated_... -0.63352520  2.1142798  42.2002680 82512330-1...
            worker_id          x1         x2           y          keys
               <char>       <num>      <num>       <num>        <char>

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
    1: overrated_... 13964 runnervm46...     FALSE terminated
    2: firstgener... 13962 runnervm46...     FALSE terminated

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

    [1] "bridal_seriema"         "gimmicky_hypacrosaurus"

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
[`rush_plan()`](https://rush.mlr-org.com/reference/rush_plan.md)
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
> [`rush_plan()`](https://rush.mlr-org.com/reference/rush_plan.md)
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
    1: contractib... 14254 runnervm46...     FALSE running
    2: technocrat... 14256 runnervm46...     FALSE running

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
    1: contractib... 14254 runnervm46...     FALSE running
    2: technocrat... 14256 runnervm46...     FALSE running

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
