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
    1: carping_ra...  8980 runnervm7b...     FALSE running
    2: likeminded...  8978 runnervm7b...     FALSE running

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
    1: likeminded...  8978 runnervm7b...     FALSE    running
    2: carping_ra...  8980 runnervm7b...     FALSE terminated

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
     1: apiphobic_...  2.36502247 11.2370764  71.6850774 20b4654f-7...
     2: apiphobic_... -4.35970416  3.3737815 151.1712429 1691aa46-a...
     3: apiphobic_...  7.96494240  6.8090918  36.9227995 251e2ba0-4...
     4: apiphobic_...  3.89833597 10.3948169  77.5988822 c9440ecf-2...
     5: apiphobic_...  5.88257462  4.3807780  29.5530472 3da70057-4...
     6: apiphobic_...  8.70120594  8.3119000  43.5032002 88f3ceb5-9...
     7: apiphobic_... -4.83845752  5.6403034 134.0764970 b2f5387c-2...
     8: apiphobic_...  8.31193697  0.9918249   6.2510171 52a362d2-d...
     9: apiphobic_... -2.10463104 10.1724846   5.1768989 8c7822dd-0...
    10: apiphobic_...  4.10584945  2.8319942   5.9399279 d97e2d08-3...
    11: apiphobic_... -1.01339267 13.5914672  49.2543228 40dfe2c0-a...
    12: apiphobic_...  6.04997314 13.9079649 183.3963178 f3f5211d-3...
    13: apiphobic_...  7.65630981  4.7556418  23.2315813 59d3d42e-b...
    14: apiphobic_... -1.46206986  7.0556428  13.4365950 84d3ad41-f...
    15: apiphobic_... -1.16467864  1.5475824  55.8004840 1887cddd-7...
    16: apiphobic_... -3.54284754 11.0635668   5.9853747 d022fc34-7...
    17: apiphobic_...  9.26079277  4.4397057   4.9348427 0aac409f-9...
    18: apiphobic_... -2.89650434 12.3696231   1.1416370 50e8fa0e-c...
    19: apiphobic_...  5.24305231  2.9838863  18.0182400 4f032cf6-9...
    20: apiphobic_...  2.31074940 13.8759019 121.5475688 3a0740ac-5...
    21: apiphobic_...  9.22817850  2.0492817   0.6530168 512293dd-8...
    22: apiphobic_...  5.20555445  6.3961877  41.3830607 bceae592-d...
    23: apiphobic_...  8.69227858 13.5644549 138.3042659 a292c9cd-0...
    24: apiphobic_... -1.34131624  3.5794649  35.1065234 ad5eea97-6...
    25: apiphobic_...  0.91762728  0.6187674  32.0726329 ffc46a62-6...
    26: apiphobic_... -4.59197990  7.6947412  78.3628909 7a8c822b-a...
    27: apiphobic_... -0.01415873  3.9006432  24.1036818 18f8c567-2...
    28: apiphobic_... -3.70076207 10.2384418  13.5619843 5020f3aa-5...
    29: apiphobic_... -3.53154123  9.1632419  17.6717633 40b206e7-b...
    30: apiphobic_...  7.03205937  3.0619085  20.5136725 80c4a67e-f...
    31: apiphobic_... -0.78982117  3.6064471  30.6813251 bbd4a3ed-a...
    32: apiphobic_... -2.12714235 11.9936516   9.0245066 db4fdada-6...
    33: apiphobic_...  4.55962048  2.2824424   9.2673291 70df9892-5...
    34: apiphobic_...  3.05917980  5.3031300   9.2097406 fa515935-d...
    35: apiphobic_...  0.96634399  2.2821246  20.7494129 c09bccfe-b...
    36: apiphobic_...  2.33669135  3.1944028   3.3872483 6d024e41-a...
    37: apiphobic_...  1.47642363  6.3748041  16.8731083 7230efbc-3...
    38: apiphobic_...  9.82400933  2.9820031   1.1753931 62931e90-f...
    39: relievable... -3.79436826 10.4051558  14.5777883 56a7aa3b-8...
    40: apiphobic_...  4.28549180  3.2821865   9.0179498 794d0452-c...
    41: relievable...  2.20028695  9.9097475  50.3993850 49209baf-a...
    42: apiphobic_...  5.66826132 11.4010742 123.3530283 ddfb59c0-a...
    43: relievable... -0.98123814  8.0197577  15.4500620 cf8670dd-6...
    44: apiphobic_... -0.53638657 13.5162203  62.1490857 a9bfb489-1...
    45: relievable...  8.15809865 10.1007896  79.1535865 b54268dd-c...
    46: apiphobic_... -2.84791158  6.5469439  26.1442410 9ae0a3f3-f...
    47: relievable... -0.26419586  5.6204312  19.9235349 4b50cdd5-b...
    48: apiphobic_...  5.23350833  2.5688613  16.6298475 90362e32-3...
    49: relievable... -1.40081808  8.2867751  11.6627941 4ca96691-a...
    50: apiphobic_... -1.57753252  0.2901111  82.9027847 fbb3d8bc-5...
    51: relievable...  9.96629711 11.8605654  80.8197972 8424c491-2...
    52: apiphobic_...  0.50654540 12.8839313  77.0256181 613b5f16-2...
    53: relievable... -0.07538449  2.9428721  29.6735102 94115636-0...
    54: apiphobic_... -4.62156899 11.5168595  30.2692212 123d259f-7...
    55: relievable... -2.54482760 14.0363842  11.9771852 125a9039-e...
    56: apiphobic_...  9.41773490 13.7485132 127.6240663 cd54e9a6-0...
    57: relievable...  6.68193212  9.7029184  92.2883228 4ee50560-c...
    58: apiphobic_... -2.16737529  9.1454332   5.4351178 bd801c38-d...
    59: relievable...  6.51951142  0.8699494  19.3951403 2c926df0-c...
    60: apiphobic_...  1.39554897 12.5574182  84.3823247 a5d6efa2-e...
    61: relievable...  0.40814046  4.0374920  20.5941608 a8e5db76-5...
    62: apiphobic_...  0.83792208 11.9147129  67.6552076 4a77738a-5...
    63: relievable... -0.48220465  0.3546843  60.0169829 994b0705-b...
    64: apiphobic_... -2.45161234  8.7010876   6.5037097 4b7235f3-8...
    65: relievable... -3.23836623  0.1888565 152.2233286 397b863b-1...
    66: apiphobic_...  6.91448480  4.7053010  30.2385974 9f211b12-9...
    67: relievable...  5.67725982 13.7690187 177.6844551 9fc0f4a0-9...
    68: apiphobic_...  4.74879034 13.7040343 162.8405306 589bd940-a...
    69: relievable...  3.91803751 14.6887400 170.6289920 eb4471ec-9...
    70: apiphobic_...  0.67535849  5.7229843  18.0402999 34e15ac7-7...
    71: relievable...  2.64793032  3.8902995   2.9815402 b419dc13-9...
    72: apiphobic_...  2.28025997  6.6282208  16.6018929 81e415de-0...
    73: relievable... -0.74724294  5.4588348  20.2930445 c0a89dfc-7...
    74: relievable...  3.41812763  4.9810035   9.2411775 060f333a-5...
    75: apiphobic_...  8.50693259 12.1561112 111.2165241 1b08330a-e...
    76: apiphobic_...  9.40830206  7.0313224  21.2857826 d1aa1f8a-c...
    77: relievable...  3.21722688  3.6211616   2.3976968 38834c81-1...
    78: relievable...  5.08574370  4.0997968  21.6400637 97bfb608-c...
    79: apiphobic_... -4.35020951  5.2520120 108.9371862 eb2c7e92-0...
    80: relievable... -0.56237755  4.1497764  25.8858224 b2710265-6...
    81: apiphobic_... -2.91627858  2.0678985  94.1915795 92e9b41b-b...
    82: apiphobic_...  3.29755834  9.6128851  56.1119505 6a153455-1...
    83: relievable... -0.25827492  8.1438034  22.2562499 70b985c5-f...
    84: relievable...  4.11681770  0.4057510   6.1301632 43f2e267-5...
    85: apiphobic_... -1.90024206 13.4173913  22.3116249 12d5beb5-d...
    86: apiphobic_...  2.65633356 13.5953869 120.5679681 65919ddf-d...
    87: relievable... -1.45630948  7.9558983  11.5012457 5d9935ea-7...
    88: apiphobic_... -4.53356720  5.3205425 119.5948434 70b5890c-6...
    89: relievable...  9.47649931 14.4195636 142.0347691 5ebd0c11-f...
    90: apiphobic_... -3.49659676 10.7159467   6.8942100 de43f38d-5...
    91: relievable...  4.60161453  5.0799708  22.3942289 f06b5cb8-f...
    92: relievable... -1.37903474  7.7870068  12.2570753 f279c210-7...
    93: apiphobic_...  7.37217508 11.9614769 128.3754615 eb0ae1fe-1...
    94: relievable...  1.16106773 13.4381848  96.8523815 e9ca3d08-8...
    95: apiphobic_...  5.24602133  9.3347743  80.9620167 ed3ac208-6...
    96: relievable... -1.17688495  8.1380813  13.6927315 5c6c9cf8-8...
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
    1: relievable...  8978 runnervm7b...     FALSE terminated
    2: apiphobic_...  8980 runnervm7b...     FALSE terminated

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

    [1] "indicolite_garpike"  "wolflike_blackrhino"

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
    1: craven_gro...  9229 runnervm7b...     FALSE running
    2: debonair_c...  9231 runnervm7b...     FALSE running

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
    1: craven_gro...  9229 runnervm7b...     FALSE running
    2: debonair_c...  9231 runnervm7b...     FALSE running

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
