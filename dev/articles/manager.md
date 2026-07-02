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
    1: promethean...  9064 runnervmmk...     FALSE running
    2: pseudocons...  9066 runnervmmk...     FALSE running

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
    1: pseudocons...  9066 runnervmmk...     FALSE    running
    2: promethean...  9064 runnervmmk...     FALSE terminated

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

            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>
     1: padparadsc... -3.3437870 13.7582827   1.5777215 4de2c3a4-f...
     2: padparadsc... -3.2390577 12.8207764   0.5397555 93cd5f58-f...
     3: padparadsc... -4.4011437  5.4330922 108.5420241 585d8826-c...
     4: padparadsc...  7.2421657  5.1016572  30.3554538 d4799211-f...
     5: padparadsc... -2.8097497  2.6788768  78.5880842 c46c3b00-d...
     6: padparadsc...  9.7987081  8.9111583  38.3040726 76ef3f87-6...
     7: padparadsc... -4.1967968  1.7310836 180.1310187 cb46dd35-4...
     8: padparadsc...  4.8858400 11.2876236 111.2547671 b95f0d69-b...
     9: padparadsc...  3.7887368 12.6163279 118.8046122 11f2ae9b-9...
    10: padparadsc...  6.9821132  4.1979629  26.4265394 f6311009-7...
    11: padparadsc...  5.8610234  2.1922599  19.9312814 4521afcd-2...
    12: padparadsc...  4.5523034  4.6492869  18.8207514 9ec7676f-d...
    13: padparadsc... -0.9353119  0.5248104  65.7805494 575f957c-0...
    14: padparadsc...  1.3982008 12.6546514  86.0811976 f5b6b284-9...
    15: padparadsc... -2.6123378  2.9326788  67.4282675 9bf70753-6...
    16: padparadsc... -2.3696952 14.6241277  20.1531068 095841e5-d...
    17: padparadsc... -2.6134962 13.3186764   6.8897811 1c49b4da-7...
    18: padparadsc...  8.1003172 14.3114294 169.6356784 82edb5dc-9...
    19: padparadsc...  8.0796874 13.2989738 145.3233669 2fdc5591-f...
    20: padparadsc...  0.8174950  8.5155766  30.4836671 04166802-d...
    21: padparadsc...  4.4551190  1.2779311   7.5950815 b0830fd9-4...
    22: padparadsc... -0.4789325  4.7408701  22.7283816 6cf1972d-c...
    23: padparadsc...  5.8984406 10.7163413 111.2419633 90a7ff82-6...
    24: padparadsc...  7.1058872  8.8398787  74.6915250 9e293c41-0...
    25: padparadsc...  5.2109729  6.2982393  40.4371252 2d6d22d3-b...
    26: padparadsc...  6.3810257  4.3674936  30.2042893 ac5f4aa2-e...
    27: padparadsc... -3.6538946  5.5726736  65.1103337 b5ffba18-6...
    28: padparadsc... -3.8041572  0.6367519 178.9808181 e02f6718-c...
    29: padparadsc...  0.9328137  8.1056271  27.8141422 e2021f67-6...
    30: padparadsc...  2.7080938 12.0640380  90.1486162 289fe340-3...
    31: padparadsc... -3.8168463 13.9673800   2.5052001 e9f3ea95-1...
    32: padparadsc... -4.2893443  8.7603702  47.5719029 ab4fde73-0...
    33: padparadsc... -2.2946653  4.8677762  33.5015745 6953573a-6...
    34: nonsentien... -4.5329673  5.9084171 107.4975825 13a68c36-0...
    35: padparadsc...  5.0268431  1.5021613  13.0266700 109a9712-6...
    36: nonsentien... -3.0917322  1.5213761 113.4942939 727cb8d9-2...
    37: padparadsc...  9.0189471  4.8250002   8.3123331 7166802a-b...
    38: nonsentien... -4.1530079 10.7814241  21.3589065 899e1701-4...
    39: padparadsc... -1.8453665  4.9842230  26.6922824 b3d8609d-a...
    40: nonsentien...  8.2975696  4.7174028  15.0542944 9af3552f-4...
    41: padparadsc...  9.8586575 11.0970732  69.0495988 fe2ebd76-f...
    42: nonsentien...  1.4696027  9.3328435  40.0521437 65e6acb9-8...
    43: padparadsc... -0.9694312 13.3163643  47.3783518 46508e9d-7...
    44: nonsentien...  6.2686093 10.2979830 104.2120141 adf6134e-6...
    45: padparadsc...  7.0548020  4.6304972  28.6408249 37e15d29-f...
    46: nonsentien... -4.5603133 13.0531546  16.9055068 667c4b07-f...
    47: padparadsc...  8.7092199  3.4896533   5.1620263 c29ff74d-2...
    48: nonsentien...  6.4876988  5.7148540  40.5890684 8e298c57-9...
    49: padparadsc... -1.4374727  1.2140962  65.1615442 2fa36495-1...
    50: nonsentien...  2.0108643  3.2951082   5.9102125 c5922ba6-8...
    51: padparadsc... -0.2489087  8.8978682  25.5248022 17a22ae1-3...
    52: nonsentien... -3.5145425  7.5116501  33.2931814 56ad7d5b-4...
    53: padparadsc...  6.7166599 14.0272415 184.8447288 fff8c0aa-e...
    54: nonsentien...  6.5337921 12.5462985 149.9518210 7215240d-6...
    55: padparadsc... -0.2111363  9.2783091  28.0120107 9c9029bb-3...
    56: nonsentien...  5.7950361  7.0240614  53.3947188 543b1026-e...
    57: padparadsc... -1.1801478  0.8891977  65.0507512 01a06797-2...
    58: nonsentien...  5.3569319  2.2755230  16.9664828 0e6439ec-a...
    59: padparadsc... -4.5442758  0.4790722 246.2032005 d500699e-8...
    60: nonsentien...  7.4316940  6.2489770  38.3589224 61dd114e-b...
    61: padparadsc... -0.7226320  1.6096102  48.6513835 73b9155b-a...
    62: nonsentien... -3.5900372  2.1524246 127.3765538 7d5878f3-1...
    63: padparadsc...  0.3615336  0.8442156  40.1162908 42381248-c...
    64: nonsentien... -3.5022985  1.3840505 139.6574802 27902ba4-5...
    65: padparadsc...  1.3059816  7.6276138  24.6640540 f75e6556-1...
    66: nonsentien...  6.3984789 13.1140560 163.7464930 3bff7407-c...
    67: padparadsc...  2.7588286  7.5565607  25.7353426 11805444-f...
    68: nonsentien...  8.8297780  9.1984407  53.5946987 5ed2fcf6-5...
    69: padparadsc...  0.7012262  7.0406014  21.7176414 7408fcd5-3...
    70: nonsentien...  2.1657367 13.7472387 116.7281024 6a033e86-3...
    71: padparadsc...  0.3084356  5.6896245  19.1772852 6714e34e-f...
    72: nonsentien...  1.9125006  1.2427870  11.5604957 1de105aa-0...
    73: padparadsc...  1.4025958  6.5421856  17.9596130 fb3125d5-b...
    74: nonsentien...  3.1449617  4.2241286   4.2072875 67bdd732-0...
    75: padparadsc... -0.2936415  5.9414943  19.4794638 2f3d02c4-e...
    76: nonsentien...  7.2226490  4.0961835  23.8027690 4a96c88e-b...
    77: padparadsc... -1.1842523  6.1754180  17.1940892 a799e65a-d...
    78: nonsentien...  9.6341307  5.9794586  11.6445773 4271ab08-4...
    79: padparadsc...  7.1088392  4.4327642  26.8691765 f0dc636d-b...
    80: nonsentien...  1.1562789  5.0488058  14.3804113 dc112c5f-a...
    81: padparadsc... -1.4967349  4.4030935  28.9300352 a4e7a391-7...
    82: nonsentien... -1.3147841  1.1445532  63.8591273 31669abc-1...
    83: nonsentien...  5.2760807  8.5753188  69.5410371 61cc47a7-9...
    84: padparadsc...  3.8575928  2.2098993   2.9381825 c6b6cd00-2...
    85: nonsentien...  7.7102308 11.9207331 121.8825401 08180f48-e...
    86: padparadsc... -0.2223800 11.4103109  44.8680978 4a314a80-7...
    87: nonsentien... -0.1031566  0.1680580  55.5210213 5da2d33e-5...
    88: padparadsc...  8.2013582  0.6576309   7.6890757 f8238903-7...
    89: padparadsc...  3.2884318 11.4910555  87.5087724 45786a7e-b...
    90: nonsentien... -1.1024598 14.8675377  62.7190364 2da3875a-8...
    91: padparadsc...  1.2010794 13.4741293  98.0977049 f97cbf8a-e...
    92: nonsentien... -2.6845638  3.4153055  62.0414311 51839d8d-8...
    93: padparadsc...  8.9480383  4.7497849   8.4781577 be90757d-2...
    94: nonsentien...  0.5912185 13.9443216  96.1199919 b1428831-a...
    95: padparadsc...  9.3834729 12.2140322  95.9303799 9a07eb91-e...
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
    1: nonsentien...  9066 runnervmmk...     FALSE terminated
    2: padparadsc...  9064 runnervmmk...     FALSE terminated

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

    [1] "cowlike_numbat"     "psychodelic_kawala"

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
    1: idiotic_bl...  9337 runnervmmk...     FALSE running
    2: nonrationa...  9339 runnervmmk...     FALSE running

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
    1: idiotic_bl...  9337 runnervmmk...     FALSE running
    2: nonrationa...  9339 runnervmmk...     FALSE running

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
