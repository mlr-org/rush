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
    1: glowing_wh...  9553 runnervmrg...     FALSE running
    2: fascist_me...  9551 runnervmrg...     FALSE running

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
    1: fascist_me...  9551 runnervmrg...     FALSE    running
    2: glowing_wh...  9553 runnervmrg...     FALSE terminated

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
     1: juiced_ann...  8.53292882  0.9678041   4.705695 4cf89d61-4...
     2: juiced_ann...  6.29010586  2.7426015  22.299278 4fa1d522-a...
     3: juiced_ann...  8.85882032  6.4932676  21.735756 9df28261-9...
     4: juiced_ann...  2.88192696 12.5350923 101.699764 5fc522f7-c...
     5: juiced_ann...  4.44752969 12.1487462 121.375290 bfa0b1a8-1...
     6: juiced_ann...  8.01401930  8.3876087  55.330795 7b42e55c-5...
     7: juiced_ann...  8.23645160  4.1945225  12.865309 9af098f8-3...
     8: juiced_ann... -4.94538112 11.9059511  38.475547 142b35f4-7...
     9: juiced_ann...  1.58004062  1.7255029  14.247198 f1463237-4...
    10: juiced_ann...  1.13504228  2.4413449  17.734061 d69d9043-3...
    11: juiced_ann...  1.92224599  6.1571349  14.197293 14c530e6-a...
    12: juiced_ann... -2.92143434  9.6572778   5.018221 3a1741cc-5...
    13: juiced_ann...  2.66437088  7.4056816  23.835031 f219a19e-8...
    14: juiced_ann...  4.88264961 12.8910775 145.775779 60a06d5e-b...
    15: juiced_ann...  4.73441529  8.4558454  60.554351 9528ede5-3...
    16: juiced_ann...  7.41522525 13.6492445 166.543789 f56756ed-9...
    17: juiced_ann...  4.63183562 12.0512208 122.681900 1b113ab7-8...
    18: juiced_ann...  9.14495893  8.9771387  46.038109 ea08b814-9...
    19: juiced_ann...  4.64431767 10.9001239  99.697902 630eadc8-b...
    20: juiced_ann...  2.73404891  2.8336053   1.232430 b3cc3f2a-f...
    21: juiced_ann... -3.04064847  5.4174075  44.222401 3ec1a177-7...
    22: juiced_ann... -3.21240352 10.9144141   2.767165 b33e3367-e...
    23: juiced_ann... -4.44326882 14.7536152   8.201267 0746c561-9...
    24: juiced_ann...  1.95966743 12.9082329  97.200019 7d9396a5-d...
    25: juiced_ann... -3.67230777 10.9412042   8.717994 848cbe5d-b...
    26: juiced_ann... -3.20745151 10.0554597   6.075373 a06192bc-7...
    27: juiced_ann... -1.90351312  2.5326819  55.374162 a6d0f6b6-4...
    28: juiced_ann... -4.18261056  2.2560969 165.441434 4a56ca39-d...
    29: juiced_ann... -3.01111079  1.9013275 101.729247 c97a4eed-0...
    30: juiced_ann...  2.18067719 10.6857947  61.383959 e7c1295f-0...
    31: juiced_ann...  2.10609618  8.7179699  35.317992 7d82043f-1...
    32: juiced_ann... -0.79228273  4.6138629  24.185807 5777edab-5...
    33: juiced_ann...  3.18637052  4.3047677   4.669380 622311a6-5...
    34: juiced_ann...  0.99590534 12.8630516  84.442743 0e272fc6-6...
    35: joyless_af...  4.26110350 13.2009571 141.234639 d85274fa-b...
    36: juiced_ann... -0.15369572  6.2042811  19.490806 655d32d6-b...
    37: joyless_af... -0.30106687  8.9815437  25.373660 e0d5e9ef-f...
    38: juiced_ann...  7.22784108 11.3536665 117.805104 9ef3a9df-6...
    39: juiced_ann...  5.99880744  0.0872050  20.245039 122e6693-f...
    40: joyless_af...  8.01381153  1.5424580   8.471821 caab543b-7...
    41: juiced_ann...  3.04240787 13.3154695 120.607202 57016a0c-b...
    42: joyless_af...  6.19091961  1.8190028  20.080881 9ac4ff30-c...
    43: juiced_ann... -4.92252926  2.4166606 223.650067 8063ec1b-0...
    44: joyless_af...  5.15926741 14.2249506 183.085656 7eaef8af-8...
    45: juiced_ann...  6.54228452  9.4512495  88.742655 0816a2a6-e...
    46: joyless_af...  9.88608876 10.5184127  59.569613 924dcea4-a...
    47: juiced_ann...  7.96606576  1.1272677   9.079798 ecf52679-7...
    48: joyless_af... -3.16520351 10.4182588   4.062259 ebaf4add-e...
    49: juiced_ann... -1.59398952  3.3456891  40.241715 9f1c7c8a-6...
    50: joyless_af...  4.12225565 12.9009343 131.590192 15a24d65-7...
    51: juiced_ann... -1.64631885 12.7688377  23.704135 b5d93cf1-7...
    52: joyless_af...  3.84880620 11.3759943  94.628721 3f9fc89f-c...
    53: juiced_ann...  0.08583458  8.3152203  25.573568 6dba0837-1...
    54: joyless_af... -0.74558508  5.5075652  20.120180 9bb27284-5...
    55: juiced_ann...  8.90403604  3.7315677   4.428879 2b500e04-9...
    56: joyless_af...  4.82671549  6.5458472  38.324668 410a595b-8...
    57: juiced_ann... -1.22082929  3.0903792  38.745994 ed7f99ee-3...
    58: joyless_af...  1.06179111  3.7753936  15.142078 78157d5c-8...
    59: juiced_ann... -4.36758228  8.4828681  54.815975 80b17407-0...
    60: joyless_af...  7.35301949 14.1001929 178.919943 6c851a82-6...
    61: juiced_ann...  6.44994921  2.1101234  20.471350 18ce47a6-2...
    62: joyless_af...  4.76637472  1.0847724  10.587907 0755fef1-c...
    63: juiced_ann... -4.29971675 13.5128909   9.102671 00a6b1b6-b...
    64: joyless_af...  2.72157391 14.3806046 139.418603 f414b258-b...
    65: juiced_ann... -3.92390014  3.3653601 121.319574 71226501-6...
    66: joyless_af... -0.96664045  9.5511163  19.034128 57f2015b-a...
    67: juiced_ann...  5.55623149  1.4680118  17.278974 10f2cf7e-0...
    68: joyless_af... -2.51191505  3.3170962  58.427300 27ea31f6-c...
    69: juiced_ann... -4.81738581  9.2979625  65.281337 38912561-6...
    70: joyless_af...  7.64947684  7.0416340  43.951533 128f3c9c-0...
    71: juiced_ann...  0.22819959 12.2277304  62.704792 08fb3785-8...
    72: joyless_af...  0.16643218  1.1217765  40.785352 c75009f7-a...
    73: juiced_ann...  5.10917837  8.3920103  64.852289 5e478780-9...
    74: joyless_af...  2.32628566 11.9671324  83.885072 066cc5c6-6...
    75: juiced_ann... -3.52375277  7.7794569  30.606239 9ad1d801-7...
    76: joyless_af...  9.25983289  9.6251001  53.609930 b5785387-a...
    77: juiced_ann... -4.93350991  9.3145472  71.113971 1ccfd22a-8...
    78: joyless_af... -3.36887565  7.1530221  32.848945 d5a9599f-0...
    79: juiced_ann...  3.20160422  5.0585456   8.423399 8a927f5c-9...
    80: joyless_af... -1.69830971 13.8649452  31.717272 8335119f-4...
    81: juiced_ann... -2.28474200  2.8990016  58.644555 ee6a8cba-6...
    82: joyless_af...  4.49386284  0.6047590   8.644068 55a2501e-7...
    83: juiced_ann...  9.69199922  7.9855969  28.574493 636066db-3...
    84: joyless_af...  2.26401688 11.7785501  79.896802 27020447-1...
    85: juiced_ann... -0.25667065  4.8327984  21.797294 d585453d-d...
    86: joyless_af... -4.10203635 10.0278848  26.347045 8b7bcf52-9...
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
    1: joyless_af...  9551 runnervmrg...     FALSE terminated
    2: juiced_ann...  9553 runnervmrg...     FALSE terminated

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

    [1] "semimagical_banteng" "blameworthy_snail"  

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
    1: aciduric_s...  9844 runnervmrg...     FALSE running
    2: defective_...  9846 runnervmrg...     FALSE running

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
    1: aciduric_s...  9844 runnervmrg...     FALSE running
    2: defective_...  9846 runnervmrg...     FALSE running

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
