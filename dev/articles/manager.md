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
    1: limy_daddy...  9361 runnervm3j...     FALSE running
    2: apprentice...  9363 runnervm3j...     FALSE running

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
    1: apprentice...  9363 runnervm3j...     FALSE    running
    2: limy_daddy...  9361 runnervm3j...     FALSE terminated

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

            worker_id         x1           x2          y          keys
               <char>      <num>        <num>      <num>        <char>
     1: uncrystall...  2.9437920  8.361244043  35.713652 a9f956c0-a...
     2: tsunamic_s...  8.3517019  3.520182540   8.661451 59892627-b...
     3: tsunamic_s...  7.5878400  6.684445172  40.860094 e758068f-2...
     4: tsunamic_s...  6.3911191  5.763625925  41.249585 60abee31-3...
     5: tsunamic_s... -0.8223739  4.955784006  22.489789 fa8263a6-2...
     6: tsunamic_s...  4.4273186  6.371810517  31.172074 edd7ba56-1...
     7: tsunamic_s...  3.0671244  9.384346455  50.134830 ec98dce2-1...
     8: tsunamic_s...  4.3480553  1.761987220   6.636025 edc4047a-3...
     9: tsunamic_s...  5.1755244 10.107025038  93.211429 29518959-7...
    10: uncrystall...  7.1281196  2.064328377  17.088068 915456a3-7...
    11: tsunamic_s...  2.0359271  0.900694475  11.426686 f25df382-2...
    12: uncrystall...  3.3089237  7.138216188  25.433037 a771c303-8...
    13: tsunamic_s... -3.6836596  7.893869093  34.513479 71fc7da4-c...
    14: uncrystall...  3.7851709  0.005940737   5.633580 76e0fe9e-8...
    15: tsunamic_s...  2.1641353  4.546586294   6.551815 18c6fd28-d...
    16: uncrystall...  5.3276376 14.102657637 182.342268 b6ed54ac-e...
    17: tsunamic_s...  1.1858271 12.422589562  79.674085 ceda54ef-9...
    18: uncrystall... -3.7602643 10.853812962  10.924150 83bc682c-1...
    19: tsunamic_s...  2.3275267  8.322233920  31.782127 77ba6023-b...
    20: uncrystall...  6.8916848  5.318207580  35.109441 ac015eb4-d...
    21: tsunamic_s... -0.5995287  4.490929602  24.226030 fc6b5bdd-0...
    22: uncrystall... -3.8662555  8.890512883  29.786911 e58b3f1e-c...
    23: tsunamic_s...  5.7522513  1.770395834  18.703878 415484da-c...
    24: uncrystall...  9.7159231  6.241316564  13.120534 715f72ab-a...
    25: tsunamic_s...  5.7668075 13.422028476 169.739002 d0f9ec8b-3...
    26: uncrystall... -3.1844416  5.312510306  50.330864 642bc7e1-4...
    27: tsunamic_s...  9.3010123  9.670990053  53.738127 9c299ae4-f...
    28: uncrystall...  2.6062936 12.410739775  95.467954 83c0b322-b...
    29: tsunamic_s... -1.2099705 13.299800254  40.273626 cdb5ec78-1...
    30: uncrystall...  7.2038972  9.946105425  91.628564 81cacad5-a...
    31: tsunamic_s...  7.6888591  5.453923630  28.012610 edd4ad5e-2...
    32: uncrystall... -3.9831620  8.056385056  43.704015 7f1b75ab-8...
    33: tsunamic_s...  6.6977960 11.134939912 118.779264 a0777886-e...
    34: uncrystall...  0.4929778  3.080968271  23.149578 e46dbce1-e...
    35: tsunamic_s...  9.0086720  8.413242960  40.490892 9126236f-8...
    36: tsunamic_s...  0.2251298  4.080052708  21.819024 fbc4ed1b-f...
    37: uncrystall...  9.1185841  8.345694435  38.260525 d61d7aae-7...
    38: uncrystall...  2.2179443  0.182465484  12.755041 8a35e017-e...
    39: tsunamic_s...  9.7569148  7.888713499  27.129877 97833b6e-6...
    40: tsunamic_s... -2.9324423 14.669527037   8.967995 a2c8cf5c-d...
    41: uncrystall... -4.1149720  3.380860020 133.552968 d602aead-a...
    42: tsunamic_s...  0.5936069 10.187146760  43.830736 7baae072-c...
    43: uncrystall... -1.9557432  0.588478157  87.724150 a860586c-e...
    44: uncrystall...  9.8766688  8.676362449  34.929869 50de8358-9...
    45: tsunamic_s...  7.6213878 11.704767303 118.939340 97e7e3ff-9...
    46: uncrystall...  1.1779548  1.106266279  23.904405 339a696e-c...
    47: tsunamic_s...  1.8811470  3.639554189   7.098684 35e22e86-9...
    48: tsunamic_s... -4.1126383  8.143573593  47.967382 219f6faf-8...
    49: uncrystall...  5.9308534  2.376867615  20.630361 6c7ea86c-7...
    50: tsunamic_s...  6.6172264 10.341056412 104.006174 b14e8d00-5...
    51: uncrystall...  4.0727923  6.543340317  28.107817 19cba2d3-4...
    52: uncrystall...  2.4659436 14.808183105 145.245414 a9807128-e...
    53: tsunamic_s... -3.9331782  0.276067522 198.755747 412987b0-2...
    54: tsunamic_s...  0.5296601  3.013622704  23.037244 0245cdd1-4...
    55: uncrystall...  5.5572680  3.538484168  22.910252 c1d899e2-e...
    56: uncrystall...  5.6410329  8.794605735  76.392259 354af38f-6...
    57: tsunamic_s...  3.6399530  0.374779894   3.948684 00416c17-9...
    58: tsunamic_s...  2.1063491  0.544423965  12.262846 5f45a76b-d...
    59: uncrystall...  6.3697985  4.602413362  31.806931 3e1f3241-f...
    60: tsunamic_s...  9.7509154  8.439752560  33.119975 59fb5fe5-5...
    61: uncrystall...  8.2560082  0.519493452   7.556376 747992f0-9...
    62: tsunamic_s... -0.5831516 14.195511251  70.193637 5df75a82-e...
    63: uncrystall...  0.1496746 13.251269993  75.543794 51ce82e3-8...
            worker_id         x1           x2          y          keys
               <char>      <num>        <num>      <num>        <char>

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
    1: tsunamic_s...  9363 runnervm3j...     FALSE terminated
    2: uncrystall...  9361 runnervm3j...     FALSE terminated

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

    [1] "menial_laughingthrush" "pebbly_teledu"        

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
    1: invigorati...  9617 runnervm3j...     FALSE running
    2: foil_cockr...  9615 runnervm3j...     FALSE running

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
    1: invigorati...  9617 runnervm3j...     FALSE running
    2: foil_cockr...  9615 runnervm3j...     FALSE running

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
