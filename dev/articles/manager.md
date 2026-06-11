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
    1: generic_ca...  9328 runnervm3j...     FALSE running
    2: retrophili...  9330 runnervm3j...     FALSE running

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
    1: retrophili...  9330 runnervm3j...     FALSE    running
    2: generic_ca...  9328 runnervm3j...     FALSE terminated

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
     1: unextravag... -3.9354001  4.52547442  98.1086918 41868587-8...
     2: unextravag... -1.2684388  5.11524254  22.5399858 d82107a5-f...
     3: unextravag... -0.9806757 10.05091041  20.9405759 09418793-4...
     4: unextravag...  6.0767984 12.33006502 145.5366561 49926a58-5...
     5: unextravag...  0.9624741 11.20030656  59.2121630 5a4cae11-b...
     6: unextravag...  6.1798019  0.66179535  19.7411970 4ec3d49b-1...
     7: unextravag...  9.2340304  6.33698654  16.7178605 3856362f-b...
     8: unextravag... -2.0888443 14.97094386  31.0798068 839f66d8-f...
     9: unextravag...  7.0535242  3.00438124  20.1427228 df22a3d2-6...
    10: unextravag...  3.6726154  0.94121433   2.6343078 9d788621-f...
    11: unextravag...  5.5090242  1.41579370  16.9347606 88e0eb82-a...
    12: unextravag... -2.6702571  7.58020431  14.3384534 2a987dc3-f...
    13: unextravag... -4.0296068  5.69730108  81.6224746 43ef68e5-d...
    14: unextravag...  2.1973280 10.55145263  59.4986576 821f78aa-9...
    15: unextravag...  1.4164756 11.56694981  68.6619605 8b5f7e98-8...
    16: unextravag...  3.2862682  7.25249163  26.3820216 e6c7fd6a-6...
    17: unextravag...  9.7222758  2.21360650   1.0940177 4974503e-7...
    18: unextravag...  9.6709860  4.07193799   2.5957884 041cf6ef-f...
    19: unextravag...  1.4775887 11.12093849  62.5976966 9ef1b2f2-6...
    20: unextravag...  8.0583204 11.60585243 108.8988132 94edea0f-5...
    21: unextravag... -3.0034108 12.99021713   1.5810936 75aedec1-4...
    22: unextravag...  7.4811958  6.70949273  42.5056508 35ef2211-2...
    23: unextravag...  5.6582006  6.15351702  43.0170788 5893a02d-1...
    24: unextravag...  7.2089670 11.93117252 130.0700168 f3f2420b-1...
    25: unextravag...  8.0559638 13.47401692 149.9597721 1a451008-0...
    26: unextravag...  5.2919145  3.06162823  18.7412365 a296778f-4...
    27: unextravag...  4.9898007 13.45530004 160.9909778 d2edb2e8-0...
    28: unextravag... -3.8318272 12.05441874   6.3630400 6b346927-b...
    29: unextravag... -1.8174555  8.80824382   7.9166575 9cc5a9a9-4...
    30: unextravag... -2.9949502  1.85944644 101.8235815 b38a4bad-9...
    31: unextravag...  6.8271260 13.71052617 175.8440705 bed0ae1e-3...
    32: unextravag...  7.2136301 13.91338678 176.3148858 614d2199-7...
    33: unextravag...  8.5764420  9.16255679  57.0894364 4148e07d-b...
    34: unextravag... -3.6969239  0.46031666 175.7936445 a9d7f207-7...
    35: unextravag...  2.3797681 13.17848086 107.7948483 13bef11f-2...
    36: unextravag...  8.0649746  4.86914150  18.8941651 b49780d6-f...
    37: futuristic... -4.7528701  6.53934514 109.2584353 428d48ac-f...
    38: unextravag...  2.9609654 10.23521396  61.6304424 a82a1e89-f...
    39: futuristic...  4.0509571  0.31670089   5.9405306 2552fea6-f...
    40: unextravag...  8.0493651  7.43820774  42.6985962 9b9670c7-c...
    41: futuristic... -3.6218001  3.37600700 103.1474856 4a5dcc47-9...
    42: unextravag...  8.3511401  0.09261294   8.0632404 11ac6dc1-3...
    43: futuristic... -0.4464556  3.92583623  26.5596817 da8e4526-4...
    44: unextravag...  0.4348104 13.38712991  83.5872865 3c76d204-3...
    45: unextravag...  2.5885923  3.16559877   2.0053167 1f5ccc98-8...
    46: futuristic...  2.5716059  4.81458315   6.1311378 2085462e-6...
    47: unextravag...  6.1904330  7.33214922  58.4234732 6f145b73-2...
    48: futuristic...  7.0221161 10.53757041 104.3990002 5aed0d25-3...
    49: unextravag...  1.5075118  7.64636768  24.6852406 ca9a9807-b...
    50: futuristic...  6.4848888  2.05835017  20.3036379 aa2d8f64-0...
    51: unextravag...  7.1408481  0.52080979  16.7738942 d708ae56-5...
    52: futuristic... -4.6399283  4.33794707 149.2048362 71ec7352-2...
    53: unextravag...  2.8535851  2.32269174   0.8285866 2b59a387-4...
    54: futuristic...  4.5804809  1.98973726   9.0612944 84dd14f0-3...
    55: futuristic...  6.9147836 13.12827587 160.7109034 a85c1350-6...
    56: unextravag...  5.7005493  5.61773925  38.1998508 5ed0ecaa-d...
    57: futuristic...  5.6475076  5.26432394  34.8028977 9ad4b4e0-b...
    58: unextravag...  3.5571536  3.85810533   4.7678781 d4724370-c...
    59: futuristic...  3.5519627  1.43822672   1.4850990 fe83be12-8...
    60: unextravag... -1.0989881  9.56025019  17.1035951 b375c26a-a...
    61: futuristic...  1.3235611 10.02326075  47.2007852 875c45cc-8...
    62: unextravag...  8.5125403  7.13078845  32.4024626 1897797c-9...
    63: unextravag...  5.3215647  4.06529158  23.7681684 ba2be71e-a...
    64: futuristic...  3.6091024  7.93172626  37.3452994 3c3f802a-5...
    65: futuristic...  6.9458586  4.90063660  31.4291693 0cc650a2-7...
    66: unextravag...  6.8594542  0.30266900  18.7885367 a5fce9a9-1...
    67: futuristic...  6.6775743  8.06764643  66.9591833 05d9a336-c...
    68: unextravag...  7.0867138 13.22798402 161.1218206 66989826-c...
    69: futuristic...  9.3737494  6.92918437  20.6324204 5acce315-5...
    70: unextravag...  0.6243714 12.74677374  76.9285962 7bb67991-7...
    71: unextravag...  3.3223126 10.32328505  67.5485203 dcf53b86-0...
    72: futuristic... -0.0297297  9.23230754  29.7413115 0b9a8e5c-4...
    73: unextravag... -1.8668724  9.63878444   7.2456306 6124caa0-6...
    74: futuristic...  0.8428670  0.44692941  34.9076247 0b084e3e-6...
    75: futuristic... -0.6297945  6.32376355  18.2925786 e14bb1a3-e...
    76: unextravag...  5.6290058  1.24470648  17.6318864 87d91d75-d...
    77: unextravag...  2.0819790  4.97194019   8.2800641 4489e61c-d...
    78: futuristic...  5.5735952  6.60637172  47.1387745 49ca3213-b...
    79: futuristic...  3.4685621  1.61047082   1.0858322 39a80fcd-9...
    80: unextravag...  3.4695981  6.70884964  22.7724359 1282d5eb-6...
    81: unextravag... -2.1038999 11.19684453   6.7497345 f9531cd3-b...
    82: futuristic... -4.1177396  2.45699520 155.5914546 3fbcfe0a-2...
    83: futuristic...  3.6984067  2.64881062   2.4381678 ce12bae3-0...
    84: unextravag...  8.3382266  9.26378001  62.5745376 86bd0507-b...
    85: unextravag...  0.2010821 14.83015944 103.0390809 82bc6726-a...
    86: futuristic...  9.4031235 14.81114245 153.0300489 e6944108-6...
    87: futuristic...  7.2951001  4.39975504  24.9212849 15b60e6c-8...
    88: unextravag...  1.4769081  5.15943061  12.4087213 b7a4cda1-7...
    89: unextravag... -0.6127249 12.64696142  49.4766060 bc51e49c-d...
    90: futuristic...  3.1280629 11.77284944  90.4071434 ad95335c-5...
    91: unextravag...  8.3127857  0.98573131   6.2530026 ad72fc3b-6...
    92: futuristic... -4.4720219  9.12839608  50.9132810 a6c5a455-8...
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
    1: unextravag...  9328 runnervm3j...     FALSE terminated
    2: futuristic...  9330 runnervm3j...     FALSE terminated

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

    [1] "superenergetic_firecrest" "linen_grayfox"           

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
    1: allergenic...  9580 runnervm3j...     FALSE running
    2: webby_road...  9582 runnervm3j...     FALSE running

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
    1: allergenic...  9580 runnervm3j...     FALSE running
    2: webby_road...  9582 runnervm3j...     FALSE running

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
