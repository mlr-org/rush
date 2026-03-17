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
    1: undemocrat...  9642 runnervm46...     FALSE running
    2: sappy_gold...  9640 runnervm46...     FALSE running

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
    1: undemocrat...  9642 runnervm46...     FALSE    running
    2: sappy_gold...  9640 runnervm46...     FALSE terminated

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

            worker_id         x1         x2          y          keys
               <char>      <num>      <num>      <num>        <char>
     1: ethnologic...  2.3001824 11.0617852  68.228884 a555635e-8...
     2: ethnologic...  0.2436614  5.3850233  19.373630 2d91e90d-c...
     3: ethnologic...  2.5001761  5.3813652   8.824136 417c7367-1...
     4: ethnologic...  6.4503771 12.6938822 153.679269 6b855f28-9...
     5: ethnologic... -1.8561151 10.2367262   7.998873 1b4d2f76-d...
     6: ethnologic...  6.3207334  7.4260394  59.596695 37a473a7-d...
     7: ethnologic...  8.9794405  9.3932824  54.162806 5e518cc3-0...
     8: ethnologic... -2.7774572 11.6005055   1.061144 d6eb26af-6...
     9: ethnologic... -2.1857340  3.2803052  50.912447 60219440-0...
    10: ethnologic...  5.7995472 14.1756094 189.084997 be8944fa-c...
    11: ethnologic... -4.7435476  4.9744638 142.134060 7a90d431-7...
    12: ethnologic...  3.5214636  5.8718150  16.093523 70bec8bd-2...
    13: ethnologic...  1.3335668  3.3965015  12.761840 6c9ea152-8...
    14: ethnologic...  4.1770507  4.1687469  11.669344 dd5de84f-8...
    15: ethnologic... -2.3895120 12.6043474   7.246763 c02a8b19-a...
    16: ethnologic...  5.4210920  8.1655737  65.207603 2a83a883-b...
    17: ethnologic... -3.1938041  0.8312116 134.267016 68fd5562-7...
    18: ethnologic...  3.1384491  9.0714706  46.556612 83377d77-f...
    19: ethnologic...  8.7117213 10.6123330  77.960431 238d0dfd-e...
    20: ethnologic...  6.5714641  0.1368475  20.172294 a2a833de-9...
    21: ethnologic...  0.2722761  7.5724105  23.233095 ce6dd2fa-1...
    22: ethnologic...  2.8275165  4.3833748   4.292679 0065cc24-d...
    23: ethnologic...  9.9512698  0.9196969   5.840369 a06673e2-7...
    24: ethnologic...  6.7928063  2.5409143  20.317242 61b8abba-3...
    25: ethnologic... -3.4383512 10.4776455   7.177647 a2442972-a...
    26: ethnologic...  1.5720246 11.1153684  63.250099 eda67880-0...
    27: ethnologic... -4.3380512 10.9118199  26.056157 3649d457-2...
    28: ethnologic...  8.6978490  3.7152083   6.011787 f065ada8-8...
    29: ethnologic...  3.4066156  8.5688743  42.872461 7abaa898-2...
    30: ethnologic...  2.3645014 13.1595665 107.205007 67e1ed21-5...
    31: ethnologic...  1.8990418 12.3135797  85.583347 5cce0c4e-a...
    32: ethnologic...  4.1768784 12.9891170 134.673649 469b00ec-6...
    33: ethnologic... -1.1603684 13.5642823  44.562292 0369a554-d...
    34: ethnologic...  8.7805136  7.4473299  32.157891 d77f8316-d...
    35: ethnologic...  0.7337747 12.2311272  70.851274 98649ee9-e...
    36: ethnologic...  9.1463824 12.7875223 111.803181 765240cc-8...
    37: ethnologic...  0.5914813 11.4151941  57.804262 da3f1fa3-7...
    38: ethnologic...  1.3415896  5.3578175  13.770533 d402434e-b...
    39: ethnologic...  7.3804860  8.3314203  63.953472 39b77031-f...
    40: ethnologic...  7.9174693  2.4757777  10.348686 eacb9945-9...
    41: ethnologic...  3.6306210  7.4847838  32.439876 af2d6943-a...
    42: ethnologic...  7.1000010  0.6025152  16.944791 6d9dbac6-a...
    43: ethnologic...  9.1659521 13.4879354 126.664616 39c80b20-1...
    44: ethnologic...  1.0125578  2.5167829  19.102712 7fc4d1dc-e...
    45: tricky_hon... -3.7892421  3.6114334 107.901661 600b95fd-7...
    46: ethnologic... -2.9879300  6.3733983  31.151280 783d8bd0-6...
    47: tricky_hon...  4.9368104 14.5555864 188.077652 57c05a97-0...
    48: ethnologic...  7.8970791 10.6322658  93.206592 0718a830-4...
    49: tricky_hon...  9.1181403 10.4572605  68.558429 63532a91-8...
    50: ethnologic... -4.2320700  0.3704764 221.031003 dd6b1871-1...
    51: tricky_hon... -1.1256870  6.3392676  16.745766 98c6ce98-e...
    52: ethnologic...  5.1417408  9.2948910  79.007706 bcb56b34-3...
    53: tricky_hon... -1.4946668 14.7267497  47.445556 5cbb4859-5...
    54: ethnologic...  1.8398012  5.9099566  13.211955 02aa6b48-6...
    55: tricky_hon...  1.0925960  7.5182813  24.047241 cbeac741-6...
    56: ethnologic...  5.3134167  6.0974352  39.506708 8604b655-9...
    57: tricky_hon...  4.8273276  2.2794979  12.007586 2a8cf470-5...
    58: ethnologic... -1.1468800 12.6756929  35.856336 19b5570b-d...
    59: tricky_hon... -2.9685246  4.8449301  49.793873 a05d14a1-0...
    60: ethnologic... -0.2565113 14.7719380  89.097100 68905823-c...
    61: tricky_hon... -0.3893430 13.3831102  64.363243 a6d0b9ae-f...
    62: ethnologic...  1.2290773 12.9742216  89.521610 2272a88a-e...
    63: tricky_hon...  0.8649251  0.8276334  31.379935 5638156d-d...
    64: ethnologic...  4.1578631 14.5027367 171.015314 9a6df8b9-6...
    65: tricky_hon... -0.4106016 14.9776334  87.733191 f5815e67-1...
    66: ethnologic...  3.3594786  4.1075631   4.610329 c751d4c9-6...
    67: tricky_hon...  5.6450921  4.1263286  26.677014 73f8569f-7...
    68: ethnologic...  1.0426259  1.3224684  24.815608 ae916363-3...
    69: tricky_hon...  0.1694902  8.9828071  30.019537 179f9543-0...
    70: ethnologic... -3.1305312  5.5894927  44.739954 3aea64f2-1...
    71: tricky_hon...  1.9097793  1.9606648   8.970858 a00e3885-8...
    72: ethnologic...  9.2145363  9.4006104  50.980186 38b42711-8...
    73: tricky_hon...  7.1963791 13.3568824 162.765466 c2827189-9...
    74: ethnologic...  7.3018874  4.1722445  23.479455 261d399e-f...
    75: tricky_hon... -2.8703375 12.6957450   1.879232 3c7f7aae-f...
    76: ethnologic...  1.5210098 11.8283939  73.684995 6e7dea9b-4...
    77: tricky_hon...  9.4590517  9.9811238  56.309974 ebd6b112-6...
    78: ethnologic... -0.9316009  9.4309194  19.099453 3daa1030-b...
    79: tricky_hon...  1.4566896  6.4464666  17.297064 89087d99-e...
    80: ethnologic... -2.4982195  1.9846143  79.716729 0c27c595-d...
    81: tricky_hon...  9.9842153  5.9618297  10.709352 68a08916-c...
    82: tricky_hon...  2.7519149  0.2280542   6.736805 ce4a12a1-2...
    83: ethnologic...  1.9008780 12.5810334  90.419821 90219772-2...
    84: tricky_hon...  2.8826671 12.7975977 107.055547 53294b09-2...
            worker_id         x1         x2          y          keys
               <char>      <num>      <num>      <num>        <char>

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
    1: ethnologic...  9640 runnervm46...     FALSE terminated
    2: tricky_hon...  9642 runnervm46...     FALSE terminated

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

    [1] "seminationalistic_antelopegroundsquirrel"
    [2] "dense_redhead"                           

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
    1: forest_ter...  9930 runnervm46...     FALSE running
    2: antimonarc...  9932 runnervm46...     FALSE running

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
    1: forest_ter...  9930 runnervm46...     FALSE running
    2: antimonarc...  9932 runnervm46...     FALSE running

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
