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
    1: sharp_neon...  9108 runnervm1l...     FALSE running
    2: dissectibl...  9110 runnervm1l...     FALSE running

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
    1: sharp_neon...  9108 runnervm1l...     FALSE    running
    2: dissectibl...  9110 runnervm1l...     FALSE terminated

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

            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>
     1: illuminati...  8.90979764 14.58323479 158.1026099 32d5c0bf-c...
     2: illuminati...  0.05300932  9.38812964  31.6443365 7fbd93d6-4...
     3: illuminati...  4.57387962 13.41065001 152.3772316 39293a5b-9...
     4: illuminati...  6.09160812 12.18102767 142.2456887 22984e3d-0...
     5: illuminati... -4.46964080  7.00845118  83.1387168 481c12ff-f...
     6: illuminati...  3.98440915  0.25311296   5.7321349 73bd3d6a-6...
     7: illuminati... -4.06544323  5.40054299  88.9434160 3089eccf-5...
     8: illuminati...  1.74187228  1.59989335  12.4448702 f4e851c1-e...
     9: illuminati...  7.47694697 13.06142316 151.3469835 236b0472-2...
    10: illuminati...  7.16080103  1.18091301  16.1377893 3404859f-c...
    11: illuminati...  6.27159572  9.84722006  96.1214770 2ec6cf05-5...
    12: illuminati... -1.07536373  8.07037554  14.6088488 3aa8f8ff-d...
    13: illuminati... -0.63713783  4.87633136  22.5149377 7263d323-1...
    14: illuminati... -1.74325613 10.10025409   9.2230647 80ed4d70-8...
    15: illuminati...  2.70248455  9.99664432  55.3944536 1b19ef88-4...
    16: illuminati... -4.72138782  9.38132811  59.2645200 3f21fb71-6...
    17: illuminati...  6.74820915 12.27669723 142.5475219 55817984-4...
    18: illuminati...  1.88025643  6.91625953  18.9924917 0ab7ef05-9...
    19: illuminati...  0.12420037  7.59449801  22.7328791 5b838543-6...
    20: illuminati...  8.34771911 13.74806874 150.2118782 7f176a23-c...
    21: illuminati...  2.04866910  5.78592484  11.8555392 3c7a1b26-2...
    22: illuminati... -2.68333820  1.27490953  99.9125339 99744ff0-a...
    23: illuminati... -0.92752996 14.43643524  62.6694500 103ff5b5-d...
    24: illuminati...  6.13929035  3.79465782  26.7743280 65b96b6d-7...
    25: illuminati... -1.86096504  6.17761386  17.6959059 851caa26-e...
    26: illuminati...  3.92958386  5.86470245  20.2353691 7b23da0d-0...
    27: illuminati...  4.04030603  3.59368412   7.6896014 c9fd91f8-b...
    28: illuminati...  3.88799668  3.16303337   4.9055801 9462011e-9...
    29: illuminati...  0.30197426 12.99563832  74.8858685 b49364f3-4...
    30: illuminati...  4.11417030  6.18316229  25.2442940 3d18661b-b...
    31: illuminati...  6.75950342  4.39391101  29.0921540 3bb6c208-2...
    32: illuminati... -3.02602366  8.66936288  11.5483261 3ed7878b-7...
    33: illuminati...  9.33605661  9.84966018  55.9155328 09190559-5...
    34: illuminati...  3.37810800 14.50792782 154.6770289 f9ea469f-b...
    35: illuminati... -1.89658478 14.43510410  31.4482460 697abdea-4...
    36: oppressive... -0.59704057 13.87409949  65.2455372 f48772f6-2...
    37: illuminati... -4.34531981 10.12529603  33.9040756 8c849170-0...
    38: oppressive...  8.12772374  6.10292012  27.6963384 52d9143f-9...
    39: illuminati... -3.19209569  7.39862954  25.3908423 5e5180e5-5...
    40: oppressive...  2.97557883 11.09316339  75.9614837 2adc35e0-c...
    41: illuminati...  4.51913059  2.28618076   8.8619861 8841ed3a-e...
    42: oppressive...  7.18483280 14.37459584 188.6389019 2ffbcc88-0...
    43: illuminati...  0.57064203  1.23379101  33.2912506 fbb9c6e3-b...
    44: oppressive...  4.45720772  1.14130185   7.6859878 300dc656-b...
    45: illuminati...  3.28845972  4.44159529   5.6921131 b845b9a7-d...
    46: oppressive...  5.51008055  7.93485999  62.8716726 26e4716d-d...
    47: illuminati... -2.58579781  0.48382597 111.9960167 7760f682-3...
    48: oppressive... -3.41522886  8.14562511  23.7630959 aaa5fc7a-f...
    49: illuminati...  3.78997541  6.24744016  21.9163397 cd4b36a8-5...
    50: oppressive... -2.60260536 10.22654141   2.3843515 02bad25a-3...
    51: illuminati...  6.95965101 14.56768116 196.7002860 01c1b958-c...
    52: oppressive...  3.63619496  1.78555824   1.5669406 efa0a931-9...
    53: illuminati...  2.08213796 10.40536743  56.5545067 ebc2e142-6...
    54: oppressive...  5.45796536  0.08244028  17.6788424 8432a348-9...
    55: illuminati... -0.26043335  1.61940191  42.3553151 f25ea116-f...
    56: oppressive...  3.52145210 10.84242671  79.3167916 961166cc-a...
    57: illuminati...  8.13837512 10.64860517  89.1167247 59c1a76c-5...
    58: oppressive... -4.22833203 13.36249691   8.3429702 f09a6199-5...
    59: illuminati...  2.89353361  6.84606773  19.7857940 18044ecc-b...
    60: oppressive...  8.75566608 14.65749086 163.4806992 49c046bb-a...
    61: illuminati...  7.17726908 12.42121466 141.2177790 6fe397ba-1...
    62: oppressive... -3.75926241  7.91624480  36.8930301 f2d4bdc0-3...
    63: illuminati...  1.62459949  9.10562316  38.1092694 da2cd60c-8...
    64: oppressive... -2.15672940  5.11619488  28.8695598 1d47dce1-9...
    65: illuminati... -3.07398778 12.01863371   0.4287494 b3624a80-2...
    66: oppressive...  7.91413499  4.59930067  19.0560474 2932b534-9...
    67: illuminati... -1.55729787 13.69368362  34.1579572 0fc6a1d1-a...
    68: oppressive...  6.72070928 13.60743334 174.1680295 98132199-c...
    69: illuminati... -2.14191023  8.45595147   7.1985006 aa1c0d0e-5...
    70: oppressive...  6.64272227  5.71333393  40.0121216 9f68c3c8-8...
    71: illuminati...  4.46302437  2.47080996   8.6318338 ecc8dcdb-e...
    72: oppressive... -2.14989124  2.48373279  61.5216161 e829d8ee-a...
    73: illuminati...  7.27844718 12.50907989 141.7760902 f9c68faf-0...
    74: oppressive... -1.10098685  4.61942669  25.1674636 9fa50294-b...
    75: illuminati... -2.52896432 12.93247128   6.4758557 75531bd0-b...
    76: oppressive...  3.42295389  0.29182287   3.9224694 632a3bef-c...
    77: illuminati...  6.49006056 11.08752824 118.9062651 7be29aec-b...
    78: oppressive...  7.38266855  5.43191791  31.5057451 e0a0ad8a-c...
    79: illuminati... -2.18952806  3.68001354  45.6990848 c97dc65b-f...
    80: oppressive... -4.64698787 10.50742635  41.6139480 f32e70da-c...
    81: illuminati...  2.15455202 10.42200003  57.2903326 21590e69-1...
    82: oppressive...  0.61844920  5.47388564  17.9906864 ef324bc4-d...
    83: illuminati...  5.94259862  8.30222545  70.8629314 64a2d3e7-1...
    84: oppressive... -1.56620091  2.88998821  45.0856199 f922ff68-c...
    85: illuminati...  8.13119566  8.57247579  55.9874360 f235be69-3...
    86: oppressive...  4.80513417 11.62355483 116.7400703 68ba1d9d-5...
            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>

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
    1: oppressive...  9108 runnervm1l...     FALSE terminated
    2: illuminati...  9110 runnervm1l...     FALSE terminated

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

    [1] "sensualist_moray"          "dramatizable_finnishspitz"

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
    1: nonspheric...  9361 runnervm1l...     FALSE running
    2: scholastic...  9363 runnervm1l...     FALSE running

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
    1: nonspheric...  9361 runnervm1l...     FALSE running
    2: scholastic...  9363 runnervm1l...     FALSE running

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
