# Rush Manager

The `Rush` manager class is responsible for starting, monitoring, and
stopping workers within the network. This vignette describes the three
mechanisms for starting workers: `mirai` daemons, local `processx`
processes, and portable R scripts. We advise reading the
[tutorial](https://rush.mlr-org.com/articles/tutorial.md) first. We use
the random search example from this vignette to demonstrate the manager.

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
    1: dozing_ver...  9072 runnervmeo...     FALSE running
    2: veiny_tric...  9074 runnervmeo...     FALSE running

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
    1: dozing_ver...  9072 runnervmeo...     FALSE    running
    2: veiny_tric...  9074 runnervmeo...     FALSE terminated

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
     1: snazzy_man...  4.5794941  5.7015608  27.0531413 deade639-9...
     2: snazzy_man...  8.8259354  6.4640631  21.8523322 586d9303-f...
     3: snazzy_man...  6.7859525  1.6149616  18.6313144 466da082-1...
     4: snazzy_man...  1.1653738  6.5813482  18.8976944 fea296eb-b...
     5: snazzy_man...  1.5709895  3.3155531  10.2511220 5517e426-4...
     6: snazzy_man...  5.4801142 10.7982864 109.6085833 983bc2dd-0...
     7: snazzy_man...  3.5295411  7.6210312  32.7985932 27a3591f-6...
     8: snazzy_man...  7.4496942  0.3338708  14.7356563 94402976-5...
     9: snazzy_man...  6.4043041  8.3833575  72.4953334 bfbd15e4-f...
    10: snazzy_man...  9.1241816 14.5880298 153.4724020 7914ce42-3...
    11: snazzy_man...  5.0023219  7.3336912  49.4992871 8749bfec-b...
    12: snazzy_man... -0.4205089 11.6642778  43.4881008 174d8788-8...
    13: snazzy_man...  0.5412125 10.2495828  43.9662657 1c567eda-d...
    14: snazzy_man...  0.8448198 10.3449555  47.7045791 453c6b53-a...
    15: snazzy_man...  0.7836070 10.2409618  46.0568426 747370e4-2...
    16: snazzy_man... -1.5544287  2.5287220  49.3118372 12682731-0...
    17: snazzy_man...  6.4359652  8.5629214  75.0679294 1d7fef29-b...
    18: snazzy_man... -2.7376514  6.0173421  29.3452104 e6ba4121-2...
    19: snazzy_man... -3.3253030  9.9160571   8.4263837 3726606d-6...
    20: snazzy_man...  8.7670584  9.3182543  56.3084630 d245d01f-f...
    21: snazzy_man...  9.8616773  9.6605948  47.4365585 85d908f1-1...
    22: snazzy_man... -2.0328317  6.0060225  19.8811222 1f8ca0e3-a...
    23: snazzy_man... -4.3183467 10.7644904  26.7206008 4ffe9a4f-3...
    24: snazzy_man...  0.3645215 13.7603946  88.2499050 e837a6d5-7...
    25: snazzy_man...  6.2614977  3.1784172  23.9222901 e5033528-8...
    26: snazzy_man...  0.3230482 11.1766953  51.3378420 c5ccc50a-3...
    27: snazzy_man...  1.6866442 10.5929395  56.6356748 8dd307f6-c...
    28: snazzy_man...  7.1260122  3.3407132  20.8921995 f99b5be4-a...
    29: snazzy_man...  9.6549506  2.9823399   0.7449681 d6169e0a-8...
    30: snazzy_man...  9.5090164 11.7886217  85.8399943 d922afc0-0...
    31: snazzy_man...  4.8502279  5.7453747  30.9063904 4e284a0b-d...
    32: snazzy_man...  6.3308764  8.6581418  76.6893165 c275d173-0...
    33: snazzy_man... -4.9336764  2.8058062 213.4887397 3d5b53b1-a...
    34: snazzy_man...  9.7431475  5.6947483   9.5128702 0c9123e1-e...
    35: snazzy_man...  0.7265927  4.7061601  17.2193101 03008f1d-8...
    36: snazzy_man...  2.7410117  5.3875737   8.8833699 73359005-5...
    37: snazzy_man...  3.8731266  7.4393900  34.9553219 3fc8a6b4-b...
    38: thermophob...  6.7155932  8.9713626  80.0811749 bc76d140-7...
    39: snazzy_man...  4.1382023  4.9169597  15.6143850 c405a084-e...
    40: thermophob...  8.3399640 11.6818216 104.9131429 220ba833-1...
    41: snazzy_man... -4.5494897  5.5490741 115.8864449 8ad829dc-3...
    42: thermophob...  3.5280197  3.5034143   3.3874891 f7a1ab6f-c...
    43: snazzy_man... -0.4434538  1.3597479  47.5256643 74dca348-6...
    44: thermophob...  5.7639064  1.4434305  18.4420418 05425cff-c...
    45: snazzy_man...  1.7117537  4.9474526  10.3235350 a21f2f5f-5...
    46: thermophob... -1.0995454  8.4594643  14.6655112 426d9fb7-e...
    47: thermophob...  5.3062720  5.9431241  37.9445356 ed524c82-1...
    48: snazzy_man...  2.8442375  5.9115284  12.3331572 8070303a-7...
    49: snazzy_man...  5.3571997  8.6004102  70.8146048 d42f0a31-7...
    50: thermophob...  6.4523594  3.8337253  26.8887142 edfcee75-1...
    51: snazzy_man...  6.1338119 13.3405704 169.3725907 f76ade16-a...
    52: thermophob...  4.9769745  8.3339364  62.2854981 b8f3b6e8-a...
    53: snazzy_man... -2.5032521 12.9986413   7.1510881 8dcda4d1-f...
    54: thermophob...  2.8565228  2.2651478   0.8442956 9fb58fbc-8...
    55: thermophob...  6.3537254  6.4628014  48.3069029 ecf09746-e...
    56: snazzy_man...  0.7733038  6.5206443  19.6740935 4d86463b-0...
    57: thermophob... -1.7232472 13.0393487  23.8540999 84f116ca-5...
    58: snazzy_man... -3.2405857  6.2365280  39.8536845 0735cc58-c...
    59: snazzy_man...  1.4069532  9.7829082  44.8178192 c99e35e3-7...
    60: thermophob...  9.2290230  2.0828746   0.6350790 c7ba414e-c...
    61: thermophob... -3.2173723  3.2430418  85.3382901 9b1b6b87-5...
    62: snazzy_man...  9.5906584 12.5141155  98.4533271 05001bae-2...
    63: thermophob...  4.0994854  7.4366796  38.0024640 0d47188d-5...
    64: snazzy_man...  0.7402329  8.1778112  27.8815113 da92f374-6...
    65: thermophob...  1.5969160  1.1064250  16.9393607 2932fd15-a...
    66: snazzy_man... -4.3483546 10.1808624  33.4385062 20652ea7-e...
    67: thermophob... -1.1591088  6.6129080  15.8175936 b5140ded-c...
    68: snazzy_man...  4.3051877  3.1433049   8.7598442 5a562bca-4...
    69: thermophob...  6.5788203  6.7460126  50.8296767 08e53177-5...
    70: snazzy_man...  9.4317969  6.2059391  14.2738397 78f3b349-9...
    71: thermophob... -2.4237191  8.7795394   6.1415100 24524130-c...
    72: snazzy_man...  1.2504211  0.8750922  24.1580747 bbc9760a-5...
    73: thermophob...  8.4569126  5.8623105  21.2235572 02373f47-1...
    74: snazzy_man...  6.5523412  1.0058591  19.2689545 8b659786-9...
    75: thermophob...  7.5556127  0.8771516  13.0459177 8cfda958-7...
    76: snazzy_man...  8.0753532  8.5690138  56.8503084 9372a6b5-6...
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
    1: thermophob...  9072 runnervmeo...     FALSE terminated
    2: snazzy_man...  9074 runnervmeo...     FALSE terminated

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

    [1] "nonartistic_tragopan" "creational_gar"      

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
[`rush_plan()`](https://rush.mlr-org.com/reference/rush_plan.md)
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
> [`rush_plan()`](https://rush.mlr-org.com/reference/rush_plan.md)
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
    1: interlibra...  9362 runnervmeo...     FALSE running
    2: swinish_to...  9364 runnervmeo...     FALSE running

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
    1: interlibra...  9362 runnervmeo...     FALSE running
    2: swinish_to...  9364 runnervmeo...     FALSE running

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
