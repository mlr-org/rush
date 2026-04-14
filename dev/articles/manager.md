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
    1: talismanic...  9035 runnervm35...     FALSE running
    2: infertile_...  9033 runnervm35...     FALSE running

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
    1: talismanic...  9035 runnervm35...     FALSE    running
    2: infertile_...  9033 runnervm35...     FALSE terminated

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
     1: gastrovasc...  8.09267604  8.2571259  52.3059815 1ef788cf-7...
     2: gastrovasc... -1.57109474  2.3927327  51.2984939 e09a4831-f...
     3: gastrovasc...  5.71549115  4.9788965  32.9595517 9f4fa12e-c...
     4: gastrovasc... -4.25952625  1.0273599 204.4889593 f2ffc519-a...
     5: gastrovasc...  7.06241220  6.1010636  40.8201301 0de321b3-b...
     6: gastrovasc...  9.11076434  6.2968463  17.4647721 555fbea2-b...
     7: gastrovasc...  2.03109996  0.5834644  13.1159477 65e8a4a0-c...
     8: gastrovasc... -1.88588120  9.4100467   7.0269210 5e0e5864-7...
     9: gastrovasc...  7.62995714  5.2350101  27.0159890 629436a7-9...
    10: gastrovasc...  7.49750502  1.6560794  13.4577789 5615067f-c...
    11: gastrovasc...  4.88851018 12.0728303 127.5879776 39445598-c...
    12: gastrovasc...  1.00357200 12.8850266  84.9175926 0b2a904d-4...
    13: gastrovasc... -1.22313416  8.3460417  13.3139227 38628ef1-3...
    14: gastrovasc... -0.92546323  1.5709911  51.9263726 899648d9-1...
    15: gastrovasc...  9.67733903 11.3509573  75.6059315 9228fe36-1...
    16: gastrovasc...  6.93814505 10.3578529 101.9167352 d8a48968-7...
    17: gastrovasc...  7.36185168  2.9798860  17.4108838 449a4ad6-3...
    18: gastrovasc...  9.61797079  5.9890396  11.7739501 1cd902c4-f...
    19: gastrovasc...  0.97549678  8.9495957  34.5619816 c9c74d76-6...
    20: gastrovasc...  7.10291595 11.3445496 119.2029896 d885a1a3-5...
    21: gastrovasc... -3.19724752  9.9302352   6.5577839 6715aea0-e...
    22: gastrovasc... -2.07819712 12.3416616  11.4656961 ba7e371a-7...
    23: gastrovasc...  7.48685766 11.1849262 110.6551870 ea5f4072-1...
    24: gastrovasc...  0.70646275 11.7970147  64.3211905 266322db-a...
    25: gastrovasc...  4.60159971  4.2538092  17.0155369 c64b99d2-4...
    26: gastrovasc...  4.54118117  0.7040238   8.9006880 c90a4b90-6...
    27: gastrovasc...  9.92117715  1.4357075   3.7764800 0abbb3cf-8...
    28: gastrovasc... -4.45002074  8.9306536  52.5332723 b706b19a-5...
    29: gastrovasc...  8.61399934  7.6754142  37.0178412 d9d3ff4b-6...
    30: gastrovasc...  2.10281046  6.7103059  17.2799587 42a440f9-d...
    31: gastrovasc... -2.63202590 10.5766653   1.8750992 6a489172-d...
    32: gastrovasc...  5.53511367  2.1016409  17.9468807 61ef1226-f...
    33: gastrovasc... -4.52130263 14.3995819  10.2415908 907a9149-a...
    34: employable...  2.28193134  5.8128329  11.4164559 daaa8c8f-3...
    35: gastrovasc...  6.98818747  6.6203573  46.8382501 ff3c977c-9...
    36: employable...  4.26966028  1.2248146   5.9985110 ee46f88f-3...
    37: gastrovasc... -1.12467913 11.3287305  25.5359197 0584ff84-f...
    38: gastrovasc...  3.32179475  1.5282030   0.9260307 8a5fbde0-b...
    39: employable...  6.80247924 10.7514978 110.4987878 3fe0299c-5...
    40: gastrovasc... -3.27039158 13.9020405   2.2076019 fb1d4443-3...
    41: employable...  0.81918415  2.4114921  22.1801551 ca7c8e88-7...
    42: gastrovasc... -3.87289664  6.7160695  57.3989807 e814b971-9...
    43: employable... -0.42670983 13.5121166  65.1099238 78b72719-0...
    44: gastrovasc...  5.21687343  7.3600385  52.4280144 4da42a58-d...
    45: employable... -4.41309577 10.9742652  28.0109828 6e56f24b-c...
    46: gastrovasc...  7.24887631  3.9376658  22.6791882 ab00d99a-c...
    47: employable...  9.86589703  1.4617623   3.3064764 fa5d2775-7...
    48: gastrovasc...  6.15069386  2.2994727  20.9613739 ac4e9daa-d...
    49: employable... -3.86928516  5.5021795  76.6189180 ec2502b1-4...
    50: gastrovasc...  4.82345578  7.8250697  53.2657654 6480c51a-c...
    51: employable...  2.47274133  6.8769151  18.6474224 2977c5e1-a...
    52: gastrovasc... -2.79715204  1.1488590 107.3341574 fb2e3102-3...
    53: employable...  3.66419871  7.3975146  31.8722951 c50eec7a-c...
    54: gastrovasc...  4.24625130  9.2672226  64.9137840 b1d2880a-9...
    55: employable...  8.32774686  1.5638853   5.6390739 9cddc205-5...
    56: gastrovasc... -2.20862230 10.6413098   4.5284501 6f6b5798-d...
    57: employable...  7.90109812 11.7128591 114.0615797 39ab2e65-9...
    58: gastrovasc...  1.53355219 10.1890108  50.3748166 a97dc9a4-e...
    59: employable... -3.38538504 13.5120754   1.0959260 29c27371-f...
    60: gastrovasc...  3.29304578  3.3597317   1.9475172 2bd62d6c-7...
    61: employable...  5.44827564  4.6181114  28.3798782 19d281a4-b...
    62: gastrovasc...  8.74922440 13.8156985 142.9669776 c069cc9e-0...
    63: employable...  7.79022862  1.2417803  10.6515858 e6b352ce-a...
    64: gastrovasc... -2.79370416  9.5048353   4.7745915 ea3b6737-4...
    65: employable... -1.28768006 10.5568155  17.9411345 6a10455c-e...
    66: gastrovasc...  6.63623501  7.7611414  63.0172003 8d947743-d...
    67: employable...  0.27773365 11.4978989  54.3985897 470e0ce2-4...
    68: gastrovasc...  7.54862361  0.1334158  14.3598729 97542715-8...
    69: employable...  0.40722122 12.8576823  74.8327307 f97ba0b5-8...
    70: gastrovasc...  5.70108747 10.8715563 113.0113570 6794c0a2-1...
    71: employable... -3.61210513 10.3477072  10.9686752 77470112-5...
    72: gastrovasc...  6.94901016  9.0162338  78.9818051 e6f27693-5...
    73: employable...  0.93939175  5.7154530  16.8703301 9a29c43b-9...
    74: gastrovasc... -3.94577708  7.2546685  52.8517037 ded498fb-6...
    75: employable...  2.20951384  7.7335752  25.6148920 95e6c3b4-d...
    76: gastrovasc...  0.12929403  1.6397205  36.7997982 70b93c25-6...
    77: employable...  5.04895806 13.9174827 173.4462081 467ed5c6-3...
    78: gastrovasc... -3.53324383  7.9413562  29.1587137 f50b23d9-3...
    79: employable... -1.86876622 12.2479359  15.1478140 26852a80-7...
    80: gastrovasc... -1.37673091  5.9380206  18.0916150 a7c7dfed-4...
    81: employable...  5.12281582 14.5103549 190.0130491 ab51ecff-1...
    82: gastrovasc... -1.66831884  1.7525036  61.8055687 61f0b8b0-c...
    83: employable... -0.55616173  2.0703597  41.7236318 f298e3f9-4...
    84: gastrovasc... -1.22108391  7.0173702  14.5413611 02df61f7-7...
    85: employable... -0.03071414  6.0551535  19.5976217 ff99b64a-b...
    86: gastrovasc... -3.66509789 10.6663856  10.1062180 7793f852-4...
    87: employable... -1.68247239  6.1951945  17.0423031 42fb60f6-9...
    88: gastrovasc...  9.09700945  8.6457949  42.2976591 ef161d5d-c...
    89: employable... -0.90316370  7.3729902  15.9737805 1ff570f2-2...
    90: gastrovasc...  4.37446691  3.9415751  12.7297318 65237c93-e...
    91: employable...  3.39771785 12.3552833 106.2158655 822a7ba3-1...
    92: gastrovasc...  2.45977592  9.1326658  41.8060200 ecd6cbd1-8...
    93: employable...  3.00131741  9.9680691  57.9657689 87af460b-3...
    94: gastrovasc...  5.29063272 10.4555571 100.9935160 6771790e-0...
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
    1: gastrovasc...  9033 runnervm35...     FALSE terminated
    2: employable...  9035 runnervm35...     FALSE terminated

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

    [1] "fungous_tench"       "mechanistic_waxwing"

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
    1: nuclear_ar...  9327 runnervm35...     FALSE running
    2: phantasmag...  9325 runnervm35...     FALSE running

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
    1: nuclear_ar...  9327 runnervm35...     FALSE running
    2: phantasmag...  9325 runnervm35...     FALSE running

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
