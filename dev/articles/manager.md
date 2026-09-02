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

           worker_id   pid      hostname profile heartbeat   state
              <char> <int>        <char>  <char>    <lgcl>  <char>
    1: mucky_amph...  9798 runnervmgx...    <NA>     FALSE running
    2: ceramic_ju...  9796 runnervmgx...    <NA>     FALSE running

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

           worker_id   pid      hostname profile heartbeat      state
              <char> <int>        <char>  <char>    <lgcl>     <char>
    1: ceramic_ju...  9796 runnervmgx...    <NA>     FALSE    running
    2: mucky_amph...  9798 runnervmgx...    <NA>     FALSE terminated

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

            worker_id           x1          x2           y          keys
               <char>        <num>       <num>       <num>        <char>
     1: moistful_l... -4.581803263 10.72580388  36.6103526 ff4eaaef-f...
     2: moistful_l...  2.391027242 14.16674388 129.1724449 940bbf8e-2...
     3: moistful_l...  1.013639717  3.56523747  15.9879260 198360ea-5...
     4: moistful_l...  5.332869147  8.47576963  68.7175768 8b2efb0f-2...
     5: moistful_l... -0.265919499 14.50864956  84.4910785 a2bb0802-f...
     6: moistful_l...  5.731133811 11.96251432 135.6968525 21c32c4e-3...
     7: moistful_l...  5.168559788 14.57463288 192.4420819 0e5102c9-1...
     8: moistful_l...  6.301994006  9.06028718  82.9563274 6104903e-f...
     9: moistful_l...  6.421595147 14.64567305 202.8091866 bf984ff1-e...
    10: moistful_l...  7.354066938 14.93544461 201.0129282 ddfff735-e...
    11: moistful_l... -3.201865985  8.15735343  18.5882125 5af33c1c-1...
    12: moistful_l...  7.629612829  2.11269712  12.6775570 9c15fa4a-2...
    13: moistful_l...  7.196368875 12.24082917 136.9578588 41759bbd-a...
    14: moistful_l... -2.643408932  6.17613921  25.9060844 7b911906-e...
    15: moistful_l...  9.057320190  8.16151125  36.7876473 1fdcb2a6-0...
    16: moistful_l...  9.106309255  9.52385723  54.2348353 c62c987c-3...
    17: moistful_l...  5.010616114 12.62804412 141.8560853 c3086c2f-1...
    18: moistful_l...  9.607533539 11.57311148  80.4749325 f381e729-4...
    19: moistful_l...  0.330250560  1.61719592  34.0700616 014565bd-f...
    20: moistful_l...  1.416486541  5.73286179  14.4620524 7892efb7-6...
    21: moistful_l...  1.838700843 12.36361963  85.8383053 4ca46e4c-0...
    22: moistful_l...  4.852316478  9.69990357  81.5796937 8d3e045d-2...
    23: moistful_l...  9.826826456 13.73504336 119.9740954 76449668-1...
    24: moistful_l...  3.254626816  7.48480176  28.5099781 f3ee8bb3-8...
    25: moistful_l...  3.194119639  4.43678667   5.2616697 c5a7bc63-c...
    26: moistful_l... -0.370254050 10.34612080  32.9325493 fb5369c9-c...
    27: moistful_l...  4.529518150 14.61930847 181.9093453 da664127-e...
    28: moistful_l...  9.784982733 11.01373117  68.5517578 a61c2d2e-c...
    29: moistful_l...  3.279484420  0.69711330   2.6581908 dd8f174c-d...
    30: moistful_l...  6.867043974 13.65493727 174.0693689 7595613e-e...
    31: moistful_l...  8.660041646 11.99329896 104.8355718 4f18df87-1...
    32: moistful_l...  1.590402554 11.81741049  74.1619569 8116d497-a...
    33: moistful_l...  6.478649043  9.52831858  90.2678681 a94ab3be-a...
    34: moistful_l... -4.381253375 11.41701594  23.1651540 358222d3-0...
    35: moistful_l...  7.540302679  2.76684960  14.9868430 ca7d8eb9-3...
    36: moistful_l... -3.017358061  0.37804699 135.0407408 0fc698e3-d...
    37: moistful_l...  8.266508434 12.73803922 128.6232618 4b6ff510-8...
    38: moistful_l...  2.923073471 10.59489683  66.9397928 20185ec7-c...
    39: moistful_l... -1.244295290  7.68046019  13.3296040 311c1962-3...
    40: queenly_wa...  0.791426852  6.24628996  18.7792004 24a641e4-c...
    41: moistful_l... -0.001477897  3.19852126  27.4635714 af10637a-b...
    42: queenly_wa...  4.896360008  5.83768008  32.3079659 38b79938-2...
    43: moistful_l...  8.490243010  1.86553779   4.2988541 941aa697-0...
    44: queenly_wa...  3.773162580  5.06541177  12.6921832 3c6dfab4-3...
    45: moistful_l... -0.706082096 14.93292547  77.2875836 e4c5f134-c...
    46: queenly_wa...  0.092466723 13.55542728  78.8740113 cc642bcc-f...
    47: moistful_l...  1.516639190  9.73371894  44.7466645 a188d371-4...
    48: queenly_wa... -2.893126012  2.12927393  92.0209161 a97e3049-7...
    49: moistful_l...  0.561097261  3.10442708  22.3046266 0a437e48-f...
    50: queenly_wa...  3.197389849 10.88041222  75.2097979 2324d04b-6...
    51: moistful_l...  8.757382124  9.12061904  53.5955349 19447889-c...
    52: queenly_wa...  9.600011280  8.84100175  39.1614889 0bb1da37-3...
    53: moistful_l...  3.947939184  9.94645436  70.8615147 183439b4-5...
    54: queenly_wa...  0.426307548  4.50343955  19.4509164 92e6b7d8-b...
    55: moistful_l...  9.213134357 10.15322502  62.2497804 d3535691-c...
    56: queenly_wa... -2.656910192  6.28807885  25.0502052 3a46a243-5...
    57: moistful_l...  7.173457954 11.97063023 131.3871503 efe21d93-2...
    58: queenly_wa...  5.694475940 11.55167989 126.6797791 dd01500d-7...
    59: moistful_l... -1.681791381  3.84223776  35.9743689 0216b929-d...
    60: queenly_wa...  7.933621116 12.33116758 126.4544419 a442e6c5-4...
    61: moistful_l...  9.267998997  2.09338826   0.5794309 d9d717e7-2...
    62: queenly_wa...  9.108629178  1.03841796   2.2728229 a3a2a8ec-c...
    63: moistful_l...  0.872518503  3.82655797  16.9531166 94ce818e-c...
    64: queenly_wa... -2.422451742  4.91643868  35.2326216 b2adafeb-2...
    65: moistful_l... -2.273188106  3.48792586  50.0027622 994759d7-5...
    66: queenly_wa...  6.427282653  9.33186652  87.1465975 475c1953-e...
    67: moistful_l... -1.975380242  9.26732281   6.3651824 21df14b8-a...
    68: queenly_wa...  4.013757097  9.20137959  60.1984440 191114da-9...
    69: moistful_l...  4.250485212  2.92545486   7.5605660 58da1424-4...
    70: queenly_wa...  9.935972671  0.32375327   8.4699637 eed70ede-7...
    71: moistful_l...  6.275345874  9.43441660  89.0683449 1f0ee2ec-a...
    72: queenly_wa...  0.169378326  6.98060460  21.0183975 1731a5a1-c...
    73: moistful_l...  2.809489528  1.90516090   1.3361118 8885f370-1...
    74: queenly_wa...  6.344807380  4.38146970  30.3358443 9674143b-5...
    75: moistful_l... -4.265245084  5.70143782  94.9065256 8cdf54f3-7...
    76: queenly_wa...  8.427935165  9.65759566  67.1188178 011307fe-5...
    77: moistful_l...  6.761275635  5.45365727  37.0921949 ee3eb4bc-f...
    78: queenly_wa... -1.212913897  0.73994287  67.8356246 e30271ec-7...
    79: moistful_l...  9.230538527 12.17805041  97.8379253 0f10c15c-7...
    80: queenly_wa...  4.308531938 13.81811737 156.9575217 b3f1a848-4...
    81: moistful_l...  4.956150166  0.06915438  13.7964144 677de2cb-3...
    82: queenly_wa...  1.303711814 10.36053391  51.1714250 c8582dd8-7...
    83: moistful_l...  1.607119702  9.44280072  41.7656072 e0f34854-9...
    84: queenly_wa... -0.854536324  4.59764118  24.4653511 0ca5f6bf-7...
    85: moistful_l...  0.367588713  3.67530445  22.0481138 4cd5c40a-0...
    86: queenly_wa...  9.970031049  3.05110351   1.7962788 eceff690-4...
    87: moistful_l...  1.194388085  7.10000659  21.4630549 15ae1a80-f...
    88: queenly_wa...  1.206595231  3.20338643  14.5531067 b87358e1-e...
    89: moistful_l... -1.008116706 14.42201661  59.8283495 9c11ae12-a...
            worker_id           x1          x2           y          keys
               <char>        <num>       <num>       <num>        <char>

