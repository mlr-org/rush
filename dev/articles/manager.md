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
    1: hallucinog...  9276 runnervm35...     FALSE running
    2: vacuous_sc...  9274 runnervm35...     FALSE running

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
    1: hallucinog...  9276 runnervm35...     FALSE    running
    2: vacuous_sc...  9274 runnervm35...     FALSE terminated

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
     1: venerated_... -1.63197082  5.0732300  24.375879 11e12302-9...
     2: venerated_...  5.76342883  3.6613750  24.801013 511a976a-d...
     3: venerated_...  9.14058677 14.4633585 150.053920 fa14aee3-9...
     4: venerated_... -1.28526471  6.0672729  17.508109 632edb23-4...
     5: venerated_... -1.96300213  0.2903854  93.409054 756f9af4-3...
     6: venerated_... -4.58218180 11.1659953  32.170947 6e22fb11-8...
     7: venerated_... -3.57058077  6.1366925  53.007826 37f76a22-c...
     8: venerated_...  9.81492113  4.7485487   4.824263 3fa8c49d-0...
     9: venerated_...  4.92387142  4.7069943  23.654344 85f50af8-3...
    10: venerated_...  9.71046348 10.4488826  60.421876 bf0d7dd0-e...
    11: venerated_... -3.38214438 10.7531457   5.115638 93f1d3f2-4...
    12: venerated_... -0.62145210 12.0341650  42.758885 e0bfd328-d...
    13: venerated_...  1.14316464  8.2795481  29.428077 56ebfccd-e...
    14: venerated_...  6.96895576  7.8454855  61.825662 ed4154de-8...
    15: venerated_... -4.49927778 12.9102799  16.181314 9645bfb7-2...
    16: venerated_...  3.75430210  7.7224535  36.681159 369b03fd-6...
    17: venerated_...  2.20753565  8.7409859  35.929679 dacfc46e-1...
    18: venerated_...  6.37274314  9.6114319  91.941953 895cbd99-8...
    19: venerated_... -3.67244662  3.7060311  99.356369 f7836271-5...
    20: venerated_... -3.48645404  8.9209030  18.588502 81d428a2-8...
    21: venerated_... -4.40382162 11.0797037  26.749171 e49ca83e-d...
    22: venerated_...  5.57280938  9.9580053  94.991265 8ad9cb27-a...
    23: venerated_...  6.76363437  7.0089075  52.899119 67cb0a35-2...
    24: venerated_...  8.81725799  1.1168534   2.914140 7b836000-8...
    25: venerated_...  9.35501866  9.2549185  47.181308 9a6812d5-8...
    26: venerated_...  5.56908930  2.3174890  18.635262 72cc17f7-5...
    27: inferior_a...  5.27500509  1.8799341  15.585153 2ce4fbf2-b...
    28: venerated_...  5.45995969  0.3328083  17.214557 d1f949d4-d...
    29: inferior_a...  6.14072376  0.2543759  20.216687 49d5897f-9...
    30: venerated_...  4.93511761  3.6930890  17.886952 d451d528-3...
    31: inferior_a...  3.52350337  9.0840965  51.330710 51567940-0...
    32: venerated_...  8.75811622  9.0586626  52.701921 65828549-7...
    33: inferior_a... -0.68319885  0.1131314  66.931343 058092a1-5...
    34: venerated_...  3.20095292 11.1306043  79.650465 931aa714-b...
    35: inferior_a... -0.74163646  7.7979319  17.378944 c7ffb734-8...
    36: venerated_...  9.14695044  3.8195855   3.227753 2b2662fc-0...
    37: inferior_a...  7.10060933 14.2395278 186.276497 4c08d79e-e...
    38: venerated_...  8.07663450 11.1657722  99.908557 20cbd876-2...
    39: inferior_a...  6.37231831  2.9142514  22.841499 e4f78e9c-5...
    40: venerated_...  8.27302519 14.4970264 170.501495 73f46147-9...
    41: inferior_a...  6.46292225  5.4183767  38.010448 e4d95cb0-3...
    42: venerated_...  6.19475773 12.2665150 144.295957 11e5f48c-c...
    43: inferior_a...  6.95386433  7.6875766  59.877916 3985066e-6...
    44: venerated_...  6.59075901 13.1770004 164.474253 ba8db0bd-2...
    45: inferior_a...  5.70848542 13.0711264 160.784483 b348b608-8...
    46: venerated_...  1.03251898  3.5423588  15.829014 0855d68c-c...
    47: inferior_a...  5.54339607  3.7035103  23.627186 7d29245e-a...
    48: venerated_...  3.34466284  5.1078373   9.510648 ec76cb83-b...
    49: venerated_...  7.58261293  0.6373694  13.095310 4ce17d93-0...
    50: inferior_a... -1.12331675 10.0285856  18.471875 be2cb4b7-8...
    51: venerated_...  8.72709417 12.9922621 124.587033 1debdf94-f...
    52: inferior_a...  2.63990593  9.2308323  44.249106 20d8d657-7...
    53: venerated_...  1.51764440 10.6979622  56.965598 114add85-6...
    54: inferior_a...  9.27762927 11.7345857  88.503158 5ad1da07-2...
    55: venerated_...  6.29481077  3.4505193  25.124583 54358b48-6...
    56: inferior_a...  7.11763026  8.3461432  67.280312 f07cee25-3...
    57: venerated_...  1.92375273 13.2243394 102.877625 cdbe7a89-c...
    58: inferior_a... -1.94495056  6.7034688  14.788998 be6527f9-b...
    59: venerated_...  7.78835400  1.0724502  10.765233 f5a42d7e-3...
    60: inferior_a...  7.36518979 13.8971602 173.558148 873732eb-1...
    61: venerated_... -3.45792059  9.1909548  15.752171 f7f2fec7-9...
    62: inferior_a... -1.59437922  6.3529673  16.088538 e35d70d1-f...
    63: venerated_...  3.69433818  2.1011049   1.875167 10f9add0-f...
    64: inferior_a... -4.33043203  3.2461089 152.070559 c263f140-9...
    65: venerated_... -0.29877286  7.2357103  19.737226 0af86d54-1...
    66: inferior_a...  0.87901743  7.5940554  24.496091 d3eccf98-7...
    67: venerated_...  6.08949296  0.9483747  19.445147 f8437f93-5...
    68: inferior_a...  4.05322659  5.3924439  17.965187 4757b18c-3...
    69: venerated_... -1.57129590  1.9723811  56.881635 b2c1b8e7-7...
    70: inferior_a... -2.34472114  0.2089868 108.002357 a7cf3e73-4...
    71: venerated_...  2.51782542  6.7492271  17.710127 04db1ace-7...
    72: inferior_a... -0.88286865  7.6687812  16.123297 0921e54d-f...
    73: inferior_a...  4.18151384  3.5104969   8.774390 3e360352-2...
    74: venerated_...  4.82606970  8.3372052  60.219567 b7c5b992-0...
    75: venerated_... -1.70910302  5.7218291  20.071173 c7c5a7f6-d...
    76: inferior_a...  8.52115725  6.9640867  30.538037 102c30a6-b...
    77: inferior_a...  0.41405418  1.2783570  35.476322 792f8859-8...
    78: venerated_...  2.07844468  8.4532708  32.404956 2da28911-a...
    79: inferior_a... -3.55944194  8.3688509  25.557483 35d498a7-9...
    80: venerated_...  7.09196420  7.4600228  55.688828 a17dd7ea-e...
    81: inferior_a... -4.60237295  1.4169800 223.400950 5b734f94-a...
    82: venerated_...  3.53951258 10.1170248  67.275764 754e99d4-a...
    83: venerated_...  2.81236108 12.5977621 101.956413 6d811173-d...
    84: inferior_a... -3.98163423 11.8931548   9.800451 74ca6f4c-e...
    85: venerated_...  3.03490861  8.2526338  35.179515 afaf127b-4...
    86: inferior_a...  3.75295311  9.7197780  64.125500 e566e734-7...
    87: venerated_...  5.24859181  5.9436101  37.356641 5f1cf9db-d...
    88: inferior_a...  5.22999712 13.8044588 173.377389 0fe8d523-2...
    89: venerated_... -4.02390646  3.9692176 114.711844 66e63b39-8...
    90: inferior_a... -1.77629066  8.8704534   8.173324 9d5921b7-a...
    91: venerated_...  5.49493347 12.4268096 143.820023 46bd12ed-4...
    92: inferior_a...  2.61292648  4.3293578   4.287892 ec11e536-e...
    93: inferior_a... -3.02802903  1.0388899 120.687795 503d38c4-c...
    94: venerated_...  6.54953653  4.1023344  28.171903 53459b12-6...
    95: venerated_... -0.04220619  6.3401628  19.667959 010af3a5-4...
    96: inferior_a...  4.58308985  2.7189840  10.451170 80d7d57f-4...
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
    1: venerated_...  9274 runnervm35...     FALSE terminated
    2: inferior_a...  9276 runnervm35...     FALSE terminated

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

    [1] "sugarcandy_redpoll"   "aeronautical_inganue"

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
    1: influenzal...  9566 runnervm35...     FALSE running
    2: veiny_foxt...  9568 runnervm35...     FALSE running

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
    1: influenzal...  9566 runnervm35...     FALSE running
    2: veiny_foxt...  9568 runnervm35...     FALSE running

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
