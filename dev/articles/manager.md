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
    1: chewed_una... 16309 runnervm46...     FALSE running
    2: abhorrent_... 16311 runnervm46...     FALSE running

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
    1: abhorrent_... 16311 runnervm46...     FALSE    running
    2: chewed_una... 16309 runnervm46...     FALSE terminated

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
     1: underavera...  5.7981235  8.74985315  76.7861389 f88f5478-6...
     2: immediate_...  9.6087489  9.41484815  46.5322889 e4e4548b-7...
     3: underavera...  1.2885963 11.24091682  62.7616892 3e8f6291-3...
     4: immediate_...  1.6010201  0.80239148  18.5940472 72a9427e-1...
     5: underavera... -3.4877506  8.93779143  18.4782355 dec0b9ca-4...
     6: immediate_...  4.8431697 14.97807490 197.7393277 22c05d9d-9...
     7: underavera... -1.4623502 13.31265388  33.2138981 65feec76-c...
     8: immediate_... -3.8333865  3.08463935 121.7367603 4aae8171-e...
     9: underavera... -1.2252742  0.51849095  71.4009477 95d37ff4-6...
    10: immediate_...  2.0140209  2.13827887   7.2752344 8560340e-7...
    11: underavera...  4.1415133 13.79546845 152.9470340 06c14dbe-3...
    12: immediate_...  8.6825020  8.30849478  43.7360997 2d412ed3-2...
    13: underavera... -0.8300598  3.37066634  32.7967464 9c330ebf-2...
    14: immediate_...  4.8120483 14.74537226 190.8535503 897b595b-5...
    15: underavera...  7.0459144 14.69777408 199.1471101 6e02db68-1...
    16: immediate_...  9.5991158 11.92356535  86.9884578 e5056eb3-6...
    17: underavera...  1.3106146  5.37930037  14.0160140 ad3764fa-3...
    18: immediate_...  8.5987050  5.80571259  19.0106082 ca4cb611-a...
    19: underavera...  9.5133163  9.11902682  43.5784597 a704e9e5-6...
    20: immediate_...  0.2495928  7.23616106  21.9463439 714d8c63-7...
    21: underavera...  5.0184737  7.71054797  54.4207726 9b2a57b2-0...
    22: immediate_... -1.9322045 14.48818378  30.9164323 5051c30c-9...
    23: underavera... -3.8836154  9.77413858  21.8904444 6d5a96b6-1...
    24: immediate_... -2.5547328 13.42551948   8.3367095 58f1ecf1-3...
    25: underavera...  7.3253251  4.29014338  23.9433482 8e84bb32-e...
    26: immediate_... -4.6445789  7.54178653  83.9484107 f58bba4c-1...
    27: underavera...  2.8525934  4.91477396   6.5734114 8463714b-9...
    28: immediate_... -4.6226791 12.76616456  20.3731248 0b41efc1-8...
    29: underavera... -4.4640729  3.47102663 156.6789492 72efa8ae-8...
    30: immediate_...  0.9114469 11.81298248  67.0945831 228c870c-c...
    31: underavera...  3.6353958  3.34972995   3.5851043 6d2eef94-e...
    32: underavera...  6.2362761  3.06588991  23.4610277 873bbcbc-8...
    33: underavera...  5.6996825  7.73961046  61.7609653 e930d1f7-c...
    34: immediate_...  2.8254453  9.82308140  53.9977340 b3345bf6-d...
    35: underavera...  7.9448995  8.39951238  56.5989479 555e41a6-a...
    36: immediate_...  2.5869911 14.40986046 137.8537194 41a36075-1...
    37: underavera... -2.8873228  8.54521456  10.4851657 ab6f5c0a-a...
    38: immediate_...  8.1818549  7.16771173  37.6168489 841fb7db-c...
    39: underavera...  0.2082733  0.01121942  51.4631209 e6d04f5c-a...
    40: immediate_... -4.8859784  3.60319114 187.4086124 205df3d0-9...
    41: underavera... -0.2310690  0.03925663  59.4841852 77ae794d-6...
    42: immediate_...  0.9973732 14.72968506 119.0157424 0f3a4a86-8...
    43: immediate_...  1.9882478  9.96370805  49.8972381 7571f2fb-e...
    44: underavera...  9.0209947 13.33312337 126.1101774 47e23c77-a...
    45: immediate_...  5.0360278  2.91433287  15.7863808 0bab40ba-5...
    46: underavera...  4.7508131  5.21718607  25.2886678 f37d93e3-1...
    47: immediate_...  6.8117470 10.25001579 101.0489704 6c1bb8d1-e...
    48: underavera...  5.6490553  0.68357596  17.9362127 037f868e-5...
    49: immediate_... -4.4103283  9.82560528  39.7066850 56459c9b-2...
    50: underavera... -2.4600521  3.71209349  51.3332937 da4ec491-a...
    51: immediate_...  8.1291715 11.50011647 105.4233823 44c099bf-1...
    52: underavera... -3.9902288 13.44286392   4.5834821 a22f85b0-5...
    53: immediate_... -2.4918102  1.08489017  96.1165096 d4d4d65a-8...
    54: underavera...  3.8316001 13.55532303 140.8197547 3eea4517-3...
    55: immediate_...  9.5728406  4.43206571   3.8494302 f4d5ed6c-c...
    56: underavera... -0.1608794  5.21979908  20.5588702 e1105c70-2...
    57: immediate_... -4.5468232  3.66564415 158.2732343 7a9ef508-5...
    58: underavera... -0.9729404  2.76233794  39.4974668 9e01f952-7...
    59: immediate_...  3.0270723 10.02930553  59.1869741 3da8ea85-e...
    60: underavera...  6.5802112  5.45314247  37.9503892 5c9bc79e-0...
    61: immediate_...  9.1261116  5.10876684   9.0838559 1bab6d85-6...
    62: underavera... -0.1816405  5.59180618  19.9363117 4c780583-6...
    63: immediate_... -2.5626627 10.19841523   2.4933865 0a220e5b-6...
    64: underavera... -2.4584318 12.83711813   7.1479122 95682934-5...
    65: immediate_...  8.6431863  2.64657396   3.7499083 ef224f3f-b...
    66: underavera... -4.3421721  2.74285561 165.3772694 a5c107fd-6...
    67: immediate_... -4.7028740  4.02422068 161.6371485 1c843106-1...
    68: immediate_... -2.3369320 13.99256614  16.0709048 858489b8-9...
    69: underavera...  9.9010731  3.46025947   1.7737303 c27fb148-8...
    70: underavera...  1.2315621  7.50401738  23.8761784 de1c002b-9...
    71: immediate_... -1.6660885 10.50335458  11.3157125 936f45ae-7...
    72: underavera...  8.1446363  2.28044045   7.7019207 eb18e20e-6...
    73: immediate_...  7.6773695  9.86409276  83.4044386 d2fc2edc-f...
    74: immediate_...  7.0029557 10.74251496 108.4740223 6c2d668a-9...
    75: underavera... -3.4199636 13.18540789   0.8210752 9d87cffb-e...
    76: immediate_...  8.7675591  9.72641018  62.4603869 0b48d18c-0...
    77: underavera...  5.6750311  1.71683700  18.2267257 f4d40208-4...
    78: immediate_... -1.4104438 13.65126914  38.0503257 5ae899f2-3...
    79: underavera...  7.5431190 12.99510755 148.6579840 284d70bc-1...
    80: immediate_...  4.6228921  3.22362639  12.4555297 3338a13f-9...
    81: underavera...  0.9365452  6.18849617  18.1415218 d48fcba8-b...
    82: underavera... -3.3368664 10.67475593   4.8837627 a49d72bd-5...
    83: immediate_...  1.8471747  6.28978155  15.1576183 bcde811d-7...
    84: immediate_...  3.2802145  2.23458555   0.4942491 0a227a25-3...
    85: underavera...  4.6796764 11.58460969 113.7970833 5debe172-9...
    86: immediate_... -4.8654687  4.12563880 172.1489897 12ee60d9-5...
    87: underavera...  8.0790332  4.27897367  15.1752289 cc33b312-1...
    88: immediate_...  8.5768179 11.29309560  92.7707195 29331fc6-1...
    89: underavera...  5.1231859  9.50470241  82.1909566 8cbe8aa5-7...
    90: underavera... -3.7223580  2.06827563 137.6018904 4c45b8cf-9...
    91: immediate_... -0.1681459  4.17178594  23.8745040 bec79572-1...
    92: immediate_...  8.3391654  3.70473065   9.4947673 f96a6b73-d...
    93: underavera... -0.8645799  1.21280749  55.4162231 2e721075-3...
    94: underavera...  0.4156948 10.44492768  44.6334796 5d940c14-8...
    95: immediate_...  7.4698239 13.87563383 171.2506897 19691e75-4...
    96: underavera...  6.0061954  7.65724333  62.2191944 35535fc9-2...
    97: immediate_... -4.4610374  6.12787643  98.6800528 0beca948-7...
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
    1: immediate_... 16311 runnervm46...     FALSE terminated
    2: underavera... 16309 runnervm46...     FALSE terminated

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

    [1] "fluidic_neondwarfgourami"  "unacknowledged_xiaosaurus"

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
    1: blameable_... 16601 runnervm46...     FALSE running
    2: shrinkable... 16603 runnervm46...     FALSE running

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
    1: blameable_... 16601 runnervm46...     FALSE running
    2: shrinkable... 16603 runnervm46...     FALSE running

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
