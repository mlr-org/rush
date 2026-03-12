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
  while(TRUE) {
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
    1: dendrologi...  9019 runnervm0k...     FALSE running
    2: wellmade_f...  9021 runnervm0k...     FALSE running

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
    1: dendrologi...  9019 runnervm0k...     FALSE    running
    2: wellmade_f...  9021 runnervm0k...     FALSE terminated

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
  while(!rush$terminated) {
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

            worker_id         x1         x2          y          keys
               <char>      <num>      <num>      <num>        <char>
     1: superlativ...  3.8378857 12.9530799 127.144220 7567002d-2...
     2: superlativ...  3.7718798 14.3298489 158.369478 cd5037a7-2...
     3: superlativ... -0.2887234  3.5398313  27.792231 7260a0d0-0...
     4: superlativ... -2.2346732  6.5201155  17.637555 5b90f2c8-5...
     5: superlativ... -2.7079460  6.8652946  20.574937 2fb39da9-7...
     6: superlativ...  0.0896820 12.3108613  61.198998 c5359027-c...
     7: superlativ...  3.1058424 13.1299373 117.625614 e48d29f1-f...
     8: superlativ...  8.7704379  7.0621605  28.226213 bc6e94c0-6...
     9: superlativ...  4.2210027  6.8650805  33.361938 6ddecdaf-7...
    10: superlativ...  7.3292683 12.4938501 140.680478 7347a982-6...
    11: superlativ...  9.2522250 13.2957561 120.716050 b38cd8b2-2...
    12: superlativ...  7.1488249  4.9545655  30.138102 3484e609-d...
    13: superlativ... -1.3238851  0.3752676  75.679467 043ad405-1...
    14: superlativ... -4.9492616  5.8838726 136.743542 46015f53-a...
    15: superlativ... -0.6165578 11.2496483  35.636244 7cdad85a-9...
    16: superlativ... -0.9351610 13.2942942  48.110507 0560bb67-4...
    17: superlativ...  8.6837858  9.7907253  64.849898 39a563ca-f...
    18: superlativ... -1.8360835  1.9935063  61.714172 b0ed89e2-a...
    19: superlativ... -2.3335010  8.4018347   7.428284 c5c01cc5-f...
    20: superlativ... -1.2862350  8.2989029  12.697112 9181e1cf-7...
    21: superlativ...  7.9734519 13.4046113 150.031023 4545ef25-b...
    22: superlativ... -0.1337617  4.4832109  22.516125 a6636da2-2...
    23: superlativ...  1.8195026  8.6812782  34.153063 ac5becdc-8...
    24: superlativ... -3.5273326 12.5024186   1.620163 03e8fd35-7...
    25: superlativ...  1.3000816  3.7590213  12.720043 76d27fdd-1...
    26: superlativ...  1.6436434  2.5935490  10.599619 9906e480-b...
    27: superlativ...  0.7413510 11.7697403  64.397753 c9b68498-0...
    28: superlativ...  4.9074447  1.1079519  11.898249 6548ad67-5...
    29: superlativ...  5.3853809  5.5542397  35.158179 4b97732d-2...
    30: superlativ... -3.5967107  3.5298350  98.706954 ef696b0a-0...
    31: superlativ...  1.0931651  8.1462808  28.339680 dab36ecd-9...
    32: superlativ...  0.5512803 12.5268392  72.422367 697df04b-b...
    33: superlativ...  2.9946775 11.3275203  80.338390 4c31cb57-3...
    34: superlativ...  5.2277339 10.8924918 108.476851 15982eee-6...
    35: superlativ...  3.6209020  9.6954874  61.768970 24423a77-8...
    36: superlativ... -4.1578404  9.4102112  34.542870 ab4d938b-0...
    37: superlativ... -1.0573152 11.9589908  31.788483 aa718e26-1...
    38: superlativ...  8.4370689  1.6468295   4.727694 781c8325-a...
    39: superlativ...  8.2339071 12.6648419 127.684703 eded7cdf-0...
    40: superlativ...  3.8749655  4.4765613  10.178053 c89eb543-0...
    41: superlativ...  4.1821145  5.6634172  21.627232 14f2eedb-e...
    42: superlativ... -1.3507218  7.5186022  12.847556 5c06aa9e-8...
    43: superlativ... -0.4401947 10.3018446  31.476086 70a582aa-1...
    44: superlativ...  0.5967875 10.6840074  49.166013 924ec34f-6...
    45: commonplac... -0.1400544  4.5791160  22.218467 2619fbf9-3...
    46: superlativ...  0.3134805  3.0626635  25.142112 7de677f1-2...
    47: commonplac...  2.9941163 12.7766849 108.326759 09115751-c...
    48: superlativ...  5.3247851 14.1752201 184.183487 f70e5da0-e...
    49: commonplac...  8.8086941 10.9835411  82.789071 2314ef3f-4...
    50: superlativ...  2.2501223  5.5553228  10.129781 b3efd0b1-3...
    51: commonplac...  7.9059818 14.5771047 180.724582 b451c07c-f...
    52: superlativ...  6.7828645  6.2525976  44.483406 c9e90f68-c...
    53: commonplac... -3.0556586  6.3888964  32.701825 fbdd127b-8...
    54: superlativ... -1.8345477  2.7097437  51.650171 4de71670-7...
    55: commonplac...  5.2282157  9.8496841  89.377027 79709465-3...
    56: superlativ...  9.5231177  2.6308067   0.449407 b6c0fa50-5...
    57: superlativ...  5.0399607  9.6964343  84.261243 91bd70b5-5...
    58: commonplac...  0.8440557  1.1645907  29.225687 0f40e0bb-9...
    59: superlativ...  5.6211379  1.4959822  17.703437 e47636b2-3...
    60: commonplac...  1.4486156  2.3894876  13.654245 8abf532f-f...
    61: superlativ...  0.9150308  6.0835023  17.904680 cfca5511-d...
    62: commonplac... -2.4073714 12.8017300   7.807346 f2691fbc-a...
    63: superlativ...  5.5259535  2.1293420  17.937410 f92f381c-9...
    64: commonplac... -3.0726960  0.2518459 141.037389 0207553a-3...
    65: superlativ... -1.7421036 11.7851685  15.229929 d8365fa6-f...
    66: commonplac...  3.1379485  7.6653320  29.422982 00e25880-c...
    67: superlativ...  2.2001508 10.2021976  54.453246 af217a7d-a...
            worker_id         x1         x2          y          keys
               <char>      <num>      <num>      <num>        <char>

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
    1: superlativ...  9021 runnervm0k...     FALSE terminated
    2: commonplac...  9019 runnervm0k...     FALSE terminated

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

    [1] "leekgreen_waterboatman" "plaster_xenoposeidon"  

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
    1: tranquil_c...  9313 runnervm0k...     FALSE running
    2: agrarian_a...  9315 runnervm0k...     FALSE running

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
    1: tranquil_c...  9313 runnervm0k...     FALSE running
    2: agrarian_a...  9315 runnervm0k...     FALSE running

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
