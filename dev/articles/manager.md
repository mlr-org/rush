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
    1: credible_g...  9096 runnervm35...     FALSE running
    2: nondespoti...  9098 runnervm35...     FALSE running

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
    1: nondespoti...  9098 runnervm35...     FALSE    running
    2: credible_g...  9096 runnervm35...     FALSE terminated

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
     1: demonic_au...  2.66925916  4.4709487   4.6848200 47c1d127-e...
     2: demonic_au...  1.48840481  3.2847008  11.1904436 3d117b79-5...
     3: demonic_au...  6.29095741  8.3767017  72.5484969 0d374b8e-6...
     4: demonic_au...  3.43783744 12.7037125 114.2046762 45733636-2...
     5: demonic_au... -1.71140748  4.6292913  28.6608358 4436064a-5...
     6: demonic_au...  8.08652553  6.8829097  35.9343728 db433c50-b...
     7: demonic_au...  3.47195560  8.9542857  48.8426052 d49636c5-a...
     8: demonic_au...  6.01652855  8.6930669  76.9068157 d743fcbc-3...
     9: demonic_au... -2.89464054  0.8992530 117.1163227 19660ce9-3...
    10: demonic_au...  1.00574448  9.3748505  38.6143043 1eb72c4c-b...
    11: demonic_au...  1.30675317  2.0834154  16.7389841 b8c87522-1...
    12: demonic_au...  8.85290556  5.3407231  12.8544075 3363a1c2-8...
    13: demonic_au...  1.41623953  9.5044844  41.7214588 0d319754-7...
    14: demonic_au... -1.26637618  5.6321178  19.5891223 81f21b5c-5...
    15: demonic_au...  7.18713488  2.1809442  16.8350873 5e232a49-a...
    16: demonic_au... -3.32973397  5.1646017  57.8286319 79f57906-3...
    17: demonic_au...  7.78989388  6.3412326  34.6249733 09c79dc5-d...
    18: demonic_au...  6.92281896  5.2701791  34.4890407 63b77338-4...
    19: demonic_au...  1.42329377 10.4036156  52.4629113 28ab6626-0...
    20: demonic_au...  5.37717678  5.2980707  32.9050250 fba1a7c7-4...
    21: demonic_au...  3.37278985 13.3242376 126.6008807 3e116308-d...
    22: demonic_au...  0.93163827  6.1153910  17.9360879 dada7ff6-a...
    23: demonic_au...  4.79117026  1.9884973  11.1761211 1ea66d7a-2...
    24: demonic_au...  7.43215503 13.5440023 163.6728207 56a56e00-8...
    25: demonic_au...  3.26877284  1.8686851   0.5710570 b27172b7-c...
    26: demonic_au...  1.24333038  0.3564132  28.0225778 cefdce06-a...
    27: demonic_au... -0.48616773 13.4093850  62.1167440 dd6f3add-e...
    28: demonic_au...  0.32156445  2.7118447  26.8925096 254af278-2...
    29: demonic_au...  5.74151850  2.1256681  19.2376139 cfe8b52c-7...
    30: demonic_au... -0.06421768 11.6741233  50.6226509 0bc76dee-8...
    31: demonic_au...  5.07252670  1.0894676  13.4098454 bf89b7ae-a...
    32: demonic_au...  6.01187953 14.3085854 193.6945541 79fe65ee-0...
    33: verbose_sw...  7.89153758  7.0334829  40.4210300 431c9acb-7...
    34: demonic_au...  3.87929140 10.1196302  72.6105685 47f6772c-5...
    35: verbose_sw...  9.75389150  6.5515944  15.2393700 063c4ef8-f...
    36: demonic_au... -0.36920359  2.7698695  33.6649501 98707857-0...
    37: verbose_sw...  2.44199837 12.7300984  99.6027433 ed4f4b90-4...
    38: demonic_au...  1.07426024 11.9998158  71.7349972 df928292-2...
    39: verbose_sw...  2.72637911  9.1260640  43.5285968 d84e2a38-6...
    40: demonic_au... -1.83221808  9.8450227   7.7635971 fe8d069b-5...
    41: verbose_sw...  5.44996992 12.0204428 134.3379185 39eaa708-a...
    42: demonic_au... -3.03469979  9.7736689   5.4968400 4981a298-d...
    43: verbose_sw... -1.58248657  3.4350783  39.1238262 69ca922e-0...
    44: demonic_au...  9.16886272 12.5599051 106.6423437 5ea2fedb-8...
    45: verbose_sw... -2.50530664  1.4649335  89.3859440 80600aea-e...
    46: demonic_au...  4.16506166  7.4637143  39.2437104 81f6135c-f...
    47: verbose_sw...  3.24179026  6.1010031  15.6782560 e2bc124c-3...
    48: demonic_au...  6.14833125 11.3775290 125.1824842 b565313c-d...
    49: verbose_sw... -3.93420380 13.7067714   3.5665923 e0cd8017-8...
    50: demonic_au...  1.20341079 11.7870639  69.9280932 f3343f0b-f...
    51: verbose_sw...  6.87481888 12.2624822 141.1452296 8f120155-b...
    52: demonic_au... -4.03264500  3.0388547 135.7574829 fe845419-7...
    53: demonic_au...  0.02127135  2.7651549  29.8466560 4395d2c7-b...
    54: verbose_sw...  0.32827476  4.8578319  19.4908391 eed7f6dc-2...
    55: demonic_au...  1.63059167  3.4808521   9.4977154 485bceee-d...
    56: verbose_sw... -3.52569793  0.5459235 161.6576994 03a767c8-6...
    57: demonic_au...  8.32110378 13.3381862 141.0910929 94297e2f-0...
    58: verbose_sw...  4.09329530  6.6569495  29.4993334 c7eb44b2-8...
    59: demonic_au... -4.04479050 10.5890352  19.7523625 be4ea1aa-3...
    60: verbose_sw...  7.86464713  7.1951890  42.6360851 1515f6bb-1...
    61: demonic_au...  4.56937094  6.9220163  38.8498749 93209fcb-1...
    62: verbose_sw...  4.20133469 13.9084506 156.9584049 7ad92368-a...
    63: demonic_au...  4.76191969  9.1688367  71.6011418 04b60eb1-6...
    64: verbose_sw... -1.19991259 14.6365042  56.2620563 549520b0-5...
    65: demonic_au... -0.84542299  0.5208789  64.2148914 207644fc-d...
    66: verbose_sw...  9.78838336  7.9142772  27.1938952 ef2f77ad-4...
    67: demonic_au...  0.83146768  9.2017686  36.1459735 395c4c58-7...
    68: verbose_sw...  6.48269883 10.4286448 106.2209544 8ca36218-b...
    69: demonic_au...  1.59916521 13.6998237 108.0270639 f5034e24-6...
    70: verbose_sw...  2.17983324  2.0338095   5.7405449 631fe3b8-0...
    71: demonic_au... -0.06425026  3.4255878  26.7497158 2822bbdb-2...
    72: verbose_sw...  5.77924199  9.2910210  85.2268637 5135f44f-b...
    73: demonic_au...  2.17078099 10.4975538  58.5083518 cac6f892-3...
    74: verbose_sw...  5.12874807  7.1920520  49.3648715 4e6a0ebc-6...
    75: demonic_au...  6.51860733  8.3658647  71.9173111 d387d21d-9...
    76: verbose_sw... -3.69127479  2.7043217 121.2932130 20f574fb-1...
    77: demonic_au...  7.29905427  8.3747243  65.5980680 ff8122a4-9...
    78: verbose_sw...  9.84739089  2.8260265   1.2434915 b48068c3-9...
    79: demonic_au... -3.26504278  8.6953741  15.5119787 84f1ecf2-b...
    80: verbose_sw... -3.27389266 13.2924899   0.9679987 99ee5e45-f...
    81: demonic_au...  8.31320424  1.6158839   5.7504274 f683e291-f...
    82: verbose_sw... -2.90442248  2.9784123  76.9472983 289aa84e-c...
    83: demonic_au... -2.73764967  8.8675653   7.2111766 abc762fd-d...
    84: verbose_sw...  0.49315832 11.5750950  58.5086484 54fdf32b-7...
    85: demonic_au... -0.17775568 13.0908424  65.7432367 06a98919-0...
    86: verbose_sw...  6.18841483 10.3554639 105.2570039 c644d57b-8...
    87: demonic_au...  3.97409080  5.4470781  17.4636533 0ffe0117-1...
    88: verbose_sw... -4.82560515  3.8498136 175.9151140 afd335a1-1...
    89: demonic_au...  9.57688476 11.7320493  83.7881593 8d4150d8-9...
    90: verbose_sw... -2.49641087  3.9630282  48.7752229 055179c7-b...
    91: demonic_au... -4.22690975  9.3464808  37.8836605 acda267e-9...
    92: verbose_sw...  2.82773571  5.3900868   9.0328125 5d7cdd71-4...
    93: demonic_au... -3.69453808 12.4924133   3.1534564 7d47b26b-a...
    94: verbose_sw... -3.28275008 13.3789745   1.0742877 4f1a6957-2...
    95: verbose_sw...  0.92696107 11.1206232  57.8180849 2b2722d6-2...
    96: demonic_au...  8.60594165  5.7878725  18.7836533 f951debc-b...
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
    1: verbose_sw...  9098 runnervm35...     FALSE terminated
    2: demonic_au...  9096 runnervm35...     FALSE terminated

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

    [1] "penniless_garpike"    "musicianly_beauceron"

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
    1: piggish_gr...  9386 runnervm35...     FALSE running
    2: ashamed_ge...  9388 runnervm35...     FALSE running

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
    1: piggish_gr...  9386 runnervm35...     FALSE running
    2: ashamed_ge...  9388 runnervm35...     FALSE running

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
