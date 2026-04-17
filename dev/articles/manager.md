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
    1: climatolog...  9313 runnervmeo...     FALSE running
    2: antimonarc...  9315 runnervmeo...     FALSE running

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
    1: climatolog...  9313 runnervmeo...     FALSE    running
    2: antimonarc...  9315 runnervmeo...     FALSE terminated

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
     1: selenite_d...  5.36452453  7.7351092  58.7996964 4386a2c2-3...
     2: selenite_d...  8.15925567 11.3808531 102.4976451 a5248a6d-b...
     3: selenite_d... -1.58365004 10.1682380  11.6290078 6d64dfa6-b...
     4: selenite_d...  3.14993179 11.1802304  79.8170592 45cebef7-9...
     5: selenite_d...  6.93287786  4.4868934  28.6131248 7238a862-4...
     6: selenite_d...  2.94769027  0.5131572   4.2562368 666ecc02-b...
     7: selenite_d...  5.50214335 11.9930571 134.3055914 33a899a9-2...
     8: selenite_d...  9.99224055 12.0242879  83.4260877 054f7c24-3...
     9: selenite_d...  1.21394011  6.7195016  19.4116880 152a3efa-c...
    10: selenite_d... -3.28065314 11.3610316   2.0547358 71c04c8c-3...
    11: selenite_d...  5.27362554 13.6423332 169.9338919 186f5317-1...
    12: selenite_d...  1.83601021  9.7097096  45.8777436 07ee878a-3...
    13: selenite_d...  6.09716472 11.7430543 132.7419498 d327eddf-d...
    14: selenite_d...  7.30002808  1.1450577  15.0658388 d3b288b5-7...
    15: selenite_d...  0.79605455  4.6459380  16.7455306 f6598cd5-4...
    16: selenite_d...  2.57332016  3.3505991   2.2559694 86c3e199-4...
    17: selenite_d...  3.64396547  4.6978475   9.3239588 ceff9f5d-0...
    18: selenite_d... -2.48667294 11.1400637   2.5317307 c792acd7-1...
    19: selenite_d...  7.42828344  5.4948253  31.5128318 32cd8083-f...
    20: selenite_d...  0.50508399  0.3179918  42.5220206 a186ea39-7...
    21: selenite_d...  5.23657229  3.0342408  18.1403639 b1881237-5...
    22: selenite_d...  2.95769979  2.8611213   0.7519295 1083b1b0-0...
    23: selenite_d...  1.49042275 14.8936176 131.3035208 64c283bb-d...
    24: selenite_d...  4.78721635  2.0690089  11.2471189 719c74e5-9...
    25: selenite_d...  3.55480095  0.2856427   4.0593232 c6ed23cf-3...
    26: selenite_d... -1.46421895  2.5418102  47.8120868 3ca38993-1...
    27: selenite_d... -1.89397993  7.5488849  10.6710849 cc7c21ab-1...
    28: selenite_d...  6.83479660 10.6000896 107.3524113 658f48d7-e...
    29: selenite_d...  6.67374752 10.1111415  99.5015368 3f7f9a3d-b...
    30: selenite_d...  4.82372498  7.6976526  51.6302822 87d9e7e3-e...
    31: selenite_d... -2.16330422  0.7467407  91.1432715 3bdb4f07-f...
    32: selenite_d...  2.08848047  2.0012246   6.7816630 3241cffd-2...
    33: selenite_d...  7.36022940  4.1681152  22.8680710 489dc18c-e...
    34: selenite_d...  9.24095464  7.4935301  27.2805369 cd7a5fc3-9...
    35: selenite_d...  9.26791971  4.4092072   4.7731530 8d203ccd-d...
    36: selenite_d...  5.91194249 14.1454066 188.9744454 28e34aef-5...
    37: continenta...  6.88066203  2.5572594  19.8766332 b22ab63f-7...
    38: selenite_d...  5.91292583  2.9231725  22.2538013 23f7da28-d...
    39: continenta... -2.37673643 12.5750991   7.3268088 e3804b9c-2...
    40: selenite_d...  7.64161488 13.4405123 157.4405580 2756c83a-0...
    41: continenta...  5.03991351  7.8631181  56.6887287 1cb01058-c...
    42: selenite_d... -2.56191779  3.9262623  50.9531678 08f2384e-8...
    43: continenta...  6.38096539 11.1419518 120.3097451 f2e4c68a-7...
    44: selenite_d...  4.46085310  3.3177663  11.0206533 10d4da4c-4...
    45: continenta... -0.96211443  8.9326737  17.1334719 b241994e-6...
    46: selenite_d...  1.29799905 14.5243930 120.1773195 64097366-0...
    47: continenta...  0.55508464  7.8128031  25.2171037 339386ed-0...
    48: selenite_d...  7.64373767  4.7298435  23.2090464 350c2cac-c...
    49: continenta...  0.08867089  9.7239155  34.4950692 04576f09-3...
    50: selenite_d... -1.97825177  9.2004914   6.4006410 6c6c608f-a...
    51: continenta...  0.66311191  7.4956397  23.7883229 f574d570-8...
    52: selenite_d...  5.03750895 14.8328080 197.2663764 9a7aceac-5...
    53: selenite_d...  7.74755828  2.9038803  13.2110896 c121d9e9-0...
    54: continenta... -0.23161676  4.0049242  24.9656159 a6646075-8...
    55: continenta... -3.83894597 13.0627216   3.5439695 bc3e461f-4...
    56: selenite_d...  9.12481824  3.8500027   3.4393914 3ee94947-f...
    57: selenite_d... -0.55300019 12.1797715  45.8399993 713c18b4-8...
    58: continenta...  2.50022972  4.1725074   4.1128690 bb253fe6-2...
    59: selenite_d... -4.57954690  9.5018014  50.9270273 8da5ce23-8...
    60: continenta...  5.92650819 14.2085603 190.6989395 889f2e14-c...
    61: selenite_d... -2.12647908  4.1658762  38.6057729 35efb1c6-0...
    62: continenta... -3.75140955 14.2286254   2.3222831 069e2472-1...
    63: continenta...  8.29500634  1.3374262   6.0233151 73a011d1-9...
    64: selenite_d... -3.60412139  8.4664395  25.8871860 d336994a-5...
    65: continenta...  3.35603223  9.4550041  54.5124481 400cfdac-a...
    66: selenite_d...  5.84086559 12.8777562 157.1299786 8b4adfe3-4...
    67: continenta...  6.92547354  6.7063474  48.2984419 37082e4d-9...
    68: selenite_d... -3.57622173  3.1326331 105.5610341 d1281f2e-2...
    69: selenite_d...  8.83324122 11.9397148 100.4057761 1fceecae-5...
    70: continenta...  8.06335258  5.7203567  25.2625198 c528fa23-f...
    71: selenite_d...  3.83476773 12.5099955 117.3929868 8aa3a81b-8...
    72: continenta... -0.23634401  3.6583110  26.7611214 11b4e904-8...
    73: selenite_d... -4.34359049 10.5053263  30.0125906 929ac15b-3...
    74: continenta...  1.68546024  8.8404064  35.4848589 57e7d318-e...
    75: selenite_d...  6.03119975 13.4613725 172.0979059 7ddcc609-8...
    76: continenta... -4.49577923  8.6335784  58.8125485 8ff10d82-7...
    77: selenite_d...  8.21906366  2.3298839   7.0398280 eec65d9b-e...
    78: continenta... -3.68895198  0.3533900 178.0462669 6e75d724-0...
    79: selenite_d...  7.03593842  1.8084430  17.3813776 b4835fcc-2...
    80: continenta... -0.45639416 14.2935873  75.4755102 24a226f8-d...
    81: selenite_d... -1.14404138  5.1368981  22.1139969 a4f2c831-3...
    82: continenta... -1.00766033  7.1967069  15.4156625 b54543e2-1...
    83: selenite_d... -0.88834151 14.7784769  68.8027387 074bd680-4...
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
    1: selenite_d...  9315 runnervmeo...     FALSE terminated
    2: continenta...  9313 runnervmeo...     FALSE terminated

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

    [1] "sullen_bream" "daft_goat"   

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
    1: desperate_...  9603 runnervmeo...     FALSE running
    2: fascist_ar...  9605 runnervmeo...     FALSE running

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
    1: desperate_...  9603 runnervmeo...     FALSE running
    2: fascist_ar...  9605 runnervmeo...     FALSE running

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
