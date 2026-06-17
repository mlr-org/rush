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
    1: disyllabic...  9065 runnervm1l...     FALSE running
    2: kneedeep_c...  9067 runnervm1l...     FALSE running

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
    1: kneedeep_c...  9067 runnervm1l...     FALSE    running
    2: disyllabic...  9065 runnervm1l...     FALSE terminated

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
     1: microcosmi...  3.324349890  1.7499796   0.7074200 d7764b2d-7...
     2: microcosmi... -3.666951170  2.7907351 117.9547148 b571f39f-f...
     3: microcosmi...  8.788155854  4.6096351   9.1395006 81cea374-b...
     4: microcosmi... -0.390138105  7.4513807  19.5379633 e808ac63-b...
     5: microcosmi...  8.594134832  3.3918208   5.8601873 795943c0-f...
     6: microcosmi...  8.201868024 12.2576121 119.5314482 ba15d1f2-b...
     7: microcosmi...  6.791480359  9.8391983  93.8980515 65ca933f-3...
     8: microcosmi...  2.388760503 11.9109864  83.5554078 14ba06a5-e...
     9: microcosmi...  2.725423407 12.9727487 108.3569775 def349bd-8...
    10: microcosmi...  0.112734022  9.9224389  36.3529559 6bd32929-0...
    11: microcosmi... -2.552270990 12.0658171   3.3683763 db6b280c-f...
    12: microcosmi...  2.668412441  7.7290042  27.0167358 73181297-8...
    13: microcosmi... -4.275820752 13.1121052  10.1625706 8ad44948-e...
    14: microcosmi...  8.496872519 10.9900863  88.6364022 07fffc12-0...
    15: microcosmi...  3.211099518 11.7695555  91.5879927 ce2f86ac-f...
    16: microcosmi...  1.167885047  5.1284511  14.4226851 62f61e31-8...
    17: microcosmi... -2.376066536 10.2747511   3.1325011 6381a6d8-2...
    18: microcosmi...  6.060822685  3.9662783  27.5852102 8e44bd64-9...
    19: microcosmi...  3.099424958 12.9295545 113.2214092 43f39450-0...
    20: microcosmi...  7.567011419  6.1328885  35.5576517 49120eff-2...
    21: microcosmi...  5.768148350  1.7178816  18.7164834 8531c14a-3...
    22: microcosmi... -4.757340996 13.5050495  19.3729974 3b553de3-e...
    23: microcosmi... -3.716599571 12.8695070   2.6310584 fa32e23c-5...
    24: microcosmi...  5.512599843  1.9469495  17.5212006 77eae95e-7...
    25: microcosmi...  1.536675746  0.2773435  23.1583888 12a28659-1...
    26: microcosmi...  2.620632210  3.9895361   3.2927260 d2177741-8...
    27: microcosmi...  9.383488137 12.0026136  91.8421641 20053c80-6...
    28: microcosmi... -2.435301005  2.5521608  68.1413570 51498599-9...
    29: microcosmi...  2.236796654  6.2811190  14.2737867 3327f8c9-3...
    30: microcosmi...  7.373541288 14.1242907 179.2006814 9f9cdf8f-7...
    31: microcosmi...  0.610609766 11.1575339  54.8477939 9b80fa8d-d...
    32: microcosmi...  1.848753861  6.7864377  18.1714807 2ae8c0ee-a...
    33: microcosmi...  1.638759680  1.5748029  14.0306305 91904c9a-e...
    34: microcosmi...  0.273223640  7.3896411  22.5395994 c25b1cb7-a...
    35: microcosmi...  0.154105324  1.5934593  36.8300680 0c73b5a4-2...
    36: trusting_b... -0.616695867  5.5091135  20.1483645 f4865ee0-f...
    37: microcosmi...  8.550628719  9.3222195  59.8770321 0fd6fd84-1...
    38: trusting_b... -2.909107104  5.8384481  35.2872720 79269c7e-e...
    39: microcosmi... -2.663447899  0.2837658 119.6680196 a7d7890b-b...
    40: trusting_b...  3.244082940  7.3922076  27.4443901 9206c0a5-b...
    41: microcosmi...  8.915551404  1.9740813   1.6271845 85b59206-9...
    42: trusting_b...  6.803732791  8.6538183  74.6139447 1974292c-5...
    43: microcosmi... -3.481122248 12.9463821   0.9714925 61a78e6d-1...
    44: trusting_b...  0.608350613  5.2072545  17.8957130 bc9c3900-f...
    45: microcosmi...  5.214631270  7.1979866  50.4365715 80fc4d5e-a...
    46: trusting_b...  0.757512479 12.3677351  73.2147558 42853462-e...
    47: microcosmi...  1.347093484 11.4472218  66.2520906 addc12e0-9...
    48: trusting_b... -4.149975484 14.3106056   5.1493761 ce132255-d...
    49: microcosmi...  7.048726554  4.2148044  26.0117760 ca19eca9-3...
    50: trusting_b...  6.723627236  6.3099328  45.4234372 c9d90e11-c...
    51: microcosmi...  5.762909000  9.4869744  88.3644867 5cb4b7cb-9...
    52: trusting_b...  8.512353085 10.1584894  73.7740261 8efdaf57-8...
    53: microcosmi... -3.238861968 13.5715657   1.5702321 1a67cffe-5...
    54: trusting_b...  0.387375098 14.5133249 101.8912267 bcf3b603-2...
    55: microcosmi... -0.840318582  8.3393078  17.2361085 5e818a94-e...
    56: trusting_b... -0.352714613  9.6131999  28.2268643 09a6b9a6-4...
    57: microcosmi...  8.311222264 12.7242906 127.3867193 915bdd8a-a...
    58: trusting_b... -1.423533861 12.5047665  27.2282880 8bcde67f-f...
    59: microcosmi... -0.796637630 14.6450335  69.9323493 afc1f026-0...
    60: trusting_b... -4.406596071  7.2120482  76.1617918 d4baf1cc-d...
    61: microcosmi... -3.377682175  7.5136806  29.1360743 7fd96a29-0...
    62: trusting_b... -4.934951623  8.5660921  83.2561166 485be6bc-9...
    63: microcosmi...  8.426262158 13.3082488 138.1266372 cbefdb10-8...
    64: trusting_b... -2.733479342  5.3476460  36.8044328 c8427576-b...
    65: microcosmi...  8.327396603  4.1926092  11.8107946 4cf3889a-2...
    66: trusting_b...  1.394372359  9.6624619  43.3878476 4e5b7b85-e...
    67: microcosmi...  4.410863742  8.3170260  53.7120415 4f64ab2b-7...
    68: trusting_b...  6.514465011  0.3708028  19.8991918 e8e062b5-a...
    69: microcosmi...  8.039635289 10.4116205  86.6768682 bcb3a8f2-5...
    70: trusting_b... -4.295969654  5.3628751 103.3064527 002c480f-c...
    71: microcosmi...  6.326261733  1.0288955  19.5984928 a51c53b4-1...
    72: trusting_b... -1.263152981  8.3372138  12.9222229 97d25522-e...
    73: microcosmi... -2.181111104  0.6460267  93.6081557 19d4e0bd-7...
    74: trusting_b... -1.869429988  5.9979908  18.9313776 e17875b4-7...
    75: microcosmi... -3.995909492  1.3664947 174.1510049 70ee52d8-d...
    76: trusting_b...  6.351658971  1.0235339  19.5858918 4d4e817f-3...
    77: trusting_b...  3.495935691 14.7895225 164.1858477 944fae4f-5...
    78: microcosmi... -0.046326449  0.4809170  50.8744787 977da0df-6...
    79: microcosmi... -1.435922862  4.5464293  27.3333765 10e6d180-5...
    80: trusting_b... -4.964449403 14.2988465  20.1575098 373e2db1-2...
    81: trusting_b...  5.442519603  6.4765437  44.6216973 62c955cc-4...
    82: microcosmi...  0.492061776 10.7703149  48.9573607 4e894f22-9...
    83: trusting_b...  0.701385468  1.9207221  26.4954647 70e30cd4-c...
    84: microcosmi...  8.949092785 12.0325166 100.0596011 21590c01-6...
    85: microcosmi... -0.006648474  0.3901048  51.1917218 3a26fddb-d...
    86: trusting_b...  7.612814108  2.3447390  13.2420670 044af3e7-8...
    87: microcosmi... -0.700137029 12.0861629  41.4369692 658fc2fa-9...
    88: trusting_b...  2.743866909  0.2813471   6.5495635 428df6fb-f...
    89: trusting_b...  8.349550617 13.9217042 154.3795383 326c4983-3...
    90: microcosmi... -3.007470226 12.6679280   0.9923960 ee4aa48e-7...
    91: microcosmi...  6.451373414  2.6015400  21.6942761 7e7c4461-3...
    92: trusting_b...  2.793400066  9.0195411  42.6713133 c8f87a1b-c...
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
    1: trusting_b...  9067 runnervm1l...     FALSE terminated
    2: microcosmi...  9065 runnervm1l...     FALSE terminated

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

    [1] "knowing_sparrow" "wizardly_cuckoo"

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
    1: meteorogra...  9319 runnervm1l...     FALSE running
    2: easy_ameth...  9317 runnervm1l...     FALSE running

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
    1: meteorogra...  9319 runnervm1l...     FALSE running
    2: easy_ameth...  9317 runnervm1l...     FALSE running

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
