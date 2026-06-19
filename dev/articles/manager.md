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
    1: closeknit_...  8799 runnervm7b...     FALSE running
    2: animalisti...  8801 runnervm7b...     FALSE running

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
    1: animalisti...  8801 runnervm7b...     FALSE    running
    2: closeknit_...  8799 runnervm7b...     FALSE terminated

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
     1: turtleshel... -3.08886697  1.8393955 106.6918906 e32ed431-5...
     2: muddy_corm... -4.13817900 12.5625942   9.7829631 f9b20414-5...
     3: muddy_corm...  4.81174424 13.4858713 158.6480153 ab6bf51f-a...
     4: muddy_corm...  6.37760795  3.9982791  27.9352810 b0c30cd8-4...
     5: muddy_corm...  4.11165819  8.1748410  47.2759215 4242b495-d...
     6: muddy_corm...  3.78256308  3.9741671   6.9088955 cb1a9af0-1...
     7: muddy_corm...  0.23300877 11.7082957  56.2133505 69ebebb0-8...
     8: muddy_corm...  8.58496007  1.5898556   3.6613902 4e978d35-4...
     9: muddy_corm...  9.92085195  1.9950751   2.4205515 6e7e5063-4...
    10: turtleshel...  0.59787352  3.2186223  21.4558897 739df23c-3...
    11: muddy_corm...  1.11231396  9.7903611  43.4187552 a81a3db1-6...
    12: turtleshel...  8.28795293 13.0447719 135.0519746 0b4e4ae6-3...
    13: muddy_corm...  2.43738543 12.2495401  90.3158150 0ecfda0c-0...
    14: turtleshel...  4.18321232 12.4452511 122.7104082 f685ed79-b...
    15: muddy_corm...  0.07483485  9.8098903  35.0065451 52a6f1f9-0...
    16: turtleshel... -1.38453642  8.4370290  11.7783660 2a6c7f59-6...
    17: muddy_corm...  8.85508053  5.9100266  16.9195766 fe3fd677-a...
    18: turtleshel...  5.63694721  2.3420881  19.1268680 8b483346-3...
    19: muddy_corm...  3.73255036  2.3902543   2.3082980 8b74abb5-8...
    20: turtleshel... -0.94493093 10.3924408  23.3154804 9680c04c-1...
    21: muddy_corm...  6.23143760  9.6520554  92.7491684 e77f32f4-6...
    22: turtleshel... -1.31978161  1.1388367  64.0333751 af7a7ef1-5...
    23: muddy_corm... -2.85043639 11.9202255   0.9135663 6e91a512-7...
    24: turtleshel...  8.18745895  1.3965455   6.9110015 0e9fc863-b...
    25: muddy_corm...  0.93996026  3.8371504  16.2734712 7bdecea0-1...
    26: turtleshel... -0.55167756  8.1970456  19.8152540 69484e8f-4...
    27: muddy_corm...  9.34423229 11.0396549  74.9362775 88074020-3...
    28: turtleshel...  0.81621147  7.2944647  22.8645846 b944b49a-4...
    29: muddy_corm... -4.95258986  7.8835987  96.3246167 52adc8f6-9...
    30: turtleshel...  6.19096485  7.0236794  54.6730524 cc66e0b0-e...
    31: muddy_corm...  3.77712008 13.6928634 142.9632519 a90cec8a-7...
    32: turtleshel... -2.51810015  3.3682361  57.8350189 7e5039f2-e...
    33: muddy_corm...  6.83067070  6.7868161  49.9030451 1de66d60-5...
    34: turtleshel...  5.59099051  0.7825076  17.5198616 56d6b3c7-1...
    35: muddy_corm...  9.03006366 14.0328649 142.0494602 fc2e34be-b...
    36: turtleshel...  9.57198586  6.8168662  18.2670691 187a4a5c-8...
    37: muddy_corm...  9.00582554  3.7502850   3.8075743 4474a105-1...
    38: turtleshel... -1.46414397 11.7906560  21.1565867 1a811d0a-6...
    39: muddy_corm...  4.28846617 13.2782833 143.5907319 a9b4ae2b-b...
    40: turtleshel...  2.52981422 14.0936158 129.6750058 5792129c-e...
    41: muddy_corm...  1.00608905 14.7155747 118.8944165 3097a72c-8...
    42: turtleshel... -2.83958330  9.6910947   4.3289503 7d300982-0...
    43: muddy_corm...  1.59509032  8.7811124  34.6777456 ec664697-c...
    44: turtleshel...  9.42896232 11.2707437  77.7009602 64a369e6-1...
    45: muddy_corm...  8.70294144  7.3561044  32.1981480 f47c47ae-2...
    46: turtleshel...  1.85810687  1.0531945  13.2109339 d75a13ed-b...
    47: muddy_corm...  6.22340979  7.1496393  56.2005371 be67ef23-8...
    48: turtleshel... -3.21198807  7.6228676  23.6728673 7fd991b3-9...
    49: muddy_corm...  8.27895991  3.1768755   8.2874141 33d3571f-5...
    50: turtleshel...  5.30057681 10.9096278 109.7318312 5245bab9-7...
    51: muddy_corm...  0.88219246  0.3720755  34.8022890 54a040c7-b...
    52: turtleshel...  4.76818309 10.0765308  86.7177491 20b23226-8...
    53: turtleshel...  3.11263923  3.9048424   2.9848575 a6ab33c6-0...
    54: muddy_corm... -1.38902308 13.3938208  36.0789360 ee4d8402-7...
    55: turtleshel... -1.75504448  6.8667108  13.6438471 2e3a5bd6-0...
    56: muddy_corm... -2.76697053 12.7828536   2.9960170 73102669-f...
    57: turtleshel...  1.40884360 12.7322813  87.5538274 6fc60b2a-9...
    58: muddy_corm... -2.39016803 11.6012109   4.1053114 a0520e23-8...
    59: turtleshel... -0.91045802 12.2893574  38.2932780 9d2b21d5-6...
    60: muddy_corm... -4.12222975 11.0758572  18.1994695 63b5ab06-4...
    61: turtleshel... -2.61932517  2.5585367  73.8695787 8c03f28d-f...
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
    1: turtleshel...  8799 runnervm7b...     FALSE terminated
    2: muddy_corm...  8801 runnervm7b...     FALSE terminated

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

    [1] "lavish_bullfrog"     "medium_sandbarshark"

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
    1: surah_toad...  9052 runnervm7b...     FALSE running
    2: semimystic...  9054 runnervm7b...     FALSE running

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
    1: surah_toad...  9052 runnervm7b...     FALSE running
    2: semimystic...  9054 runnervm7b...     FALSE running

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
