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
    1: halftheatr...  9051 runnervm1l...     FALSE running
    2: enthroned_...  9049 runnervm1l...     FALSE running

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
    1: enthroned_...  9049 runnervm1l...     FALSE    running
    2: halftheatr...  9051 runnervm1l...     FALSE terminated

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
     1: commiserat...  7.2986465  3.0333387  18.187640 fdcdd2e6-2...
     2: commiserat... -2.2343939 12.1372621   7.834239 bc77e927-2...
     3: commiserat...  1.4237406  1.7707633  16.358232 65581cdb-5...
     4: commiserat...  8.6952438  8.8709006  51.040402 914c900c-a...
     5: commiserat...  1.5694517 12.4426960  84.357856 5b1d1c19-7...
     6: commiserat...  7.3640010  9.5568730  82.937561 3267570c-2...
     7: commiserat...  8.1792258 12.2853703 120.580197 ff3dadf9-3...
     8: commiserat...  1.9824820 10.7198518  60.435433 c34436ed-b...
     9: commiserat... -2.4892854  7.6388857  12.125171 d854df8e-4...
    10: commiserat... -2.6998464  9.5519839   4.164258 7dabd69f-8...
    11: commiserat...  8.2387675  8.2057669  49.291410 c330680a-1...
    12: commiserat...  4.3607362  4.9138602  18.236321 2f6b857c-b...
    13: commiserat...  6.0798088 12.0746438 139.871833 94492554-0...
    14: commiserat...  8.7309196 12.5045522 113.976298 86a0c526-9...
    15: commiserat... -4.2733641  7.4977962  64.633919 e468a405-7...
    16: commiserat...  2.7386861  0.4158550   5.981842 a8c8ac0f-8...
    17: commiserat... -1.6069784  4.1410577  32.216399 8bc28bc1-c...
    18: commiserat...  1.4341146  9.3460039  40.067721 6f74710c-a...
    19: commiserat... -4.1089981  2.0977972 163.891788 ef37c2e5-4...
    20: commiserat...  7.0533713  3.7866930  23.577268 404f8069-e...
    21: commiserat...  5.7795948  0.7411373  18.551135 97bc1293-f...
    22: commiserat... -4.6065106  9.6086691  50.769929 65454ec0-5...
    23: commiserat... -4.0224260  2.6295116 144.608788 c624666b-d...
    24: commiserat...  6.0552949 14.3838255 195.828350 5237d297-9...
    25: commiserat... -1.2274441  1.8283573  53.172538 3d66fd1e-1...
    26: commiserat...  1.6526284  6.5295291  17.094043 8d2df981-c...
    27: commiserat...  7.6613806  2.7148524  13.595198 45d62f6a-5...
    28: commiserat...  7.6623093  2.0353055  12.246140 fa7e0b6f-4...
    29: commiserat...  0.2577914 14.7049922 102.216706 89176b87-5...
    30: commiserat...  6.5399533  9.2947942  86.168699 aaa110c1-2...
    31: commiserat...  8.5737072  2.7845802   4.542675 b16c5fcd-8...
    32: commiserat...  3.1199399  8.2678817  36.111939 b5e33207-c...
    33: commiserat...  3.5995233 12.0549100 103.598115 0f4e6d27-d...
    34: commiserat...  7.0674273 12.5288372 145.040074 b52be48d-3...
    35: commiserat...  3.8826517 13.1746005 133.026028 19fad493-3...
    36: wonderful_...  7.3345344  5.9786010  36.878526 f9fcdd8d-3...
    37: commiserat... -0.5625479 10.9684322  34.381278 8e5d6d15-8...
    38: wonderful_... -0.7593785 14.8540597  74.283748 22d0d855-5...
    39: commiserat... -0.8842822 12.0734378  36.925864 b88f7c27-9...
    40: wonderful_... -1.1417933 14.1857077  52.435010 da0279a0-4...
    41: commiserat...  0.5879029  7.0584760  21.790532 0dc10c36-0...
    42: wonderful_...  7.3735949  9.9284866  89.090031 15469c8a-3...
    43: commiserat...  3.1494490  4.8469435   7.044589 9995f834-0...
    44: wonderful_...  5.9602750 10.8883630 114.855414 39cf48d9-d...
    45: commiserat...  0.2964093  2.5545303  28.094019 6b87098f-5...
    46: wonderful_... -0.5677082 11.9244911  42.889511 e571a38f-4...
    47: commiserat... -3.5976117  8.2726093  27.646551 f57922e2-8...
    48: wonderful_...  3.8493342  7.5719966  36.161290 e4d14351-d...
    49: commiserat...  4.6652472  3.8077514  15.409148 d6e7fd9d-e...
    50: wonderful_...  5.5321890  9.6093028  88.596729 97b1c8b0-0...
    51: commiserat... -2.9794567  3.8358326  65.373212 9b5c2c7b-6...
    52: wonderful_...  5.1072929  7.3313644  50.784264 d4438a7c-a...
    53: commiserat...  6.7687109 14.9292372 208.472557 17b76473-f...
    54: wonderful_...  5.8620622  5.3238920  36.524234 c7bf9e11-c...
    55: commiserat...  8.9317126  8.3926280  41.258507 2b922aa7-4...
    56: commiserat...  9.3082168 10.4508626  65.627156 590078e5-5...
    57: wonderful_...  2.3381330  0.3415991  10.321478 536191ff-2...
    58: commiserat...  5.7251806  7.5154726  59.016181 42e41df5-4...
    59: wonderful_...  0.6128987  8.7596306  31.445111 0a55fda9-0...
    60: commiserat...  3.6149987 11.6906124  96.630541 6b9df836-e...
    61: wonderful_... -3.0453197 14.6936571   7.458635 d83d00ae-3...
    62: commiserat...  0.0202224  4.9504369  20.635315 974d5b41-e...
    63: wonderful_... -3.8926998 14.5960612   3.177820 8493f395-8...
    64: commiserat...  0.8291535  1.2741646  28.701327 e72876e3-0...
    65: wonderful_...  8.9786408 12.5225043 109.458589 f51b73af-8...
    66: commiserat... -4.7215516 13.4763034  18.603847 fb55d8f8-f...
    67: wonderful_...  5.0949861 10.4446112  98.225647 03841863-8...
    68: commiserat...  0.2544292  1.8536451  33.353851 7794a4ca-a...
    69: wonderful_... -0.8606790  5.7299383  19.272041 47071406-e...
    70: commiserat... -4.6803669 10.2711744  45.785698 948f1541-e...
    71: wonderful_... -3.2723997  2.6426809  99.460337 c91c6674-d...
    72: commiserat...  5.6225848 10.6585894 108.274191 234c7fc3-5...
    73: wonderful_... -2.1452972  8.2483747   7.881482 1606b35c-d...
    74: commiserat...  5.2616006  8.7169161  71.481849 5702fb3c-6...
    75: wonderful_... -4.2692629  7.5279039  63.969200 f416a01c-2...
    76: commiserat...  0.2329384 12.5011561  66.469352 f4c16f91-5...
    77: wonderful_...  6.5278725  5.5116565  38.642084 10c1a487-e...
    78: commiserat...  5.0285873  9.2110378  76.150723 49b68c71-4...
    79: wonderful_...  1.5146196  9.6362679  43.607396 717b6396-f...
    80: commiserat...  2.5523055 10.0347238  54.656818 90a3e39e-8...
    81: wonderful_... -0.5841469  5.4192348  20.426528 feb4a569-b...
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
    1: commiserat...  9051 runnervm1l...     FALSE terminated
    2: wonderful_...  9049 runnervm1l...     FALSE terminated

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

    [1] "genial_noctule" "vigorous_skua" 

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
    1: weaponless...  9321 runnervm1l...     FALSE running
    2: poorly_puf...  9323 runnervm1l...     FALSE running

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
    1: weaponless...  9321 runnervm1l...     FALSE running
    2: poorly_puf...  9323 runnervm1l...     FALSE running

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
