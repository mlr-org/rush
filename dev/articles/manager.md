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
    1: next_ameri... 11862 runnervm35...     FALSE running
    2: contradict... 11860 runnervm35...     FALSE running

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
    1: contradict... 11860 runnervm35...     FALSE    running
    2: next_ameri... 11862 runnervm35...     FALSE terminated

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
     1: evolutiona... -3.13440471  2.8795347  88.3487252 a3e1ec18-1...
     2: evolutiona... -4.85632862 12.9177504  26.2616350 ab984de6-a...
     3: evolutiona... -1.96329402  1.9085187  65.8346409 34f4b7c3-5...
     4: evolutiona... -2.47948112  7.1936643  15.0063346 0113f358-f...
     5: evolutiona...  5.26369087 14.5247447 192.5299071 de8f3784-d...
     6: evolutiona...  2.27466130 14.0357210 124.5119648 43de8fec-8...
     7: evolutiona... -4.96986632  8.6007633  84.6921517 09c213ab-0...
     8: evolutiona...  7.38240067  7.7005425  55.4434113 4ad0b352-4...
     9: evolutiona...  9.21404792 14.6130384 152.1478036 4ef0b498-5...
    10: evolutiona... -4.14514886  2.8476505 148.1034410 72598faa-3...
    11: evolutiona...  2.52428565 13.4614609 115.7165566 eeb70343-b...
    12: evolutiona...  7.83370206  4.4255232  18.9894726 49c82f76-c...
    13: evolutiona...  0.02158302 11.0916026  45.8746545 c23b2ea3-e...
    14: evolutiona...  0.30998095 11.6014465  56.1398579 0cd32fd2-f...
    15: evolutiona...  1.03936575  3.8626231  15.2538284 f144e15a-0...
    16: evolutiona... -4.69208827  1.1657825 239.2062274 cd79d78e-0...
    17: evolutiona... -1.95271640  9.4432980   6.4459580 29b4445a-e...
    18: evolutiona... -2.91734024 14.3252087   7.3083705 11b1bc74-2...
    19: evolutiona...  8.54911145  1.0963619   4.3961880 036ed85c-1...
    20: evolutiona...  5.34755085 14.2748019 187.0842356 bdf60e7e-e...
    21: evolutiona...  9.14515535  2.5287862   0.8489865 3315c930-a...
    22: evolutiona...  3.19792427  7.5472197  28.6702152 e34a919e-b...
    23: evolutiona...  5.30801575  9.7695502  88.9647095 7eba805b-d...
    24: evolutiona...  6.26226596  6.5526702  49.3382695 bd9e6b30-d...
    25: evolutiona...  6.76524811  5.1045176  34.1827496 b2e40174-3...
    26: evolutiona...  5.30224431  7.1385216  50.6893281 758a398a-a...
    27: evolutiona...  6.04832721  1.6282133  19.6178888 188c7f9a-a...
    28: evolutiona...  9.02527879 11.7464113  93.0795132 d212fbcc-0...
    29: evolutiona...  6.60825948  5.1649513  35.4285187 cf2e3c49-f...
    30: evolutiona...  5.37246191  4.1221594  24.5549106 002149ce-4...
    31: evolutiona...  6.25498783  5.0056401  34.8585294 6c12a9d9-0...
    32: evolutiona...  7.85422538  9.9917499  82.6373678 6c863822-b...
    33: evolutiona...  8.33536807 10.6560583  85.5972346 41a1cf3f-d...
    34: evolutiona...  3.83086622  7.6949524  37.3541249 42529a4c-1...
    35: evolutiona...  8.18876849  9.3388001  66.2743920 0a26d853-c...
    36: evolutiona...  7.41125926  2.5610396  15.7030146 d977c743-e...
    37: evolutiona...  4.44649412  6.8435287  36.2728954 33a1e28f-1...
    38: untheologi...  3.74219320  9.6394228  62.7033130 d2e482cb-3...
    39: evolutiona...  9.45303945 13.3576649 118.3135767 82bb4a88-4...
    40: evolutiona...  8.45919453 10.8857379  87.4340682 dadc2597-a...
    41: untheologi...  2.84385463  5.0714247   7.3370371 7acae952-a...
    42: evolutiona... -2.68265850 14.4731981  12.1100030 31b4f721-3...
    43: untheologi...  8.71079802  8.2096254  42.0688908 ec484544-2...
    44: evolutiona...  6.41500080 11.3701896 124.8633597 59648e45-d...
    45: untheologi... -1.80466725 11.0615115  10.9025761 7832f75d-1...
    46: evolutiona...  6.37884291  3.7107206  26.3520239 016721b7-a...
    47: untheologi...  1.42168290  0.3353248  24.8448204 ef34118b-e...
    48: evolutiona...  0.16797659  7.3318093  22.0126071 fe8bfe73-0...
    49: untheologi...  7.24160064  3.9907746  23.0358519 54a2d16a-2...
    50: evolutiona...  9.11503810  0.1178183   5.2997673 615af017-b...
    51: untheologi... -1.52658625  5.3287761  21.9974411 bdae11b0-f...
    52: evolutiona... -2.94898838 10.0910127   3.5541888 41859563-0...
    53: untheologi...  2.46839788 10.6545187  63.2699905 6a9d6a08-6...
    54: evolutiona...  1.33200850  4.4211683  12.3684344 b92c4763-6...
    55: untheologi...  6.94633222 14.0691959 183.7520418 6866eece-2...
    56: evolutiona... -2.43247441  2.5521413  68.0578094 035a02cc-1...
    57: untheologi... -2.25308948  5.3114045  28.2529377 3a0a6aca-b...
    58: evolutiona...  3.30377494  8.2984433  38.3036596 e68a319a-1...
    59: untheologi...  6.25030877  4.4046055  30.5233360 24447803-f...
    60: evolutiona...  9.06803131 14.8507389 161.2836579 9c12d31f-0...
    61: untheologi...  3.52875807  3.0970888   2.3288781 7f31934f-1...
    62: evolutiona...  2.06623993  7.5274980  23.6207982 9686f02f-3...
    63: untheologi...  4.99169828 10.0092362  88.9452413 55373252-6...
    64: evolutiona... -2.71871920  8.6631383   8.1012751 4aeae212-7...
    65: untheologi... -1.25236786  0.7189376  68.9099710 859d0bb3-7...
    66: evolutiona...  4.68053714  8.3073096  57.6708236 1fff6c34-3...
    67: untheologi...  6.45979328  4.7275217  32.5417440 dc9db0d2-c...
    68: evolutiona...  9.83862352  2.6923323   1.2321657 3a762036-d...
    69: untheologi...  4.90378197  8.2795717  60.5145004 a0349613-7...
    70: evolutiona...  5.74834781 12.3322672 143.9777194 e9c34469-9...
    71: untheologi... -3.36700898  7.4774073  29.2193107 87d695a4-e...
    72: evolutiona... -1.54583125  5.6192516  20.1603895 f32a9ccf-4...
    73: untheologi...  6.87763267  6.9386641  51.2950940 3e6ba32a-9...
    74: evolutiona...  6.92083819  7.4697765  57.3668665 e5ce9890-5...
    75: untheologi...  8.30481135  1.1900206   6.0685481 2b236db2-f...
    76: evolutiona...  3.58652922 13.5809847 136.5291559 6a88f2dc-c...
    77: untheologi...  3.16482935  5.8689370  13.4469409 ad012047-f...
    78: evolutiona...  9.42405802 12.9965370 111.1134078 cb38dd1e-0...
    79: evolutiona...  4.55678608  5.1561851  22.3957980 f98d48d7-5...
    80: untheologi...  6.95952763  7.1731201  53.3984006 83cbcb5a-1...
    81: evolutiona...  7.89880889  2.7643605  11.1971975 e080cc67-9...
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
    1: untheologi... 11860 runnervm35...     FALSE terminated
    2: evolutiona... 11862 runnervm35...     FALSE terminated

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

    [1] "drinkable_kiwi"     "slender_blackmamba"

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
    1: humorous_w... 12153 runnervm35...     FALSE running
    2: lunar_leon... 12151 runnervm35...     FALSE running

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
    1: humorous_w... 12153 runnervm35...     FALSE running
    2: lunar_leon... 12151 runnervm35...     FALSE running

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
