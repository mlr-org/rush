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
    1: unrealisti...  9207 runnervm35...     FALSE running
    2: evenminded...  9209 runnervm35...     FALSE running

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
    1: unrealisti...  9207 runnervm35...     FALSE    running
    2: evenminded...  9209 runnervm35...     FALSE terminated

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

            worker_id         x1          x2           y          keys
               <char>      <num>       <num>       <num>        <char>
     1: stoutheart...  1.7517360 12.34810332  84.6538038 6682931b-2...
     2: stoutheart...  7.1678197  5.95540834  38.4201522 a49236a8-a...
     3: stoutheart...  3.9689601  2.95366507   5.0275064 6ec3e328-7...
     4: stoutheart... -1.3246181 13.96776563  44.0696081 efa71225-4...
     5: stoutheart...  8.3587217  4.12645084  11.1352351 193f241b-b...
     6: stoutheart... -1.5889172  3.55699730  37.8947053 3fe35f11-a...
     7: stoutheart...  2.3600016 11.93548036  83.6818492 5e036f12-1...
     8: stoutheart...  9.2148324  5.13495116   8.6252746 7f12f896-0...
     9: stoutheart...  0.4535832  3.85313666  20.7381455 924f49b8-0...
    10: stoutheart... -0.4750813  2.10803019  40.4153288 c3b31613-e...
    11: stoutheart...  8.0821207  2.55160271   8.7814548 58017be1-3...
    12: stoutheart... -4.0786815  7.90170623  49.7254517 8992de8d-e...
    13: stoutheart...  3.9893478  4.16616551   9.6954924 a628c5e4-0...
    14: stoutheart...  8.1285483 10.71165992  90.4433472 ee4f8b15-0...
    15: stoutheart...  8.9465077 12.62348754 112.1955597 8c1f3231-1...
    16: stoutheart...  7.4528146  3.29078335  17.6573920 69965483-6...
    17: stoutheart...  8.4340444  9.43792531  63.5942632 72bd3574-4...
    18: stoutheart... -0.4839109 11.59642845  41.5013239 b7fe7c54-f...
    19: stoutheart... -0.9142769  9.34536166  19.0372275 69bc905a-a...
    20: stoutheart...  2.8279429  7.29304284  23.5309020 a628cc0b-d...
    21: stoutheart...  6.1225080  4.41929923  30.5079921 77748e01-8...
    22: stoutheart... -4.6902217  5.83409879 119.4592682 584e280a-4...
    23: stoutheart...  7.5470974  9.84423463  85.1104890 1e6f28a6-2...
    24: stoutheart...  3.0921654  0.86629201   2.5050728 7aece2f2-0...
    25: stoutheart...  9.9105040  4.53711824   4.1391270 6affe7fe-f...
    26: stoutheart... -0.4523713  8.91539664  23.3407801 b41be75d-0...
    27: stoutheart... -0.1899501  8.76915931  25.4917523 59811a45-f...
    28: stoutheart...  2.7093272 12.16766331  92.1290386 845cc526-6...
    29: stoutheart...  5.9694889 11.91824140 136.1088720 99eb7473-2...
    30: stoutheart... -0.1033885  7.30502597  20.8483815 efcef90a-1...
    31: stoutheart...  9.8871581  8.80053082  36.3092706 13bcd56f-e...
    32: stoutheart... -0.3301423  0.01423897  61.6628302 13bb847c-d...
    33: stoutheart... -1.9723453  3.54047217  43.4712133 c5f18d4e-7...
    34: branny_ski... -1.3105902  7.31703891  13.4519619 52e8ecb1-4...
    35: stoutheart... -1.2783967  9.64466155  14.7247489 7caa36aa-7...
    36: stoutheart... -2.9703672  7.43269460  20.2039539 676f550d-f...
    37: branny_ski...  5.0536767  5.70740262  33.0274794 bed61ca7-f...
    38: stoutheart... -3.8340363  6.95103085  52.3121254 d9125cec-9...
    39: branny_ski...  1.6785002  5.90869481  13.8791396 c8b7f81d-a...
    40: stoutheart...  8.3637201  7.85638226  42.9033965 d0cf3441-0...
    41: branny_ski...  3.2962018  3.81665911   3.2651834 95856f8d-1...
    42: stoutheart...  0.3025475 13.07829521  76.1381362 e1bdd241-b...
    43: branny_ski... -4.6897198 13.32796770  18.6458829 f810b022-2...
    44: stoutheart...  5.6821623  0.78766857  18.0349233 aa84a1a4-8...
    45: branny_ski...  7.3818596  0.08679664  15.8167079 1728a808-4...
    46: stoutheart... -1.8622162 13.41057645  23.2313942 087a7551-a...
    47: branny_ski... -1.9845812 10.31047840   6.5528054 ccd254e8-f...
    48: stoutheart...  8.6389095  7.63566271  36.2044424 539ec5fd-c...
    49: branny_ski... -0.1842508  7.58043701  21.0851795 78afdacb-b...
    50: stoutheart...  3.4655128  5.27896414  11.4144351 68f28754-f...
    51: branny_ski... -2.6333391  7.54378531  14.1654112 1a9aee1d-6...
    52: stoutheart...  6.5910247  0.39823983  19.6746098 685e2118-7...
    53: stoutheart... -0.5814662  7.20761293  18.0809680 0a3f2258-a...
    54: branny_ski...  9.0476839  3.35479954   2.4638043 b977df47-2...
    55: stoutheart...  6.1563586 13.90672225 183.5873084 38854829-6...
    56: branny_ski... -2.1094068  4.95276591  29.8678692 6413001e-b...
    57: stoutheart... -3.0985833 12.10413907   0.4113555 c1264ec1-d...
    58: branny_ski...  3.6277219  5.18459398  12.1260309 b08d1744-8...
    59: stoutheart...  1.8653959 14.43504743 127.2107018 f897f291-3...
    60: branny_ski...  2.9228097 12.39910837  99.5756553 765412f9-a...
    61: stoutheart... -2.6669976  1.50556882  94.7353839 4af3023b-3...
    62: branny_ski...  0.6412687 11.69416921  62.0721939 0ea7282b-1...
    63: stoutheart... -3.3409257 13.54637453   1.2076983 87ee8f22-1...
    64: branny_ski...  8.0403076 12.91990273 137.3871036 3da203f3-3...
    65: branny_ski...  9.6177902 12.41239312  96.0246075 18d18a3f-d...
    66: stoutheart...  4.5761905 14.30263911 174.6048801 d5ec3336-9...
    67: stoutheart...  4.0621805 14.87322606 178.6035617 5d038fc7-3...
    68: branny_ski...  6.6124725 13.68661471 176.8932228 119efe6b-4...
    69: stoutheart...  4.1671194 12.76853367 129.5082593 419770c7-2...
    70: branny_ski...  3.5474012 10.22574747  69.1733768 cd3552be-0...
    71: branny_ski... -3.0520970  2.48415211  92.1514710 c3f80a3e-e...
    72: stoutheart...  6.8750150  5.80361645  39.4942312 0c036fff-0...
    73: branny_ski... -3.2188460  0.69175274 138.9518116 6c39c873-9...
    74: stoutheart... -3.2885753  4.83182383  61.3289683 5b002491-6...
    75: stoutheart...  3.0067501  2.06667639   0.5847994 52d2008a-b...
    76: branny_ski... -0.4929043  8.25432993  20.5282737 f030e4f8-8...
    77: stoutheart...  6.5658544  9.76045285  93.8902288 bbb5ba0a-9...
    78: branny_ski...  5.9067243 13.20427960 165.2901900 e765ef3c-c...
    79: stoutheart...  1.4285051  7.53554103  23.9319782 963382a2-9...
    80: branny_ski... -3.5720871  0.83133559 157.5786650 d21a2031-7...
    81: branny_ski...  8.8977815  6.52383361  21.5698905 363c2491-6...
    82: stoutheart... -2.8994548  2.40904713  87.0120517 a15da81a-8...
    83: stoutheart...  6.5477702 14.59404424 200.8861423 e9abdc3f-b...
    84: branny_ski...  3.9855941  0.72859326   4.5804551 15d560f1-6...
    85: branny_ski...  1.3688309  7.46850097  23.5202325 71d851ea-8...
    86: stoutheart...  4.8189542 13.56264774 160.6501764 eedaa543-2...
    87: branny_ski...  1.9168677  5.04344146   9.3658858 fa401b77-9...
    88: stoutheart... -1.2458770  2.39939556  46.5199687 f3947285-6...
    89: stoutheart...  2.8684567  9.76456690  53.5619921 cc26ffb4-a...
    90: branny_ski...  9.9596220  5.19217388   6.7075814 99c191ef-3...
    91: branny_ski...  9.7845425 12.22819742  89.9942562 f5ce6f2f-2...
    92: stoutheart...  8.2248778 10.49114611  84.7058446 51359e68-a...
    93: branny_ski... -3.6778234 11.31411735   6.9747226 16f526dd-8...
    94: stoutheart... -3.2090347  1.38221901 122.6426449 d1bb8965-8...
    95: branny_ski...  3.4591075  1.07649285   1.8069868 607b83c1-0...
    96: stoutheart... -3.4032698 14.15834864   2.2763614 c05c190b-b...
    97: branny_ski...  3.7592920  4.92396728  11.6672282 15f9eb90-9...
    98: stoutheart...  9.4075479  1.61212217   1.1190651 ffaee2e1-e...
    99: branny_ski... -0.4411885  2.21998863  38.9986852 7336fd3d-7...
            worker_id         x1          x2           y          keys
               <char>      <num>       <num>       <num>        <char>

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
    1: branny_ski...  9207 runnervm35...     FALSE terminated
    2: stoutheart...  9209 runnervm35...     FALSE terminated

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

    [1] "clubfooted_tarantula" "idle_racer"          

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
    1: emanatory_...  9497 runnervm35...     FALSE running
    2: scribblena...  9499 runnervm35...     FALSE running

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
    1: emanatory_...  9497 runnervm35...     FALSE running
    2: scribblena...  9499 runnervm35...     FALSE running

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
