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
    1: depictive_...  9020 runnervm1l...     FALSE running
    2: correctabl...  9018 runnervm1l...     FALSE running

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
    1: depictive_...  9020 runnervm1l...     FALSE    running
    2: correctabl...  9018 runnervm1l...     FALSE terminated

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
     1: unapproach...  6.1976621  0.9659662  19.5845098 a1e435f5-9...
     2: unapproach... -0.8523030 14.2256353  62.2254383 f87b6ca8-9...
     3: unapproach...  8.4081748  0.6652803   6.1255685 2307f285-2...
     4: unapproach...  7.8001994 13.0300513 144.7160460 6fc331cd-2...
     5: unapproach...  5.6474387  2.2790303  19.0418668 676b70fa-a...
     6: unapproach...  9.5579774 13.0615287 110.1432159 3f7cd0ce-e...
     7: unapproach...  6.6103808  6.6349177  49.4602089 40339e73-0...
     8: unapproach... -3.8826422 11.8652915   8.0306423 95644f39-c...
     9: unapproach... -2.3490778 13.6094172  13.2309914 ec9e6de7-6...
    10: unapproach...  1.8045903  0.4394208  17.4424777 defe3cea-7...
    11: unapproach...  8.7435739  8.3320254  43.1393534 bd1ce587-8...
    12: unapproach... -3.1723074  9.7831719   6.9855663 f45176f5-b...
    13: unapproach... -2.3490444  5.7592077  25.2762487 0722f0b8-f...
    14: unapproach...  5.7632068  4.0520157  26.9392352 d0c8256a-0...
    15: unapproach... -0.8600002  5.5163751  20.0591012 a16bda4a-7...
    16: unapproach...  7.9131497  7.8828305  50.2353110 3ddb8aa9-f...
    17: unapproach...  8.8463100  7.9991829  37.5879596 cd361e14-8...
    18: unapproach...  8.3413113  3.1928223   7.6943325 f1665d00-f...
    19: unapproach...  3.3558131 14.7028755 159.1005148 fb29097f-f...
    20: unapproach...  4.3071126  0.8638275   6.6734531 20ce3662-3...
    21: unapproach...  6.3935563 10.0979784 100.4157837 ef0cdcca-2...
    22: unapproach...  7.9605383  4.3927565  17.2495810 e99df7cd-6...
    23: unapproach...  6.4830914  0.1881692  20.2634761 b133b371-2...
    24: unapproach... -2.1899093  7.0943009  13.4913525 5c9d5661-2...
    25: unapproach...  4.2223823  9.6959494  71.3002801 fd4e654f-1...
    26: unapproach... -4.1266125  6.5130233  72.8292408 27de57eb-c...
    27: unapproach...  3.3035557  1.0375407   1.7657524 31b4b6fe-5...
    28: unapproach...  9.9730784 10.3911455  56.7847822 631e5886-e...
    29: unapproach...  8.0586050  4.8427035  18.8006134 47868ffa-b...
    30: unapproach...  0.7299137 12.3670816  72.8066427 91d1bfb1-7...
    31: unapproach...  7.3774101 12.2556264 134.6606144 3fbbbe6f-9...
    32: unapproach...  6.8878268 14.8400874 204.8673894 8d0faa27-7...
    33: unapproach...  4.6963097  6.5129144  36.2458585 9d057e84-d...
    34: unapproach...  8.9869424 13.0614548 120.7907014 6d7ea394-3...
    35: unapproach...  9.5041397 13.2470157 115.0092666 6fffeaad-a...
    36: unapproach...  8.1929016  3.0977229   8.9561583 fcae9d1a-9...
    37: unapproach... -1.2986963 12.8115217  33.0716099 eb5c96f2-6...
    38: churnable_...  4.7499362  6.7009287  38.9405891 19ba66c3-5...
    39: unapproach...  2.4342548  7.6569389  25.4131973 f5d2bbdc-6...
    40: churnable_... -2.5058752 11.8853545   3.4529378 00daa1e1-c...
    41: unapproach...  5.6968545  8.6496084  74.6068088 2f9f8ce7-7...
    42: churnable_...  6.9899425 12.7220414 150.3587326 4546c776-3...
    43: unapproach...  1.1268816 12.4015810  78.6212144 1cb8cc7a-e...
    44: churnable_...  1.2251445  5.3895007  14.5654059 5dfc2360-5...
    45: unapproach...  7.8240755  6.6105689  36.8590054 d68cc61e-3...
    46: churnable_...  3.6707386  6.9440386  27.1684281 075cb6ba-3...
    47: unapproach...  2.8232091  8.6236486  37.9351868 754fdf2a-a...
    48: churnable_...  7.1340208  6.4636762  43.8210265 ec58e690-d...
    49: unapproach... -3.4998016  1.5185010 136.3558620 8406073b-e...
    50: churnable_...  6.6046618 12.7985143 155.4141986 41ae8ad3-f...
    51: unapproach...  4.2066192  9.1358366  62.2731094 a38d6264-4...
    52: churnable_... -4.8225625 11.6372479  36.4831394 3324318e-9...
    53: unapproach...  6.5490007 13.6448261 176.1965416 143d72e4-e...
    54: churnable_... -1.6017923 11.3730763  15.9139352 307439f1-3...
    55: unapproach...  0.6435666  9.4070260  36.8463461 761dfb99-f...
    56: churnable_...  6.8376243 10.3475453 102.6231835 0b40671d-9...
    57: unapproach... -2.9825169  3.6880394  67.8892792 3b97cbb4-d...
    58: churnable_... -1.5885586  0.7120307  76.1254987 8e2ef9c9-3...
    59: unapproach... -1.6460576 11.4695543  15.5267454 092342ef-5...
    60: churnable_...  6.5596064 12.8822959 157.6205044 995c27f8-f...
    61: unapproach...  0.7826642  5.2807669  17.0083177 bca2ab7d-f...
    62: churnable_... -3.8593713 14.5092770   2.9630367 7862c158-9...
    63: unapproach...  4.3291371 13.3728661 146.6376201 f472d9cb-6...
    64: churnable_...  3.2193850  1.3157602   1.2357654 0c5c96b0-a...
    65: unapproach...  4.1218858 10.3765544  81.0745944 e103c373-a...
    66: churnable_...  5.9521050  3.5700197  25.1637567 d6bdd5dc-f...
    67: unapproach...  5.0087333  2.7020818  14.8570489 c15449fe-1...
    68: churnable_... -2.8935718 13.7795364   5.0708666 b73e7408-e...
    69: unapproach... -3.9652989  0.8116563 186.5512992 711ddae3-7...
    70: churnable_...  1.0194142  6.0213011  17.3088012 4209ec9e-f...
    71: unapproach...  1.7616469  6.9234964  19.2430292 d8c70fc2-e...
    72: churnable_... -3.2528615  4.3898259  66.9479062 24668b5c-1...
    73: unapproach... -1.1106181 14.1382123  52.8441623 ece06ada-2...
    74: churnable_...  9.5059021  1.9180595   0.8216187 c8c57fc0-2...
    75: unapproach...  1.4644424 14.9578358 132.2728761 41f55d6e-e...
    76: churnable_...  0.2290937 10.2735040  40.8005249 44d309b7-c...
    77: unapproach... -0.4605947  9.6681642  27.0561720 ec7ae4a2-8...
    78: churnable_...  7.9762442  8.2300613  53.7976200 4c28a789-b...
    79: unapproach...  8.9390213  6.2016359  18.3670532 31cbead2-6...
    80: churnable_...  9.7753608 11.6000149  78.6582059 6129e49a-2...
    81: unapproach...  2.1578195  5.0120346   8.0848361 1db5c4f8-2...
    82: churnable_...  3.2843252  3.6217616   2.6138402 2d34a7a6-c...
    83: unapproach...  1.6745951 14.6294126 128.5212767 a94c09f4-9...
    84: churnable_...  4.2469558  7.1315379  36.6121321 70426b11-6...
    85: unapproach...  0.2741179  5.4669026  19.2549608 cbf01ebd-6...
    86: churnable_...  6.8098854  1.3555195  18.3419191 45800188-f...
    87: unapproach...  4.5969978 10.8452344  97.8496557 93f6a1af-b...
    88: churnable_...  5.8018478  5.2350151  35.4888352 ee2081d8-f...
    89: unapproach...  3.6424619  7.3604624  31.2108076 04886260-7...
    90: churnable_... -1.7592742  0.3995250  85.6458183 4de4dc58-3...
    91: unapproach...  1.0626847  6.5401424  19.0213008 65319423-3...
    92: churnable_...  7.5763878 10.8014052 101.8242363 b3354ff1-c...
    93: unapproach... -3.1389850 10.5608484   3.3147932 3bfaca9f-4...
    94: churnable_...  4.8654752  7.1584757  45.6160223 3f34cefb-6...
    95: unapproach...  6.7441503 11.4920277 125.7204010 90f7d54e-0...
    96: churnable_... -3.5420567  9.2103399  17.5421969 0ac4a700-5...
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
    1: unapproach...  9018 runnervm1l...     FALSE terminated
    2: churnable_...  9020 runnervm1l...     FALSE terminated

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

    [1] "antimonarchal_sandbarshark" "superdesirous_baleenwhale" 

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
    1: executable...  9269 runnervm1l...     FALSE running
    2: quasilawfu...  9271 runnervm1l...     FALSE running

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
    1: executable...  9269 runnervm1l...     FALSE running
    2: quasilawfu...  9271 runnervm1l...     FALSE running

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
