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
    1: relievable...  9074 runnervm1l...     FALSE running
    2: criminativ...  9076 runnervm1l...     FALSE running

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
    1: criminativ...  9076 runnervm1l...     FALSE    running
    2: relievable...  9074 runnervm1l...     FALSE terminated

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
     1: painful_ca... -4.75209821  0.9790803 250.675214 c80693f0-4...
     2: painful_ca... -3.91627125  7.8428668  43.732611 269e4303-7...
     3: painful_ca...  6.82981622 12.8602280 155.191832 66ad5af9-6...
     4: painful_ca... -4.22123401  8.3307503  50.220188 ce8d97ac-9...
     5: painful_ca... -3.52913069  2.3936365 118.444606 f1d8bcad-f...
     6: painful_ca...  2.25181741  7.5604765  24.108468 e5cfb82d-a...
     7: painful_ca...  5.35513541 12.0601008 134.094576 d3ea092d-7...
     8: painful_ca...  6.09619457  3.0916033  23.406932 491c0865-2...
     9: painful_ca...  0.89220401 14.3014134 108.544031 e51c4a6c-a...
    10: painful_ca... -3.46482028 11.8928573   2.269730 07467f7c-1...
    11: painful_ca...  4.55331153  9.0047847  65.833349 88ce4c23-c...
    12: painful_ca...  7.99797322  5.9185713  27.842668 f01d9926-3...
    13: painful_ca... -3.84681382 10.4777997  15.335310 483f8e1d-c...
    14: painful_ca... -0.29914882  3.6399535  27.285155 d136a6e9-9...
    15: painful_ca... -3.99127541  9.8976549  24.024061 661f666f-2...
    16: painful_ca...  2.79792986  9.1421002  44.306228 54c19be7-f...
    17: painful_ca...  4.48357721 10.6518227  92.291571 7c7ac087-0...
    18: painful_ca...  3.26328912  8.9809665  46.694752 be68c1f5-7...
    19: painful_ca...  8.03406793  4.2507027  15.564419 8702dc81-3...
    20: painful_ca...  4.89578211 12.7193586 142.050031 92fff6ed-9...
    21: painful_ca... -2.66976764  5.2956715  35.952988 25f85bf9-f...
    22: painful_ca... -1.52820799 12.4440198  24.173665 909e357a-b...
    23: painful_ca...  6.59340289  9.8434862  95.202751 d043c5cc-4...
    24: painful_ca... -0.46234143  5.1626832  21.156458 bf3bb1a8-f...
    25: painful_ca...  3.45915431  4.4358935   6.616509 7505d08c-0...
    26: painful_ca...  2.50533401  1.6365971   3.685499 a6c92603-7...
    27: painful_ca...  3.74309820  9.1105688  54.760584 f610f6ce-3...
    28: painful_ca... -2.00801881  8.2213113   8.170567 8835b687-a...
    29: painful_ca...  4.65603709 13.5735123 157.891396 0ff30f06-5...
    30: painful_ca...  4.88689515  8.3472953  61.227034 01427578-c...
    31: painful_ca...  5.38563831  3.2096418  20.124934 6fb5ee70-c...
    32: painful_ca... -1.49982073  3.1898670  40.796536 84adbd11-5...
    33: painful_ca... -0.67613722  6.6847176  17.692509 46793d89-2...
    34: painful_ca...  4.95474148 12.5498031 139.184527 445135e2-f...
    35: painful_ca...  4.74671254  0.7559009  10.689711 834ef5a0-6...
    36: silt_masti...  3.53295729  2.6560808   1.568136 473603a5-a...
    37: painful_ca... -0.76110446 11.8886188  38.135188 1abb8e88-7...
    38: painful_ca... -1.06988463  3.5342989  33.242029 1e868b9a-2...
    39: silt_masti... -2.79736435  9.0822833   6.629208 ae861390-c...
    40: painful_ca... -3.55682689  3.1554455 104.028100 f6d6776d-8...
    41: silt_masti... -4.62237080  6.5304867 101.036662 63fe5638-5...
    42: painful_ca... -4.71934364 12.1808577  27.769286 0e738f23-3...
    43: silt_masti...  8.51635616  6.7990463  28.932177 0ba12e14-5...
    44: painful_ca...  2.36372934  8.6333431  35.348523 6d765157-e...
    45: silt_masti...  6.84786814 10.5683471 106.644134 5f62cf14-6...
    46: painful_ca...  3.79371906 12.7778949 122.413696 672af92a-5...
    47: silt_masti...  0.22856102 12.5855886  67.552176 21dda4ae-4...
    48: painful_ca...  3.18654336  7.2896448  25.904421 8985334c-9...
    49: silt_masti...  7.48401493  0.9549621  13.608537 a8419853-4...
    50: painful_ca... -4.11318140 11.2333524  16.824418 0d3ac930-9...
    51: silt_masti... -3.62374530  4.5061843  81.730702 47cc695c-1...
    52: painful_ca... -4.46329020  3.9659484 144.782131 410dd15f-6...
    53: silt_masti...  1.92453517  8.6975695  34.574169 2c74ae58-e...
    54: painful_ca...  4.60667677 10.5116960  91.832586 cd11220c-6...
    55: silt_masti...  6.25770427  0.8590388  19.656708 fe56407f-6...
    56: painful_ca... -1.21762028  7.6500924  13.550941 9dff5854-3...
    57: silt_masti...  8.02211191 14.4818020 175.728464 e13fff79-8...
    58: painful_ca...  5.08593701  2.7207055  15.675633 0877e5ab-6...
    59: silt_masti...  5.90594410  2.0905867  19.895604 4f5a6db7-e...
    60: painful_ca... -4.17964315  3.9204672 125.868446 de3259f9-9...
    61: silt_masti...  6.21728125  6.7321117  51.319262 1bdb9ffc-e...
    62: painful_ca...  6.53037469 11.1366678 119.728804 d08b6ec2-4...
    63: silt_masti...  6.44039532 13.3588850 169.563057 45dd9d11-2...
    64: painful_ca...  5.53157527 11.6267181 126.796655 aada0332-f...
    65: silt_masti...  4.18864531 12.1966297 117.484735 dd6f2fd8-b...
    66: painful_ca...  1.07285560  8.3292625  29.703235 c86f9838-d...
    67: silt_masti... -4.70964541  9.7920989  53.124696 f7e9b52f-f...
    68: painful_ca... -2.58140333 12.0035049   2.935168 c502795e-2...
    69: silt_masti... -0.72674847 13.0657203  51.291370 e2938370-9...
    70: painful_ca...  3.08156150  8.9085948  43.794708 1ba50ce9-9...
    71: silt_masti... -2.14953266  7.9433475   9.052080 bc3e901a-8...
    72: painful_ca...  2.77764997  0.7677105   4.296496 6642615c-8...
    73: silt_masti... -0.08744539 10.2942874  36.822186 62c7dfb0-0...
    74: painful_ca...  1.48359463  9.2568309  39.284649 059fb5d2-6...
    75: silt_masti...  3.10829578  7.0389367  22.850210 3c9c6856-9...
    76: painful_ca...  5.64177599  2.7508854  20.312150 630e9919-2...
    77: silt_masti...  1.68820806  2.9905918   9.352287 47568e33-c...
    78: painful_ca...  6.19015562  1.3122367  19.606422 e38844b8-5...
    79: silt_masti...  0.43415262 10.5714237  46.148454 91a038f9-0...
    80: painful_ca...  7.20854890  4.7383517  28.014030 cfbca821-9...
    81: silt_masti...  2.91473895  5.5895606  10.447056 b71e9663-7...
    82: painful_ca...  5.23235745 10.9724505 110.091864 3f90f980-6...
    83: silt_masti... -0.72315626  9.6720104  23.218633 2e1fc916-2...
    84: painful_ca... -4.40039227  7.9860391  63.585806 d282e767-5...
    85: silt_masti...  5.84304079 13.1867907 164.511264 69e09bef-8...
    86: painful_ca...  4.91677596  3.4363810  16.522855 652d6b15-a...
    87: silt_masti...  7.57455290  4.0359916  19.827800 fd658573-6...
    88: painful_ca...  5.98256266  8.4274667  72.832392 51b26fe1-3...
    89: silt_masti...  4.92192189 10.3036380  93.133847 0c51cb8a-f...
    90: painful_ca...  7.64371184  5.6752215  30.432234 905df2f2-4...
    91: silt_masti... -0.90130029 11.7943325  34.063383 c5ae5a26-7...
    92: painful_ca... -4.60696298  3.8578402 158.224983 f771e267-f...
    93: silt_masti...  3.38264126 13.9110371 140.305526 07428552-e...
    94: painful_ca...  9.57189395  5.1292323   6.889062 dd392e76-a...
    95: silt_masti...  6.21815521  2.8993913  22.825111 612a8ea6-a...
    96: painful_ca...  4.56467502 14.5365513 180.451949 75bef181-c...
    97: silt_masti...  7.21299488  0.0676903  17.119254 74c09771-6...
    98: painful_ca...  8.09730609 11.7563936 111.186613 4511fdba-b...
    99: silt_masti... -0.85409332  7.8647415  16.476714 6eeb1d24-f...
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
    1: painful_ca...  9074 runnervm1l...     FALSE terminated
    2: silt_masti...  9076 runnervm1l...     FALSE terminated

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

    [1] "frolicsome_stickinsect" "disallowable_antelope" 

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
    1: pseudozool...  9350 runnervm1l...     FALSE running
    2: stylish_co...  9348 runnervm1l...     FALSE running

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
    1: pseudozool...  9350 runnervm1l...     FALSE running
    2: stylish_co...  9348 runnervm1l...     FALSE running

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
