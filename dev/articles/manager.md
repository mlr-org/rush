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
    1: unethical_...  9688 runnervm35...     FALSE running
    2: submetalli...  9690 runnervm35...     FALSE running

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
    1: submetalli...  9690 runnervm35...     FALSE    running
    2: unethical_...  9688 runnervm35...     FALSE terminated

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

            worker_id          x1           x2           y          keys
               <char>       <num>        <num>       <num>        <char>
     1: censorial_...  5.69184616 11.750905023 130.8527818 c14048a6-c...
     2: censorial_...  2.27549163  1.517023235   6.1216108 f263b968-0...
     3: censorial_...  1.53301910  6.309531971  16.3446169 d5a0db3f-6...
     4: censorial_...  7.80523243  0.500428834  11.3652717 d7b5e770-b...
     5: censorial_...  6.30085443  6.382081523  47.4946318 475286cb-1...
     6: censorial_... -4.12392376 12.177515847  11.3414915 a2e7763a-0...
     7: censorial_...  7.82360238  5.200989858  24.3198080 56cd3570-3...
     8: censorial_...  4.90714085  8.655331931  65.9472265 b9b04132-5...
     9: censorial_... -0.27410366 11.556694268  45.3632991 8f454a78-1...
    10: censorial_... -2.15338487 12.877842184  12.8485854 b23f37f4-5...
    11: censorial_...  9.00050485  5.796819531  14.6188450 1b44bf77-b...
    12: censorial_... -2.67143139 13.178691373   5.4599682 499c6c62-3...
    13: censorial_...  1.03621263  1.179541774  25.8481109 795bf8cc-4...
    14: censorial_... -0.30740342  1.296144454  46.2472500 60661951-0...
    15: censorial_... -3.93213724  9.879638404  22.3943825 ab8280c6-1...
    16: censorial_...  6.09684913  5.448136599  38.3547634 c5b79875-9...
    17: censorial_...  8.60810123  9.270254554  58.1560138 a226501e-0...
    18: censorial_...  0.20441096  8.391903136  26.7562552 e92e07de-2...
    19: censorial_... -4.97623826  7.615697238 102.8154283 22fdadea-b...
    20: censorial_...  8.17927775  0.800693692   7.6104085 35a9461e-0...
    21: censorial_...  3.86497329  6.155917868  21.9646199 463fceac-0...
    22: censorial_... -4.68182278  7.608485323  84.9538830 78e589e0-7...
    23: censorial_... -3.32939453 10.186653489   7.0398567 73ab26ab-f...
    24: censorial_...  4.26302722 10.736080639  89.9761126 959ccc73-4...
    25: censorial_...  1.01232408 12.708426409  82.1183503 9d4ddbdb-c...
    26: censorial_...  1.47554387  7.793304554  25.8162487 5e663eb6-5...
    27: censorial_...  2.68516707  9.677620104  50.6578531 e4b67852-6...
    28: censorial_...  1.60728420  6.293145290  15.9874585 d5880716-1...
    29: censorial_...  4.93271906  7.147830172  46.3821061 2e80e3cb-6...
    30: censorial_...  2.23884616 12.707733344  96.6624915 830bb23e-a...
    31: censorial_...  7.05883453  1.744437962  17.1493809 b98aae02-2...
    32: censorial_... -2.05599368  0.864708511  85.6884085 cc078a1e-3...
    33: censorial_...  5.29091164  1.986387983  15.8756445 fc3f1785-8...
    34: rabid_berg... -0.08510687 11.212754051  45.3368560 62cfc5e5-a...
    35: censorial_... -0.38641429 11.865957236  46.2644899 7079ba1c-1...
    36: rabid_berg...  1.08578669 10.282249410  48.7932148 9d356167-1...
    37: censorial_...  0.98057714 13.083140868  87.9269416 9ae4a26f-e...
    38: rabid_berg...  4.30557437  3.518570812  10.1062879 fb48e068-b...
    39: censorial_... -4.64538524  9.063693230  60.0147367 59cea7f4-2...
    40: rabid_berg... -4.73090195  9.273576822  61.2605353 ed054db5-c...
    41: censorial_... -3.50408832  0.272800947 167.1827035 180aa357-2...
    42: rabid_berg...  9.96399553 11.383480679  72.5906953 0da218ba-6...
    43: censorial_... -2.15456857  3.650217517  45.3938445 736a88ee-3...
    44: rabid_berg...  9.76038115  5.558679801   8.6955984 05578507-e...
    45: censorial_...  4.98743072 11.434305532 115.8060302 97ba3919-b...
    46: rabid_berg...  3.06671397  6.309653285  16.2296651 9a6aca0c-6...
    47: censorial_... -1.37184203  9.017168095  12.2467238 6e23097c-c...
    48: rabid_berg... -0.43984063  1.800731281  42.9367996 3f41fb80-3...
    49: censorial_... -3.81870639  8.479978649  32.5632904 d99ac642-8...
    50: rabid_berg... -0.93509008  0.300018623  69.0084675 39992c25-5...
    51: censorial_... -1.92447522 11.112894067   9.1440594 99243643-3...
    52: rabid_berg... -4.39627457  4.178141174 135.0560605 8ed18620-e...
    53: censorial_...  7.26855013  0.940376634  15.4058558 a6b06bbf-6...
    54: censorial_...  9.48761452  1.786785215   0.9669994 292e7d2f-0...
    55: rabid_berg...  2.69505064  3.366142944   1.8537097 cc7e62aa-a...
    56: censorial_...  2.76926417  2.721906413   1.0750166 9b8ad0ce-0...
    57: rabid_berg...  3.60841233  9.731239986  62.1427455 ebc617f6-7...
    58: censorial_... -4.62697610  0.009973826 269.0283729 22dbee2c-a...
    59: rabid_berg...  8.64015086  4.174848504   8.4133339 7676e15b-8...
    60: censorial_... -0.68787653  6.323631852  18.1112506 58efb5d4-2...
    61: rabid_berg...  8.26279363  9.555873499  68.3815274 f75acf1a-5...
    62: censorial_...  0.99049625 14.718639935 118.6593896 51dfd4ea-c...
    63: rabid_berg...  5.02810477 11.283925461 113.3894615 a78ec03d-3...
    64: censorial_...  7.49561629  3.964202382  20.3148481 11a4901a-2...
    65: rabid_berg...  7.56821516 13.443391986 158.8546928 ddb5f23c-4...
    66: censorial_... -3.72288802  7.650571877  38.7601152 3f80f188-e...
    67: rabid_berg...  5.22134963 10.745876643 105.5763775 6a717687-9...
    68: censorial_...  0.69078251  7.674894712  24.7593569 17c6fd44-2...
    69: rabid_berg... -3.58993096  9.740901265  14.5785028 aecd03ce-f...
    70: rabid_berg...  8.48717224 14.300224612 160.6319516 28d39972-a...
    71: censorial_...  9.65406073 12.120269289  89.8585839 94256405-c...
    72: rabid_berg...  8.89015424 12.158195510 103.6919796 92e122ae-b...
    73: censorial_... -3.03475824  1.806590699 104.7607602 0440f6b2-c...
    74: censorial_...  7.92699598  9.096546000  66.9858445 5599b10d-6...
    75: rabid_berg... -3.14358693 13.703478280   2.4247856 7a944a4f-f...
    76: censorial_... -0.27438153  4.721635686  22.2177982 32687638-8...
    77: rabid_berg...  2.31707496  3.938557190   4.3509964 81ee2935-3...
    78: censorial_...  7.36142305  5.689910792  33.9482137 8d13bdcd-d...
    79: rabid_berg...  3.81471605  6.157171033  21.4024618 07a2a32a-a...
    80: rabid_berg... -3.47378699  7.304932379  34.3620719 09ab189c-d...
    81: censorial_...  8.92788520 13.410036763 129.7531228 2e3b8db7-a...
    82: rabid_berg...  2.08312286  1.123971444   9.7925527 a7a1668b-f...
    83: censorial_...  7.87731582  0.317447443  11.1252442 2f87a6c5-6...
    84: censorial_...  6.71996371  8.798200636  77.3709321 ac15bfe3-e...
    85: rabid_berg... -4.64607969  2.641362767 192.7410396 937f5864-6...
    86: censorial_...  4.59941758  1.335538112   8.9234883 09ea02d7-d...
    87: rabid_berg... -0.71590522 10.686139955  29.3588898 209cec1a-2...
    88: rabid_berg...  3.27253669  4.420146277   5.5203360 899eb576-3...
    89: censorial_...  9.73411368  6.542469035  15.2494159 3d6ce076-e...
    90: rabid_berg... -1.90701506  1.009598990  79.0024637 1d906896-6...
    91: censorial_...  6.30283411 14.812564648 207.6161682 fbaa1671-4...
    92: rabid_berg... -3.75754760  3.758564664 103.0793418 ce4fa5dc-3...
    93: censorial_... -2.48534116 11.778757652   3.4435321 8855c23c-8...
    94: rabid_berg...  8.27261650  9.888651761  73.5669823 da0a6ee4-8...
            worker_id          x1           x2           y          keys
               <char>       <num>        <num>       <num>        <char>

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
    1: censorial_...  9688 runnervm35...     FALSE terminated
    2: rabid_berg...  9690 runnervm35...     FALSE terminated

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

    [1] "stable_akitainu"       "stoppable_ghostshrimp"

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
    1: uncontradi...  9978 runnervm35...     FALSE running
    2: ruinable_g...  9980 runnervm35...     FALSE running

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
    1: uncontradi...  9978 runnervm35...     FALSE running
    2: ruinable_g...  9980 runnervm35...     FALSE running

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
