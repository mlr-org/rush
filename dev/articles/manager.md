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
    1: tantalous_...  8656 runnervm76...    <NA>     FALSE running
    2: nonspirito...  8654 runnervm76...    <NA>     FALSE running

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
    1: nonspirito...  8654 runnervm76...    <NA>     FALSE    running
    2: tantalous_...  8656 runnervm76...    <NA>     FALSE terminated

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

             worker_id        x1         x2          y          keys
                <char>     <num>      <num>      <num>        <char>
      1: goodish_ve...  1.993995  7.6291841  24.452873 9a035d9b-2...
      2: goodish_ve...  2.650704 13.6346676 121.340416 1504c5bc-7...
      3: multipurpo... -1.441198  5.6526565  19.705571 b4be4e9a-c...
      4: goodish_ve...  3.949022  2.6141346   4.144012 5cd30f9d-1...
      5: goodish_ve...  6.433923 14.5424816 199.985687 ffe60121-4...
     ---
    201: multipurpo... -3.394013  4.9175844  64.259322 b7cdc20c-0...
    202: goodish_ve...  8.270567  5.6584626  21.994532 009f0287-b...
    203: multipurpo... -3.399257  8.0640824  24.128112 e2ae6b94-d...
    204: multipurpo...  4.684584  3.1317471  12.804297 03474c7e-d...
    205: goodish_ve... -2.193569  0.6967912  93.059970 064afb7a-3...

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
    1: multipurpo...  8656 runnervm76...    <NA>     FALSE terminated
    2: goodish_ve...  8654 runnervm76...    <NA>     FALSE terminated

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

    [1] "postlegal_dugong_91644db7"  "patchy_archerfish_0661dbfd"

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
    1: department...  8907 runnervm76...    <NA>     FALSE running
    2: weariful_m...  8910 runnervm76...    <NA>     FALSE running

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
    1: department...  8907 runnervm76...    <NA>     FALSE running
    2: weariful_m...  8910 runnervm76...    <NA>     FALSE running

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
