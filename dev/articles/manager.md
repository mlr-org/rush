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
    1: sensitive_...  9023 runnervm1l...     FALSE running
    2: unhygenic_...  9021 runnervm1l...     FALSE running

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
    1: sensitive_...  9023 runnervm1l...     FALSE    running
    2: unhygenic_...  9021 runnervm1l...     FALSE terminated

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

            worker_id           x1          x2           y          keys
               <char>        <num>       <num>       <num>        <char>
     1: ungracious...  0.207410976  1.07621930  40.5492609 227fb914-4...
     2: ungracious...  4.220786682 11.54453208 104.6828827 e4c55e3b-d...
     3: ungracious...  5.876513430  5.97310459  42.4841430 c5c17ef8-f...
     4: ungracious...  6.432087817  8.18826009  69.6315513 7983b195-b...
     5: ungracious...  0.234293462 13.04536138  74.2650566 39936115-5...
     6: ungracious...  7.971429920 11.60666271 110.5765461 6671e65a-1...
     7: ungracious...  7.592173611  6.45760668  38.4401272 c6f9b3f4-1...
     8: ungracious...  5.363228915  3.69584375  22.1467134 8dc6286f-1...
     9: ungracious...  5.241503642  3.27835185  19.1372652 07b2de3b-b...
    10: ungracious...  5.614671504  9.19903791  82.5404489 c34defcf-2...
    11: ungracious...  2.028014454 13.92103727 118.4904427 ff25b9f0-b...
    12: ungracious...  6.746838756  0.34099743  19.2308199 768fcfe1-5...
    13: ungracious... -4.538425096  8.47717509  63.1987549 06dc4912-6...
    14: ungracious...  7.462510567  6.91261208  44.9721977 baa7aac1-8...
    15: ungracious...  9.397855478 11.21356592  77.1596765 91fb5cbc-f...
    16: ungracious... -2.010931325 10.76294656   6.9906081 4482082a-f...
    17: ungracious...  8.877989932  8.60599991  44.7476104 93e35b69-4...
    18: ungracious...  3.439515757  3.70756118   3.5547187 abbc0754-a...
    19: ungracious...  9.505449291  3.30622683   1.0102745 b2c436ec-a...
    20: ungracious...  8.929676780  7.41358695  29.9017240 82a0d00b-9...
    21: ungracious...  8.424766226  6.24487669  24.9202824 78e47fe0-2...
    22: ungracious... -3.186092252 10.88295450   2.6551270 9084854e-1...
    23: ungracious...  9.745523340  1.68305780   2.0449082 9523a4eb-7...
    24: ungracious...  1.288396561  7.08619095  21.2155492 7cbd444e-8...
    25: ungracious... -0.375983996 11.08300976  38.8796617 d3653dbc-d...
    26: ungracious...  7.524338666  6.64057124  41.2200978 001809d7-c...
    27: ungracious...  7.438719274  5.68257479  32.9995180 70ed8c8c-e...
    28: ungracious...  8.794031903  1.87505851   2.2596813 08716dff-5...
    29: ungracious...  0.514043818  0.09601369  44.5755262 d394be66-b...
    30: ungracious...  5.872383555  2.49000472  20.7111604 2f3f0bf6-3...
    31: ungracious...  1.732313696  9.85427929  47.1899071 c0b35f7d-0...
    32: ungracious... -1.975475949  9.11219898   6.5067238 ec4263e1-e...
    33: superluxur...  5.897961258 10.04074134  98.7117822 a1c74445-b...
    34: ungracious...  6.415275454  4.94482181  34.2514990 17c25524-8...
    35: superluxur...  1.265138608 11.10868969  60.7129312 1b5b336c-5...
    36: ungracious...  1.967508094  1.51420767   9.7289982 5154a1f5-d...
    37: superluxur...  2.171376438 10.62517718  60.4035484 db84f004-7...
    38: ungracious...  8.542835581  1.51920622   3.9939453 9699d1e7-9...
    39: ungracious...  3.725681695  0.40188402   4.1262881 24738438-0...
    40: superluxur...  9.845158878  1.76172616   2.4235435 beddb69a-5...
    41: ungracious... -2.438416356  0.25984053 110.6096996 9d28fc2d-1...
    42: superluxur...  9.624520748  7.15133431  20.8630436 e8d1916e-8...
    43: ungracious...  5.948157328  2.84406528  22.0966442 9d44b129-c...
    44: superluxur...  3.426445184  2.12118849   0.7881695 f2d64dc0-2...
    45: ungracious...  7.427802006  3.90007442  20.7003234 544973ca-e...
    46: superluxur... -0.994948886  7.91992686  15.2722761 244f9d98-1...
    47: ungracious...  4.231586852 14.76745068 179.5091048 87f969da-1...
    48: superluxur...  0.306504211 12.62094366  69.5166711 6995f27b-8...
    49: ungracious...  1.164376959  2.67580068  16.5058463 a58a2673-d...
    50: superluxur... -3.176487823 10.81428376   2.7899391 4f6a88fc-3...
    51: ungracious...  5.214811638  1.63584286  14.8023179 92659b33-a...
    52: superluxur...  7.582770907 14.40029704 182.6334778 13bc83e5-4...
    53: ungracious...  7.786821214  1.09369764  10.7642797 3146107e-a...
    54: superluxur... -0.209876838  4.34521809  23.3694462 be95a339-c...
    55: superluxur...  0.693135534  3.74533941  18.8591328 2a2a9002-e...
    56: ungracious...  2.473842758  3.41799076   2.7790741 2b449dfa-f...
    57: ungracious...  1.333351759  2.00294422  16.6880658 d1425ca6-f...
    58: superluxur...  7.047626778  3.80047715  23.6939015 cb323595-c...
    59: ungracious...  3.662298767  8.04663575  39.4030745 12f515a2-9...
    60: superluxur...  7.842896348 14.05871341 168.7354094 7811eac8-0...
    61: ungracious...  0.474110942  7.12196263  21.9562289 4cfd0df7-4...
    62: superluxur... -4.749804020  3.42124988 180.7343231 e6ed8cbe-c...
    63: superluxur...  7.230435826  2.03866317  16.2350489 ffb97eb7-d...
    64: ungracious...  1.746468520 14.03871670 116.9873532 cac996db-a...
    65: superluxur...  3.244235697  8.63133230  41.8578866 eef3787e-1...
    66: ungracious...  1.399090993  8.39160435  30.6978319 a0a1059e-7...
    67: ungracious...  1.726477921  3.13585034   8.7625994 3ecc6ef7-b...
    68: superluxur...  3.278120555  9.05969119  47.9421952 61628810-a...
    69: ungracious...  4.573893355 11.69502485 114.1883320 2fe55547-1...
    70: superluxur... -3.970606890  9.81871717  24.1006628 74d6fff7-0...
    71: superluxur...  2.934592072 14.49110333 145.7845674 3041c90f-2...
    72: ungracious...  9.833248772  8.42829262  32.4044917 eb8eae59-9...
    73: ungracious...  9.911025482  3.22011904   1.6035112 3439c225-1...
    74: superluxur...  0.007387499  5.35581526  20.0018237 ee287e8e-7...
    75: superluxur...  6.919356367 12.20583595 139.4574947 32618391-6...
    76: ungracious...  3.724973361  5.83753284  17.7749035 40a51742-f...
    77: superluxur...  2.309648213  7.73749691  25.8524227 2d65574b-0...
    78: ungracious...  2.252031357  5.06737296   7.9387116 58a7d7b5-f...
    79: superluxur...  7.975097079  2.08326211   9.1530379 d2a5f110-c...
    80: ungracious...  9.450043658 13.36780840 118.5885897 9015ad2d-4...
    81: superluxur... -1.641761386  8.87055417   9.3273641 5c8684e6-6...
    82: ungracious... -2.514381359 14.09615992  12.9686599 ddd81669-8...
    83: superluxur... -4.318385270 11.49287199  20.6714622 c33e9ff5-0...
    84: ungracious...  3.945681602 13.98591906 153.5103955 2c8f0ee9-7...
    85: ungracious...  4.266211141 12.57319518 127.1173520 e2e113da-a...
    86: superluxur...  8.477061163 12.24564685 113.6836800 8c6086a6-7...
    87: superluxur... -3.622702043  6.90938460  44.4131753 648f5b73-a...
    88: ungracious...  4.935434473 11.14905765 109.2904160 bbef546b-7...
    89: superluxur...  9.292668818 13.61503278 127.0263958 25513b04-5...
    90: ungracious...  9.030034359  8.05651746  35.8798417 ffcda7d7-3...
            worker_id           x1          x2           y          keys
               <char>        <num>       <num>       <num>        <char>

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
    1: superluxur...  9023 runnervm1l...     FALSE terminated
    2: ungracious...  9021 runnervm1l...     FALSE terminated

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

    [1] "finegrain_sheep"         "socialminded_chevrotain"

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
    1: bardic_dun...  9275 runnervm1l...     FALSE running
    2: silvicultu...  9277 runnervm1l...     FALSE running

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
    1: bardic_dun...  9275 runnervm1l...     FALSE running
    2: silvicultu...  9277 runnervm1l...     FALSE running

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
