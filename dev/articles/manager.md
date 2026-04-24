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
    1: peculiar_y...  9736 runnervmeo...     FALSE running
    2: pancreatic...  9734 runnervmeo...     FALSE running

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
    1: peculiar_y...  9736 runnervmeo...     FALSE    running
    2: pancreatic...  9734 runnervmeo...     FALSE terminated

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
     1: prickly_au...  3.49237609  4.1534415   5.5455734 f5f21e72-1...
     2: prickly_au... -2.77445172  4.4813262  49.0455012 5ca2c55d-b...
     3: prickly_au...  1.28322024  2.6226526  15.1189993 9b75c80b-e...
     4: prickly_au...  4.25773369  6.8255785  33.4516182 3809cf60-1...
     5: prickly_au...  1.84206579  3.6551535   7.4491337 6d8d7371-6...
     6: prickly_au... -4.61852385 13.3588615  16.6479602 5c6bb0e2-4...
     7: prickly_au...  1.54692263 13.5665175 104.6956950 59934088-a...
     8: fairish_as...  5.94306274  9.4393826  88.5286781 57c03e4c-d...
     9: prickly_au... -0.27716306  3.5159870  27.8502048 c78f175a-2...
    10: fairish_as...  4.05611499 10.3085988  78.7691568 c53fd82c-e...
    11: prickly_au...  8.71318882 11.9548451 103.0217325 efb5812b-a...
    12: fairish_as...  0.99896094  4.1881338  15.3195577 25633262-4...
    13: prickly_au...  7.01499005  8.1173147  65.0970535 447a8940-f...
    14: fairish_as... -0.62164949  2.1363942  41.8443131 d7b8db5b-a...
    15: prickly_au... -0.58402229 13.5583408  61.3698787 967a4b44-3...
    16: fairish_as...  2.98283078  1.1754370   2.0232692 ab47a6ab-f...
    17: prickly_au... -0.05224099 14.6976413  93.7925011 386767dd-8...
    18: fairish_as... -0.71596897  9.0681707  20.7131040 b6547895-b...
    19: prickly_au...  5.61290149  4.7118972  30.3066555 07392572-a...
    20: fairish_as...  7.24924319  1.4770655  15.5102153 6ecee019-2...
    21: prickly_au...  4.54666266  5.6993961  26.6071496 142e3c15-1...
    22: fairish_as...  1.59343107 12.7517786  90.0607029 933d77d2-4...
    23: prickly_au...  7.56782298 11.2705089 111.0458692 553d4ef9-4...
    24: fairish_as...  1.36357368  1.2043679  20.1874251 20f76ed4-6...
    25: fairish_as...  2.24840541 10.6325988  61.1031465 343aa898-6...
    26: prickly_au...  4.36140887 11.9031330 114.5924916 91849b9a-e...
    27: fairish_as...  1.77109199  7.1763995  20.9773730 0c57044b-e...
    28: prickly_au... -3.98590630  9.9361774  23.5134660 dd3d30be-2...
    29: prickly_au...  2.80812163 11.7590759  85.7444983 0899196a-6...
    30: fairish_as... -3.54480056  6.7676571  43.3834724 fd979c65-2...
    31: fairish_as... -2.18879465  1.4746698  78.8755101 bf502c26-3...
    32: prickly_au...  1.87495215 13.0142109  98.2150608 db7d975b-d...
    33: fairish_as...  2.32655521  6.8089091  17.9494733 57fef6b4-3...
    34: prickly_au... -1.50595993  6.0441222  17.6216844 6d0d4aee-a...
    35: fairish_as...  0.57256602  8.0577581  26.6361286 21ab3dee-b...
    36: prickly_au...  9.52550406  2.4441186   0.4602822 8fa10697-4...
    37: fairish_as... -1.11879578  8.3123404  14.3307923 552ca5f2-a...
    38: prickly_au... -0.68294508 14.5905001  72.8513274 5f519029-7...
    39: fairish_as...  6.83286348  7.4858857  58.2484030 b74f66c8-a...
    40: prickly_au...  9.06888689 11.1461314  81.1910910 5beecdf4-a...
    41: fairish_as...  9.81713254  3.0844695   1.1944252 9c3552bd-b...
    42: prickly_au... -3.98462467  2.2758491 150.4336329 b6dcab21-a...
    43: fairish_as...  5.18163127  9.0326757  75.3536488 d6dc46db-2...
    44: prickly_au... -2.21772467 13.9477153  18.5214734 a24a63ea-7...
    45: fairish_as...  4.75378831  9.2243623  72.3480781 441f9d3e-a...
    46: prickly_au...  7.88730857 11.2398336 104.8664875 4ca8446e-c...
    47: fairish_as...  3.57474422  5.8892254  16.7121625 8d765a9f-e...
    48: prickly_au...  8.97659140  7.3735847  28.9159921 eadb703b-4...
    49: fairish_as...  0.79177088  6.0854963  18.3456593 30e0dd7e-c...
    50: prickly_au... -1.06999875  0.9456166  62.2925884 9d56132a-e...
    51: fairish_as...  8.71344572 14.7551781 166.9464750 b0448365-8...
    52: prickly_au... -1.12972568  6.3122592  16.8237991 c0e6e918-6...
    53: prickly_au...  7.30914817  2.1368058  15.7302585 e0e20646-a...
    54: prickly_au...  4.99756417  9.8941640  87.0327474 d1f63186-1...
    55: fairish_as... -4.08096655 10.2070836  24.0406732 4633f676-c...
    56: fairish_as... -0.38993069  4.4492061  23.6819458 527bd7da-c...
    57: prickly_au...  8.70699003 12.0748176 105.5609054 37d6c82f-a...
    58: fairish_as...  2.94713465  9.4969414  50.4988329 884cae0e-1...
    59: prickly_au... -4.66393555  5.7337167 119.7686898 f1e15c69-0...
    60: fairish_as...  3.95019363 11.1831407  92.7528597 fe454e2f-0...
    61: prickly_au... -0.29958060 10.5455044  35.6346037 4f868fda-5...
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
    1: prickly_au...  9736 runnervmeo...     FALSE terminated
    2: fairish_as...  9734 runnervmeo...     FALSE terminated

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

    [1] "demagnetisable_lemur" "rancour_parakeet"    

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
    1: couped_sna... 10025 runnervmeo...     FALSE running
    2: undergroun... 10027 runnervmeo...     FALSE running

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
    1: couped_sna... 10025 runnervmeo...     FALSE running
    2: undergroun... 10027 runnervmeo...     FALSE running

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
