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
    1: educated_p...  8766 runnervmmk...     FALSE running
    2: exorcistic...  8768 runnervmmk...     FALSE running

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
    1: exorcistic...  8768 runnervmmk...     FALSE    running
    2: educated_p...  8766 runnervmmk...     FALSE terminated

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
     1: ergasiopho... -0.43783562  5.4727753  20.2559265 9bf1c005-f...
     2: ergasiopho...  7.48134122 12.5122066 138.6809744 dc47e8f5-d...
     3: ergasiopho... -0.10385735 10.7019456  40.1189387 52fcd628-c...
     4: ergasiopho...  8.74803341  7.8904442  37.6448922 5e3ada65-0...
     5: ergasiopho... -3.54133212  7.4239063  35.1718552 22b30c7d-9...
     6: ergasiopho...  0.47004465  7.5007172  23.4903626 d46c1b99-f...
     7: ergasiopho...  0.63577501  0.9812662  34.2021360 7e219702-c...
     8: ergasiopho...  8.19836622  7.8549255  45.4481165 f69d9cb8-3...
     9: ergasiopho...  6.67936418 13.0467765 160.7991104 90b7c4c2-c...
    10: ergasiopho...  7.91586723  2.5228292  10.4598460 faa8f833-d...
    11: ergasiopho...  5.44232718 12.8711286 153.4463450 855c088d-c...
    12: ergasiopho... -0.81230060  5.4833973  20.1943583 8ce110b3-c...
    13: ergasiopho...  7.20413694  7.4584500  54.4928963 5785966a-6...
    14: ergasiopho...  3.73370275  2.8788765   3.0736138 fb2b6449-0...
    15: ergasiopho... -0.65649798  5.4876460  20.2075474 98c0d630-0...
    16: ergasiopho...  9.28176573 10.4236409  65.5664746 e2110c3a-9...
    17: ergasiopho... -0.94024779 14.3904618  61.6270222 e9787cc0-7...
    18: ergasiopho...  4.09593745  5.7646347  21.3919622 3c7f0041-a...
    19: ergasiopho...  9.69504636 13.7951590 123.5736999 3fda77d9-b...
    20: ergasiopho... -0.39116509  7.6773914  19.9481839 ee937886-2...
    21: ergasiopho... -1.18094552  8.5588386  13.8984282 dc7a8b79-6...
    22: ergasiopho...  9.92733419  8.9473187  37.7746934 7ed4e36f-3...
    23: ergasiopho... -0.17860866  6.9158903  19.8431228 76771aae-2...
    24: ergasiopho...  1.49920422  3.8339855  10.6917924 906041b4-c...
    25: ergasiopho...  1.44437047  7.8969013  26.6256350 8eb193d2-d...
    26: ergasiopho... -2.35152230  0.2971140 106.4635332 287f26cb-7...
    27: ergasiopho...  9.37073543 11.7272350  86.8543665 278e7417-f...
    28: ergasiopho...  6.91878397  6.9213925  50.7776580 c87ba31b-4...
    29: ergasiopho...  6.77126109  5.6279738  38.5662495 071ace79-9...
    30: ergasiopho... -2.15741338  8.5705820   6.8290393 6bafea37-7...
    31: ergasiopho...  1.56293250  2.2000796  12.7259010 1f325221-0...
    32: ergasiopho...  1.04343595  4.3865358  14.8410326 4d75640e-5...
    33: ergasiopho...  1.01963704  6.4132011  18.6448355 7546e9f6-6...
    34: ergasiopho...  9.54410769  4.5502073   4.3577585 497a154f-5...
    35: ergasiopho...  1.60618984 10.9976514  61.7988110 7275181c-6...
    36: ergasiopho...  9.40662906  1.4514187   1.4161676 c77ea0d7-f...
    37: opinionate...  6.07778092  8.2617014  70.7058118 845746e1-c...
    38: ergasiopho...  9.44917749 11.2449712  76.9512187 58dab37b-9...
    39: opinionate... -3.12362506 13.3822844   1.7229107 8a05c8e7-2...
    40: ergasiopho...  0.21066635 12.9493491  72.3722374 dcd0269f-5...
    41: opinionate... -2.40275635  6.9352149  16.1126819 92ec4f5c-1...
    42: ergasiopho... -3.05584953 11.9865235   0.4401123 2b592b80-3...
    43: opinionate...  9.10043489  1.3345286   1.6737683 dfcf5112-7...
    44: ergasiopho...  0.01732150 11.4110507  49.1788242 b7bcbb6e-f...
    45: opinionate...  7.41641151 10.6335897 101.1479110 ccd72a4c-8...
    46: ergasiopho...  4.84597446 14.7135347 190.6364013 8fe15743-4...
    47: opinionate...  0.75120069 13.8636159  97.7712993 8a696a2c-8...
    48: opinionate...  5.46610510  8.7313202  73.8925252 f2f98ae5-1...
    49: ergasiopho...  0.86568450 13.6805192  96.5315564 4328483f-c...
    50: ergasiopho...  9.51968126 10.8622551  69.4313746 7a680f45-e...
    51: opinionate... -4.98945821  8.4633904  88.2050090 12e53612-f...
    52: opinionate... -3.35512490  1.1266997 136.7432487 013752fc-c...
    53: ergasiopho...  2.66238351 12.8970346 105.9003362 c8f25a64-4...
    54: opinionate...  9.58730951  8.9706483  40.9122002 dd5349c3-e...
    55: ergasiopho...  8.66163059  7.2663869  31.7892289 a5665627-0...
    56: opinionate...  8.85379138  1.2753069   2.4989484 96a572c1-c...
    57: ergasiopho...  3.35696629 14.6370503 157.4707826 2f7ce08f-7...
    58: opinionate...  5.86662481 13.5807149 174.3207566 3adbad45-c...
    59: ergasiopho...  8.91661308 12.3089250 106.2480255 565affe2-4...
    60: ergasiopho... -4.83678373  1.9988930 227.9077940 ad227e3a-4...
    61: opinionate... -0.37855581 12.5074142  53.5721133 03beeacf-6...
    62: ergasiopho... -0.74515173  4.2492091  26.1082802 3477f1ce-6...
    63: opinionate... -3.29804639  8.8331751  15.1150774 f60d8f1b-2...
    64: ergasiopho... -3.99861486  1.5580906 169.3871231 27a8509c-5...
    65: opinionate...  6.97528065  7.8726787  62.1324085 03cff6f5-3...
    66: opinionate... -3.65324020  8.0732132  31.4961380 a9669e84-9...
    67: ergasiopho...  4.08086033 11.8545329 108.3315350 b298ee95-a...
    68: opinionate...  3.45207777  7.5028458  30.6416082 4257e3a1-6...
    69: ergasiopho...  9.21207447  9.3643508  50.4992077 1f28c3e2-9...
    70: ergasiopho... -3.23516813 10.6466787   3.8784613 25356527-9...
    71: opinionate...  0.02409399 11.7187737  52.7428988 a292b937-b...
    72: ergasiopho...  6.35396762  5.4538677  38.5089857 c09eac8e-3...
    73: opinionate...  4.03846408  1.2220488   4.2169716 c95da0be-3...
    74: opinionate... -0.63337683  0.5767197  59.7709270 57bc7bbb-5...
    75: ergasiopho... -2.55144231  1.4023731  92.2595963 ac1d5318-a...
    76: opinionate... -1.60634134 13.3569227  29.6129611 7471c00d-2...
    77: ergasiopho...  0.14834955 12.1746195  60.5575990 b2762dbd-b...
    78: opinionate...  2.67204706 13.1771157 111.8436876 307469f2-7...
    79: ergasiopho...  9.07507779  1.7202087   1.2052553 f2ba668a-5...
    80: opinionate...  3.82670923 14.1382871 154.7648442 cfab8dcd-c...
    81: ergasiopho...  4.73235490  9.4754147  76.0300092 7d3fcf72-1...
    82: opinionate...  5.98585532  3.2270170  23.6966756 10e30dc7-3...
    83: ergasiopho... -1.61887804 10.0700031  10.8723236 295c4582-7...
    84: opinionate... -2.13520955  7.0448380  13.5214789 d813f125-6...
    85: ergasiopho... -2.48766884  9.5830748   3.7608822 e7f922d6-e...
    86: opinionate... -2.89989801  6.0090692  33.0829883 6a60bd7d-c...
    87: ergasiopho...  6.40915320 12.5754958 151.0739977 943eed21-e...
    88: opinionate...  5.34261890  2.3566974  17.0332261 78619282-b...
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
    1: opinionate...  8768 runnervmmk...     FALSE terminated
    2: ergasiopho...  8766 runnervmmk...     FALSE terminated

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

    [1] "conversational_liger"              "cryptocrystalline_americankestrel"

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
    1: autositic_...  9020 runnervmmk...     FALSE running
    2: chivalric_...  9022 runnervmmk...     FALSE running

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
    1: autositic_...  9020 runnervmmk...     FALSE running
    2: chivalric_...  9022 runnervmmk...     FALSE running

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
