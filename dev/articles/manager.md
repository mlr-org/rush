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
    1: rectangula...  9595 runnervm46...     FALSE running
    2: nonpoisono...  9597 runnervm46...     FALSE running

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
    1: nonpoisono...  9597 runnervm46...     FALSE    running
    2: rectangula...  9595 runnervm46...     FALSE terminated

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

            worker_id         x1        x2           y          keys
               <char>      <num>     <num>       <num>        <char>
     1: ancient_mo...  0.6293474  6.916854  21.2493605 b3624b3d-b...
     2: ancient_mo...  6.3693454  7.470955  60.1084158 cc2d96e0-7...
     3: ancient_mo...  5.9298239  2.778894  21.8111573 7cb8daba-c...
     4: ancient_mo... -3.4113385 12.506804   0.9264693 3959ddcb-b...
     5: ancient_mo... -1.0057613  3.970340  29.2869503 02a721fb-b...
     6: ancient_mo...  6.1029696  1.409805  19.5435433 82eb6fd4-e...
     7: ancient_mo... -2.1116091  8.090696   8.4644321 662742ea-1...
     8: ancient_mo...  9.4418343  3.609296   1.6533946 d016092c-6...
     9: ancient_mo...  3.9858873 11.843701 106.3408567 6277e830-0...
    10: ancient_mo... -3.0712159 10.831872   2.0463526 96a2b4a7-3...
    11: ancient_mo... -3.6993812  2.893191 117.6847323 e89dd4e5-b...
    12: ancient_mo... -0.0982894 11.528435  48.4007705 ccfdc7c7-0...
    13: ancient_mo...  1.1315628  2.643353  17.0455163 6080307f-2...
    14: ancient_mo... -4.1579750 13.873703   5.9002452 8988c57d-7...
    15: ancient_mo... -3.6155397  7.789487  33.4188036 8e72168d-4...
    16: ancient_mo... -4.6755577  1.443868 229.3260958 9098e4d8-9...
    17: ancient_mo...  9.1444812 14.299697 145.9988273 5b714d5f-a...
    18: ancient_mo... -3.2660255  6.075281  42.7320189 207ab489-4...
    19: ancient_mo... -3.6934461 11.214026   7.7114347 16ca6c32-4...
    20: ancient_mo...  2.9360456  7.066183  21.9945964 a6f89fed-1...
    21: ancient_mo...  5.2087633 12.397950 139.6328757 d74c652f-2...
    22: ancient_mo... -4.5987703  3.184677 174.4601498 558d353a-8...
    23: ancient_mo... -3.3391181 12.884563   0.6014523 01a3bb5f-d...
    24: ancient_mo...  4.8947504  6.548457  39.2368790 8d51d9f4-9...
    25: ancient_mo... -1.0304241  6.220329  17.3635028 494f78bd-0...
    26: ancient_mo... -4.6136962  2.223027 201.4236887 86899f6e-f...
    27: ancient_mo... -1.5766160  3.283331  40.7138584 ac9c92d1-f...
    28: ancient_mo...  0.5973752  6.752581  20.6855900 31c18bee-9...
    29: ancient_mo...  7.0586483  4.543147  28.0176420 de11aa2d-6...
    30: ancient_mo...  6.4850000 14.181738 190.2335071 0034785b-3...
    31: ancient_mo...  9.2159960 14.971011 161.0464161 1d539414-3...
    32: ancient_mo... -2.6871680  7.549503  14.7685762 6b48f6c2-a...
    33: ancient_mo...  2.1108786 11.631498  75.8822249 50b9d344-4...
    34: ancient_mo... -2.7790110  8.187152  11.4774458 382e3167-f...
    35: ancient_mo...  4.9698943  2.781418  14.6965991 ac4289e8-0...
    36: ancient_mo...  9.9775928 14.133559 126.2123672 5906df47-8...
    37: ancient_mo...  0.2109519 14.806793 102.8700860 840233fa-6...
    38: ancient_mo...  7.6488529 11.852124 121.5290183 412ecc2d-1...
    39: ancient_mo... -2.2591840 13.757516  16.1678208 1a1c635e-1...
    40: ancient_mo...  6.8242439 12.865138 155.3569804 1db7ecde-4...
    41: ancient_mo... -1.8222107 14.092587  30.3021534 729c8911-2...
    42: ancient_mo...  3.6881189  2.870527   2.7631699 048d3afe-3...
    43: ancient_mo...  5.0837269 10.967152 107.9524174 32d5ce9c-2...
    44: ancient_mo... -4.4184842  6.646947  86.5593889 4202fbe0-d...
    45: sleepless_... -1.7670227  9.482267   8.1989572 821222a0-2...
    46: ancient_mo...  5.4521310 11.005898 113.3599574 faf69e80-a...
    47: sleepless_...  0.4136975 14.902717 109.7851304 751088a1-3...
    48: ancient_mo...  7.6395341  2.378172  13.0380893 eee75b8b-5...
    49: sleepless_... -2.5029262  4.641450  40.1299676 c1665c52-8...
    50: ancient_mo...  7.6868666  9.202676  72.4911891 c81900c6-d...
    51: sleepless_...  2.7505638  7.058468  21.0032897 62e07e88-2...
    52: ancient_mo... -1.5751368 14.383892  40.8326768 15cd730a-6...
    53: sleepless_...  4.5953267  2.624405  10.3428660 8ee86357-3...
    54: ancient_mo...  0.4385505  6.030531  19.1885837 d228d9fd-1...
    55: sleepless_...  2.4751526  6.868100  18.5806905 307b62db-4...
    56: ancient_mo...  9.6796426  3.429158   1.2421039 c5477bbf-7...
    57: sleepless_...  4.8884181 10.714431 100.1828865 986f0ef2-8...
    58: ancient_mo...  7.4329594  1.159776  13.9461084 0b2ae77b-e...
    59: sleepless_... -3.2493043  3.581893  80.6180199 c9a11eae-c...
    60: ancient_mo... -3.4999417  4.352264  78.4570556 6d9f3eca-8...
    61: sleepless_...  3.8478289 12.618879 119.9880811 0e10849a-e...
    62: ancient_mo...  3.4441192 11.196686  84.4794419 9c957f15-8...
    63: sleepless_... -4.8184812 13.769273  19.4207282 b09cfc3e-7...
    64: ancient_mo...  7.3786333 11.602544 120.7451929 b7660d5b-f...
    65: sleepless_...  0.4580589  2.960744  24.0754049 d254a7f1-f...
    66: ancient_mo... -0.3127648 13.813128  72.4658505 80caaeeb-f...
    67: sleepless_...  2.7828750 10.699379  67.0735734 9d075948-0...
    68: ancient_mo...  4.5743601 12.435801 129.9642259 e585ebe4-5...
    69: sleepless_... -4.9583907  9.843979  64.5191890 b48bbc92-9...
    70: ancient_mo...  1.9793642  9.342286  42.0222554 e78aeac5-6...
    71: sleepless_... -2.8640410 14.030546   6.5860915 1b4ad5b6-7...
    72: ancient_mo... -0.2106405  0.152415  57.6881737 b73f3c1e-9...
    73: sleepless_... -3.1562291  4.362000  63.5728354 2b0674d1-d...
    74: ancient_mo...  5.6974916  3.464280  23.4708055 04f91874-e...
    75: sleepless_...  5.4314071  2.173059  17.3373266 56546f98-3...
    76: ancient_mo...  7.3638415  4.743977  26.4828975 199581af-2...
    77: ancient_mo...  7.8887439  1.140788   9.7841532 254ac98d-a...
    78: sleepless_...  0.1665415  1.008270  41.8445624 094a2657-1...
    79: ancient_mo... -1.8290798  2.076171  60.3580267 6b48d8c7-d...
    80: sleepless_...  2.3686885  8.682957  35.9362859 84be6f14-3...
    81: ancient_mo... -1.3421799 14.957130  55.5813647 b6236020-a...
    82: sleepless_...  9.1303709 13.393701 125.2638466 9cc19ffc-8...
    83: ancient_mo... -2.1293256  5.414014  25.7108854 2f35a392-3...
    84: sleepless_...  8.5753424  6.102431  21.7274501 811d94ef-1...
            worker_id         x1        x2           y          keys
               <char>      <num>     <num>       <num>        <char>

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
    1: ancient_mo...  9595 runnervm46...     FALSE terminated
    2: sleepless_...  9597 runnervm46...     FALSE terminated

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

    [1] "offcolour_pintail"          "undelighted_indianelephant"

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
    1: amphitheat...  9887 runnervm46...     FALSE running
    2: halfpetrif...  9889 runnervm46...     FALSE running

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
    1: amphitheat...  9887 runnervm46...     FALSE running
    2: halfpetrif...  9889 runnervm46...     FALSE running

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
