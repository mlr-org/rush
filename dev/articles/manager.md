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
    1: congregati...  9478 runnervm35...     FALSE running
    2: portly_pom...  9480 runnervm35...     FALSE running

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
    1: portly_pom...  9480 runnervm35...     FALSE    running
    2: congregati...  9478 runnervm35...     FALSE terminated

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
     1: downcast_p...  0.611338720  8.3971870  28.8978820 1a97cf22-0...
     2: downcast_p...  2.474214139 10.5048398  61.0087129 1a06f035-5...
     3: downcast_p...  5.955429856  1.4186877  19.1903443 116dbc63-7...
     4: downcast_p...  2.802731531 12.2064967  94.1127272 62177152-c...
     5: downcast_p...  1.408643021  6.2991560  16.7702522 fe8c25b4-8...
     6: downcast_p... -2.291880292 12.2863109   7.5026876 774cf7f7-7...
     7: downcast_p...  5.772936184  6.7029472  49.5774500 0097dd92-6...
     8: downcast_p...  4.799986871  3.4168684  15.1659916 711a961e-a...
     9: downcast_p...  9.863214088  4.2720319   3.2727261 9732e884-8...
    10: downcast_p...  6.416714627 10.9335702 116.0868899 30107559-a...
    11: downcast_p...  9.064478702  2.0990363   1.0223138 4d72ad14-8...
    12: downcast_p...  1.374362027  8.5902398  32.4275344 d4d17e44-0...
    13: downcast_p... -2.856537212  7.6281826  16.5642036 e24c5446-0...
    14: downcast_p... -2.124234331 13.2445941  15.7169065 49fda816-9...
    15: downcast_p...  6.364153557  7.8373331  64.9161837 020dd3ef-2...
    16: downcast_p... -1.766337851  9.7979025   8.4749659 faf4b602-7...
    17: downcast_p...  4.774742320  0.5384466  11.2503673 380ddcbe-c...
    18: downcast_p...  3.653822368  1.6889185   1.6789062 3b34ccbb-2...
    19: downcast_p... -1.425840822  4.8226529  25.1457544 a5505bda-6...
    20: downcast_p...  6.459569019 12.7886511 155.8525834 956a6cc9-c...
    21: downcast_p...  2.554531271  1.5280509   3.5662918 99d63541-d...
    22: downcast_p...  6.426911666  9.3372599  87.2362748 9af44614-4...
    23: downcast_p...  8.474296082  7.1281391  32.9145795 63b0ea02-5...
    24: downcast_p... -2.912992420 11.4266430   0.7411595 c0d0057d-7...
    25: downcast_p...  0.887208439  1.7124880  24.9279846 23548242-c...
    26: downcast_p... -1.139849839 14.4082543  55.3082124 335f9c7e-2...
    27: downcast_p... -1.061797515 10.1754860  20.1544517 f33ede7c-e...
    28: downcast_p...  8.865987584  5.9767192  17.3247888 bbf6d253-6...
    29: downcast_p... -4.125418141 12.7399074   8.7805538 cb539a30-5...
    30: downcast_p...  4.584342247  5.7195227  27.2704027 20164a2e-0...
    31: downcast_p... -3.190646527  3.3090162  82.9318159 a6b0d544-d...
    32: downcast_p... -0.012482837  3.4864978  26.0194263 30f234cf-a...
    33: downcast_p...  8.249362199 10.8377723  90.4965723 d30fbace-9...
    34: downcast_p...  9.019830436  2.8596982   1.6716371 6e29ab1f-0...
    35: downcast_p...  5.614380132  3.0952876  21.3703294 6a228b80-3...
    36: downcast_p...  2.353720793 13.4959502 114.0307384 568f1d5f-1...
    37: downcast_p... -3.978072875  5.4463217  83.2987726 9c9dff98-4...
    38: anachronis... -1.177805013  1.4644723  57.0956472 ea433e7f-1...
    39: downcast_p...  5.423521526  4.3486443  26.3830465 22543ddc-0...
    40: anachronis...  3.823048838  3.5687961   5.6585489 79a170ca-6...
    41: downcast_p... -2.756601738  7.0251691  19.9689342 55d447c9-0...
    42: anachronis...  5.347121488  6.5192306  44.1648025 35b4ba60-c...
    43: downcast_p...  0.519149574  4.2644261  19.2283505 d9c9959b-c...
    44: anachronis...  6.821363197  3.9116347  25.8463287 1df051ee-5...
    45: downcast_p...  0.638409289 10.7849755  50.7548465 781a15bc-2...
    46: downcast_p...  5.478646299  7.0184933  51.0037902 8d3036f3-f...
    47: anachronis...  0.006436719  1.1347346  43.1731952 29a963b2-4...
    48: downcast_p... -4.551886137  8.8488384  58.4839087 8dee4eac-a...
    49: anachronis... -2.231347026  4.5975681  35.4342200 6765ad6b-c...
    50: downcast_p...  6.593076063  9.3029680  86.0685534 362d1213-7...
    51: anachronis...  1.852701458 14.3086886 124.2698720 2397330d-b...
    52: downcast_p...  2.442105955 13.7272387 120.2348659 cdece843-5...
    53: anachronis...  9.837645978  7.2365436  20.4878791 5978c8a6-f...
    54: downcast_p...  8.499999654 11.6711815 101.5528561 081102e2-b...
    55: anachronis... -4.337195893 11.4373108  21.6575711 e49cb186-9...
    56: downcast_p...  0.494976954 10.6650083  47.8384020 613c90b2-8...
    57: anachronis...  2.404892611  2.4542896   3.1043601 f8d66d91-f...
    58: downcast_p... -2.152060641  2.6257118  59.4536235 060420da-2...
    59: anachronis...  1.357905155  0.3512634  25.9101421 bed0d5ac-c...
    60: downcast_p...  1.068918253  7.7114375  25.2799930 24e2f9f5-9...
    61: anachronis...  7.273708542 11.6150557 122.5272475 5ca6ce74-1...
    62: downcast_p...  2.949281606  6.5724951  17.7372113 6db667e3-d...
    63: anachronis... -2.311814052  3.7470315  47.3791405 9fd76789-e...
    64: downcast_p... -2.384794193  6.8591012  16.4960249 9d1b0338-7...
    65: anachronis...  7.447989995 10.4149299  96.6491122 6604b898-c...
    66: downcast_p...  1.418285284  4.5161853  11.7225402 7e7d3774-7...
    67: anachronis...  4.800920091 14.3512892 180.2297924 a48b3824-7...
    68: downcast_p...  5.972840337 13.3605392 169.4013673 d8f929da-4...
    69: anachronis...  0.313917341 12.2878906  65.0304485 07ecc6e5-e...
    70: downcast_p... -2.998326750  0.9136008 121.9311161 1ee0ab9c-c...
    71: anachronis...  7.891226408  4.2635679  17.3616139 4b0b3ee2-4...
    72: downcast_p... -1.988120306  0.9456274  82.3067321 98bf0eeb-5...
    73: anachronis...  8.779093835  7.8305505  36.5106042 2d9ca214-0...
    74: downcast_p...  3.485398762  8.9626934  49.1309650 f39299a9-c...
    75: anachronis...  3.402783231  5.1653294  10.2420701 e68011a4-0...
    76: downcast_p...  0.684413929  4.3108534  17.8757209 f0ef0dcb-3...
    77: anachronis...  5.357877387  8.4983854  69.3184032 9340689c-5...
    78: downcast_p...  4.359413044  1.9992033   6.9132802 a1dc9a3f-6...
    79: anachronis... -1.496780281  5.9293041  18.2303498 3c14d1f2-7...
    80: downcast_p...  5.250220752 13.5199793 166.5785837 e5dd2d66-a...
    81: anachronis... -3.998819535  4.3662266 104.9956344 5edc71f9-4...
    82: downcast_p...  9.421142142  3.7110127   1.9332648 90dc804d-a...
    83: anachronis...  6.231415619 11.4155875 126.0274505 f3e34757-2...
    84: downcast_p...  7.092701816  5.1191852  31.9024132 5b72fc87-0...
    85: anachronis...  2.070543800  2.1223689   6.6893348 cf0a19ed-0...
    86: downcast_p...  9.109055177  6.7498805  21.3781997 72549ed8-e...
    87: anachronis... -3.355523897 14.9831548   5.4046231 24725069-b...
    88: downcast_p...  1.297912697  3.2553697  13.3916791 6e9d4e21-6...
    89: anachronis... -1.765172742  6.7721228  14.0977084 9074674f-d...
    90: downcast_p...  7.945908522  0.8604449   9.5405708 3858cec8-e...
    91: anachronis... -4.036189173  8.8430081  36.3134076 f8570918-e...
    92: downcast_p... -0.717549197 11.9470079  39.6875999 8d9e77f7-0...
    93: anachronis...  3.529495796  7.8891369  35.8883515 201a5148-f...
    94: downcast_p...  4.975813378  8.7736602  68.6673617 07964cf1-0...
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
    1: downcast_p...  9478 runnervm35...     FALSE terminated
    2: anachronis...  9480 runnervm35...     FALSE terminated

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

    [1] "emasculatory_stickleback" "dissociable_zopilote"    

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
    1: doddering_...  9770 runnervm35...     FALSE running
    2: multicysta...  9772 runnervm35...     FALSE running

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
    1: doddering_...  9770 runnervm35...     FALSE running
    2: multicysta...  9772 runnervm35...     FALSE running

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
