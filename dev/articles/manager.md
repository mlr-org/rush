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
    1: unreputabl...  9074 runnervm1l...     FALSE running
    2: perpetual_...  9072 runnervm1l...     FALSE running

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
    1: unreputabl...  9074 runnervm1l...     FALSE    running
    2: perpetual_...  9072 runnervm1l...     FALSE terminated

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

            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>
     1: aeromarine... -3.9325344 12.6329896   5.8842613 8d6d62b1-0...
     2: aeromarine...  5.3638071 12.8647044 152.3558729 297f2ade-e...
     3: aeromarine...  3.5620373  7.0382406  26.9217409 53c2c9f1-7...
     4: aeromarine...  7.8593491  5.5496279  26.5828280 a9d42719-0...
     5: aeromarine...  0.5977211 12.1586593  67.8346859 d145749a-a...
     6: aeromarine...  1.3264316  7.3862943  23.0165965 7ec19661-c...
     7: aeromarine...  7.1643670 14.0705773 181.0318383 ffe46c1c-1...
     8: aeromarine... -2.9665970  4.1615822  59.7855365 8b505956-2...
     9: aeromarine...  9.0687612 12.3686860 104.5839566 9039c95b-3...
    10: aeromarine... -4.8749300  6.1045419 126.5626111 cf7f2740-7...
    11: aeromarine... -4.7431841 10.4155303  46.7754211 1affe1b1-1...
    12: aeromarine... -0.9903225 11.0378297  26.3881264 4ce40772-6...
    13: aeromarine...  1.0121668 10.8717081  55.4153403 4e30d35f-7...
    14: aeromarine...  1.7943543  8.1267498  28.7251984 bf4a2be3-5...
    15: aeromarine... -1.9483369  9.4988435   6.4688624 10aefa30-6...
    16: aeromarine...  3.5318737  6.2068183  18.8988630 60f3b4fb-5...
    17: aeromarine...  6.4985069  1.0209896  19.3888152 0f8f3748-1...
    18: aeromarine...  0.3157037  6.7592303  20.6870912 8e2d371e-d...
    19: aeromarine...  3.8022289  8.5113572  47.2435759 94d5999b-c...
    20: aeromarine...  3.4736280  0.3108018   3.8790258 0f3b9f46-d...
    21: aeromarine...  8.4257658  4.2596034  11.0457893 f341436d-9...
    22: aeromarine...  4.1896085  6.1152722  25.5971968 58e3278b-9...
    23: aeromarine...  7.2474399  4.3968924  25.3713395 d5860805-d...
    24: aeromarine...  6.8271659  3.4424357  23.4459763 debf580a-6...
    25: aeromarine... -4.5231570  7.4201178  79.1186534 4f66e6a7-4...
    26: aeromarine...  6.5844104 12.8677628 157.1489175 5d2ae3c9-3...
    27: aeromarine...  6.2092490  6.6937746  50.8846255 b6f12c1f-d...
    28: aeromarine... -2.4682002 13.4472273   9.9575928 6511a04e-9...
    29: aeromarine...  7.1646787  2.1252890  16.9112781 da38663c-d...
    30: aeromarine...  5.7523389  0.8302828  18.3643094 71299b0c-0...
    31: aeromarine... -1.8546433  5.1007469  25.7610884 4b323cbe-2...
    32: aeromarine...  4.3826327  6.2225042  29.1348929 e838f695-4...
    33: aeromarine...  8.4109815  7.8036394  41.5388183 c9e05192-e...
    34: aeromarine... -3.0408481  5.4796759  43.4083333 1933ff2b-d...
    35: aeromarine...  8.7292863  5.2076696  13.2351180 5cf0bc26-c...
    36: mousey_iba...  0.5372665  0.7453357  37.9350754 8bd48cf2-a...
    37: aeromarine...  8.2321506 13.2038125 139.8819779 311b6c7c-3...
    38: mousey_iba...  0.3741889  3.2018605  23.8691415 f95425c9-0...
    39: aeromarine... -3.9525669 12.5878857   6.3481220 3bea43d4-5...
    40: mousey_iba...  0.7397123  8.0391902  26.9887310 60935ea6-9...
    41: aeromarine...  8.8693538 11.8905785  98.7503224 d0293237-d...
    42: mousey_iba...  6.3443624 10.3989146 106.0087596 8f8fee0d-e...
    43: aeromarine...  5.7656304 11.9699432 136.1064001 d900e9d5-2...
    44: aeromarine... -0.1732521 13.0910315  65.8537317 d09314d7-a...
    45: mousey_iba...  0.8224657  6.3711200  19.0702168 aed78891-2...
    46: aeromarine... -1.9010069  1.8303530  65.5935058 5119399b-6...
    47: mousey_iba...  2.3018239  1.5594281   5.7254969 12b05faf-5...
    48: mousey_iba...  0.6743922  1.7105679  28.2247725 00b28879-0...
    49: aeromarine... -4.0226819  0.5645176 197.8859197 e1a3bc3c-1...
    50: aeromarine...  6.7068391  8.9066811  79.1262650 d88edb78-0...
    51: mousey_iba...  3.6547506 10.0285927  67.5652429 c620240a-5...
    52: aeromarine... -0.9616838  3.9901982  28.8882056 d306f61c-a...
    53: mousey_iba...  1.5122699  4.3524666  10.7768400 cf1cd042-0...
    54: aeromarine...  5.6608274  7.7071864  61.0581750 df4418b4-7...
    55: mousey_iba...  9.7025470  4.1823346   2.9064944 ae1e5757-7...
    56: mousey_iba...  3.7736234  1.3915577   2.4482311 c3ed4b85-2...
    57: aeromarine...  2.9484772 14.7526467 152.4136371 dc2e3d60-9...
    58: mousey_iba... -1.7593668 12.0497875  16.3213648 f62454b0-2...
    59: aeromarine... -2.8075409  8.8737926   7.7554881 66448aca-5...
    60: aeromarine...  4.8802989  2.7149692  13.5798108 46d799d9-4...
    61: mousey_iba...  3.2640414  1.4694183   0.9767638 3f3127b0-d...
    62: aeromarine... -4.1933267  7.8520830  55.5527921 ba337fe0-3...
    63: mousey_iba... -4.9632910  3.8680136 186.9851696 3f8c4dc4-b...
    64: mousey_iba... -1.9457652  1.5676059  70.7759163 a9c58839-3...
    65: aeromarine... -2.4381954  4.3953217  41.7789985 becee90f-0...
    66: mousey_iba...  1.2484231  0.7182877  25.2650298 412757c2-6...
    67: aeromarine...  5.9725028  6.4392860  47.6228433 0cbe551d-7...
    68: mousey_iba...  8.7805171  7.7060888  35.0515653 922e86a3-c...
    69: aeromarine...  2.0412770  1.5769575   8.5800028 62c83363-2...
    70: mousey_iba...  3.8833552 11.3304400  94.3683121 2b267c14-b...
    71: aeromarine...  3.0573325 13.4736054 124.3528678 814ee841-f...
    72: aeromarine...  3.7108528  7.7415094  36.3524785 f92c81c0-c...
    73: mousey_iba...  6.7292111  2.6791542  21.0320368 829da10c-c...
    74: aeromarine... -0.9393672  4.5277425  25.1625303 9761542d-9...
    75: mousey_iba...  7.6527118  1.3380145  11.9218860 7df2d9ad-c...
    76: aeromarine...  5.3884333  6.5716592  45.1327187 4754d61d-4...
    77: mousey_iba...  5.4602956  0.1155922  17.6239210 5cabd456-b...
    78: aeromarine... -3.6867519  4.6548557  82.2270963 06fae719-b...
    79: mousey_iba... -0.3442784 10.8461374  37.3817953 bf732145-2...
    80: mousey_iba...  4.5163005  2.1048802   8.5619111 8a3bfb3c-c...
    81: aeromarine... -4.7660612 13.1440228  21.9116117 2b8753c9-c...
    82: mousey_iba...  7.7711135  7.8523442  51.9980584 db1ba905-6...
    83: aeromarine... -2.3175302 10.7271191   3.5967049 30c8648d-e...
    84: mousey_iba...  5.7695154  7.5075580  59.1927624 ad0a6480-4...
    85: aeromarine...  1.8544162 10.7231170  59.5897416 743d05d2-a...
    86: mousey_iba...  1.4455622 10.7892052  57.7109322 7cef92d3-d...
            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>

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
    1: aeromarine...  9072 runnervm1l...     FALSE terminated
    2: mousey_iba...  9074 runnervm1l...     FALSE terminated

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

    [1] "iridescent_rhinocerosbeetle" "surgical_greatargus"        

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
    1: cuneiform_...  9325 runnervm1l...     FALSE running
    2: arty_acaci...  9327 runnervm1l...     FALSE running

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
    1: cuneiform_...  9325 runnervm1l...     FALSE running
    2: arty_acaci...  9327 runnervm1l...     FALSE running

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
