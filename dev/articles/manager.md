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
    1: socalled_a...  8953 runnervm1l...     FALSE running
    2: semiphilos...  8951 runnervm1l...     FALSE running

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
    1: semiphilos...  8951 runnervm1l...     FALSE    running
    2: socalled_a...  8953 runnervm1l...     FALSE terminated

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

            worker_id          x1           x2           y          keys
               <char>       <num>        <num>       <num>        <char>
     1: turtleshel...  2.19642152  6.248957103  14.1204123 febdf1df-0...
     2: turtleshel...  6.98555132  5.135954253  32.9309033 841736cc-7...
     3: turtleshel... -4.09488547  5.036374947  97.5052566 c2f9de1d-5...
     4: turtleshel... -0.79292520 11.670615904  35.4649327 469b864d-f...
     5: turtleshel...  7.20004063 13.183512661 158.5416777 3a032674-b...
     6: turtleshel...  3.88645824 12.285106006 113.5968538 ca73bbfa-8...
     7: turtleshel...  7.96141130  4.192936166  16.1296725 ea05df75-4...
     8: turtleshel...  7.29027476  3.121405204  18.5840067 d92d695e-6...
     9: turtleshel... -1.47032165  4.280859925  29.7857866 235dc2e1-8...
    10: turtleshel...  7.11181880 13.980365220 179.4424513 9d0bad79-1...
    11: turtleshel...  9.81386734 14.764061201 143.7102141 091de9a4-7...
    12: turtleshel...  8.32232828  8.660958822  54.0916207 d889527d-d...
    13: turtleshel...  2.56172183  8.056076662  29.9031841 72fe6cbd-4...
    14: turtleshel...  8.23505629  9.198461374  63.3432127 1f6771f3-b...
    15: turtleshel... -1.57546862 14.377865783  40.7552003 4fa10c03-b...
    16: turtleshel... -0.21895326  5.445769857  20.1989615 d1e66535-d...
    17: turtleshel...  9.13282541  2.598210991   0.9327124 8991b937-b...
    18: turtleshel...  1.28855555  2.749844426  14.6732429 44b00de6-e...
    19: turtleshel... -2.78220178  7.560058511  15.9721968 741ec4ec-b...
    20: turtleshel... -1.19655704 10.942025421  21.6480096 7549c7f6-f...
    21: turtleshel...  8.00697151 12.218282405 122.5894586 e752e6ed-0...
    22: turtleshel... -2.49580002  3.888427902  49.7823279 c99771e9-9...
    23: turtleshel...  8.86364473  9.469110058  57.0271318 d281eb5b-9...
    24: turtleshel...  2.40518420  2.197094468   3.4075887 a53d92d2-b...
    25: turtleshel...  7.89510413 10.189668023  85.3422571 3e357554-e...
    26: turtleshel...  5.86374750 14.042016259 186.0229651 164789c7-6...
    27: turtleshel...  3.39624737 14.481845323 154.3947149 2923404e-9...
    28: turtleshel... -4.09096350  4.752378602 102.8284351 f54502df-a...
    29: turtleshel... -3.79084346  1.635089349 152.5285147 00396095-e...
    30: turtleshel...  9.27725926  0.008992892   5.9983103 455957f2-3...
    31: turtleshel...  5.61359614  5.856885558  39.8098307 04b2abf4-5...
    32: turtleshel... -0.98319938 10.746963437  24.6699694 0923aebe-9...
    33: turtleshel...  9.18880291 14.662985300 153.9244732 61bd033d-a...
    34: turtleshel...  5.19893587  2.825545211  17.0759922 ad72e64c-8...
    35: nonrationa...  1.94395631  5.777887929  12.1810365 6cc7cdc2-b...
    36: turtleshel...  7.30623328  9.043610776  75.4641156 46d76658-d...
    37: turtleshel...  9.24332805  1.750004957   0.8875211 531e6097-4...
    38: nonrationa...  4.37147536  7.016010360  37.0917100 189f7bfe-9...
    39: turtleshel...  6.63867715 13.190363558 164.5110133 4ccb58eb-3...
    40: nonrationa...  3.31328968  9.074128767  48.5531634 80a12355-5...
    41: turtleshel...  1.39308138  2.064219738  15.5757221 b0830bbc-0...
    42: nonrationa...  4.23441626 10.035830410  77.1344944 5190f02a-e...
    43: turtleshel...  7.41247235  6.087603353  37.0175277 95e25174-a...
    44: nonrationa...  1.25233833  1.103231209  22.6550299 d215420a-a...
    45: nonrationa... -3.09680938  2.805262474  88.0615179 19dc98c3-8...
    46: turtleshel...  2.40889740  2.154620000   3.4413562 b56c55fc-c...
    47: nonrationa... -0.02908864  5.886431618  19.6236421 d145d180-0...
    48: turtleshel...  9.09859580  9.103289200  48.3719579 aaef76b8-2...
    49: turtleshel...  1.29527789  2.041557054  17.0798699 48256c7f-3...
    50: nonrationa...  7.40199913  3.213229576  17.8644346 0f9931d1-c...
    51: turtleshel...  7.32198475  7.180873124  49.7799546 b72e7eb1-7...
    52: nonrationa...  1.72035049  9.669433243  44.8713927 a0bd17a1-3...
    53: turtleshel...  6.88518103 13.458749875 169.0263590 5b8d45f3-9...
    54: nonrationa...  0.52125367  3.473873508  21.3254369 a8f4a11a-a...
    55: nonrationa...  9.19292767  2.242760595   0.6567141 36827ecc-1...
    56: turtleshel...  6.05047409  3.190493676  23.7151695 c074249d-8...
    57: turtleshel...  7.93901513  6.487011679  33.9859826 7f1174c2-7...
    58: nonrationa... -1.84408981  5.308376582  23.9398687 d860a137-9...
    59: turtleshel... -2.41944043  6.155116740  22.6127860 84a26895-0...
    60: nonrationa...  0.49301938  6.523576895  20.0888992 d09fef7c-9...
    61: nonrationa...  4.25242330  8.699679532  56.5966679 6b8b7819-9...
    62: turtleshel... -4.22711109  0.306221542 222.4870015 c6f9ff7a-4...
    63: nonrationa...  5.64537234  7.996702044  64.8350283 0806807c-5...
    64: turtleshel... -4.53906779 14.702828375   9.7433899 756e7a0f-7...
    65: nonrationa...  4.71840797  0.930187271  10.2481665 7ad8b409-e...
    66: turtleshel...  0.49729472 10.276983828  43.8054558 503134c3-5...
    67: nonrationa...  2.54564982  9.510433698  47.2760725 838cbb72-2...
    68: turtleshel... -4.22535017  9.580131570  35.2209079 2131f18a-9...
    69: turtleshel...  3.78361075 14.059864352 151.9389347 b2b2690d-6...
    70: nonrationa...  6.65786741  2.250492007  20.1913193 d570cc2b-d...
    71: nonrationa...  8.54410627  2.322556198   4.1272990 1b06ee0b-7...
    72: turtleshel...  3.14057848  9.152292738  47.6841678 03a05224-6...
    73: nonrationa... -1.99634649 11.374522824   8.8664628 b6705dda-6...
    74: turtleshel...  6.73611004  3.385756197  23.6732404 495cadfe-0...
    75: turtleshel...  6.15875947  3.040764680  23.3020610 d73eaeb3-b...
    76: nonrationa... -3.22366586 14.212253129   3.4548219 a3786d54-e...
    77: nonrationa...  1.75444493 14.231104571 121.1530555 cf2d0873-7...
    78: turtleshel...  3.80400367 14.694079211 168.2967964 0dc7a0ea-a...
    79: turtleshel... -4.79469018  6.136965179 120.2815490 25ec3587-2...
    80: nonrationa...  2.59175464  2.209578521   2.0975308 0a80b7fe-2...
    81: nonrationa...  9.01959029 14.426135102 151.7702606 243c7eea-2...
    82: turtleshel...  1.85656677  8.678143551  34.2052505 f48ab562-6...
            worker_id          x1           x2           y          keys
               <char>       <num>        <num>       <num>        <char>

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
    1: nonrationa...  8951 runnervm1l...     FALSE terminated
    2: turtleshel...  8953 runnervm1l...     FALSE terminated

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

    [1] "preglacial_mynah"       "noncapitalistic_sphinx"

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
    1: sulky_trum...  9205 runnervm1l...     FALSE running
    2: earnest_co...  9203 runnervm1l...     FALSE running

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
    1: sulky_trum...  9205 runnervm1l...     FALSE running
    2: earnest_co...  9203 runnervm1l...     FALSE running

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
