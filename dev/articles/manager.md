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
    1: frivolous_...  8915 runnervm7b...     FALSE running
    2: familial_n...  8917 runnervm7b...     FALSE running

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
    1: familial_n...  8917 runnervm7b...     FALSE    running
    2: frivolous_...  8915 runnervm7b...     FALSE terminated

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
     1: virtuous_a...  3.76777048 13.8203810 145.813354 bdbfc553-9...
     2: virtuous_a... -3.95300142  6.0888941  70.976777 97f72a52-1...
     3: virtuous_a...  5.17855147  3.8250875  21.089391 74d51403-2...
     4: virtuous_a...  4.65958064 12.5886230 134.927826 6d95b299-f...
     5: virtuous_a...  4.27890548 12.6650019 129.395506 7db4b43f-0...
     6: virtuous_a... -0.46759524 14.6267604  80.261618 fc9ee706-7...
     7: virtuous_a...  4.40657200 10.4300980  86.941262 e0a472fb-b...
     8: virtuous_a...  2.00968782  6.9781590  19.278156 1f6253b3-5...
     9: virtuous_a...  1.09165520  9.3963544  39.225416 20a0be21-5...
    10: virtuous_a... -0.67350696  5.6946282  19.567169 7a859684-5...
    11: virtuous_a...  4.70530263  9.4520798  75.229232 feb49503-d...
    12: virtuous_a...  4.14795562  8.8186161  56.668973 0c8553c4-0...
    13: virtuous_a...  8.37371474 13.1675174 136.022301 fe13ecf4-e...
    14: virtuous_a...  0.78379817  9.4292954  37.936530 b166c0e0-f...
    15: virtuous_a...  5.24299425  4.9281222  28.708430 29603923-1...
    16: virtuous_a... -4.55059290  1.1112468 227.682254 7376e034-3...
    17: virtuous_a...  5.80649612  6.9899040  53.055774 29ebb8cc-1...
    18: virtuous_a...  5.16495033  5.3305016  31.046112 8b075679-a...
    19: virtuous_a...  4.46488837 14.8438844 186.528984 029b1dde-e...
    20: virtuous_a...  3.53121228  6.9482712  25.694426 638bae11-6...
    21: virtuous_a...  2.44253343  1.3868622   4.889404 e970cd20-8...
    22: virtuous_a...  4.79083359 10.7914979 100.079389 7ed8919f-3...
    23: virtuous_a... -3.72325078  4.6226955  84.675487 21511deb-8...
    24: virtuous_a...  2.50650690  5.8196587  11.253767 182b733c-2...
    25: virtuous_a...  3.64457050 13.3694295 132.781204 9d3fc343-d...
    26: virtuous_a...  4.90399598  5.4715786  29.215407 1e992d38-a...
    27: virtuous_a...  2.90726362  0.2787154   5.439438 71de0f63-c...
    28: virtuous_a...  4.55958440  4.9544331  20.967717 58c44660-c...
    29: virtuous_a... -1.90361821  8.9463585   7.167009 ddadea0a-1...
    30: virtuous_a...  6.62688276  5.6312285  39.335812 6c3e823c-a...
    31: virtuous_a...  3.88053351  5.7315814  18.602206 660f00de-f...
    32: virtuous_a... -0.65068907 10.8463772  31.748196 67a7ca72-e...
    33: virtuous_a...  9.29985017  1.9070822   0.688531 686c6f30-f...
    34: virtuous_a...  0.49412837 14.8427276 110.567750 5406300c-d...
    35: virtuous_a...  5.81209548  3.3819652  23.701339 08ca5aa1-8...
    36: virtuous_a...  9.04642373 11.5742434  89.435132 f33183f7-f...
    37: virtuous_a...  0.83626111  6.7880619  20.551244 03c4cd3b-a...
    38: virtuous_a... -1.71095095  7.5691342  11.005944 3a4afce6-e...
    39: unwhite_af...  2.05117043  1.3202184   9.399501 a2b6e642-c...
    40: virtuous_a...  9.17204835 12.8103251 111.799922 28303128-0...
    41: unwhite_af...  3.16402475  6.1813261  15.796157 b58414b6-1...
    42: virtuous_a...  1.15724327  7.8001660  25.892512 944decdd-e...
    43: virtuous_a... -2.47548559  3.8285270  50.101593 cb55ffe3-9...
    44: unwhite_af...  7.79297555  1.0970329  10.704792 de72266c-c...
    45: virtuous_a... -2.30208104  6.9039014  15.452708 661a99c4-a...
    46: unwhite_af... -3.32853502  7.1176035  32.050508 9adc1b8b-e...
    47: virtuous_a...  3.19035460 13.3619174 124.166865 680b3b8c-9...
    48: unwhite_af...  9.47757869  0.9248427   2.955473 1749a6ef-9...
    49: virtuous_a... -0.21896267  7.6134496  20.957338 a551f953-3...
    50: unwhite_af...  1.65935331  3.5881346   9.166811 b4b92c04-e...
    51: virtuous_a...  8.38510089 12.9574683 131.020874 3748792d-c...
    52: unwhite_af... -0.41835426  0.3589145  58.836925 d824741c-2...
    53: unwhite_af...  4.03059808  5.2167671  16.430757 c70b40bf-b...
    54: virtuous_a...  4.33910828  0.4306241   7.699020 606bb11e-e...
    55: virtuous_a...  9.01982230  6.7049146  21.879906 7d5d4642-7...
    56: unwhite_af... -2.21865657  4.1501388  40.407971 cf9f5aee-9...
    57: unwhite_af... -0.04615893  6.6074259  19.876706 650f7826-e...
    58: virtuous_a... -0.07036231  1.1567126  44.139417 081f2d43-d...
    59: virtuous_a...  1.27426183  1.0775425  22.441679 ad699965-7...
    60: unwhite_af...  3.08338484  0.5810576   3.440963 7a2864a1-9...
    61: virtuous_a...  3.94394294 11.2421092  93.760078 fee0284a-0...
    62: unwhite_af...  3.72229401 13.1523422 129.360232 93cd1991-3...
    63: virtuous_a...  8.05113129 13.4176926 148.722665 358fa41b-4...
    64: unwhite_af... -3.05056645 10.1747651   3.981626 966982d7-b...
    65: virtuous_a...  2.61671879 12.2929761  93.333914 a48bc0c8-0...
    66: unwhite_af... -4.15727993  0.1994534 219.554689 8fc7ab3c-7...
    67: virtuous_a...  2.22220268  3.3583563   4.244321 e1e3fe62-0...
    68: unwhite_af... -4.18619129 12.8467269   9.502327 fc001a68-0...
    69: virtuous_a...  4.05056488  5.7633473  20.830994 80ed0fcd-1...
    70: unwhite_af...  7.46492659 10.3085396  94.471594 0cf51fa1-0...
    71: virtuous_a...  3.37666274  0.6066410   2.888553 4ae045b5-7...
    72: unwhite_af... -1.45681898  5.3171558  21.821707 e800fb91-9...
    73: unwhite_af...  2.93840620 14.6966929 150.851597 0b8b3d03-c...
    74: virtuous_a...  9.54027939  3.7873504   1.933717 8f4bc6ae-4...
    75: unwhite_af...  9.82519024  3.0839029   1.220128 fc67e7eb-4...
    76: virtuous_a...  5.09358492  7.3875803  51.304199 e052d501-3...
    77: unwhite_af...  2.36021866  1.3922018   5.651157 67862cbb-3...
    78: virtuous_a... -2.21617798  0.1918328 103.621340 81722ad9-f...
    79: virtuous_a...  9.27179425 12.9691763 113.298636 5f1eeb4e-5...
    80: unwhite_af... -4.61992478 11.4645141  30.695018 a6aa7d49-f...
    81: unwhite_af...  4.66051946 14.8349394 190.308967 fd82fadd-7...
    82: virtuous_a...  3.40716778  7.3573316  28.616421 f04c583b-1...
    83: virtuous_a... -0.30629363  8.4158823  22.827342 bc1e8ced-8...
    84: unwhite_af...  0.40617229  8.1124874  26.315437 194a6919-e...
    85: virtuous_a...  4.54665471 12.5381658 131.712038 bf2d4ac0-f...
    86: unwhite_af... -3.45935724  0.8375503 150.064273 5e36b663-1...
    87: virtuous_a... -2.83323617  5.3249460  39.555144 409de670-b...
    88: unwhite_af... -4.91555108  7.1740293 107.404994 25fb746a-5...
    89: virtuous_a... -2.59562928  4.3957864  45.428245 b3adf7fa-f...
    90: unwhite_af...  5.11802005  8.3877408  64.903573 5748730f-a...
    91: virtuous_a...  8.69729467  7.3561243  32.274512 c9df8d06-8...
    92: unwhite_af...  4.64296451  8.4410838  58.976442 30b0ec6a-b...
    93: virtuous_a... -4.44350169  3.4147873 156.483781 605ff3e3-9...
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
    1: unwhite_af...  8917 runnervm7b...     FALSE terminated
    2: virtuous_a...  8915 runnervm7b...     FALSE terminated

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

    [1] "kooky_godwit"        "querulous_crocodile"

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
    1: deerskin_l...  9167 runnervm7b...     FALSE running
    2: gnomic_oct...  9169 runnervm7b...     FALSE running

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
    1: deerskin_l...  9167 runnervm7b...     FALSE running
    2: gnomic_oct...  9169 runnervm7b...     FALSE running

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
