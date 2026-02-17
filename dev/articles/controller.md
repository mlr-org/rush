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

           worker_id   pid      hostname heartbeat   state
              <char> <int>        <char>    <lgcl>  <char>
    1: subpentago...  9570 runnervmjd...     FALSE running
    2: antidemocr...  9581 runnervmjd...     FALSE running

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

           worker_id   pid      hostname heartbeat   state
              <char> <int>        <char>    <lgcl>  <char>
    1: subpentago...  9570 runnervmjd...     FALSE running
    2: antidemocr...  9581 runnervmjd...     FALSE running
    3: shadowed_w...  9643 runnervmjd...     FALSE running
    4: dietetic_s...  9647 runnervmjd...     FALSE running

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

           worker_id   pid      hostname heartbeat      state
              <char> <int>        <char>    <lgcl>     <char>
    1: antidemocr...  9581 runnervmjd...     FALSE    running
    2: shadowed_w...  9643 runnervmjd...     FALSE    running
    3: dietetic_s...  9647 runnervmjd...     FALSE    running
    4: subpentago...  9570 runnervmjd...     FALSE terminated

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

             worker_id        x1        x2          y
                <char>     <num>     <num>      <num>
      1: cainophobi... -1.446759  4.967859  24.184908
      2: lax_mosasa... -3.082537  8.358510  14.665363
      3: cainophobi... -4.970583  2.671470 220.710724
      4: cainophobi...  8.596596  1.126222   4.052714
      5: cainophobi...  6.643052  7.162193  55.396287
     ---
    508: cainophobi...  4.197123  8.353770  50.939042
    509: cainophobi... -2.249488 14.485438  22.047853
    510: lax_mosasa... -1.980607 12.993052  17.290090
    511: cainophobi... -1.163884 10.543580  20.131560
    512: lax_mosasa...  8.501033  6.753192  28.685855
                                         keys
                                       <list>
      1: 1895409c-a3dd-47a5-b6ed-434f17a57d76
      2: 72a53e0a-ad60-45f5-ae0d-393180c86b75
      3: 79ab329d-2af7-4199-82e2-06cf7dfa5aad
      4: a7f63f9e-20c7-45e7-a44a-35ebd031c5d0
      5: b4c47818-7ed1-436d-9d60-ab7c9d65d6d7
     ---
    508: 4e3c5d1a-15c3-4bba-bda1-2f34f231302e
    509: 51a867c6-f47d-4dea-9800-6f7d79bd93cd
    510: 7a0953e8-1539-4b74-8fbf-e88964031eb8
    511: 16190303-66aa-4343-a440-0676453eb45c
    512: 34e11e35-16bd-4e17-80e9-3e17e61fae2b

To terminate the optimization, the following command is used.

``` r
rush$stop_workers(type = "terminate")
```

The workers are terminated.

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat      state
              <char> <int>        <char>    <lgcl>     <char>
    1: lax_mosasa...  9718 runnervmjd...     FALSE terminated
    2: cainophobi...  9721 runnervmjd...     FALSE terminated

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
```

    [1] "green_goose"      "contusioned_oryx"

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat      state
              <char> <int>        <char>    <lgcl>     <char>
    1: green_goos...  9794 runnervmjd...     FALSE terminated
    2: contusione...  9797 runnervmjd...     FALSE terminated

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

    Warning:
    ✖ $start_remote_workers() is deprecated and will be removed in the future.
    → Class: Mlr3WarningDeprecated

``` r
rush$worker_info
```

           worker_id   pid      hostname heartbeat   state
              <char> <int>        <char>    <lgcl>  <char>
    1: bellicose_...  9982 runnervmjd...     FALSE running
    2: unpretenti...  9984 runnervmjd...     FALSE running

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

    [1] "expert_americancreamdraft" "phantasmagorial_morayeel" 

A segmentation fault also terminates the associated `mirai` daemon.
Therefore, it is necessary to restart the daemon before restarting the
workers.

``` r
daemons(2)
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