The `$stop_workers()` method with `type = "terminate"` sends the
terminate signal.

``` r

rush$stop_workers(type = "terminate")
```

``` r

rush$worker_info
```

           worker_id   pid      hostname profile heartbeat      state
              <char> <int>        <char>  <char>    <lgcl>     <char>
    1: moistful_l...  9798 runnervmgx...    <NA>     FALSE terminated
    2: queenly_wa...  9796 runnervmgx...    <NA>     FALSE terminated

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

    [1] "improbable_nag_2546a052" "peachy_tomtit_0b2639ee" 

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

### Compute Profiles

Daemons can be started on separate compute profiles, for example one
profile for CPU daemons and one profile for GPU daemons.

``` r

mirai::daemons(n = 2L, .compute = "cpu")
mirai::daemons(n = 2L, .compute = "gpu")
```

The `profiles` argument of the `$start_workers()` method distributes the
workers over the compute profiles. The names are the compute profiles
and the values are the numbers of workers started on the daemons of the
respective profile. The `profiles` argument cannot be combined with the
`n_workers` argument.

``` r

worker_ids = rush$start_workers(
  worker_loop = wl_random_search,
  profiles = c(cpu = 2, gpu = 2),
  branin = branin)
```

The profile of a worker is recorded in the `profile` column of the
`$worker_info` field. Furthermore, the name of the profile is passed to
the worker loop when the worker loop has a `profile` argument. This
allows the worker loop to run different code on different profiles. The
profile is `NULL` when the worker runs on the default compute profile.

