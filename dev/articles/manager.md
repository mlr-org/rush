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
    1: added_mang...  9931 runnervmeo...     FALSE running
    2: rutherford...  9929 runnervmeo...     FALSE running

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
    1: rutherford...  9929 runnervmeo...     FALSE    running
    2: added_mang...  9931 runnervmeo...     FALSE terminated

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

            worker_id          x1         x2          y          keys
               <char>       <num>      <num>      <num>        <char>
     1: contentiou...  6.28086276  3.5893677  25.799403 4d966419-e...
     2: contentiou... -3.76957324  7.8846927  37.637561 b4c80567-d...
     3: contentiou... -0.48943807  8.4564296  21.185821 c7407927-c...
     4: contentiou...  2.58881714 11.3228188  75.397280 8549a9a2-0...
     5: contentiou... -2.81760663  0.8194158 115.184841 69347ce8-b...
     6: contentiou...  9.02548076  9.4162106  53.823522 629a12c5-0...
     7: contentiou...  0.17350100  7.9031191  24.190166 e38ed41e-2...
     8: contentiou... -2.92821778  9.2426456   6.993518 157639ed-5...
     9: contentiou...  4.92174329  4.9681900  25.479759 63f52ca8-6...
    10: contentiou... -0.80104110  6.7324405  17.073743 fca7b314-0...
    11: contentiou...  4.08777840  5.6944916  20.720433 dc5b3840-d...
    12: contentiou... -2.50260191 11.0194952   2.344112 95b5a4c2-1...
    13: contentiou... -2.22259579  0.1373436 104.940448 d23e2cbe-9...
    14: contentiou...  9.34481196  6.4871110  17.064674 3ebf4045-2...
    15: contentiou... -2.34839730  1.9624380  75.302799 c9020ead-3...
    16: contentiou... -0.98345783 12.9505702  42.992822 8aa6710a-d...
    17: contentiou...  6.38052498  1.3911484  19.638928 30734c44-e...
    18: contentiou... -3.28753682  6.0101808  44.301989 b95b117b-2...
    19: contentiou...  4.02308830  8.7302212  53.486827 a13aa121-2...
    20: contentiou...  0.40113409  2.5563269  26.826361 08a19f7c-e...
    21: contentiou...  2.29570205  0.8971656   8.169844 68de4b24-0...
    22: contentiou...  3.77347571  3.9320758   6.654655 bb41ffb9-f...
    23: contentiou...  8.08781088  3.2981837  10.733649 bf1b53fb-9...
    24: contentiou...  3.86632238  7.6856268  37.715118 3b26bcd1-7...
    25: contentiou...  7.88080021  9.4529048  73.300466 39fefed7-4...
    26: contentiou... -4.88098048  7.0672220 107.235865 61403271-2...
    27: contentiou...  9.24301648  6.9634496  22.062484 26486dab-3...
    28: contentiou... -1.06260938 12.8752225  40.055387 04c57518-a...
    29: contentiou...  6.56869413  7.9023754  65.219195 ceff5cf8-c...
    30: contentiou...  4.02731196  5.4342495  17.976737 49bcb68f-7...
    31: contentiou...  6.14757717 14.6887054 204.219626 d2ebba88-5...
    32: contentiou...  1.38765954  0.4651956  24.529550 48ddc678-9...
    33: contentiou...  6.67060130  3.5903524  24.935352 b209df5e-2...
    34: contentiou... -0.61934962 11.5519872  38.219224 1685d9e0-0...
    35: contentiou...  1.13693862  8.3570019  30.032546 3904c746-6...
    36: contentiou...  1.10066618  2.5261201  17.878984 ffd37bc5-7...
    37: contentiou...  3.83338726  6.0463045  20.659236 f4b1a6bb-d...
    38: lunisolar_... -1.88269703  8.2729768   8.448956 80ff185f-3...
    39: contentiou...  0.79691514  4.8842545  16.716050 3a603424-f...
    40: lunisolar_...  9.52970931  9.5839946  49.717909 508f45e5-8...
    41: contentiou...  8.65168356  5.2222425  14.163963 1bd26fd1-7...
    42: contentiou... -0.21054889  3.5480750  27.189520 a366e3bf-3...
    43: lunisolar_...  8.99974126  6.4852076  20.134725 c33b0588-0...
    44: contentiou...  9.54176306  1.8316762   1.016713 eab2b740-c...
    45: lunisolar_... -1.27697507  5.3266716  21.286006 ea3c22e0-a...
    46: contentiou...  8.86735053 10.5193307  73.666781 d5e513b7-5...
    47: lunisolar_...  0.26270614 12.6106470  68.550842 b504a963-7...
    48: contentiou... -2.55403644  2.3768422  74.781311 a7d2f6a2-b...
    49: lunisolar_...  1.30812884 11.2720445  63.372030 c4540460-8...
    50: contentiou...  7.36384582  2.9841429  17.406344 58782981-5...
    51: lunisolar_...  2.51380274 13.5771968 118.042822 a9620790-2...
    52: contentiou...  4.11674039  9.9978460  74.510413 97813d30-8...
    53: lunisolar_...  2.76298347 14.6437978 146.401372 32583923-6...
    54: contentiou... -1.74357929 12.7365278  21.085533 9f102760-e...
    55: lunisolar_...  0.08187615  0.2888857  50.724990 48289a22-d...
    56: contentiou...  0.84517131 10.5667573  50.239863 941febda-d...
    57: lunisolar_...  9.78477001 10.1260426  54.751671 64a8e0fc-e...
    58: contentiou...  6.09811333 10.9108157 115.719015 850bf2fd-4...
    59: lunisolar_... -4.47123532  7.2426695  79.213642 2423d8bb-e...
    60: contentiou...  1.40172579  8.4148124  30.904514 4c487fd6-c...
    61: lunisolar_...  5.80092153  7.2509142  56.160156 504e396f-1...
    62: contentiou...  6.62954694 14.4394474 196.265842 d7b49701-9...
    63: lunisolar_...  4.36640127  2.0054139   6.985536 2ae8633a-3...
    64: contentiou...  8.39182437 11.6141317 102.549433 4ac35b9f-1...
    65: lunisolar_...  1.54133028 14.0799056 114.856126 67bed2a5-3...
    66: contentiou...  7.92475797  2.1851915   9.789940 26341192-5...
    67: lunisolar_... -1.07475464 12.7370232  38.357941 77c0efae-8...
    68: contentiou...  7.92394491  9.8215532  78.576940 f09866f2-4...
    69: lunisolar_...  0.42552322 13.5771788  86.495656 0ebf4c7d-b...
    70: contentiou...  2.04191052  7.2901249  21.652239 148b52d7-f...
    71: lunisolar_...  1.96777036  4.6726957   7.988691 ea07400a-4...
    72: contentiou...  3.97847151 12.8340139 127.249421 cbb827f8-f...
    73: contentiou...  2.31691006  1.5112162   5.716544 cab98837-c...
    74: lunisolar_...  0.92230637  1.1358420  28.092624 4fe3840f-e...
    75: contentiou...  6.74549277 11.8111378 132.417681 d59d0a42-5...
    76: lunisolar_...  6.21340742 11.5478681 128.769965 a7e718b1-d...
    77: lunisolar_...  8.29516666  7.1273013  35.496763 0a7c2d4d-d...
    78: contentiou... -4.73925049 12.1483725  28.712885 ce24faba-3...
    79: contentiou... -2.99737240 10.9530184   1.454200 e5bdaac1-9...
    80: lunisolar_... -1.53153111  8.8377943  10.386394 640ea4d9-3...
    81: contentiou...  2.53683659  4.8999787   6.536599 f90d1c8e-2...
            worker_id          x1         x2          y          keys
               <char>       <num>      <num>      <num>        <char>

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
    1: contentiou...  9931 runnervmeo...     FALSE terminated
    2: lunisolar_...  9929 runnervmeo...     FALSE terminated

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

    [1] "ruling_needlefish" "delayed_dore"     

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
    1: repressed_... 10224 runnervmeo...     FALSE running
    2: sombre_roa... 10222 runnervmeo...     FALSE running

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
    1: repressed_... 10224 runnervmeo...     FALSE running
    2: sombre_roa... 10222 runnervmeo...     FALSE running

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
