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
    1: semitheatr...  9265 runnervm3j...     FALSE running
    2: dissatisfa...  9263 runnervm3j...     FALSE running

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
    1: dissatisfa...  9263 runnervm3j...     FALSE    running
    2: semitheatr...  9265 runnervm3j...     FALSE terminated

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
     1: forgivable...  4.8638446 12.6965040 140.9858527 5ebc1637-3...
     2: forgivable... -3.5201605  1.3611249 141.3149511 536cdb85-e...
     3: forgivable...  6.8299042  2.5964024  20.2771726 7b95a467-b...
     4: forgivable... -2.1742088  3.7675099  44.2857161 9ce7f00a-0...
     5: forgivable...  7.9916202 14.6033956 179.5586133 82cfb666-d...
     6: forgivable... -2.6289520 14.5045138  13.3804009 2af123e0-e...
     7: forgivable... -0.5075341  7.8771845  19.4653154 a43012a7-5...
     8: forgivable...  9.8670845  0.7104636   6.0000848 9c3d140b-2...
     9: forgivable... -3.2289761  9.9987224   6.6210229 4bf63ddd-b...
    10: forgivable...  7.4524658 11.3951351 115.3851005 f1add722-5...
    11: forgivable... -2.4472377 10.2446971   2.8007755 9bbf638b-2...
    12: forgivable...  9.6676469  3.8424291   2.0135855 df37cf08-c...
    13: forgivable... -2.4760604  8.1172179   9.2882906 c6aa0c0f-4...
    14: forgivable...  7.3826526 13.7680847 170.0337141 10ec802a-a...
    15: forgivable...  3.3819796  9.7578924  59.3939531 fb4179fe-c...
    16: forgivable...  9.3549477 14.6829587 150.8817368 ec21eb44-c...
    17: forgivable...  8.6478071 10.0987065  70.4115297 4dddc967-a...
    18: forgivable...  7.8556397 14.2816175 174.1350484 aa90be85-a...
    19: forgivable...  0.4008255 14.1873031  96.3599409 4d29682e-6...
    20: forgivable... -0.4933180 10.0063678  28.6319739 171bdc6a-c...
    21: forgivable...  2.2041418 13.1308461 104.5419124 dabe761a-0...
    22: forgivable... -2.3024652  8.5474558   6.8314934 2b257c92-d...
    23: forgivable... -4.4101221  7.0049476  79.8430040 c7facff0-2...
    24: forgivable...  1.0219207 14.3966989 112.7867088 a9843c42-4...
    25: forgivable...  6.2594003  8.7957947  78.8351807 1cce80f3-b...
    26: forgivable...  4.0619072 10.2299220  77.5140082 d5da5412-6...
    27: forgivable...  2.4358181  8.5285700  34.4879892 5b66c70e-b...
    28: forgivable...  6.1810028  4.6226313  31.9743744 2a47a35f-9...
    29: forgivable...  4.9833604  4.8619757  25.4230262 c3b55ff4-8...
    30: forgivable...  1.2481452  4.9720998  13.6182092 58bde655-8...
    31: forgivable...  0.6929963  2.0443059  25.8832821 956d53b5-9...
    32: forgivable...  0.5981264  8.2060482  27.6182816 e428808d-b...
    33: forgivable... -2.0943032 10.1438730   5.2592774 3f392bea-f...
    34: forgivable...  1.6652571  5.7213742  13.1484031 037c7527-0...
    35: forgivable...  2.4836884 11.5280805  77.8155354 32d0f5ae-5...
    36: spidersilk...  9.1568004 12.9480850 115.0135540 aec750ce-8...
    37: forgivable...  2.3085128  7.2272347  21.2900866 0d2a1775-5...
    38: spidersilk...  4.0974248  5.6404150  20.4027482 84f32872-a...
    39: forgivable...  4.2924814  9.6679626  72.0098314 88b865e2-7...
    40: spidersilk...  4.0726851 10.5622659  83.5027330 b0e65a1a-7...
    41: forgivable... -2.8685861 13.5332471   4.3814599 a5ac5eb9-9...
    42: spidersilk...  5.3190216  7.0490238  49.8093813 777613d2-3...
    43: forgivable...  8.1371253  6.3601329  29.9474140 5855c3d9-a...
    44: spidersilk...  2.7145554  8.1812333  32.0587601 218c8567-8...
    45: forgivable...  3.3637412  8.8005717  45.4226134 01ec6fbb-b...
    46: spidersilk...  8.8312797  9.2507446  54.3254190 f86e3e6b-d...
    47: forgivable...  8.8537246  2.2728460   1.9778001 c3ca9b7d-1...
    48: spidersilk...  9.3730271 14.7943161 153.2451897 bfa303fd-7...
    49: forgivable... -1.9269006 14.0805804  27.2111351 62f7fcd5-1...
    50: spidersilk...  4.7858297 11.7121568 118.2451429 752f977b-6...
    51: forgivable... -3.7735071  3.8130533 102.8965879 fb0b94e4-0...
    52: spidersilk...  7.1074555  2.9534855  19.5465078 3172cf5b-1...
    53: forgivable...  9.9820123  0.2713414   9.2152545 855e787d-b...
    54: spidersilk...  4.9615488 13.7713118 168.3112140 e0323ef8-4...
    55: forgivable... -1.3274751 13.7785042  41.8864980 e5c994cf-1...
    56: spidersilk...  8.5302285 13.5930104 142.5045320 4761f19a-1...
    57: forgivable... -3.6374967 14.3192234   2.2280808 2a2de89f-6...
    58: spidersilk...  5.0535874  6.9538624  45.6766546 de6df165-8...
    59: forgivable...  1.4633550  0.7688711  21.1342196 b4cf4b14-c...
    60: spidersilk... -2.6526866  6.4167786  23.7459345 d5f51e8a-0...
    61: forgivable... -1.8862352 10.9320162   9.1830487 5ca12eb0-2...
    62: spidersilk... -4.7302513 12.6033665  24.7303203 a21f2769-8...
    63: forgivable... -3.5447602  9.0642959  18.8128858 ce432687-c...
    64: spidersilk...  0.2656292  4.0141911  21.7370360 af7f73b3-1...
    65: forgivable...  3.8955836 11.4278484  96.4593013 e13b6b49-4...
    66: spidersilk... -0.8968326  5.5640328  19.8625363 7da91778-1...
    67: forgivable...  1.5269247  8.3539074  30.5174280 a5c2bb16-a...
    68: spidersilk...  8.1810168 14.1726272 164.3407812 d16a9ec5-7...
    69: forgivable...  4.4777292  0.2140797   9.3287674 02f4ddc6-6...
    70: spidersilk...  0.2315511  6.8460680  20.8043065 a8630a24-d...
    71: forgivable...  4.3786728 13.8834367 160.0074026 e6cbee1b-5...
    72: spidersilk...  7.3037463  0.4228246  15.7335223 3ee708e3-8...
    73: forgivable...  5.9804428 14.9063100 209.7187877 4febc137-7...
    74: spidersilk... -2.7967743  0.4688837 121.8046425 6994c058-a...
    75: forgivable...  1.8313192  3.1159722   7.6887534 c9b10802-9...
    76: spidersilk... -0.1074630  7.9064431  22.5531952 6795af5d-0...
    77: forgivable...  6.3639567 13.7807854 180.2865567 e93adbb2-8...
    78: spidersilk... -4.9497327  2.4946223 223.9055643 b10654dd-4...
    79: forgivable...  9.4117256  0.8933235   2.8657678 e08b4aab-2...
    80: spidersilk...  4.4164943 14.1074660 166.3821065 23eed98d-8...
    81: forgivable...  0.2998098 14.3345226  96.6150704 b6b4f606-4...
    82: spidersilk...  7.8955153  6.0546032  30.4629212 ff529541-c...
    83: forgivable... -4.4411906  5.2268406 115.3713373 e66bf4cd-5...
    84: spidersilk... -1.3049691  5.3606618  21.1441409 5cdad761-6...
    85: spidersilk...  3.0339481  1.2791136   1.6227418 48199720-2...
    86: forgivable... -4.7435404  7.1417640  97.0611867 e1368efe-7...
    87: spidersilk... -0.4212372  5.4822212  20.2295467 2510f754-2...
    88: forgivable...  2.2282759  3.4012562   4.2257027 48b83aca-2...
    89: spidersilk... -2.9884486 12.2066776   0.5982919 513bbb34-e...
    90: forgivable...  6.1007665 13.6888204 177.9591548 0dadd58d-d...
    91: spidersilk...  6.3875877  7.5990722  61.7262929 3e28d446-2...
    92: forgivable... -4.5605630  4.1270136 148.2181221 39b9d590-6...
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
    1: spidersilk...  9263 runnervm3j...     FALSE terminated
    2: forgivable...  9265 runnervm3j...     FALSE terminated

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

    [1] "adverse_tuatara"     "centaurial_betafish"

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
    1: bubonic_si...  9515 runnervm3j...     FALSE running
    2: patronizin...  9517 runnervm3j...     FALSE running

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
    1: bubonic_si...  9515 runnervm3j...     FALSE running
    2: patronizin...  9517 runnervm3j...     FALSE running

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
