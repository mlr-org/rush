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
    1: deliberate...  9179 runnervm3j...     FALSE running
    2: heptahedri...  9181 runnervm3j...     FALSE running

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
    1: heptahedri...  9181 runnervm3j...     FALSE    running
    2: deliberate...  9179 runnervm3j...     FALSE terminated

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
     1: noncorpora...  8.40947373  5.9774557  22.7929034 476ebf82-4...
     2: noncorpora... -2.80753019 11.2382150   0.9903975 04519d9a-4...
     3: noncorpora... -0.26477482 11.2668480  42.6581535 b01a4ba8-b...
     4: noncorpora...  4.61565467  5.4806589  25.6743079 6a5b9d88-f...
     5: noncorpora...  2.84332956 10.1596479  59.1998767 517ba7bf-b...
     6: noncorpora... -4.75564064  7.8722498  84.6892287 38d428dc-2...
     7: noncorpora...  7.30344955  8.2625168  63.9612227 9620b663-9...
     8: noncorpora... -4.98731422  4.2352731 179.4176343 19618cc5-c...
     9: noncorpora...  5.82663978  8.4875059  73.0109454 c31a8772-3...
    10: noncorpora...  8.86212712 13.4139546 131.2156371 9dd254ea-0...
    11: noncorpora...  5.00843369 14.6256278 191.1915466 5c0993fe-4...
    12: noncorpora...  7.12540915  4.4427909  26.7895452 7c4a4642-c...
    13: noncorpora...  3.11927537  6.7533217  20.2994885 dd40fb0f-8...
    14: noncorpora... -3.18979527  5.4563390  48.5005415 759b98c0-4...
    15: noncorpora...  0.83463611  9.2951279  36.9999388 4ec45f94-7...
    16: noncorpora... -2.60346654 12.0277838   2.7722637 b54f3a15-0...
    17: noncorpora...  7.91980174 10.5978673  92.1738900 44ca33f4-6...
    18: noncorpora...  2.53456749 11.0620475  70.4409261 ac75b611-c...
    19: noncorpora...  6.48942170  0.5364421  19.7299652 da307944-9...
    20: noncorpora...  5.67640955  7.4674142  58.0730690 e8cfb26c-a...
    21: noncorpora... -3.94199176 12.4839454   6.5434179 1625ad69-0...
    22: noncorpora...  0.81942807  0.5529616  34.4444696 1c2afba9-1...
    23: noncorpora...  7.05717744  6.1528485  41.3773562 7858c082-d...
    24: noncorpora...  1.42546307  6.7051926  18.7422441 ee9a0c80-9...
    25: noncorpora...  7.91519377  5.4147380  24.7689117 988441fd-c...
    26: noncorpora...  3.22810179  2.5155259   0.5280590 d8982247-1...
    27: noncorpora...  7.57906216  9.2803432  75.3672197 728c6880-6...
    28: noncorpora...  7.69415452  2.9986783  14.0772229 a52775cc-0...
    29: noncorpora...  7.61838007 13.3271918 155.1487993 6d97adcd-e...
    30: noncorpora...  7.30163251 13.6651478 168.7667458 353ef7c8-b...
    31: noncorpora...  6.60174997  0.6755975  19.3193844 0af9f947-9...
    32: noncorpora...  9.05415945  2.9562272   1.6521796 9be8dc39-4...
    33: noncorpora...  2.01996731  3.0346061   5.9076560 5e287a74-c...
    34: noncorpora... -3.52614519  0.6343408 159.4545847 7fabfe68-9...
    35: noncorpora... -3.08734923 10.9207123   1.9109400 a3b1adfc-7...
    36: noncorpora...  7.13148760  2.5398279  18.0915068 f392dec8-6...
    37: noncorpora...  8.94876364 10.4970864  71.9303598 dcaeedb6-a...
    38: woodenhead...  6.36992887  2.9077158  22.8203632 792c58ed-2...
    39: noncorpora...  1.89903359 14.6889112 133.3643332 2f65cbfe-9...
    40: woodenhead...  4.53997301 11.3112009 105.8509698 20919b23-b...
    41: noncorpora... -2.30359909  3.6535243  48.4437556 ca6139d4-4...
    42: woodenhead... -4.05190253  6.0439313  76.7985635 f17a9504-6...
    43: noncorpora...  4.81466990  8.7654238  66.2384669 36606212-4...
    44: woodenhead... -0.58623713  3.0507927  33.4172546 39f5b05b-f...
    45: noncorpora...  3.45682457  1.2394253   1.5151635 38428c98-2...
    46: woodenhead... -1.72535515  6.6120383  14.8647164 690b0252-9...
    47: noncorpora...  9.56604386  2.5939254   0.4935462 60616f62-2...
    48: noncorpora... -2.66519491  1.2407957  99.8461871 89aecd38-4...
    49: woodenhead...  1.81616465  2.5284719   8.6818096 6eb884e9-1...
    50: woodenhead... -1.67065692  2.1468168  56.2764849 2fe99638-e...
    51: noncorpora...  5.19433397 10.9644170 109.4334806 1260e126-a...
    52: woodenhead...  2.21950518  5.6941959  10.9082481 8b31a5bf-2...
    53: noncorpora...  8.33479488  5.8111963  22.3865779 f41914b7-9...
    54: woodenhead...  1.45329696 14.6301148 124.9801334 766074a0-3...
    55: noncorpora... -4.83601616 11.3252762  40.2655701 e4e99b69-3...
    56: woodenhead...  3.26988220  5.4829112  11.4053269 a025e0d9-6...
    57: noncorpora... -1.22015246 10.6554037  19.6545198 c0de2a7f-7...
    58: noncorpora...  6.29747355  9.3465304  87.5984595 544b7096-7...
    59: woodenhead... -1.31257117 11.7731594  24.4345296 63832eab-1...
    60: woodenhead... -1.22245193  9.8809460  16.3132198 6225a009-b...
    61: noncorpora... -0.20995593 12.4771119  57.0572359 52077c5b-f...
    62: noncorpora...  2.87005810  5.0633132   7.3393453 d862f4ab-d...
    63: woodenhead...  6.44304671 10.4013982 105.8396819 5279506f-5...
    64: woodenhead...  8.25356389  4.5188272  14.4129875 d943b2d1-4...
    65: noncorpora...  4.12058796  1.1159250   4.9131853 3c2fb618-8...
    66: woodenhead...  3.79110443  2.5358876   2.8613280 81bcdfbc-7...
    67: noncorpora...  2.26025814  0.3913053  11.0280260 d53af5aa-6...
    68: noncorpora...  0.78657046  9.7029360  40.5461725 3b91b2ee-3...
    69: woodenhead... -1.09562503  8.7932277  15.1928543 c18a0a9b-6...
    70: woodenhead...  2.82432873  7.4112459  24.6507393 975808d7-0...
    71: noncorpora... -1.35679917 14.2644473  46.4634253 35d2486a-3...
    72: woodenhead...  3.00749016  6.4273520  16.8497454 6f673e90-2...
    73: noncorpora...  5.73322050  9.5904709  89.9085393 e1eb0ab3-a...
    74: noncorpora... -2.56661121 10.7448419   1.9783837 6ced68db-5...
    75: woodenhead... -0.09747716 11.4162995  47.2234183 5c3c1bfa-6...
    76: noncorpora...  4.38243166  2.8023179   8.5687513 3a709bfb-c...
    77: woodenhead...  2.09069677 14.9678435 142.8372616 1327b9fc-4...
    78: noncorpora... -2.50599727  5.9352792  25.9355940 3a578b53-1...
    79: woodenhead...  1.33056246  6.5788194  18.3745051 7ca81bb6-6...
    80: noncorpora...  7.43273178  3.3702778  18.1821819 13ccba12-1...
    81: woodenhead...  2.51953440  4.1450354   3.9785820 068903eb-7...
    82: noncorpora... -3.88579031 11.2095096  11.4950608 c9289d6c-9...
    83: woodenhead...  9.22127222 10.1239757  61.6747461 66f31f58-0...
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
    1: noncorpora...  9179 runnervm3j...     FALSE terminated
    2: woodenhead...  9181 runnervm3j...     FALSE terminated

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

    [1] "cooperative_leopard"        "flowering_dutchshepherddog"

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
    1: intellectu...  9431 runnervm3j...     FALSE running
    2: cursed_het...  9433 runnervm3j...     FALSE running

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
    1: intellectu...  9431 runnervm3j...     FALSE running
    2: cursed_het...  9433 runnervm3j...     FALSE running

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
