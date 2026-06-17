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
    1: opposite_e...  8920 runnervm7b...     FALSE running
    2: nonphiloso...  8922 runnervm7b...     FALSE running

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
    1: opposite_e...  8920 runnervm7b...     FALSE    running
    2: nonphiloso...  8922 runnervm7b...     FALSE terminated

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

            worker_id         x1           x2           y          keys
               <char>      <num>        <num>       <num>        <char>
     1: practical_...  0.8786640  4.033571369  16.5737402 03df5a21-f...
     2: practical_...  9.8655758  6.394861244  13.7268308 7d85f061-4...
     3: practical_...  4.2867229 11.455355132 104.1240975 27d91921-0...
     4: practical_...  6.3532161 14.817387888 207.6667772 28cc9e09-6...
     5: practical_...  2.3568339  5.538778637   9.8222542 2980d856-d...
     6: practical_... -4.9044949  6.434262418 121.6405761 c214f0c2-8...
     7: practical_... -2.4171434  3.187042892  57.7875600 c4362b9e-9...
     8: practical_... -3.6889577 14.438290214   2.4554685 b5de3153-7...
     9: practical_...  7.4277234  3.144374309  17.3510274 4134050a-1...
    10: practical_... -1.0439089  5.299648401  21.0911966 d5d59092-0...
    11: practical_...  5.6692600 12.177078688 139.9054648 2c3fd17a-4...
    12: practical_...  6.5704728  6.847728551  52.0176676 74dd8778-7...
    13: practical_...  5.8673748 14.542042160 199.2278410 d3284bda-b...
    14: practical_...  5.7079579 12.435361211 145.9938747 75edbff9-f...
    15: practical_... -4.8939054 10.468245125  52.8811999 4f94a5e8-2...
    16: practical_... -3.3317853  7.308056144  30.0417673 64c375a7-2...
    17: practical_... -4.1999528  1.904622527 175.8184101 563330c9-0...
    18: practical_...  1.8258722  8.625974034  33.6000943 396c543d-8...
    19: practical_... -1.4585166 13.392899580  34.0850321 e0acab38-9...
    20: practical_...  8.2929193 12.118693247 114.7655752 dfb97bf1-3...
    21: practical_...  2.0633464  8.960534387  37.8863073 e80fb600-7...
    22: practical_... -2.9508604  4.148993048  59.4366820 5aa5e717-f...
    23: practical_... -4.7565671 11.454387952  35.8127065 f08f27d3-c...
    24: practical_...  9.5354112 13.682865325 123.9545303 051faa35-7...
    25: practical_...  1.0138090  5.223899441  15.5725082 f34feff3-b...
    26: practical_...  2.8902487 14.184514735 137.7145969 cfe3cb35-d...
    27: practical_...  7.6132991  1.718847585  12.4098854 98d7c789-8...
    28: practical_... -2.7341157  9.067279271   6.2461478 298d40f5-c...
    29: practical_...  9.4254120  2.499946338   0.3984852 84e5a433-2...
    30: practical_...  0.4922697  7.439267088  23.2643614 b23f58f8-8...
    31: practical_...  9.4478581  7.213213176  22.6663459 ab806884-a...
    32: practical_...  8.0556672  3.192857167  10.7352841 9229f708-8...
    33: cosmograph... -0.5908743 10.979249937  33.9240862 3dd1941e-e...
    34: practical_... -0.2670973  7.520328760  20.4410587 c23d2abd-0...
    35: cosmograph... -2.7375858  9.280179719   5.3528684 ee5e645e-b...
    36: practical_...  2.6747001  9.552922077  48.8377770 d7ff0328-2...
    37: cosmograph...  8.5933649  2.901570456   4.6084475 270f08fd-0...
    38: practical_... -4.8298082  3.021832328 198.2273195 7f0c99d1-c...
    39: cosmograph...  1.6940038  8.643828016  33.5129334 b33f447b-4...
    40: practical_...  7.7965014  6.574682590  36.8753363 194dd4ac-b...
    41: practical_...  8.1100937  0.788814478   8.2083854 75effce6-f...
    42: cosmograph... -1.5651713 10.115835522  11.7657044 b6dbb1df-e...
    43: practical_...  5.8607001 10.334750476 103.8610329 2261580a-0...
    44: cosmograph...  4.0068489  3.213849470   6.0745769 2c73fccf-e...
    45: practical_...  3.6308920  6.242646811  20.1723162 eb2d163c-c...
    46: cosmograph... -3.1122930  6.418004570  33.8878157 baf585da-3...
    47: practical_... -2.8696159  2.375160682  86.4201207 14ce6211-c...
    48: cosmograph...  2.4052201  8.481344058  33.8218524 2a014a88-0...
    49: practical_... -0.8913922  7.860509113  16.1483258 d2a6eda8-c...
    50: cosmograph...  3.3748530  5.895422512  15.0622633 31da33d9-d...
    51: practical_...  3.6522560 12.381941789 111.2752110 f0aedcd3-3...
    52: cosmograph... -2.6704069  4.867632595  41.1805558 fedb43b1-a...
    53: practical_...  7.4217767 14.809537631 196.4292925 f1dd8410-1...
    54: cosmograph... -4.8989540 10.804747792  48.9005209 00f2f46f-5...
    55: practical_...  7.3979956 13.517585966 163.5945454 72545c9e-d...
    56: cosmograph... -1.3710183  8.807837663  12.0522197 3e1fcd4f-7...
    57: practical_...  8.2189174  5.044821534  18.1272836 528b0a0d-3...
    58: cosmograph...  3.3173994  0.004614853   5.1138346 2efa8b55-0...
    59: practical_...  8.4756361  4.120871915   9.8373479 d61fdd3b-2...
    60: cosmograph... -3.3288229 10.689093308   4.7289081 b974de1d-2...
    61: practical_...  3.5548464 11.365226112  89.3866395 17cb0b86-a...
    62: cosmograph...  3.2090687 14.675778784 155.4922762 5b9ccd9c-5...
    63: practical_... -0.1930515  8.925738423  26.2550235 449d5080-4...
    64: cosmograph...  4.5730487 11.312185308 106.4549653 648277ed-c...
    65: practical_... -3.2112957 10.637278717   3.6823418 5a3aa5a0-0...
    66: cosmograph...  5.4916487  0.440284055  17.2597942 66abb63e-b...
    67: practical_...  1.8276999 11.813401031  76.2965419 4a2b2420-6...
    68: cosmograph... -0.2274342  1.722178008  40.9445891 54c10031-a...
    69: practical_...  9.4832226  7.158454773  21.8855898 2b1db447-9...
    70: cosmograph...  8.9715003 14.049272958 143.6943492 6888df91-5...
    71: practical_... -4.0262594 13.588106578   4.7521195 1dc02817-5...
    72: cosmograph...  9.0788142  7.723201152  31.4876587 4799c2bf-f...
    73: practical_... -0.0426334 11.911169845  53.7349933 21f4c015-3...
    74: cosmograph... -1.7711995 12.996115408  22.3157374 1c1a2f89-b...
    75: practical_...  2.4493628  4.969908268   6.9893898 81afe54d-9...
    76: cosmograph... -2.7293289  7.519846930  15.5387668 d4dbceee-4...
    77: practical_...  7.6509279  2.885972610  14.1886783 42d06c2e-0...
    78: cosmograph...  5.5172253  7.824963726  61.4567185 2eb52b60-c...
    79: practical_...  5.8700625  3.191309561  23.1307405 fddc52da-3...
    80: cosmograph... -2.0457304  2.182725084  63.5790180 57eda7c1-b...
    81: practical_...  0.7825463 14.953529253 119.2210363 d4c1c61d-8...
    82: cosmograph...  4.8008159  2.891235303  13.2645991 da8cf93d-7...
    83: practical_...  7.0958606  2.258453327  17.6987790 adb6fd40-7...
    84: cosmograph... -0.6697543 13.097479238  53.2115114 44353943-b...
    85: practical_...  7.7486375  3.540334634  15.4882029 3930fa7a-a...
    86: cosmograph...  3.3017800  1.613747929   0.8120341 5c08be33-9...
    87: practical_...  5.7981460  9.650498422  91.3501072 9e959cbe-3...
    88: cosmograph...  9.6251697  2.353292226   0.6776129 0f2f09e2-8...
    89: cosmograph...  1.4790857 10.079873646  48.7178169 54a9cbda-b...
    90: practical_...  3.9078344 11.330418054  94.8029081 7236fdbc-7...
            worker_id         x1           x2           y          keys
               <char>      <num>        <num>       <num>        <char>

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
    1: practical_...  8922 runnervm7b...     FALSE terminated
    2: cosmograph...  8920 runnervm7b...     FALSE terminated

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

    [1] "russet_kitten"              "astrobiological_newtnutria"

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
    1: easternmos...  9172 runnervm7b...     FALSE running
    2: suspect_ki...  9174 runnervm7b...     FALSE running

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
    1: easternmos...  9172 runnervm7b...     FALSE running
    2: suspect_ki...  9174 runnervm7b...     FALSE running

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
