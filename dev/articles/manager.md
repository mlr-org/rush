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

           worker_id   pid      hostname profile heartbeat restarted_from   state
              <char> <int>        <char>  <char>    <lgcl>         <char>  <char>
    1: culm_germa...  8850 runnervmtr...    <NA>     FALSE           <NA> running
    2: suboceanic...  8852 runnervmtr...    <NA>     FALSE           <NA> running

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

           worker_id   pid      hostname profile heartbeat restarted_from
              <char> <int>        <char>  <char>    <lgcl>         <char>
    1: suboceanic...  8852 runnervmtr...    <NA>     FALSE           <NA>
    2: culm_germa...  8850 runnervmtr...    <NA>     FALSE           <NA>
            state
           <char>
    1:    running
    2: terminated

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

            worker_id         x1          x2          y          keys
               <char>      <num>       <num>      <num>        <char>
     1: squarish_u...  2.0899025  5.96924554  12.695752 464bb87b-2...
     2: squarish_u...  6.7935523  8.27803848  69.188903 d379bf2e-a...
     3: squarish_u...  0.4357281 12.64195301  72.154309 d86b71ad-7...
     4: squarish_u...  8.1478189  2.18396539   7.550117 1dc32b0d-2...
     5: squarish_u...  8.0788353  2.18282561   8.230118 60ee7dda-b...
     6: squarish_u...  7.2905718  0.38189302  15.904863 ff590e1c-4...
     7: squarish_u...  4.1928116  0.97720256   5.617755 7761a4fe-e...
     8: squarish_u...  7.6500088 13.00766384 147.034804 e615a5eb-1...
     9: squarish_u...  7.0061847  8.41449722  69.385427 d925d144-f...
    10: squarish_u... -0.8650278  6.51806400  17.140779 40e50fc5-c...
    11: squarish_u...  2.3283213  1.02547693   7.279910 ccf5ca31-2...
    12: squarish_u...  3.8357502 12.84767140 124.761469 83763bec-1...
    13: squarish_u... -0.9459725  7.02977333  15.966541 1a16263b-f...
    14: squarish_u...  6.9389768 11.17245010 117.530683 a10c1674-8...
    15: squarish_u...  9.6206764 13.52581378 118.969255 d7ad787d-b...
    16: squarish_u...  7.3460622  4.07858869  22.503456 0598f21c-c...
    17: squarish_u... -4.1597802  9.40816608  34.637293 19cdd1a9-e...
    18: squarish_u...  6.9090076 14.57803515 197.543903 6dd19c35-8...
    19: squarish_u... -3.2124771  7.89982663  21.089705 cc2b0f19-1...
    20: squarish_u...  4.6896774  3.17647842  13.018942 40f47600-0...
    21: squarish_u...  3.4572176  4.38048777   6.342013 926e11ee-3...
    22: squarish_u... -0.1701195 12.28946042  55.643344 85974299-5...
    23: squarish_u... -3.4393183  8.14742473  24.386806 b0dd3d84-7...
    24: squarish_u...  0.3833459  7.51779480  23.352738 5645fdac-5...
    25: squarish_u...  7.2438745 12.79593899 148.814742 7e6ffb2c-e...
    26: squarish_u... -2.6571705  8.30829624   9.527628 4f67411d-4...
    27: squarish_u...  8.8615925  1.94037577   1.890958 126badf5-8...
    28: squarish_u... -2.1697230  4.41066358  36.517378 2eb62852-e...
    29: squarish_u...  5.1453103  4.53610562  24.951759 5cc88fc5-0...
    30: squarish_u...  9.7608112  4.04534691   2.553701 bea2213a-a...
    31: squarish_u...  6.4322600  1.81342603  19.993783 017a0aa0-b...
    32: terrestria... -3.0934393 13.28529085   1.676252 4f5024a6-a...
    33: squarish_u...  9.1713122 12.50854588 105.542832 0749e7a7-1...
    34: terrestria...  9.2396115  8.24173151  35.590601 506e7376-4...
    35: squarish_u...  2.4815385 13.34155968 112.570841 ba424f91-8...
    36: terrestria...  5.4886712 12.79520478 152.192628 e0e53e50-d...
    37: squarish_u... -2.0274580  7.13778337  12.630518 04c31e0c-c...
    38: terrestria... -3.3563123  2.18369040 113.260280 02177ff5-f...
    39: squarish_u... -1.2092594  8.39887062  13.477819 7f356b40-0...
    40: terrestria...  4.2709286  1.78969938   5.950603 701f7298-6...
    41: squarish_u... -0.6464481  7.50894476  17.846244 67a7f00a-1...
    42: terrestria...  2.4340525  0.23733225   9.747108 d1d394f7-b...
    43: squarish_u...  8.4982434 11.66316373 101.429118 39505337-4...
    44: terrestria...  8.8777786 13.26090115 127.432856 5cf91a9e-b...
    45: squarish_u...  4.9554578  1.37707111  12.319450 a913bb5a-1...
    46: terrestria...  7.8193648  3.28457464  13.684233 9247a9de-e...
    47: squarish_u...  7.8879893 10.23833506  86.315686 057fc590-0...
    48: terrestria...  8.6993576 13.33459189 132.855723 7f36c523-6...
    49: squarish_u...  7.0359399  7.58431994  57.803490 4315e743-7...
    50: terrestria...  3.6674255  6.77613373  25.465474 8e416aad-7...
    51: squarish_u... -2.4749370 11.21253660   2.686328 144db114-8...
    52: terrestria...  1.9452156  7.31123628  21.841482 6d4786ee-9...
    53: squarish_u...  6.2168581  5.02914829  35.031333 d8d9ba00-3...
    54: terrestria... -1.5020876 13.39298616  32.851475 1eb42ac8-4...
    55: squarish_u... -2.0216664  8.66011197   6.994124 7da2e27c-b...
    56: terrestria...  4.7969973 14.81944814 192.560082 af120877-e...
    57: squarish_u... -2.0932161 11.44385276   7.600002 32af4072-d...
    58: terrestria...  0.1268422  5.08403012  20.037876 1925a2b1-2...
    59: squarish_u...  0.9661660 14.01964814 104.510807 2cd25c89-6...
    60: terrestria...  5.7788216  2.30323978  19.814099 9f57a478-6...
    61: squarish_u... -2.0969457  0.69180907  90.068751 7b2dd142-0...
    62: terrestria...  1.9669527  0.42293950  14.975821 e225a5b8-2...
    63: squarish_u... -2.4851720 14.31597513  15.087263 838fae98-4...
    64: terrestria...  6.1529723  1.51751784  19.696781 420c97df-b...
    65: squarish_u...  5.9614705  3.40517453  24.408881 9c9778f1-0...
    66: terrestria... -4.5980793  8.83825086  60.904473 e117abb2-4...
    67: squarish_u...  4.5376337 13.60937860 156.471598 3dcff0c1-e...
    68: terrestria... -3.1109790  5.07748727  51.154643 ce2a5e16-6...
    69: squarish_u... -2.8160781  5.64958113  35.204445 d7ace2d4-c...
    70: terrestria... -4.1676847 12.06882165  12.910155 aad23b3c-8...
    71: squarish_u... -4.5844541  0.07103497 262.872836 7c726bf4-e...
    72: terrestria...  1.2635956  6.01226325  16.205351 ef71381e-c...
    73: squarish_u...  6.5180677  0.96593877  19.360556 258d7fc0-6...
    74: terrestria...  8.3913521  4.47886079  12.579403 3a6c7d22-7...
    75: squarish_u...  6.0176859  4.04364981  27.926888 246bea19-3...
    76: terrestria... -1.7521341  9.78908870   8.632982 708fd6df-8...
    77: squarish_u... -4.8393351 14.75953047  15.088324 e93dbc87-0...
    78: terrestria...  3.6087988  0.71266581   2.930457 bb8d2e5d-1...
    79: squarish_u... -2.5683915  0.59963916 108.853699 3092790b-1...
    80: terrestria...  8.0400254 12.27971167 123.250859 59d1bb1b-0...
    81: squarish_u... -1.0450290 14.48680755  59.475040 680e3001-3...
    82: squarish_u... -0.6474780  9.60869206  24.029500 2f3e2d43-d...
    83: squarish_u... -4.6859714 14.97064287  11.499309 0b707ca8-b...
    84: terrestria...  9.1814628  1.13413533   1.987790 a1855f0a-1...
    85: terrestria...  1.9513297  1.05635247  11.862078 c0299757-b...
    86: squarish_u...  5.0164168  7.28437618  49.083597 43998bb1-f...
    87: terrestria...  1.8219570  5.68546542  12.263528 7d402072-c...
    88: squarish_u...  8.7358629 11.07188272  85.701740 60d12134-0...
    89: terrestria...  3.7064346  1.83312324   1.891167 7a9cfac4-4...
    90: squarish_u...  2.3376133 14.88396422 144.911216 26bdf33b-0...
    91: terrestria...  7.0226049 11.25372795 118.289383 67f3e080-c...
    92: squarish_u...  9.5735127  3.50434262   1.315745 d1e33a73-a...
            worker_id         x1          x2          y          keys
               <char>      <num>       <num>      <num>        <char>

