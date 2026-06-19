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
    1: glossophil...  8902 runnervm7b...     FALSE running
    2: premium_in...  8904 runnervm7b...     FALSE running

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
    1: glossophil...  8902 runnervm7b...     FALSE    running
    2: premium_in...  8904 runnervm7b...     FALSE terminated

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
     1: apidologic...  9.83597596  1.5209088   2.948063 1aabf875-d...
     2: apidologic...  6.52599886 11.3921010 124.932142 4dc5b3a8-a...
     3: apidologic...  1.13977864  2.4057478  17.806663 54a67f62-b...
     4: apidologic... -0.01658661 11.9589744  54.795827 3e724503-7...
     5: apidologic... -4.83622956 10.5275613  49.515176 3a8d2b4f-b...
     6: apidologic...  0.14108040  1.0987020  41.402868 539a93af-9...
     7: apidologic... -4.81129945  1.3108431 246.172341 b04d6f1b-d...
     8: apidologic...  0.15935475  6.3692892  19.864394 d60e9fbb-7...
     9: apidologic...  6.50026432  1.7868696  19.830862 ef43a68e-7...
    10: apidologic...  0.93287893  3.4241750  17.166762 0703ed83-6...
    11: apidologic...  0.82821311 11.9047376  67.390654 ca91a1b7-4...
    12: apidologic...  3.96657861 13.4573572 141.260430 1db02f9d-9...
    13: apidologic...  7.52584144  2.9430587  15.667471 c1ef2bff-7...
    14: apidologic...  3.85595785  6.5506579  25.468250 38ded57d-3...
    15: apidologic...  4.47670016  7.6726641  46.304337 7b82a0b1-6...
    16: apidologic...  8.69426966  5.8919455  18.562939 7bb64d0a-4...
    17: apidologic...  6.73556271  7.3895704  57.682914 db1fb59c-7...
    18: apidologic...  9.58931914 14.6079371 144.303159 1a6fecb9-5...
    19: apidologic...  9.15145940  3.2265421   1.699956 4dc737b8-8...
    20: apidologic...  4.74598561 10.7765283  99.062671 01cfaba0-c...
    21: apidologic...  2.50362032  6.7925320  18.027029 95a7703e-8...
    22: apidologic... -0.74478697  2.9651911  35.479621 53d64c5a-5...
    23: apidologic...  3.07278696 13.9821539 136.210303 49f3ff3d-0...
    24: apidologic...  9.02431551  2.5868505   1.341581 1fb4dac1-8...
    25: apidologic...  8.03498211  3.0956713  10.653785 22b8c240-9...
    26: apidologic...  7.39546408 13.8858979 172.775066 32a56c24-9...
    27: apidologic...  7.45759257 14.9367528 199.244226 9293ae19-1...
    28: apidologic... -1.92879805 10.3724881   7.311253 49924b74-4...
    29: apidologic...  2.91516357 14.9136869 155.781990 3bce94c5-d...
    30: apidologic... -2.50378890 13.9657317  12.340697 4a14f391-7...
    31: apidologic...  6.67658587  0.5649650  19.190729 2b6c69ec-1...
    32: apidologic...  0.54349018 12.4777470  71.575421 4effc169-7...
    33: apidologic...  3.21346358 13.8045044 134.632266 c8c5abc8-d...
    34: apidologic...  0.97674644 11.0059397  56.812487 72f7ad0b-2...
    35: apidologic...  5.74064355 14.1827397 188.838659 91d6fda6-6...
    36: apidologic...  8.95686425  6.2704519  18.751111 823c1ef0-8...
    37: apidologic...  7.19487133 13.2731670 160.764362 2d101f48-a...
    38: apidologic...  3.18530252  0.6934434   2.802483 df365215-c...
    39: apidologic...  4.22692090  9.8933214  74.617983 ae96cac3-a...
    40: consignabl...  6.92324897  8.2641598  67.981765 00bbbe6b-c...
    41: apidologic...  8.77335902 10.9618025  83.030955 1b27fff7-5...
    42: consignabl...  4.13193175  3.6770782   8.927227 8e1c9f1f-7...
    43: apidologic... -0.41896825  0.4669927  57.491028 df8ff886-b...
    44: consignabl...  8.29106499 10.4787055  83.269433 6c82358b-6...
    45: apidologic... -2.04811407  3.7902191  41.725196 8fed12ea-d...
    46: consignabl... -4.64098805  6.7893519  97.289730 6bfc514e-8...
    47: apidologic... -4.12701331  2.7043439 150.242124 7d629d12-c...
    48: consignabl...  9.96479072  7.9501625  26.584355 ae715679-0...
    49: apidologic...  9.26434225 13.9938259 136.263079 40b2bf12-7...
    50: consignabl...  7.85216733 13.0918666 145.132710 84374a90-e...
    51: apidologic...  8.87559484  6.4248214  20.942676 07999803-1...
    52: consignabl...  5.48595949 11.9027318 132.185513 4b8e3d59-1...
    53: apidologic... -4.03875973  1.1758913 182.478116 55da561c-9...
    54: consignabl... -0.75803272 12.6017843  45.287132 b9d3497e-4...
    55: apidologic... -0.19827443  4.0850603  24.411813 be3cac5f-8...
    56: consignabl... -0.35234161  7.0775864  19.263008 d72fc8c9-6...
    57: consignabl...  1.82116674 11.2288774  66.893933 bff6b281-3...
    58: apidologic...  3.17891666  0.5288369   3.353473 de1f2a99-7...
    59: apidologic... -0.94288825  5.5405583  19.946188 ed675f66-f...
    60: consignabl...  1.25967769  3.1964336  13.946880 b27fe7f3-a...
    61: apidologic... -2.11183001  6.2262473  18.826033 b37d5b48-6...
    62: consignabl...  4.51401961 10.5306091  90.601010 939f3beb-e...
    63: consignabl...  4.02860116  8.3677521  48.594553 44ac98d4-4...
    64: apidologic... -2.91256393  0.6533968 123.370011 a28e6cfc-4...
    65: apidologic...  1.41994691 11.2879775  64.549549 1f041b01-0...
    66: consignabl...  5.75327241  5.4230851  36.806827 db9c9ad5-6...
    67: consignabl...  7.96650214  7.8348401  48.803684 0201c332-d...
    68: apidologic...  5.28797597  0.6142005  15.565498 f271527b-9...
    69: apidologic...  6.16141967  4.0964180  28.521290 463eeb14-2...
    70: consignabl...  1.50949475  3.3237405  10.911085 e4bcffd9-3...
    71: consignabl...  0.57557884  2.4187828  25.388003 3d37b8e7-1...
    72: apidologic... -4.08126100 13.6339841   5.361057 e7539fad-a...
    73: apidologic... -3.44928399  1.4590699 134.658599 2726c8d7-d...
    74: consignabl...  6.83150813  7.6134130  59.888828 df9c5de2-4...
    75: apidologic...  5.53239300  1.2994115  17.043218 6c8b7119-e...
    76: consignabl...  2.82405335  6.6612999  17.898820 b61740eb-c...
    77: apidologic...  3.70790912  4.4841177   8.705561 359543b7-0...
    78: consignabl...  9.04995092  8.7886312  44.778547 6e398799-f...
    79: consignabl...  3.98203016  0.4187835   5.263446 754e0c70-1...
    80: apidologic...  4.43729590  4.2846316  15.249739 c7d59ef1-e...
    81: apidologic... -1.93382283  0.7477236  84.262003 0a8610eb-1...
    82: consignabl...  0.11894190 11.8174681  55.593605 baa8ab9c-c...
    83: consignabl...  1.98543304  8.8320569  36.192085 154edb33-c...
    84: apidologic... -1.59814696 11.6946282  17.696305 1a3bda81-5...
    85: consignabl... -4.82928948  5.6377241 133.469523 ac5f9746-7...
    86: apidologic... -1.73411728 13.7530865  29.641761 5e6f55c9-c...
    87: consignabl... -0.95188004 12.6942953  41.197373 81fd7d3f-5...
    88: apidologic...  8.45748390 13.7731634 148.387938 c9808f5c-8...
    89: consignabl...  7.62097188  6.3320260  36.801387 604cc0db-1...
    90: apidologic...  3.49909104  7.2036523  27.950840 a600d4e1-8...
    91: consignabl...  0.81571411  9.0887372  35.079640 caf60e1d-1...
    92: apidologic...  0.67563679  1.4094801  30.267386 3a0f6b12-a...
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
    1: apidologic...  8904 runnervm7b...     FALSE terminated
    2: consignabl...  8902 runnervm7b...     FALSE terminated

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

    [1] "nonartistical_fox"    "illjudged_whiterhino"

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
    1: doltish_co...  9154 runnervm7b...     FALSE running
    2: white_iber...  9156 runnervm7b...     FALSE running

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
    1: doltish_co...  9154 runnervm7b...     FALSE running
    2: white_iber...  9156 runnervm7b...     FALSE running

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
