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
  while(TRUE) {
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
    1: hyperproph... 30919 runnervm0k...     FALSE running
    2: comfortles... 30921 runnervm0k...     FALSE running

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
    1: hyperproph... 30919 runnervm0k...     FALSE    running
    2: comfortles... 30921 runnervm0k...     FALSE terminated

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
  while(!rush$terminated) {
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
     1: agricultur... -4.1974952  5.8980853  87.3285368 ac033d56-9...
     2: agricultur... -4.6358347  3.9621671 157.9176347 bcbcb1aa-a...
     3: agricultur...  6.0875778  2.8417317  22.4571001 df9147a9-f...
     4: agricultur...  3.6899975  0.2799816   4.3858202 21c8dc36-4...
     5: agricultur...  2.0306625 13.1067778 101.8954294 3bdf7a25-9...
     6: agricultur...  9.2064381 13.1902377 119.2888288 f8b48035-d...
     7: agricultur...  6.6146760 10.0119551  98.0618198 6fb298c5-6...
     8: agricultur...  4.9085112  9.0023417  71.1915612 bd43533b-d...
     9: agricultur...  9.1468779  6.0154193  14.9404344 3380cc03-9...
    10: agricultur...  8.1304881  3.5603716  11.2230975 564a9308-1...
    11: agricultur...  4.8585520 10.6020051  97.6127209 73a7091c-7...
    12: agricultur...  1.2283649  0.1175500  30.2181208 4d6ca816-5...
    13: agricultur...  8.7816698  9.1859947  54.1566349 672bdec3-6...
    14: agricultur...  7.8230780 11.2043901 105.3405214 7bd05f82-0...
    15: agricultur...  8.1765029  5.1976223  19.7319647 1b2dec50-9...
    16: agricultur...  7.9505601 11.9462488 117.9429357 36a4c095-3...
    17: agricultur... -1.8553852  2.9530908  48.8364126 7b5879e7-b...
    18: agricultur...  0.5503670  8.8919389  32.0877311 668057ef-5...
    19: agricultur...  4.7965115  7.4994308  48.7675516 3155b9f7-e...
    20: agricultur...  7.0661679  4.4785941  27.5282734 526901b9-7...
    21: agricultur... -2.0326434 11.0828451   7.4479998 80536363-6...
    22: agricultur...  6.2814174  7.0900829  55.4838604 c8cfc46a-5...
    23: agricultur...  9.1340910  1.6089639   1.1998327 dd4cf550-6...
    24: agricultur... -4.2187802  7.5295696  61.4617153 d81198a4-b...
    25: agricultur...  7.7978198  8.1113155  54.9843931 3f317116-c...
    26: agricultur...  8.1452368  9.5501910  70.3340664 0de34342-d...
    27: agricultur... -3.3048841 13.6487820   1.4819250 2b5eb581-e...
    28: agricultur...  6.5287197  5.2708616  36.5802894 45991785-a...
    29: agricultur...  3.8021637  4.7601592  11.0845602 07051ea4-5...
    30: agricultur...  8.7196929 10.4128606  74.4011014 7fc822b5-1...
    31: agricultur...  4.1929201  9.5782703  68.9196557 181e59b7-3...
    32: agricultur...  9.4700258  0.3692800   5.0051030 a6df264f-5...
    33: agricultur... -3.4093555  1.8891948 122.5899866 bd8d20d7-9...
    34: agricultur... -1.0508181 11.2861506  26.8192704 4f1339d1-1...
    35: agricultur...  6.0845577  1.8017262  19.9074604 67f24502-1...
    36: agricultur...  3.8728727  2.1112561   2.9668382 44b7b305-d...
    37: agricultur... -4.4977557 12.1850557  20.8194330 2707de84-8...
    38: agricultur...  3.6698514  3.6051202   4.6173542 52b629bf-c...
    39: agricultur...  0.6144093  3.5355431  20.2033555 ef741b22-f...
    40: agricultur...  4.3683994  1.7174052   6.8036365 1827d788-3...
    41: fawning_bi...  3.8386036 11.2215489  91.5125285 24cff4ce-1...
    42: agricultur...  5.1911168 10.5383726 101.2682260 0d61558a-e...
    43: fawning_bi... -4.7548150 14.9678314  12.7186582 dceedf41-a...
    44: agricultur...  6.5987318  2.0274649  19.9462519 e4c3193d-8...
    45: fawning_bi...  6.5458368  8.7155084  77.0059985 7376d218-1...
    46: agricultur...  4.1402932  4.6556836  13.9864854 3b9deb7e-2...
    47: fawning_bi...  7.2272177 12.0411119 132.1840776 e937b6ca-4...
    48: agricultur...  1.0234321 13.8041981 101.4451142 9c610549-0...
    49: fawning_bi...  4.9349707 13.2280088 154.5903096 df3df8c8-0...
    50: agricultur...  0.9785408  5.9555794  17.2903113 12321c4d-1...
    51: fawning_bi...  7.3598443  6.5428429  42.2092236 b7559389-4...
    52: agricultur...  1.0300421  5.8220748  16.6969701 67b0e0f2-3...
    53: fawning_bi...  3.5431022 13.3144187 129.5692596 81a61531-7...
    54: agricultur...  8.4504155  7.4588701  36.9043887 64f48d19-2...
    55: fawning_bi...  3.5646464 13.1423430 126.1059235 b4a8fdb5-3...
    56: agricultur...  3.0925043 11.7310939  89.0987708 14c5a921-7...
    57: fawning_bi... -0.9925489  4.3436733  26.5597819 f34451e8-1...
    58: agricultur...  5.7469978  5.0427115  33.6416710 bd5325e6-e...
    59: fawning_bi...  6.5527224  8.9718616  80.9391151 80d602ee-3...
    60: agricultur... -2.8064046 10.3427906   2.2345655 138eb1ee-d...
    61: fawning_bi...  7.8691165  4.2447467  17.5239399 3202e100-c...
    62: agricultur... -3.2599249 11.8437514   0.9797535 55d289a9-8...
    63: fawning_bi...  2.4457279  5.3051758   8.5107381 f4133f5d-3...
    64: agricultur...  4.5184388 10.6082144  92.0927525 8609745e-2...
    65: fawning_bi...  4.4720336  5.9096954  27.4596942 85fe48bf-3...
    66: agricultur...  2.1225716  4.6700502   7.1163499 6b025d8a-0...
    67: fawning_bi...  3.0341635  2.3947205   0.4544300 9d630aea-3...
    68: agricultur... -2.1188009  2.9404061  54.1616676 24cd983b-4...
    69: fawning_bi... -2.3762106  4.7563435  36.1950530 cb6a2789-2...
    70: agricultur... -4.7998423  2.8102862 201.4198795 57298fe1-8...
    71: fawning_bi...  0.9078711  4.8591256  15.9484150 dd12b4be-f...
    72: agricultur...  5.3281522  8.9058451  75.1199661 c2240ade-5...
    73: fawning_bi... -4.9739309 11.7103223  41.6639717 4c01ad7c-5...
    74: agricultur...  5.9844029  9.0034338  81.6090076 9edc9129-9...
    75: agricultur... -4.3962976  4.0508676 137.9542389 72b71a13-a...
    76: fawning_bi...  5.5288177  7.7200532  60.1692381 461ebffe-0...
    77: fawning_bi...  9.4602300  3.8508626   2.2150870 09deb456-a...
    78: agricultur...  1.1939534  5.2170748  14.4042282 e5f4ba68-7...
    79: fawning_bi...  3.4071413 12.3187116 105.6267205 b4958f35-d...
    80: agricultur... -0.9243826  4.6281013  24.5066923 ac931a13-b...
    81: fawning_bi... -1.5843636 13.4968836  31.5016304 4e105c06-9...
    82: agricultur... -1.1437840 12.3005295  32.5626412 b73c0c72-b...
    83: fawning_bi... -3.4994797  6.5123402  45.0865198 1b655f8a-4...
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
    1: fawning_bi... 30919 runnervm0k...     FALSE terminated
    2: agricultur... 30921 runnervm0k...     FALSE terminated

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

    [1] "computational_cob" "starving_gemsbok" 

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
    1: bacillopho... 31210 runnervm0k...     FALSE running
    2: partlycolo... 31212 runnervm0k...     FALSE running

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
    1: bacillopho... 31210 runnervm0k...     FALSE running
    2: partlycolo... 31212 runnervm0k...     FALSE running

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
