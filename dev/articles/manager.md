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
    1: defeated_e... 13718 runnervm1l...     FALSE running
    2: chocolaty_... 13716 runnervm1l...     FALSE running

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
    1: defeated_e... 13718 runnervm1l...     FALSE    running
    2: chocolaty_... 13716 runnervm1l...     FALSE terminated

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

            worker_id          x1           x2          y          keys
               <char>       <num>        <num>      <num>        <char>
     1: sepia_afri...  5.27435107  9.258320570  80.063229 8c44b9b1-f...
     2: sepia_afri...  1.28087273  4.811070147  13.151701 101ccbad-5...
     3: sepia_afri... -1.16427017  7.634737287  13.951616 00431e46-a...
     4: sepia_afri...  0.59647159  6.599677287  20.203146 52b1ae56-6...
     5: sepia_afri...  7.98353160 12.209694470 122.866259 fe0948d3-d...
     6: sepia_afri...  9.78173462 12.601270864  97.213951 86127702-d...
     7: sepia_afri...  4.76813436  3.935825779  17.230276 24c0d0b4-7...
     8: sepia_afri... -1.49542453  9.770621022  11.936752 f914e70c-9...
     9: sepia_afri... -0.52785940 10.620121369  32.312766 00ad48e0-2...
    10: sepia_afri... -1.94179584  7.315119410  11.637435 dd73791c-e...
    11: sepia_afri... -2.57924223  7.140348541  16.499867 b6e25961-2...
    12: sepia_afri...  2.98802323 14.045031732 136.168685 4af05628-5...
    13: sepia_afri... -4.99422916  9.185005163  76.442290 599c414d-b...
    14: sepia_afri...  3.24395291  3.588381613   2.385406 dc7d91d6-e...
    15: sepia_afri... -4.34921908 12.801320381  13.164552 204f6d1e-9...
    16: sepia_afri... -2.86623744  6.682026619  25.173326 517ed278-7...
    17: sepia_afri...  4.36092377  6.419893048  30.740834 7bb2c0e1-1...
    18: sepia_afri...  2.27109387  0.102508669  12.510038 14f79915-7...
    19: sepia_afri...  8.44225516 14.110372432 156.933392 bfe86292-9...
    20: sepia_afri... -0.49389954  1.254212539  49.405613 2f6b6e18-7...
    21: sepia_afri...  3.50931349  9.571892752  58.287105 880f49a8-9...
    22: sepia_afri...  6.92617514  2.855952518  20.514014 82eafeab-c...
    23: sepia_afri... -0.80385956 12.978982947  48.204058 668e3935-5...
    24: sepia_afri... -4.54854701  3.702046417 157.516080 b6d4be7e-e...
    25: sepia_afri...  0.09347662 11.616406739  52.784471 f08aa8bc-c...
    26: sepia_afri...  7.58147410  5.272593572  27.900024 0d9452a8-6...
    27: sepia_afri...  7.83118301 14.193304215 172.385507 d5eac129-a...
    28: sepia_afri...  9.84936454  6.421080701  13.957157 3f7fabf1-8...
    29: sepia_afri...  2.85697142 13.594025965 123.696817 9fda143e-5...
    30: sepia_afri...  5.53188482  5.008082879  31.909732 ce4c1210-d...
    31: sepia_afri...  0.41955754 13.206915181  80.421987 53864ef0-e...
    32: sepia_afri...  2.83672487 12.342717404  97.232942 d0a2ecb8-c...
    33: sepia_afri... -1.73920753  2.799689217  48.828789 4f15de42-8...
    34: sepia_afri... -0.32876780 14.357848208  80.250159 d61b2712-0...
    35: sepia_afri... -4.57376741  2.442487027 191.987079 4a718d86-6...
    36: sepia_afri...  1.23017785  7.597022961  24.493428 55a3f9d2-7...
    37: sepia_afri... -0.03807433 14.548896898  91.643207 432db4d1-2...
    38: sepia_afri...  9.80676135  5.196454480   6.756214 d238d863-0...
    39: sepia_afri...  4.28972951 13.084371342 139.105173 d7446ab1-2...
    40: bothersome...  4.49359806  8.768688048  61.380086 85f29589-8...
    41: sepia_afri...  8.23762169 11.698091707 107.256110 e4d0114a-5...
    42: bothersome...  8.84253715  3.404988922   3.877034 16600382-e...
    43: sepia_afri... -4.30913557 13.493174070   9.343033 f6bcc1b4-5...
    44: bothersome...  9.57820542 12.152755882  91.623350 f757876f-3...
    45: sepia_afri...  1.54298767  1.458496544  15.994998 bef44cd9-1...
    46: bothersome...  7.43038733  3.130079427  17.272172 44bedbf0-1...
    47: sepia_afri...  0.05568373  2.942874587  28.401612 949423fd-8...
    48: bothersome... -0.07976336  3.418336901  26.912607 6e3d235f-d...
    49: sepia_afri...  7.56946393  8.187031769  59.376279 884c8e99-7...
    50: bothersome...  5.80416061  4.667552400  31.146270 d202aae4-2...
    51: sepia_afri... -0.22577663  6.148665143  19.405616 f62e513e-6...
    52: sepia_afri... -0.06559821  7.428153906  21.332306 4c53b4f0-2...
    53: bothersome...  2.37172976  2.862876802   3.113559 ff38aa43-3...
    54: bothersome...  2.56565468  0.650130229   6.428027 a3726d45-b...
    55: sepia_afri... -4.51253496  9.979756019  42.114665 485ce345-5...
    56: bothersome...  2.75144823 13.766998448 125.845395 76a3b5ac-9...
    57: sepia_afri...  1.15749431  7.701069675  25.214788 fd23fc61-a...
    58: bothersome...  2.68730892  5.903407295  11.917835 701de1dc-b...
    59: sepia_afri...  2.62282581 13.808530047 124.742475 6bb3082c-5...
    60: sepia_afri...  9.81565925 14.534418847 138.245404 1cd39b42-e...
    61: bothersome...  3.98861241  6.546964928  27.065335 bb777e68-c...
    62: sepia_afri... -2.06250359  6.910033036  14.005115 1e1d3535-0...
    63: bothersome...  2.58090388  0.815938838   5.619779 ba3322a2-8...
    64: sepia_afri... -3.06694896  5.981055944  37.821239 cbe11505-3...
    65: bothersome...  5.03447930  2.333261464  14.187824 d1cf91f5-e...
    66: bothersome... -2.54876779  3.716560252  53.576392 13f62205-6...
    67: sepia_afri...  4.93197019 14.396902351 183.807669 c06c4311-b...
    68: bothersome...  9.07851986 10.201377727  65.015233 21730493-e...
    69: sepia_afri...  7.85335514 10.369168541  89.228346 d850a934-c...
    70: bothersome... -0.54237781  9.370240319  24.320096 70abdab7-f...
    71: sepia_afri... -1.94339975 12.974067335  18.017874 35bc2af5-a...
    72: bothersome...  5.45395875  5.215376397  32.912051 7b48cad0-6...
    73: sepia_afri...  0.73191757  3.395774887  19.418670 09573d26-3...
    74: sepia_afri... -2.74592559  3.172100518  67.925270 3d416a81-6...
    75: bothersome... -2.35442411 12.330896534   6.710257 ae5b7904-e...
    76: bothersome... -2.34529808 11.122201207   3.745672 cf4e8700-5...
    77: sepia_afri...  5.47174017  3.912380826  24.190415 d8fc722c-e...
    78: bothersome...  0.19548395  4.989084128  19.915873 fa1a90a6-e...
    79: sepia_afri...  3.65982500  1.210073064   2.142365 51562228-1...
    80: bothersome...  9.65053262 11.971515018  87.122279 1f6ce5ab-4...
    81: sepia_afri...  0.40730559  0.008902151  47.592103 3b6882da-a...
    82: bothersome...  4.03067192  5.240593043  16.600517 376743df-6...
    83: sepia_afri...  5.86486668 14.147581130 188.771175 58abe839-d...
    84: sepia_afri...  5.88994912  5.228552822  35.852632 38fc8847-3...
    85: bothersome...  0.51821854  8.457712339  28.889525 29f08d62-0...
    86: bothersome...  8.98813504 12.199869793 102.674640 80412adb-e...
    87: sepia_afri... -1.73286477 11.709790134  15.024353 39cc7009-f...
    88: sepia_afri... -3.73703447  0.768499614 170.616281 794b4cca-3...
    89: bothersome... -0.47896757  1.494335524  46.586177 ad26b276-5...
    90: sepia_afri...  6.20414660  7.028581403  54.740478 40d1f8f7-a...
    91: bothersome...  3.12276640  3.748825891   2.528557 acc71797-0...
    92: bothersome...  0.15345475  5.119834235  19.897569 941693bf-2...
    93: sepia_afri...  9.11542729 14.655388526 155.332973 4e7e0448-d...
            worker_id          x1           x2          y          keys
               <char>       <num>        <num>      <num>        <char>

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
    1: sepia_afri... 13716 runnervm1l...     FALSE terminated
    2: bothersome... 13718 runnervm1l...     FALSE terminated

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

    [1] "agrostographic_weaverbird" "ethnic_elkhound"          

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
    1: single_dam... 13988 runnervm1l...     FALSE running
    2: orcish_tak... 13990 runnervm1l...     FALSE running

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
    1: single_dam... 13988 runnervm1l...     FALSE running
    2: orcish_tak... 13990 runnervm1l...     FALSE running

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
