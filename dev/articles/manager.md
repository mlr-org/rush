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
    1: gainable_n...  9595 runnervm46...     FALSE running
    2: nonpsychop...  9597 runnervm46...     FALSE running

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
    1: nonpsychop...  9597 runnervm46...     FALSE    running
    2: gainable_n...  9595 runnervm46...     FALSE terminated

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

            worker_id          x1          x2          y          keys
               <char>       <num>       <num>      <num>        <char>
     1: genuine_wh...  7.34630806 11.95832068 128.697793 48d76c93-f...
     2: genuine_wh...  4.25796312  3.14501259   8.280398 861ebc1f-4...
     3: genuine_wh... -2.21330064 10.95078989   4.879016 083cffbe-9...
     4: genuine_wh...  2.38632403  8.23215053  31.040092 65b3d166-b...
     5: genuine_wh...  1.92945431  4.33476754   7.484486 057779ee-d...
     6: genuine_wh...  0.56426864 10.51700923  46.992807 5fe8b374-f...
     7: genuine_wh... -3.14287525  2.71217122  91.904556 c831e465-6...
     8: genuine_wh... -0.01621682  8.11204150  23.953071 20f01eee-a...
     9: genuine_wh...  5.26116687  8.76215023  72.158654 c5698040-1...
    10: genuine_wh...  0.60428918  9.43892931  36.854702 4933c490-d...
    11: genuine_wh...  0.24788867  4.47651293  20.601139 dd9a861d-7...
    12: genuine_wh...  0.09381233  4.71466197  20.853042 90fbe4d2-6...
    13: genuine_wh...  2.06292318  1.35769042   9.106619 5e560004-0...
    14: genuine_wh...  4.57324021 10.46116715  90.351320 e36131da-3...
    15: genuine_wh... -2.59388075 11.22575419   1.854615 9df2aef3-2...
    16: genuine_wh...  5.22285727 12.43228265 140.597638 2ba6aceb-a...
    17: genuine_wh...  6.09997660 14.27116697 192.960452 5b97745e-9...
    18: genuine_wh... -4.52942003  7.43418303  79.232115 bb3d2141-1...
    19: genuine_wh...  3.41386739  0.17198609   4.362582 d6bac1ad-2...
    20: genuine_wh... -2.66338933  3.65594479  57.715419 4568e7d1-a...
    21: genuine_wh...  6.92689499 12.07121817 136.429436 179aeb8b-a...
    22: genuine_wh...  1.53518301  4.35412926  10.584929 857f887f-2...
    23: genuine_wh... -1.69403863  2.05238447  58.022693 0ac35f3f-e...
    24: genuine_wh...  8.64143364  1.03947655   3.925713 1af4fd17-e...
    25: genuine_wh... -2.99032472  7.87313997  16.839504 0031a52d-e...
    26: genuine_wh...  2.48902240  3.79042830   3.276232 f578acfb-5...
    27: genuine_wh... -2.22312253  5.81905169  23.160044 ad201bbd-2...
    28: genuine_wh... -4.45670447 10.03041050  39.252075 42084cc6-a...
    29: genuine_wh...  8.84459368  8.08188794  38.605554 16a65fe1-9...
    30: genuine_wh... -0.54887973 14.07389464  69.477392 1cc887fa-1...
    31: genuine_wh...  7.87944895 14.87066927 189.066040 745f1933-4...
    32: genuine_wh... -1.68831048  2.31541155  54.299716 8d8fd4ad-e...
    33: genuine_wh...  0.82103171  0.42174158  35.541158 1c3cbdcb-3...
    34: genuine_wh...  3.96418249  0.48942369   4.983995 d958353a-2...
    35: genuine_wh... -2.53953444 13.33292019   8.127897 5323af35-9...
    36: genuine_wh...  3.81172585  9.99915741  69.530126 63e60862-e...
    37: genuine_wh...  7.20287557 14.78575986 199.346609 d6e4fa88-1...
    38: genuine_wh... -2.36752838 10.36826411   3.149111 3228e3f5-b...
    39: genuine_wh... -4.95743639  5.13196535 154.723618 c55106fa-8...
    40: genuine_wh...  3.61364710  8.76259095  48.055124 72bcfffc-9...
    41: suicidal_p...  5.86707500  3.84509982  26.268316 d728c2dc-a...
    42: genuine_wh...  5.62244595 11.50362568 125.082029 20fe0bf8-7...
    43: suicidal_p... -1.06000571 11.34534644  27.036321 584ba08a-9...
    44: genuine_wh...  6.97481237  1.88986836  17.894154 f243109f-4...
    45: suicidal_p... -3.94390751  8.13235946  41.197240 f80cdd89-b...
    46: genuine_wh...  6.15743818  2.69678542  22.082283 a2e351ee-3...
    47: suicidal_p... -2.40439813  1.40412161  86.969440 6017f343-0...
    48: genuine_wh...  1.64599490  5.25355318  11.598863 adb10575-6...
    49: genuine_wh...  2.85526911  6.88385976  19.929226 ffde70b6-b...
    50: suicidal_p...  8.14693359  6.53280369  31.480257 0b81dc6f-0...
    51: genuine_wh...  4.13260122 14.60837688 173.203101 03a0a7c3-0...
    52: suicidal_p...  2.55340723 10.99094044  69.457440 9d29022e-3...
    53: genuine_wh...  3.68159087  4.66963377   9.481940 0303dd82-a...
    54: suicidal_p... -2.98793538  1.40874442 110.761660 4810831b-5...
    55: genuine_wh...  3.78561383 12.04891225 106.822390 f8971eac-2...
    56: suicidal_p...  8.52943335  6.71219645  27.897417 f06aa3a3-5...
    57: genuine_wh... -3.05889969  5.40236727  44.983455 dc2f75c7-5...
    58: suicidal_p...  8.47023171  3.70595217   8.130533 e9e5143f-8...
    59: genuine_wh...  2.13698202  8.91498333  37.638058 01744451-7...
    60: suicidal_p...  9.85626817 14.81175697 144.050222 ac910777-5...
    61: genuine_wh... -4.73503516  0.08220852 277.547217 c0d322b2-a...
    62: suicidal_p...  0.14132512  2.02379825  33.597817 66d83b43-5...
    63: genuine_wh...  7.14915393 10.69594361 105.930608 a0386e90-7...
    64: suicidal_p... -0.44633847 11.82159081  44.523589 685bd9d9-c...
    65: genuine_wh...  5.51987696  2.40309078  18.505837 5059931c-e...
    66: suicidal_p... -2.92417182  9.46683686   5.876093 69c09bf5-8...
    67: genuine_wh...  6.42674442  6.43520612  47.890644 0ee31440-9...
    68: suicidal_p... -1.03751493  6.28477066  17.148012 c3ea3826-a...
    69: genuine_wh...  0.13062906  7.10507404  21.238428 9209b2e9-7...
    70: suicidal_p... -0.35411747  5.78061700  19.645015 a636733f-7...
    71: genuine_wh...  5.38090553  8.88652968  75.396938 49fb5a98-e...
    72: suicidal_p...  3.15471030 13.68634738 130.850634 1e53a0c5-b...
    73: genuine_wh...  4.35027690  8.82557543  59.953456 d570a8e7-e...
    74: suicidal_p...  0.23690373  5.85761559  19.385634 3f7f86e1-3...
    75: genuine_wh...  7.75050743  4.05637281  17.916738 dd727653-5...
    76: suicidal_p...  7.82607211  5.59618823  27.403854 5511a829-8...
    77: genuine_wh...  3.36498427 10.30918859  67.908563 7d71bfdc-2...
    78: suicidal_p...  3.30986400  6.00188694  15.390349 c5d430a1-0...
    79: genuine_wh...  9.74040431  0.12553062   7.781624 f59bc851-8...
    80: suicidal_p...  2.96616957  8.85179001  41.967468 ba878d09-a...
    81: genuine_wh...  4.22551305 12.26716775 119.691593 2367141c-0...
    82: suicidal_p...  1.26709837 14.31839685 115.440529 3bf5efde-6...
    83: genuine_wh... -4.43685213  1.00241308 220.610059 1bc74307-f...
    84: suicidal_p... -1.92409282 13.19108755  20.004186 f991acd8-0...
    85: suicidal_p... -2.67739923 11.34117356   1.437641 17e941f5-5...
    86: genuine_wh... -0.46824157  2.05796500  40.805346 442e2036-9...
    87: genuine_wh...  3.99489736  8.90790702  55.588603 42e924e0-7...
    88: suicidal_p... -0.29085040  1.87736521  40.326325 470724de-3...
    89: genuine_wh...  9.69088085  4.69146899   4.667578 17e70ae9-c...
    90: suicidal_p...  2.25757254  7.75889242  25.940977 6f749c81-0...
            worker_id          x1          x2          y          keys
               <char>       <num>       <num>      <num>        <char>

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
    1: genuine_wh...  9595 runnervm46...     FALSE terminated
    2: suicidal_p...  9597 runnervm46...     FALSE terminated

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

    [1] "noncrystallised_sawfish" "humorous_barnacle"      

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
    1: milklivere...  9886 runnervm46...     FALSE running
    2: pessimisti...  9888 runnervm46...     FALSE running

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
    1: milklivere...  9886 runnervm46...     FALSE running
    2: pessimisti...  9888 runnervm46...     FALSE running

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
