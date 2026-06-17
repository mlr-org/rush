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
    1: handcrafte...  9134 runnervm1l...     FALSE running
    2: unmodified...  9132 runnervm1l...     FALSE running

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
    1: unmodified...  9132 runnervm1l...     FALSE    running
    2: handcrafte...  9134 runnervm1l...     FALSE terminated

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

            worker_id         x1          x2          y          keys
               <char>      <num>       <num>      <num>        <char>
     1: tyrannous_... -1.7178934  7.75431961  10.445066 958b22d7-7...
     2: tyrannous_...  6.9530421 14.01647390 182.320531 a81f28d6-7...
     3: tyrannous_...  9.2559505  4.91917045   7.205767 6a517db5-4...
     4: tyrannous_...  2.4992326  2.72187441   2.323272 8005557e-f...
     5: tyrannous_...  6.0679624  0.98507414  19.393590 6c83cdeb-6...
     6: tyrannous_... -3.0028363  0.79172731 124.863863 416a774a-9...
     7: tyrannous_...  2.9389345  9.20229651  46.345360 15f09564-6...
     8: tyrannous_...  2.4265403  3.94654664   3.847838 9beec245-e...
     9: tyrannous_...  6.4644540  5.75923632  41.060051 ca97c9b3-5...
    10: tyrannous_...  2.4117541  9.92061611  51.950635 0f7e4e3a-0...
    11: tyrannous_...  0.6976071  6.10591008  18.689024 ed4885ef-d...
    12: tyrannous_...  7.3725066 14.31312058 184.101234 a6b6b5f2-a...
    13: tyrannous_...  6.7834662 11.43974708 124.340124 b5874652-d...
    14: tyrannous_...  8.8827993  5.78249513  15.662402 e6803b0f-c...
    15: tyrannous_...  7.6439827 13.50130566 158.866236 51e17324-5...
    16: tyrannous_...  8.7969146 11.56818168  93.849886 f635ad4e-e...
    17: tyrannous_...  4.3133890  3.89723034  11.832990 f6746b2d-d...
    18: tyrannous_...  4.2770911 11.75639162 109.998232 d718d58b-0...
    19: tyrannous_... -2.5878498 13.63759239   8.875234 80ebd9a9-9...
    20: tyrannous_...  3.3458227 13.57544463 131.799052 01d16d14-8...
    21: tyrannous_...  2.4225115  6.92317551  18.940446 dc559b9f-0...
    22: tyrannous_...  2.5826875 12.23537487  91.808149 d752cf90-7...
    23: tyrannous_...  1.9798919  9.01144843  38.172446 56736df8-1...
    24: tyrannous_... -1.1070975 13.92584185  50.360721 b813d65a-2...
    25: tyrannous_...  4.4523229  1.79774645   7.635193 7d28f05f-1...
    26: tyrannous_... -2.0708347 10.62324893   5.994363 24fc1910-2...
    27: tyrannous_... -1.9407781  1.71650127  68.290703 24394513-5...
    28: tyrannous_...  7.9264558  2.26566408   9.889188 57606cd9-1...
    29: tyrannous_...  2.4163776 13.78476561 121.107161 55e04a1e-1...
    30: tyrannous_...  4.4570824  6.90233826  37.056482 58539f34-1...
    31: tyrannous_...  8.1162517  0.05370272   9.878092 b0c973fe-9...
    32: tyrannous_...  5.6726171  4.92199071  32.256097 bf73fec3-c...
    33: tyrannous_... -4.8173524  5.43570633 137.103608 0fe2f44f-2...
    34: tyrannous_...  3.3529271  5.39472762  11.361843 3e0d7d13-9...
    35: succeedabl...  8.7117154  5.64440898  16.465889 34b4f63b-7...
    36: tyrannous_...  4.5743621  5.52030716  25.468131 2264983c-1...
    37: succeedabl...  3.9069754  3.97240598   7.998022 a9b99b5f-7...
    38: tyrannous_...  8.7607568  4.12127064   7.058173 42d5c550-7...
    39: succeedabl...  4.0305868 11.77131767 105.706713 9be22748-3...
    40: tyrannous_...  4.5339240  3.66019946  13.226445 6a4057e4-b...
    41: succeedabl...  6.8233415 10.54557060 106.420007 1467e71e-6...
    42: tyrannous_...  0.6970069 14.03871916  99.904893 257fe67d-9...
    43: succeedabl...  0.4698337 14.54956483 104.472532 b8481084-5...
    44: tyrannous_...  1.4792864  0.81725012  20.556314 8030238d-3...
    45: tyrannous_...  7.3730986  7.51615571  53.229596 7ac0bf4b-b...
    46: succeedabl...  1.8825187  5.01630210   9.471858 0437b934-8...
    47: tyrannous_...  3.6227754 10.51556982  75.206139 692d4f26-a...
    48: succeedabl... -4.4900974 10.14913913  39.260523 e4d32e3e-0...
    49: tyrannous_...  4.5339778  5.27511709  23.007215 7c0f52c5-f...
    50: succeedabl...  4.6134214  5.78334200  28.203355 379bb2bf-9...
    51: tyrannous_...  1.2880923 12.83066402  87.784788 fa5d5e6b-5...
    52: succeedabl...  4.8003986  2.90068076  13.289605 e6d47f9c-1...
    53: succeedabl...  3.0126753  4.03285104   3.217146 ae9ff60d-0...
    54: tyrannous_... -3.1003368  9.48468181   7.649640 15d761c4-2...
    55: succeedabl...  7.5735605  1.04856334  12.752109 5cae04a8-e...
    56: tyrannous_... -1.3639659 13.32840577  36.151240 fc39b2be-e...
    57: succeedabl... -1.8513848  8.92035245   7.560946 0e28112b-0...
    58: tyrannous_... -4.6093572 12.13936513  24.546519 15db3b64-4...
    59: succeedabl...  1.1279822  5.59351332  15.613470 b3fe5ae8-b...
    60: tyrannous_...  6.6626865  2.16214915  19.982836 a16e84c7-6...
    61: tyrannous_...  4.8399392  3.53690844  16.122177 8bfd0e57-3...
    62: succeedabl...  1.7437950  2.43616243   9.742658 adf38e28-b...
    63: tyrannous_...  2.2387869 12.91468309 100.687723 5c6a9b69-6...
    64: succeedabl... -1.5899303  7.63560647  11.308124 0b0ccc2c-7...
    65: tyrannous_...  9.7766410  8.36187816  32.056557 9c9c219b-e...
    66: succeedabl...  2.0468185  8.35389540  31.307741 da89325d-f...
    67: tyrannous_...  5.8944066  0.14975712  19.802136 32eb4fb4-2...
    68: succeedabl...  4.8008412  7.83302366  53.050724 5f244e12-1...
    69: succeedabl...  2.8055012 14.07012144 133.609233 577b829f-9...
    70: tyrannous_...  5.3982785  4.87172679  29.762251 6dae1534-4...
    71: succeedabl... -0.8677097  8.27455309  16.842559 35de15f4-6...
    72: tyrannous_...  8.0837616  3.90167173  13.221089 3308662a-0...
    73: tyrannous_... -1.3889585  7.00324053  13.858044 86879d57-1...
    74: succeedabl...  7.4918333  3.68436682  18.958162 e668033b-d...
    75: succeedabl...  7.4383508  5.96568234  35.560266 558da2b6-7...
    76: tyrannous_...  7.0930193 11.65905930 125.794166 05b2ee8f-2...
    77: tyrannous_... -1.4448737  7.91664535  11.631864 a3c6d095-d...
    78: succeedabl...  7.9543653  3.06201420  11.434111 f01449ac-f...
    79: succeedabl...  6.3983632 11.79518288 133.810378 1407f993-8...
    80: tyrannous_...  5.4136488  1.01378499  16.219500 06e11a02-9...
    81: succeedabl...  3.4346217 10.80849458  77.385854 eafdef1d-f...
    82: tyrannous_...  8.8064664 13.98082398 145.647989 6ac60aac-c...
    83: tyrannous_... -2.1079400  5.37050842  25.865783 1f476e31-1...
    84: succeedabl... -3.8601494 14.18784714   2.786175 d34794f7-e...
    85: tyrannous_...  6.1293702 13.21458717 166.296548 cf2c081e-4...
    86: succeedabl...  4.0199246  9.11935747  59.069680 3899d9c5-9...
    87: tyrannous_... -3.6241927  5.32017419  67.830944 c442f0d9-5...
    88: succeedabl... -0.8699789  2.77211402  38.378547 59d277c8-2...
    89: tyrannous_...  3.9803372  9.64575770  66.530014 59ae5308-d...
    90: succeedabl...  5.5040288  9.97398870  94.630788 3452ab99-4...
    91: succeedabl...  9.9962432  1.80766653   3.343399 f0aef27d-8...
    92: tyrannous_... -2.4675464  5.52121578  29.460764 915f2d08-f...
    93: tyrannous_...  8.2997755 14.09223524 159.686753 faf456f2-c...
    94: succeedabl...  5.1634106 12.92528888 151.050817 ae5cbc57-2...
    95: tyrannous_...  3.6372237 12.71860438 118.158604 047244ac-6...
    96: succeedabl...  3.0060851  1.18676398   1.917009 c96c1bbe-f...
    97: tyrannous_...  7.2415609  8.11514714  62.661554 a83f903c-f...
    98: succeedabl...  7.0327139 11.62539036 125.791991 48be8e36-9...
            worker_id         x1          x2          y          keys
               <char>      <num>       <num>      <num>        <char>

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
    1: tyrannous_...  9134 runnervm1l...     FALSE terminated
    2: succeedabl...  9132 runnervm1l...     FALSE terminated

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

    [1] "communist_bluebird"  "crushable_flyingfox"

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
    1: friended_a...  9382 runnervm1l...     FALSE running
    2: acidformin...  9384 runnervm1l...     FALSE running

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
    1: friended_a...  9382 runnervm1l...     FALSE running
    2: acidformin...  9384 runnervm1l...     FALSE running

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

    [1] "Rscript -e \"rush::start_worker(network_id = 'random-search-network', config = list(scheme = 'redis', host = '127.0.0.1', port = '6379'))\""

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

    [1] "Rscript -e \"rush::start_worker(network_id = 'random-search-network', config = list(scheme = 'redis', host = '127.0.0.1', port = '6379'), heartbeat_period = 1, heartbeat_expire = 3)\""

To kill a script worker, the `$stop_workers(type = "kill")` method
pushes a kill signal to the heartbeat process, which then terminates the
main worker process.
