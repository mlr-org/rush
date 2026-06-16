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
    1: socioecono...  9049 runnervm1l...     FALSE running
    2: fatwitted_...  9047 runnervm1l...     FALSE running

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
    1: fatwitted_...  9047 runnervm1l...     FALSE    running
    2: socioecono...  9049 runnervm1l...     FALSE terminated

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
     1: enthusiast...  5.0276671  0.1986549  14.111694 5fc90153-c...
     2: enthusiast...  0.5551177  1.8382416  29.169833 86126b97-6...
     3: enthusiast...  2.5956044  7.6867330  26.270946 09362285-d...
     4: enthusiast... -2.5715330  7.6055582  13.081453 43a5ff10-0...
     5: enthusiast... -3.5839455  4.2259817  84.813770 d3949390-b...
     6: enthusiast...  8.7492938  8.5530948  45.920546 4199e0cb-f...
     7: enthusiast...  9.1930640  0.9992879   2.311376 b0c3df6f-f...
     8: enthusiast... -0.9257297  4.0578981  28.207052 698dc3bd-4...
     9: enthusiast...  2.6724397  2.0398808   1.831558 b2785cf0-b...
    10: enthusiast... -3.3273150  3.6722833  82.529022 5554a21e-f...
    11: enthusiast...  4.3432521  6.1791424  28.201940 fa64e1b4-5...
    12: enthusiast...  5.3388933  2.5447776  17.478507 73fab4f2-2...
    13: enthusiast...  0.7081505  1.7413843  27.510043 554c0c01-f...
    14: enthusiast...  6.7496520 12.2016194 140.870254 09f15a00-9...
    15: enthusiast...  3.5361318 14.5927500 160.029824 584311cc-a...
    16: enthusiast... -3.7907314  0.5686867 179.794225 ee07ddb0-e...
    17: enthusiast... -1.5207036  4.3748550  29.352558 1d66a1c7-e...
    18: enthusiast...  2.3282270  5.9680032  12.242892 6416bc33-6...
    19: enthusiast...  8.6952403  1.4684126   3.053357 4bc8bb18-e...
    20: enthusiast...  2.4252520 10.1878021  55.870962 93998d66-5...
    21: enthusiast... -0.2644755 11.6304973  46.313813 876000d0-e...
    22: enthusiast...  3.4918753  6.4923025  21.003219 e87839e3-d...
    23: enthusiast...  5.9676175 13.3727219 169.678461 6d77d425-7...
    24: enthusiast...  4.4124216  8.0047982  49.571847 7e506675-5...
    25: enthusiast...  1.6432889  3.6515281   9.311243 780713f3-8...
    26: enthusiast...  8.7124739  3.2610786   4.478601 c610c6be-1...
    27: enthusiast... -2.0131035  0.2905121  94.946505 308e45ef-1...
    28: enthusiast...  1.4722552  6.9926704  20.282741 11310659-7...
    29: enthusiast... -3.9449524  0.1707702 202.658867 14a1a0ec-f...
    30: enthusiast...  1.6774889 13.7423428 109.952394 2efd5518-7...
    31: enthusiast...  5.9999377  6.2628704  45.860806 00aa34d4-1...
    32: enthusiast...  0.8190037 10.2789548  46.761430 3a249649-b...
    33: enthusiast...  0.9981405  2.0228419  21.539720 8aba4376-4...
    34: enthusiast... -2.7277040  7.4150445  16.320622 c831382e-5...
    35: enthusiast... -1.6527815 10.3341237  11.038172 24b41ea3-8...
    36: lovecrafti... -4.4397297 10.2301642  36.383009 4813335e-5...
    37: enthusiast... -2.0031159 11.6361649   9.700889 be58601e-2...
    38: lovecrafti...  0.6984362 11.2004997  56.404735 b666b77e-6...
    39: enthusiast... -4.3031216  2.9204563 157.967897 31dfe2b2-4...
    40: lovecrafti... -4.4620366 10.3392261  36.076515 1b843a50-8...
    41: enthusiast...  7.3784787  0.3428038  15.292593 cdfe055b-5...
    42: lovecrafti...  7.3238981 12.5986667 143.124598 54a67231-7...
    43: enthusiast...  1.7688063  2.4899317   9.319111 1c307014-c...
    44: lovecrafti...  0.7709697 13.3984612  89.967435 632d02f5-f...
    45: enthusiast... -4.2673437  7.4947556  64.379795 356b5286-d...
    46: lovecrafti...  8.8553905 14.5666239 158.914511 210b8a88-4...
    47: enthusiast...  7.0639672  3.2932726  21.187694 8b4f5cf6-9...
    48: lovecrafti...  6.3479130  2.7656396  22.347700 1e78ac06-0...
    49: enthusiast... -3.3382321  0.7235555 145.280046 a90ed5bf-a...
    50: enthusiast...  3.3449551  6.7967990  22.451855 f0a4600d-f...
    51: lovecrafti...  2.8104278  4.8313921   6.136110 fbbef62e-f...
    52: enthusiast...  6.2055269 13.3677945 170.113493 f588e36d-9...
    53: lovecrafti...  8.4280018 10.4858312  80.881552 d06ad023-f...
    54: enthusiast... -0.7036853  3.1773632  33.373741 e11bcc78-b...
    55: lovecrafti... -1.6278123  5.6611102  20.158435 90ab930f-c...
    56: enthusiast... -0.6729165 13.5698089  58.986799 7030efbc-a...
    57: lovecrafti...  6.3681304  9.3337409  87.302116 ed8b9a23-9...
    58: enthusiast...  7.4630614 10.5507303  98.913258 9fa3a3e1-c...
    59: lovecrafti...  3.9489248  7.6273238  38.144031 c70a129d-9...
    60: enthusiast... -1.8721512  6.1476744  17.939421 846bbd61-0...
    61: lovecrafti...  5.8811396 11.1418153 119.512228 5976f6b4-b...
    62: enthusiast... -4.7062476 13.5104719  18.012488 e20a5e9c-e...
    63: lovecrafti...  1.9094377 14.5432247 130.268634 635fd079-6...
    64: enthusiast...  4.2838261  5.1812843  19.175857 4c6a7cd3-d...
    65: lovecrafti...  1.8011563 10.4746371  55.724016 d8b13541-5...
    66: enthusiast...  7.7777765  4.8871773  22.640632 f9747d00-d...
    67: lovecrafti... -2.1619718  9.1018039   5.537454 1d000046-1...
    68: enthusiast...  3.0858490  4.3269681   4.445246 d519ec72-6...
    69: lovecrafti...  2.2453438  5.5433475  10.082392 e461c5a0-4...
    70: enthusiast...  9.4270722  0.8828491   2.939025 d00f7f0a-0...
    71: lovecrafti...  2.3847221 14.7781812 143.179519 2a9e42c3-a...
    72: enthusiast... -4.6825990 11.3996966  33.581965 bdec091f-8...
    73: lovecrafti...  3.9774073  8.4155329  48.479278 2482fe83-f...
    74: lovecrafti... -2.1116601  2.8674938  55.032023 68df3892-a...
    75: enthusiast... -0.4004508  8.4489301  22.049684 480d1d84-1...
    76: enthusiast...  1.7540662 12.2072225  82.234781 db410a66-a...
    77: lovecrafti...  1.2754926  8.3683076  30.335101 7de43893-9...
    78: lovecrafti...  0.3555293 12.5497334  69.400924 9cc62851-0...
    79: enthusiast... -4.9190658 10.7143790  50.913801 2bfaca6d-4...
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
    1: lovecrafti...  9047 runnervm1l...     FALSE terminated
    2: enthusiast...  9049 runnervm1l...     FALSE terminated

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

    [1] "compatible_ibisbill"       "grave_westafricanantelope"

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
    1: determinan...  9302 runnervm1l...     FALSE running
    2: elephantin...  9300 runnervm1l...     FALSE running

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
    1: determinan...  9302 runnervm1l...     FALSE running
    2: elephantin...  9300 runnervm1l...     FALSE running

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
