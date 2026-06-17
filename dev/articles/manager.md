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
    1: sterling_g...  9042 runnervm1l...     FALSE running
    2: aristocrat...  9040 runnervm1l...     FALSE running

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
    1: sterling_g...  9042 runnervm1l...     FALSE    running
    2: aristocrat...  9040 runnervm1l...     FALSE terminated

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

            worker_id           x1         x2           y          keys
               <char>        <num>      <num>       <num>        <char>
     1: clinical_s... -1.367892047 14.4796100  48.6685245 48b1c38a-e...
     2: clinical_s...  0.050376788 13.9695102  84.3821192 ff219029-d...
     3: clinical_s...  7.444480785  9.4418573  79.9309384 04842a30-8...
     4: clinical_s...  7.355910660  1.9052672  14.9746951 4682a833-c...
     5: clinical_s...  9.436489344 13.6073409 124.1073151 796629e1-6...
     6: clinical_s...  4.866316730  3.3605734  15.6596834 12bbdd63-b...
     7: clinical_s...  6.005760826 12.8343435 156.9036899 dc0804b8-0...
     8: clinical_s...  8.136198761  8.4116889  53.6902011 59f99e25-b...
     9: clinical_s...  3.163365160  1.5044334   0.9681491 43d11ed0-3...
    10: clinical_s... -1.957729741  6.4575027  16.3208686 130611d2-8...
    11: clinical_s...  5.182931836  0.2412198  15.3139928 48741532-b...
    12: clinical_s... -3.143988242 11.0977325   1.7974640 857ca5a4-d...
    13: clinical_s... -1.250574807 11.2218872  22.2003871 75e72e38-2...
    14: clinical_s...  6.095059796  7.7647596  63.8705980 de4a15ec-8...
    15: clinical_s...  9.714575843  3.6307550   1.6090989 11d492fd-a...
    16: clinical_s...  8.926070095 11.5897726  91.8803856 9744ee01-b...
    17: clinical_s...  0.540052554 12.8545696  77.1628639 393d4bdc-a...
    18: clinical_s... -1.331296917 12.3364707  28.1873900 04ebcbf5-d...
    19: clinical_s... -0.987954380 11.3762450  28.8110262 43b734ed-8...
    20: clinical_s...  1.191309286  7.5702555  24.3347547 d71b3c8d-9...
    21: clinical_s... -1.664870591  1.2978399  68.5414545 b70d153b-7...
    22: clinical_s...  4.704682040  6.4627987  35.8458933 df72095c-2...
    23: clinical_s...  0.305109071  9.2238792  32.8297633 e31099bc-c...
    24: clinical_s...  8.000845872  4.4744113  17.2302034 6b06ccfb-7...
    25: clinical_s... -2.813548436  8.3783455  10.6579821 92d4e102-5...
    26: clinical_s... -3.154089655 13.4952165   1.8151251 98b64789-b...
    27: clinical_s...  7.183746475  6.7950660  46.8962789 5d466876-7...
    28: clinical_s...  6.286956403 14.0669020 187.7394316 3cf5cfde-0...
    29: clinical_s...  1.296235851 13.9666129 108.8900288 5cf63d4c-a...
    30: clinical_s... -2.378310553 10.4208669   3.0708256 b0afa470-8...
    31: clinical_s...  2.214827761  5.7833098  11.3881874 8cc2196c-6...
    32: clinical_s...  6.432817615 14.4555179 197.6602536 c62eadb8-b...
    33: clinical_s...  1.711906352 12.6582816  89.7264886 05b22dcc-e...
    34: clinical_s... -2.034027988 13.3448911  18.4768769 35ea6911-8...
    35: clinical_s...  0.431589548  5.0537477  18.8019443 20bfe8a9-4...
    36: clinical_s...  1.580549329  1.8938567  13.5672276 9c7d4179-b...
    37: clinical_s...  2.349877421  4.7767350   6.5053210 18b4be26-0...
    38: clinical_s... -4.235045938 13.4530566   8.1621491 106f52b9-f...
    39: contorted_...  2.129164923  7.2958874  21.7139220 95d9a596-8...
    40: clinical_s... -0.226793307  1.2374481  45.6746579 bc334abe-b...
    41: contorted_...  2.497490252  4.8389223   6.3539141 5c348654-2...
    42: clinical_s...  8.577581264 14.0165443 151.5921209 a69b6b34-9...
    43: contorted_...  9.041064707 11.6804235  91.5376352 8ae85873-2...
    44: clinical_s...  1.421914756  0.4918684  23.7182640 ca6aa8ee-5...
    45: contorted_... -1.945910684  1.5622596  70.8652709 96a0dcc7-1...
    46: clinical_s...  4.591142558  9.1462030  68.5947139 80ef6329-0...
    47: contorted_...  6.043907403 14.5739915 200.8829225 f5c0b1a9-6...
    48: clinical_s... -0.359287416 12.5636315  54.6911936 1b5d71f9-e...
    49: contorted_... -0.094152519  3.6667779  25.7309114 54179e59-f...
    50: clinical_s... -0.895890062  3.9375346  28.9021293 4286e8ab-8...
    51: contorted_... -1.096917858  6.6159387  16.0338288 4d3f3395-f...
    52: clinical_s...  7.235921642 10.1576355  94.9529363 e24beb82-9...
    53: contorted_...  6.683256342 10.0791348  98.8698310 94b2b1cc-e...
    54: clinical_s...  5.023020535 12.0019568 128.2164778 719d7d32-9...
    55: contorted_...  0.515545576 13.7728823  91.6116256 b2bd08be-7...
    56: clinical_s...  4.011143721  4.1278841   9.7261164 994fae72-3...
    57: contorted_...  0.721263180  8.5792854  30.6065704 1ea87538-0...
    58: clinical_s...  0.004218654 13.6843724  78.7548055 7d04e408-8...
    59: contorted_... -1.776748486  6.9882221  13.0870696 cfd35903-7...
    60: clinical_s... -4.544938527 11.1907424  30.5954774 9482d253-c...
    61: contorted_... -3.872487114 12.2169649   6.3982833 93c04b8a-0...
    62: clinical_s...  2.321255721  8.1504656  29.9615693 de4d00cb-6...
    63: contorted_...  2.253472070  2.7741778   4.0295200 09cbc084-2...
    64: clinical_s...  1.047617883 11.6962230  66.9516410 9fd7ce52-b...
    65: contorted_... -1.260651339  3.8259633  32.1651697 c197dc86-a...
    66: clinical_s...  1.215591793 10.1474520  48.0460956 49eb787d-9...
    67: contorted_... -0.829846040 12.2693922  40.0979015 6c845125-5...
    68: clinical_s... -0.654426576  1.3070479  51.1404280 f91bfa9d-a...
    69: contorted_...  9.994034777  7.6089307  23.1816325 902e27ad-0...
    70: clinical_s...  7.108690042 11.1573895 115.3768414 bfc729bf-7...
    71: contorted_...  4.371622683  8.2880016  52.7158885 4a6a60ee-0...
    72: clinical_s... -1.045029957  4.3972677  26.4269227 7d784304-4...
    73: contorted_...  7.663187214  1.1738608  11.8676277 7c95b084-f...
    74: clinical_s...  8.836133943  8.3340202  41.8400639 61a57c80-b...
    75: contorted_... -0.507087557  4.9735390  21.8785039 fbc41981-6...
    76: clinical_s...  7.619799611  8.0410008  56.6858619 3de1e346-8...
    77: contorted_...  1.691798134  8.9219056  36.3482216 d3cd66ff-5...
    78: clinical_s...  9.905561033  7.6739210  24.1774677 eab9160e-0...
    79: contorted_...  3.167312059 12.6514388 108.4864221 d6bd3517-3...
    80: clinical_s...  5.506025923  6.8543037  49.3470220 5735e07b-f...
    81: contorted_... -0.601090802 11.4118785  37.3542458 efb20d69-5...
    82: clinical_s...  4.555873586  5.4591414  24.7335758 14f8b8b2-0...
    83: contorted_...  9.094422909 12.9866841 117.0446014 1cec9e57-c...
    84: clinical_s...  5.340478033  6.7221928  46.3049319 131ab4c2-a...
    85: contorted_...  0.389676297  2.3939461  27.9151792 3fb561de-c...
    86: contorted_...  4.980956975  2.4114384  13.8334755 e6dfca0d-5...
    87: clinical_s... -1.910466642  4.6175728  30.7573026 a7478ed6-f...
    88: contorted_... -0.764261818  1.0674667  55.6742337 92584bce-d...
    89: clinical_s... -3.743326381 11.7713170   6.0707336 7ec78f96-1...
    90: clinical_s... -4.011679485 12.3330488   8.3491533 a52e76f0-8...
    91: contorted_...  9.424747757  2.4578208   0.3981816 c0b62e7b-a...
            worker_id           x1         x2           y          keys
               <char>        <num>      <num>       <num>        <char>

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
    1: contorted_...  9042 runnervm1l...     FALSE terminated
    2: clinical_s...  9040 runnervm1l...     FALSE terminated

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

    [1] "kaolinite_redheadedwoodpecker" "palaeophilic_chanticleer"     

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
    1: uncarnivor...  9293 runnervm1l...     FALSE running
    2: nonrectang...  9295 runnervm1l...     FALSE running

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
    1: uncarnivor...  9293 runnervm1l...     FALSE running
    2: nonrectang...  9295 runnervm1l...     FALSE running

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