``` r

wl_random_search = function(rush, branin, profile = NULL) {
  while (!rush$terminated) {
    xs = if (profile == "gpu") sample_gpu() else sample_cpu()
    keys = rush$push_running_tasks(list(xs))
    rush$finish_tasks(keys, yss = list(list(y = branin(xs$x1, xs$x2))))
  }
}
```

#### Profile Queues

Each compute profile has its own queue. The `profile` argument of the
`$push_tasks()` method queues tasks for a single profile. These tasks
are only processed by the workers running on that profile.

``` r

rush$push_tasks(list(list(x1 = 1, x2 = 2)), profile = "gpu")
```

Tasks pushed without a profile are queued in the shared queue. A worker
takes tasks from the queue of its profile first and falls back to the
shared queue, so that tasks pushed without a profile are processed by
any worker. Workers running on the default compute profile only take
tasks from the shared queue. The `$n_queued_tasks_per_profile` field
reports the number of queued tasks of the shared queue and of each
profile.

``` r

rush$n_queued_tasks_per_profile
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

The `profiles` argument sets the number of workers per compute profile,
see [Section 1.4](#sec-compute-profiles).

``` r

rush_plan(profiles = c(cpu = 2, gpu = 2), config = redux::redis_config())
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

           worker_id   pid      hostname profile heartbeat   state
              <char> <int>        <char>  <char>    <lgcl>  <char>
    1: horrific_i... 10046 runnervmgx...    <NA>     FALSE running
    2: intrapsych... 10049 runnervmgx...    <NA>     FALSE running

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

           worker_id   pid      hostname profile heartbeat   state
              <char> <int>        <char>  <char>    <lgcl>  <char>
    1: horrific_i... 10046 runnervmgx...    <NA>     FALSE running
    2: intrapsych... 10049 runnervmgx...    <NA>     FALSE running

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

    [1] "Rscript -e 'rush::start_worker(network_id = \"random-search-network\", config = list(scheme = \"redis\", host = \"127.0.0.1\", port = \"6379\"))'"

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

    [1] "Rscript -e 'rush::start_worker(network_id = \"random-search-network\", config = list(scheme = \"redis\", host = \"127.0.0.1\", port = \"6379\"), heartbeat_period = 1L, heartbeat_expire = 3L)'"

To kill a script worker, the `$stop_workers(type = "kill")` method
pushes a kill signal to the heartbeat process, which then terminates the
main worker process.
