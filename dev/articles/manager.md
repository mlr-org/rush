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
    1: ardent_yel... 10797 runnervmrg...     FALSE running
    2: fungoid_or... 10799 runnervmrg...     FALSE running

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
    1: fungoid_or... 10799 runnervmrg...     FALSE    running
    2: ardent_yel... 10797 runnervmrg...     FALSE terminated

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

            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>
     1: fortuneles...  1.46720983  0.88144197  20.3657587 f95adc00-b...
     2: fortuneles... -4.04702417  0.04010152 214.8088899 6070f068-d...
     3: fortuneles...  9.20777232  5.73147528  12.4116049 9c5e27b6-3...
     4: fortuneles...  6.00391997  5.71221412  40.4916927 b4d1e3e7-d...
     5: fortuneles...  7.55354607  8.05520748  57.8159465 eede4f94-6...
     6: fortuneles...  6.62888331  1.97139499  19.7479885 651558f4-1...
     7: fortuneles... -1.97437867 10.84294437   7.6620068 1c4a022e-5...
     8: fortuneles...  0.33593521 11.09252502  50.5666984 bc549a42-b...
     9: fortuneles...  6.90210124 10.55613551 105.9358225 df033b4e-4...
    10: fortuneles... -3.19186551  5.79628467  43.9681650 82a7c537-1...
    11: fortuneles...  9.06556379  7.11506664  25.2801957 099570ea-3...
    12: fortuneles...  2.10752307 12.72285137  95.4026314 717ec2fa-f...
    13: fortuneles...  6.76886771  4.79747896  31.8254815 8e61649c-b...
    14: fortuneles...  6.15269470  8.06455115  68.0526700 66b56a31-b...
    15: fortuneles...  7.54217414 11.98843503 126.2318647 074ea8f3-6...
    16: fortuneles... -3.08076732 10.71538181   2.4148093 ae4a3b67-e...
    17: fortuneles... -1.46694142 13.54461994  35.3192284 42bb46fe-b...
    18: fortuneles...  5.83160904 11.28526248 122.1354937 d37518fd-a...
    19: fortuneles...  7.52679233 12.45667048 136.6801755 fe31bbc4-8...
    20: fortuneles... -3.09715450 13.10755833   1.2892732 38ee078c-8...
    21: fortuneles... -0.90568945  1.75394712  49.4901621 ab82a0e2-d...
    22: fortuneles... -2.22135525 11.80947401   6.8632078 7dd72ea2-0...
    23: fortuneles...  4.00528649  7.42115581  36.5188568 2958ae12-3...
    24: fortuneles...  5.50310805 10.63506940 106.7205839 0e4b2499-1...
    25: fortuneles...  2.53642698 12.00272540  86.8990799 729872c9-d...
    26: fortuneles...  9.13542040  9.70534887  56.5025730 c2354dde-5...
    27: fortuneles... -3.11865155  0.63498965 134.6113734 3bc2c806-c...
    28: fortuneles...  8.69545124 11.55387190  95.4879767 4d4700a2-a...
    29: fortuneles...  8.35666157 11.39558884  98.9637832 28726bc1-8...
    30: fortuneles... -0.36183950  2.54920259  35.3310236 37b35e74-9...
    31: fortuneles...  1.37873065 11.50950716  67.4585388 43bae10e-6...
    32: fortuneles...  9.10118801 12.28144148 102.2179654 2c7a14d5-f...
    33: fortuneles...  1.93432164 14.34361492 126.2436919 c24ec7f5-e...
    34: fortuneles...  1.18601140 14.15744390 110.8894420 e772b6cd-7...
    35: fortuneles...  7.64501345 11.58026149 115.9775174 87adbd67-6...
    36: fortuneles... -4.21777193 11.01402737  21.4171856 33ea3b3e-6...
    37: fortuneles...  7.13755485  8.87780747  74.9247972 f3b70d05-b...
    38: fortuneles...  4.75893634  5.11627571  24.6194202 8184abc1-0...
    39: fortuneles...  7.25293675 11.76682023 125.9840054 ce8accbe-5...
    40: baleful_ar... -1.76639577 12.87061906  21.5018568 f8778915-c...
    41: fortuneles...  6.65351996  5.17583873  35.3239624 8ca244de-e...
    42: baleful_ar...  3.37920837  5.80255234  14.3989015 e2070afc-3...
    43: fortuneles...  6.44636345 10.26138538 103.2474170 b607add1-e...
    44: baleful_ar... -3.39132443  0.81053540 146.4455193 497a88b7-d...
    45: fortuneles...  7.86429498  3.05141176  12.3914791 2f86df22-4...
    46: baleful_ar... -4.82228761 13.95973872  18.4476530 30705051-2...
    47: fortuneles...  0.48709212 11.76915745  60.9141534 1d0a50fc-e...
    48: baleful_ar...  5.87641655  3.08361419  22.7199830 21de3f54-9...
    49: fortuneles...  3.69064814  0.30222995   4.3167886 8cd78412-d...
    50: baleful_ar...  9.46379146  8.90391767  41.3116093 93790bfc-0...
    51: fortuneles... -0.01863820  1.18261644  43.0947463 d3ddab0a-3...
    52: baleful_ar... -3.44774487  9.54579110  12.9344290 1b0f368e-4...
    53: fortuneles... -1.05328425  1.39818475  55.9858542 65e3aa37-1...
    54: fortuneles... -2.90589491 14.54808807   8.6855742 0837f603-a...
    55: baleful_ar...  3.33148762  6.07546891  16.1248560 747019fd-8...
    56: baleful_ar...  4.09049441 12.03550087 112.2374625 fb738c22-6...
    57: fortuneles...  5.48009456  9.39566204  84.5316475 4c514513-e...
    58: fortuneles...  6.55564327  3.79817683  26.4298548 a91b9647-7...
    59: baleful_ar...  6.26035845 12.64803991 152.9720642 d49ab46d-2...
    60: fortuneles...  3.48290115 11.51396573  91.0135583 85b89492-2...
    61: baleful_ar...  0.47201415  0.88638650  37.8344633 ebee60fe-7...
    62: baleful_ar...  3.14945490 11.48237619  85.2867600 3c9e0339-f...
    63: fortuneles... -2.07801868  6.09671615  19.5365473 c307920a-2...
    64: fortuneles... -3.16185491 11.59552199   0.9301717 525090f7-a...
    65: baleful_ar...  5.62284817 11.71171059 129.4438354 d4076040-5...
    66: baleful_ar... -2.34201524  8.95649934   5.4961990 970a95ae-b...
    67: fortuneles...  3.48925895  0.94205428   2.1332330 728c1800-6...
    68: baleful_ar... -0.99619740  2.27628295  44.7842491 9bf62a20-1...
    69: fortuneles...  0.04165901  6.02179328  19.6015031 fd69de70-9...
    70: baleful_ar...  0.81153759 14.59599016 112.6991878 bd940f56-8...
    71: fortuneles...  4.66189330  4.06160034  16.6636641 36f03f59-6...
    72: fortuneles...  1.74797857 13.77162974 111.5110150 f4400361-d...
    73: baleful_ar...  6.56774539  6.81045792  51.6027578 68b696f4-3...
    74: fortuneles...  4.73666332  5.85061948  30.4009960 6340b3e0-b...
    75: baleful_ar...  7.99140950  0.53452575   9.6781881 cdd51e19-1...
    76: fortuneles...  6.39175593  1.42754417  19.6496239 6327af44-e...
    77: baleful_ar...  5.07497253  6.93601448  45.7351548 93109619-c...
    78: fortuneles...  1.04651567  5.63913390  16.1598367 7d16b61d-9...
    79: baleful_ar...  9.56515910  8.30433629  33.0779024 4f7a48b9-5...
    80: baleful_ar...  8.05507413 14.66941033 179.8866115 aa55e9a4-a...
    81: fortuneles...  5.81422957 12.65688205 151.8155403 f891b362-7...
    82: baleful_ar... -0.53723503  0.79659092  55.4073656 88b755ee-8...
    83: fortuneles...  9.41394610 13.38646822 119.6577360 3946c296-9...
    84: fortuneles...  0.97674205  0.31735610  33.4485724 c5ae9c7b-5...
    85: baleful_ar...  7.63197226  8.53155427  63.2883577 1b0166ef-5...
    86: fortuneles...  9.95951598  9.17054080  40.2718534 c3fd37df-5...
    87: baleful_ar...  7.24527209  2.27036465  16.5313154 6d1db6ab-5...
    88: fortuneles...  1.58947088  9.59175286  43.4038828 fd174568-2...
    89: baleful_ar...  1.35749897  0.26456964  26.5713150 45c1f4b5-4...
    90: fortuneles...  8.10242621 11.14390106  99.0026280 3baa4791-a...
    91: baleful_ar...  8.66494585 12.31840405 111.4019220 44dce3f9-9...
            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>

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
    1: baleful_ar... 10799 runnervmrg...     FALSE terminated
    2: fortuneles... 10797 runnervmrg...     FALSE terminated

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

    [1] "adjoining_africanfisheagle" "heinous_swift"             

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
    1: thieving_m... 11087 runnervmrg...     FALSE running
    2: panoramic_... 11089 runnervmrg...     FALSE running

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
    1: thieving_m... 11087 runnervmrg...     FALSE running
    2: panoramic_... 11089 runnervmrg...     FALSE running

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
