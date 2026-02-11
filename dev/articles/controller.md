# Controller

A **rush** network consists of thousands of workers started on different
machines. This article explains how to start workers in a rush network.
Rush offers three ways to start workers: local workers with `processx`,
remote workers with `mirai` and script workers.

## Local Workers

We use the random search example from the [Rush
article](https://rush.mlr-org.com/dev/articles/rush.md) to demonstrate
how the controller works.

``` r
library(rush)

wl_random_search = function(rush, branin) {
  while(TRUE) {

    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))

    ys = list(y = branin(xs$x1, xs$x2))
    rush$push_results(key, yss = list(ys))
  }
}

rush = rsh(
  network = "test-network",
  config = redux::redis_config())

branin = function(x1, x2) {
  (x2 - 5.1 / (4 * pi^2) * x1^2 + 5 / pi * x1 - 6)^2 + 10 * (1 - 1 / (8 * pi)) * cos(x1) + 10
}
```

### Start Workers

Workers may be initiated locally or remotely. Local workers run on the
same machine as the controller, whereas remote workers operate on
separate machines. The `$start_local_workers()` method initiates local
workers using the `processx` package. The `n_workers` parameter
specifies the number of workers to launch. The `worker_loop` parameter
defines the function executed by each worker. If the `worker_loop`
function depends on additional objects, these can be passed as arguments
to `worker_loop`. Required packages for the `worker_loop` can be
specified using the `packages` parameter.

``` r
worker_ids = rush$start_local_workers(
  worker_loop = wl_random_search,
  branin = branin,
  n_workers = 2)
```

Worker information is accessible through the `$worker_info` method. Each
worker is identified by a `worker_id`. The `pid` field denotes the
process identifier, and the `hostname` field indicates the machine name.
The `remote` column specifies whether the worker is remote, and the
`heartbeat` column indicates the presence of a heartbeat process. The
`state` column indicates the current state of the worker. Possible
states include `"running"`, `"terminated"`, `"killed"`, and `"lost"`.
Heartbeat mechanisms are discussed in the [Error
Handling](#error-handling) section.

``` r
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat   state
              <char> <int> <lgcl>        <char>    <lgcl>  <char>
    1: roomy_clea...  8623  FALSE runnervmwf...     FALSE running
    2: presentien...  8634  FALSE runnervmwf...     FALSE running

Additional workers may be added to the network at any time.

``` r
rush$start_local_workers(
  worker_loop = wl_random_search,
  branin = branin,
  n_workers = 2)
```

``` r
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat   state
              <char> <int> <lgcl>        <char>    <lgcl>  <char>
    1: roomy_clea...  8623  FALSE runnervmwf...     FALSE running
    2: presentien...  8634  FALSE runnervmwf...     FALSE running
    3: endangered...  8697  FALSE runnervmwf...     FALSE running
    4: incredulou...  8699  FALSE runnervmwf...     FALSE running

### Rush Plan

When `rush` is integrated into a third-party package, the starting of
workers is typically managed by the package itself. In such cases, users
may configure worker options by invoking the
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
function. This function allows explicit specification of the number of
workers, the type of workers, and the configuration for connecting to
the Redis database.

``` r
rush_plan(n_workers = 2, config = redux::redis_config(), worker_type = "local")
```

### Passing data to workers

Objects required by the worker loop can be passed as arguments to
`$start_local_workers()` / `$start_remote_workers()`. These arguments
are serialized and stored in the Redis database as part of the worker
configuration. Upon initialization, each worker retrieves and
unserializes the worker configuration before invoking the worker loop.

> **Note**
>
> The maximum size of a Redis string is 512 MiB. If the serialized
> worker configuration exceeds this limit, Rush will raise an error. In
> scenarios where both the controller and the workers have access to a
> shared file system, Rush will instead write large objects to disk. The
> `large_objects_path` argument of
> [`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md)
> specifies the directory used for storing such large objects.

### Stop Worker

Workers can be stopped individually or all at once. To terminate a
specific worker, the `$stop_workers()` method is invoked with the
corresponding `worker_ids` argument.

``` r
rush$stop_workers(worker_ids = worker_ids[1])
```

This command terminates the selected worker process.

``` r
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat   state
              <char> <int> <lgcl>        <char>    <lgcl>  <char>
    1: presentien...  8634  FALSE runnervmwf...     FALSE running
    2: endangered...  8697  FALSE runnervmwf...     FALSE running
    3: incredulou...  8699  FALSE runnervmwf...     FALSE running
    4: roomy_clea...  8623  FALSE runnervmwf...     FALSE  killed

To stop all workers and reset the network, the `$reset()` method is
used.

``` r
rush$reset()
```

Instead of killing the worker processes, it is also possible to send a
terminate signal to the worker. The worker then terminates after it has
finished the current task. The worker loop must implement the
`rush$terminated` flag. Then the rush controller can terminate the
optimization.

``` r
wl_random_search = function(rush, branin) {
  while(!rush$terminated) {

    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))

    ys = list(y = branin(xs$x1, xs$x2))
    rush$push_results(key, yss = list(ys))
  }
}

rush = rsh(
  network = "test-random-search-terminate",
  config = redux::redis_config())

rush$start_local_workers(
  worker_loop = wl_random_search,
  n_workers = 2,
  branin = branin)
```

The random search proceeds as usual.

``` r
rush$fetch_finished_tasks()
```

                x1        x2          y   pid     worker_id
             <num>     <num>      <num> <int>        <char>
      1:  3.889869  5.782428  19.112482  8772 fetid_rabb...
      2:  7.262342  4.223675  24.168217  8770 idiosyncra...
      3:  6.586416  7.091787  54.807999  8772 fetid_rabb...
      4: -2.972467  8.454350  12.216892  8772 fetid_rabb...
      5:  2.597244  8.898633  39.741652  8772 fetid_rabb...
     ---
    626:  5.006908 12.160945 131.404313  8770 idiosyncra...
    627: -2.803401 11.438668   0.943257  8772 fetid_rabb...
    628: -2.621570  8.371478   8.896414  8770 idiosyncra...
    629:  8.090129  2.114706   8.040149  8772 fetid_rabb...
    630: -1.851024 10.466015   8.505084  8770 idiosyncra...
                                         keys
                                       <list>
      1: 523c019c-351d-416a-b54f-6d285cc92d92
      2: 7bc9ea0e-ac87-492c-b34e-ec47b1f1ee99
      3: 8bfe6274-4f7c-4d2a-bcff-2101731fc4b1
      4: 4f542dd9-1651-467b-8de7-81552381e678
      5: 51ff82b5-e58d-4b1f-9a26-ea2d8978088a
     ---
    626: b2b0558c-979f-4c9a-8e41-f0b95aaed964
    627: 49022e9d-0239-4be4-9f90-30efa9e0c177
    628: a592fea1-ae70-42ff-8945-ea0091ca4e90
    629: 525e06db-d631-43ed-b873-d88e738c206d
    630: a7c60855-b68d-4aae-8255-871fb3dd01c2

To terminate the optimization, the following command is used.

``` r
rush$stop_workers(type = "terminate")
```

The workers are terminated.

``` r
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat      state
              <char> <int> <lgcl>        <char>    <lgcl>     <char>
    1: idiosyncra...  8770  FALSE runnervmwf...     FALSE terminated
    2: fetid_rabb...  8772  FALSE runnervmwf...     FALSE terminated

### Failed Workers

We simulate a segfault on the worker by killing the worker process.

``` r
rush = rsh(network = "test-failed-workers")

wl_failed_worker = function(rush) {
  tools::pskill(Sys.getpid(), tools::SIGKILL)
}
```

Workers are then started using the faulty worker loop.

``` r
worker_ids =  rush$start_local_workers(
  worker_loop = wl_failed_worker,
  n_workers = 2)
```

The `$detect_lost_workers()` method is used to identify failed workers.
When a worker is detected, its state is updated to `"lost"`.

``` r
rush$detect_lost_workers()
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat  state
              <char> <int> <lgcl>        <char>    <lgcl> <char>
    1: underprivi...  8846  FALSE runnervmwf...     FALSE   lost
    2: paleologic...  8848  FALSE runnervmwf...     FALSE   lost

### Restart Workers

Workers that have failed can be restarted using the `$restart_workers()`
method. This method accepts the `worker_ids` of the workers to be
restarted.

``` r
rush$restart_workers(worker_ids = worker_ids[1])
```

The first worker is restarted and its state is updated to `"running"`.

``` r
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat   state
              <char> <int> <lgcl>        <char>    <lgcl>  <char>
    1: underprivi...  8918  FALSE runnervmwf...     FALSE running
    2: paleologic...  8848  FALSE runnervmwf...     FALSE    lost

### Log Messages

Workers record all messages generated using the `lgr` package to the
database. The `lgr_thresholds` argument of `$start_local_workers()`
specifies the logging level for each logger,
e.g. `c("mlr3/rush" = "debug")`. While enabling log message storage
introduces a minor performance overhead, it is valuable for debugging
purposes. By default, log messages are not stored. To enable logging,
workers are started with the desired logging threshold.

``` r
rush = rsh(network = "test-log-messages")

wl_log_message = function(rush) {
  lg = lgr::get_logger("mlr3/rush")
  lg$info("This is an info message from worker %s", rush$worker_id)
}

rush$start_local_workers(
  worker_loop = wl_log_message,
  n_workers = 2,
  lgr_thresholds = c(rush = "info"))
```

The most recent log messages can be printed as follows.

``` r
Sys.sleep(1)
rush$print_log()
```

To retrieve all log entries, use the `$read_log()` method.

``` r
rush$read_log()
```

    Null data.table (0 rows and 0 cols)

We reset the network.

``` r
rush$reset()
```

## Remote Workers

The `mirai` package provides a straightforward mechanism for launching
`rush` workers on remote machines. `mirai` manages daemons, which are
persistent background processes capable of executing arbitrary R code in
parallel. These daemons communicate with the main session.

``` r
library(mirai)
```

### Start Workers

Usually `mirai` is used to start daemons on remote machines but it can
also be used to start local daemons.

``` r
daemons(
  n = 2,
  url = host_url()
)
```

Daemons may also be launched on a remote machine via SSH.

``` r
daemons(
  n = 2L,
  url = host_url(port = 5555),
  remote = ssh_config(remotes = "ssh://10.75.32.90")
)
```

On high performance computing clusters, daemons can be started using a
scheduler.

``` r
daemons(
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

We define a worker loop.

``` r
wl_random_search = function(rush, branin) {
  while(TRUE) {

    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))

    ys = list(y = branin(xs$x1, xs$x2))
    rush$push_results(key, yss = list(ys))
  }
}

rush = rsh(
  network = "test-network",
  config = redux::redis_config())
```

We start two new daemons.

``` r
daemons(2)
```

After the daemons are started, we can start the remote workers.

``` r
worker_ids = rush$start_remote_workers(
  worker_loop = wl_random_search,
  n_workers = 2,
  branin = branin)
```

``` r
rush$worker_info
```

           worker_id   pid remote      hostname heartbeat   state
              <char> <int> <lgcl>        <char>    <lgcl>  <char>
    1: microphysi...  9070   TRUE runnervmwf...     FALSE running
    2: craven_hoo...  9072   TRUE runnervmwf...     FALSE running

We stop the daemons.

``` r
rush$reset()
```

### Failed Workers

Failed workers started with `mirai` are also detected by the controller.
We simulate a segfault on the worker by killing the worker process.

``` r
rush = rsh(network = "test-failed-mirai-workers")

wl_failed_worker = function(rush) {
  tools::pskill(Sys.getpid(), tools::SIGKILL)
}
```

Start two new daemons.

``` r
daemons(2)
```

Start two remote workers.

``` r
worker_ids = rush$start_remote_workers(
  worker_loop = wl_failed_worker,
  n_workers = 2)
```

``` r
rush$detect_lost_workers()
```

A segmentation fault also terminates the associated `mirai` daemon.
Therefore, it is necessary to restart the daemon before restarting the
workers.

``` r
daemons(2)
```

Workers can then be restarted using the `$restart_workers()` method.

``` r
rush$restart_workers(worker_ids)
```

## Script Workers

The most flexible method for starting workers is to use a script
generated with the `$worker_script()` method. This script can be
executed either on the local machine or on a remote machine. The only
requirement is that the machine is capable of running R scripts and has
access to the Redis database.

``` r
rush = rsh(
  network = "test-script-workers",
  config = redux::redis_config())

rush$worker_script(
  worker_loop = wl_random_search)
```

### Error Handling

Workers started with `processx` or `mirai` are monitored by these
packages. The heartbeat is a mechanism to monitor the status of script
workers. The mechanism consists of a heartbeat key with a set
[expiration timeout](https://redis.io/commands/expire/) and a dedicated
heartbeat process that refreshes the timeout periodically. The heartbeat
process is started with `callr` and is linked to the main process of the
worker. In the event of a worker’s failure, the associated heartbeat
process also ceases to function, thus halting the renewal of the
timeout. The absence of the heartbeat key acts as an indicator to the
controller that the worker is no longer operational. Consequently, the
controller updates the worker’s status to `"lost"`.

Heartbeats are initiated upon worker startup by specifying the
`heartbeat_period` and `heartbeat_expire` parameters. The
`heartbeat_period` defines the frequency at which the heartbeat process
will update the timeout. The `heartbeat_expire` sets the duration, in
seconds, before the heartbeat key expires. The expiration time should be
set to a value greater than the heartbeat period to ensure that the
heartbeat process has sufficient time to refresh the timeout.

``` r
rush$worker_script(
  worker_loop = wl_random_search,
  heartbeat_period = 1,
  heartbeat_expire = 3)
```

The heartbeat process is also the only way to kill a script worker. The
`$stop_workers(type = "kill")` method pushes a kill signal to the
heartbeat process. The heartbeat process terminates the main process of
the worker.
