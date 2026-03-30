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
    1: lethal_pyg... 10002 runnervmrg...     FALSE running
    2: expressibl... 10004 runnervmrg...     FALSE running

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
    1: expressibl... 10004 runnervmrg...     FALSE    running
    2: lethal_pyg... 10002 runnervmrg...     FALSE terminated

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
     1: reasonable...  0.9453055  8.934908156  34.3186991 b3097db6-2...
     2: reasonable... -2.2913742  8.238920055   8.0165115 9ae23aa2-b...
     3: reasonable... -2.3909709  2.979019231  60.2051708 2e0b4ec1-f...
     4: reasonable...  4.4798098 11.113419661 100.9227176 e3c4a526-9...
     5: reasonable... -1.1657126  8.003300264  13.7849098 d6736711-c...
     6: reasonable...  3.4752396  5.825565510  15.3399215 3e7837eb-c...
     7: reasonable...  7.8689696  8.751011120  62.7914950 d8f39e33-c...
     8: reasonable...  8.1540419 10.497322710  86.1159335 5dd34f74-b...
     9: reasonable... -4.0003403 12.589828511   7.1272417 ab6c3816-1...
    10: reasonable...  8.9451434 12.360778509 106.7621207 f84dcb19-3...
    11: reasonable... -3.1055957  9.493797613   7.6663806 933ce6c6-d...
    12: reasonable...  3.0641541  7.258030890  24.6514188 326915de-a...
    13: reasonable...  2.7110501  4.092357772   3.3989211 c331de0c-f...
    14: reasonable... -2.9127393  3.358726228  70.7562114 aa16cce7-2...
    15: reasonable...  3.4497656  1.815508018   0.9038086 6c9a3161-6...
    16: reasonable... -3.6777164  0.003230864 186.6326084 79354de5-8...
    17: reasonable...  5.9688912  4.662271109  31.8018947 dea9d60b-e...
    18: reasonable...  6.4884331  2.540504267  21.4412641 08f627d2-4...
    19: reasonable...  6.1848447 13.609285493 176.0850055 635d50e4-4...
    20: reasonable...  6.8322510  4.189438066  27.3899029 81ad4073-c...
    21: reasonable...  5.6356676  9.061166963  80.5055467 3dbec4a3-5...
    22: reasonable...  7.5029294  3.601467814  18.4569513 16475b3f-7...
    23: reasonable...  4.2639127 13.541066839 149.3233866 699cba24-a...
    24: reasonable... -0.9802282  5.771676855  19.0045495 b88ded93-f...
    25: reasonable... -1.0769768 10.185784379  19.9424758 572f429e-7...
    26: reasonable...  4.7968462  3.952408170  17.6446984 e7fe5a78-8...
    27: reasonable... -1.8084036  0.490312340  85.3617302 c2fdc0b6-4...
    28: reasonable...  3.6856674  3.160688581   3.4017160 7cdb7d15-6...
    29: reasonable...  9.1433879  2.491530083   0.8349051 f5ab8b34-9...
    30: reasonable...  7.8534221 13.007983992 143.1649444 294d7a98-e...
    31: reasonable... -4.2367805 13.603075575   7.7316971 361fa31f-8...
    32: reasonable... -2.3374864  6.880342982  15.9106571 cda95c30-f...
    33: reasonable...  4.7796795  9.475739567  76.7681101 f47278b9-1...
    34: reasonable...  7.8861479  6.249120333  32.4074532 b858cd40-f...
    35: reasonable... -1.7689410  5.369812013  22.9306471 37a0d260-8...
    36: reasonable... -3.5695991  9.776454841  13.8723158 0c42b095-f...
    37: reasonable... -2.8956727 13.623625236   4.4186964 e8a97e76-2...
    38: ungodlike_...  9.8382764  7.500156019  22.8694058 40a4fcb4-3...
    39: reasonable...  0.3973640  1.832305939  31.4967293 2794701f-4...
    40: ungodlike_...  1.3811628 14.466479753 120.3496064 dfdafeed-1...
    41: reasonable...  9.9726416 11.670702685  77.4026817 0dda8ac8-5...
    42: ungodlike_...  6.6237942 12.942585017 158.6862033 08323501-f...
    43: reasonable...  7.7840833  7.974908598  53.3914936 b45e0bcb-c...
    44: ungodlike_...  9.3257551  3.375874614   1.4114817 bdb38927-7...
    45: reasonable... -1.7680678 14.270476531  33.6475150 25fa8780-4...
    46: ungodlike_...  6.2945353  5.485600597  38.8316720 3f994f55-6...
    47: reasonable...  6.8176052 13.860352465 179.7169961 a7a11af3-8...
    48: ungodlike_...  3.5673152 14.102373980 148.5365961 789d31a7-3...
    49: reasonable...  8.0794898  2.259221693   8.3224542 446a2095-f...
    50: ungodlike_...  0.5123449  7.911973013  25.6240359 ab1f72ae-5...
    51: reasonable...  2.3236247  0.869540413   7.9710017 0a77a55d-1...
    52: reasonable...  5.6638654  2.691076549  20.2562167 97d0abb8-b...
    53: ungodlike_...  2.4355587 14.912254989 147.2278895 a5122efe-4...
    54: reasonable...  4.8066510 12.422059766 133.8345964 7148604b-d...
    55: ungodlike_... -3.5253108 14.743470189   3.4287536 408749f7-d...
    56: reasonable...  3.5307191 10.303581215  70.2131236 6b418991-9...
    57: ungodlike_...  6.0214929 10.264302881 103.2501662 921fdfa5-5...
    58: reasonable...  4.8621645 14.942935784 197.1362595 d32570cc-f...
    59: ungodlike_...  0.9962087  2.326446742  20.1303794 52363cb6-2...
    60: reasonable... -0.9260109  8.057019280  15.9943397 f2f31c2c-a...
    61: ungodlike_... -3.0747859 10.970966755   1.7281739 f57d55b5-3...
    62: reasonable...  1.4541099  7.931257178  26.8977986 281d2875-4...
    63: ungodlike_...  7.5027241  5.666026711  32.0967567 350f347c-a...
    64: reasonable...  4.9066381  5.634065085  30.6291849 7734caf3-6...
    65: ungodlike_... -3.4870202 14.214779857   2.1623950 26064a5e-e...
    66: reasonable...  4.4691367  6.873139877  36.9095374 ba76d258-a...
    67: ungodlike_...  8.0798631 11.718229835 110.7507132 567e656c-1...
    68: reasonable... -1.5102456  1.182787960  67.0636800 0578bcc0-6...
    69: ungodlike_... -1.3885970 12.653223922  29.3303888 0ce471af-5...
    70: ungodlike_...  3.4675729  4.254966150   5.8339914 3ab2a6e7-5...
    71: reasonable...  5.2578781  2.107069045  15.7989593 6306bda4-b...
    72: ungodlike_...  9.9572566  7.581571694  23.0789546 bd487c8b-d...
    73: reasonable...  9.5502505  6.900255136  19.1131654 f95e018b-8...
    74: ungodlike_...  6.3677010  4.563249291  31.5369230 a1aedfd7-2...
    75: reasonable...  7.6227560  1.159905314  12.2465543 8bcdfa0d-a...
    76: reasonable... -4.4080847  8.064755959  62.7915381 289017a5-2...
    77: ungodlike_...  6.0166872  9.115531801  83.5008068 8d96af36-e...
    78: reasonable...  5.8791754  5.803538608  40.8750270 ff6c0db9-9...
    79: ungodlike_...  7.8199491  5.403086099  25.9219681 891395be-6...
    80: ungodlike_...  9.8301138  9.980754322  52.1929713 f0d2d33d-2...
    81: reasonable...  3.4240578 10.315469516  68.8482565 86af3fcc-6...
    82: ungodlike_...  3.6256228  0.709018515   2.9863195 7c108189-f...
    83: reasonable... -1.2727461  0.542915728  71.9863804 3dab29aa-8...
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
    1: ungodlike_... 10004 runnervmrg...     FALSE terminated
    2: reasonable... 10002 runnervmrg...     FALSE terminated

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

    [1] "circumfluent_grasshopper" "distractible_dodo"       

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
    1: rancid_kis... 10295 runnervmrg...     FALSE running
    2: confusing_... 10293 runnervmrg...     FALSE running

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
    1: rancid_kis... 10295 runnervmrg...     FALSE running
    2: confusing_... 10293 runnervmrg...     FALSE running

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