The `$stop_workers()` method with `type = "terminate"` sends the
terminate signal.

``` r

rush$stop_workers(type = "terminate")
```

``` r

rush$worker_info
```

           worker_id   pid      hostname profile heartbeat restarted_from
              <char> <int>        <char>  <char>    <lgcl>         <char>
    1: squarish_u...  8850 runnervmtr...    <NA>     FALSE           <NA>
    2: terrestria...  8852 runnervmtr...    <NA>     FALSE           <NA>
            state
           <char>
    1: terminated
    2: terminated

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

    [1] "noncorporative_blackrussianterrier_39e6b72c"
    [2] "laborious_siskin_49bf68c9"                  

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

           worker_id   pid      hostname profile heartbeat restarted_from   state
              <char> <int>        <char>  <char>    <lgcl>         <char>  <char>
    1: streaky_ha...  9101 runnervmtr...    <NA>     FALSE           <NA> running
    2: peachy_arm...  9104 runnervmtr...    <NA>     FALSE           <NA> running

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

           worker_id   pid      hostname profile heartbeat restarted_from   state
              <char> <int>        <char>  <char>    <lgcl>         <char>  <char>
    1: streaky_ha...  9101 runnervmtr...    <NA>     FALSE           <NA> running
    2: peachy_arm...  9104 runnervmtr...    <NA>     FALSE           <NA> running

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
