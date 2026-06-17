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
    1: amoeboid_b... 13944 runnervm1l...     FALSE running
    2: bronchial_... 13946 runnervm1l...     FALSE running

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
    1: bronchial_... 13946 runnervm1l...     FALSE    running
    2: amoeboid_b... 13944 runnervm1l...     FALSE terminated

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
     1: rainproof_...  9.3135583  5.4110587   9.6276747 caac79f3-7...
     2: rainproof_...  3.1516851  3.4689719   1.8427703 d32deeb1-3...
     3: rainproof_...  0.8939819  4.3548833  16.1199060 65b30300-1...
     4: rainproof_...  4.8239607  3.8779571  17.5681786 67250312-a...
     5: rainproof_...  1.9459494  9.6657262  45.8398925 0691f962-8...
     6: rainproof_...  5.8535169 13.7782109 179.2085109 44b92769-b...
     7: rainproof_...  1.5008230  8.5784865  32.5375948 b4b3fb1e-3...
     8: rainproof_...  0.1730467 11.4951375  52.7133164 65cfff1a-4...
     9: rainproof_...  1.6491793  7.6815179  24.8894668 3efef508-6...
    10: rainproof_...  2.0138781  4.1540590   6.5810730 42992e1c-6...
    11: rainproof_...  8.5700196 13.5582330 140.8178936 3693d8ee-f...
    12: rainproof_... -3.5292534 13.8509792   1.5009330 1bb7e358-5...
    13: rainproof_... -2.9122950 13.7824779   4.8588592 3ac5da8a-4...
    14: rainproof_...  3.8909184  8.4638742  47.8693062 9bf60231-9...
    15: rainproof_...  9.1638226  5.5175899  11.3109341 94056f27-e...
    16: rainproof_... -2.1930261 12.8680799  12.0015794 b08b7b33-6...
    17: rainproof_...  2.5961680 14.0827584 130.4768134 182db4de-4...
    18: rainproof_...  6.1258650 14.2766229 193.1546363 4d3f078c-e...
    19: rainproof_...  4.0805594  9.9005135  72.2903169 bec41836-f...
    20: rainproof_...  7.1397308  6.9816184  49.4625813 2c31de40-8...
    21: rainproof_... -2.9889572  1.3632673 111.7681992 259d5910-6...
    22: rainproof_... -2.9627386  6.9061787  24.9855404 fc5c5070-6...
    23: rainproof_...  1.9222817  8.2533644  30.0752751 82868fdf-5...
    24: rainproof_...  2.3769937 12.1465369  87.7056559 2b5e5e59-b...
    25: rainproof_... -2.2191947  2.1078842  69.1693762 c2791e86-b...
    26: rainproof_...  0.5077057 11.9469930  63.5726106 f8ff247b-0...
    27: rainproof_... -4.3844100  6.1293620  93.9924113 ac6ca043-d...
    28: rainproof_... -0.8381472 14.8527630  71.5983560 bb3cc8d6-9...
    29: rainproof_...  7.8411899 11.3642617 108.1543929 f100f605-a...
    30: rainproof_... -4.3173919  1.5608711 194.5010468 264275a6-3...
    31: rainproof_...  5.3588913 11.4116066 120.4507607 6fbe9a6b-0...
    32: rainproof_...  2.1803954  1.5695005   6.9813155 315dc641-d...
    33: rainproof_...  7.2975362  1.8647918  15.4310622 833dbeab-6...
    34: rainproof_... -2.8217804 11.7915911   0.9587321 e2ea6af5-c...
    35: rainproof_... -0.7202716  0.1302193  67.3881928 71bfc17a-0...
    36: blond_ibad...  6.9368243 11.4126436 122.4117770 0e504073-9...
    37: rainproof_...  9.4158803  0.5837029   3.9469774 01d8811c-f...
    38: blond_ibad...  7.9153851  3.2672846  12.5478202 09603bc2-6...
    39: rainproof_...  4.6536385  8.2837902  56.9444179 2c00da8b-d...
    40: blond_ibad...  8.2985088  8.2948296  49.5099404 ccb0ae3e-f...
    41: rainproof_... -0.2918610  1.4694833  44.2563981 732d21e7-0...
    42: blond_ibad...  5.9642985 10.7837327 112.8348766 2bdede02-c...
    43: rainproof_...  9.1407392  4.4445515   5.6170079 a27a92c3-6...
    44: blond_ibad... -2.9842354 12.8396188   1.3993469 f72b60ab-2...
    45: rainproof_...  9.7881715 10.5625797  61.3044862 def77a94-5...
    46: blond_ibad... -1.2924200  4.7898382  24.7691718 4e2ff952-0...
    47: rainproof_... -3.9333055 11.7283314   9.6558024 e1d48360-7...
    48: blond_ibad... -0.4258606 12.8184927  56.1656748 600bf3c9-3...
    49: rainproof_... -4.5754444 12.0405653  24.2594217 561cca95-c...
    50: blond_ibad...  9.4685022  3.0259733   0.6711002 e68ce91e-7...
    51: rainproof_...  9.1383684  1.6913428   1.0944702 b66bdf37-1...
    52: blond_ibad... -1.8073637 10.9761599  10.5641317 945d76e7-6...
    53: rainproof_...  6.5395171 12.2145714 142.4522929 9fd43229-d...
    54: blond_ibad... -4.1472736 10.2484400  25.7804139 4f822c51-9...
    55: rainproof_... -3.1043102 10.1983347   4.3537078 01c7ddb2-5...
    56: blond_ibad...  8.8801956 14.3335912 152.5765933 06b1f577-0...
    57: rainproof_... -3.8854417  1.2897889 167.9111275 0fee077b-d...
    58: blond_ibad...  5.2220468  2.6788077  16.8371097 c9b8c7fe-1...
    59: rainproof_... -4.4807317 11.1530583  28.6975247 76c61d39-b...
    60: blond_ibad...  9.2520313  9.4092328  50.6118968 5dd157a1-1...
    61: rainproof_...  9.3187310 12.7473693 107.7890828 90034d8f-c...
    62: blond_ibad...  4.1020262  5.1473862  16.7619878 8e793d09-1...
    63: rainproof_...  2.5300061  5.7604629  10.9011186 df2ce4bd-5...
    64: blond_ibad...  3.3061140 13.4531871 128.2852185 bd4bce40-9...
    65: rainproof_...  2.4342950  2.2467182   3.1166186 e8859799-e...
    66: blond_ibad... -1.1675197  5.4157483  20.6247855 5c1b6d20-8...
    67: rainproof_...  0.6400264 14.8942885 114.9213380 b01f9e0a-e...
    68: blond_ibad...  3.0349303  5.0695855   7.7961997 15909d44-6...
    69: rainproof_...  3.7033813  8.0099474  39.4787027 92ebf466-0...
    70: blond_ibad...  1.9727147 10.8940552  62.9596614 d3048b68-a...
    71: rainproof_...  2.7651261  6.2859405  14.7532301 fda2c198-2...
    72: blond_ibad... -4.0980404  1.5622380 176.8491785 96091474-b...
    73: rainproof_...  4.0883819 14.2013774 161.8653950 2fd78d7b-8...
    74: blond_ibad...  5.0271023  0.5863298  13.4312921 bc072dd2-d...
    75: rainproof_... -1.5322212 11.2120976  16.4722242 752563db-5...
    76: blond_ibad... -1.9993824  6.9110534  13.7795571 4dd58f6f-2...
    77: rainproof_...  3.0673132 13.0064510 114.3332547 f7d54308-0...
    78: blond_ibad...  7.5396054  5.6862603  31.8250933 2f3bac2f-8...
    79: rainproof_...  3.3548677  5.1921282  10.0869208 ec27974b-b...
    80: blond_ibad...  2.1787720 10.6080742  60.2034043 9fa553b4-3...
    81: rainproof_...  2.3549661  4.4877702   5.5271279 4cab49d7-c...
    82: blond_ibad...  0.4470117 13.7675553  90.1149377 18dd57ee-a...
    83: rainproof_...  6.9190304 14.6001999 198.0295361 91c54d22-4...
    84: blond_ibad... -0.8514540  0.6533526  62.5046593 d10dd44b-c...
    85: rainproof_...  7.0400894  5.7854164  38.0238455 bb46b556-4...
    86: blond_ibad...  1.0266103  9.9040541  44.1507090 b8404984-5...
    87: rainproof_...  2.5296754  2.7146154   2.1475985 be3f9ecb-3...
    88: blond_ibad...  2.6496742 14.3958989 138.5671244 03a68293-8...
    89: rainproof_...  2.7802969  1.7374529   1.7169841 1a38d035-5...
    90: blond_ibad...  4.7660089  6.7805751  40.0158991 688c62a7-c...
    91: rainproof_... -3.8426341  9.0921225  26.9784585 484566a9-9...
    92: blond_ibad...  8.4642487  6.2240028  24.2111318 a83b97c1-e...
    93: rainproof_...  0.3222699  5.7240875  19.1577732 d1697823-8...
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
    1: rainproof_... 13944 runnervm1l...     FALSE terminated
    2: blond_ibad... 13946 runnervm1l...     FALSE terminated

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

    [1] "clayish_nauplius"    "bared_frilledlizard"

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
    1: harebraine... 14199 runnervm1l...     FALSE running
    2: nonlinear_... 14197 runnervm1l...     FALSE running

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
    1: harebraine... 14199 runnervm1l...     FALSE running
    2: nonlinear_... 14197 runnervm1l...     FALSE running

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
