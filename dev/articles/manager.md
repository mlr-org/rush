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
    1: feeblemind...  9662 runnervm1l...     FALSE running
    2: cultish_wa...  9660 runnervm1l...     FALSE running

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
    1: feeblemind...  9662 runnervm1l...     FALSE    running
    2: cultish_wa...  9660 runnervm1l...     FALSE terminated

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

            worker_id          x1         x2           y          keys
               <char>       <num>      <num>       <num>        <char>
     1: epidermoid... -3.21715215 14.3902981   4.1616694 9068ec04-6...
     2: epidermoid... -3.73875730  7.6156878  39.7655550 a0dbd1da-b...
     3: epidermoid...  3.92935826 11.0484531  89.8583648 2fa1f3a9-8...
     4: epidermoid... -4.81819938  0.8584562 260.9376589 44e9fccc-8...
     5: epidermoid...  5.42993461  5.8461691  38.2093897 19318e50-c...
     6: epidermoid...  9.74920973 13.0349568 106.4270570 675208a5-6...
     7: epidermoid...  1.68009413  8.4811915  31.9014231 5a0d0968-c...
     8: epidermoid...  6.46310967  8.1006444  68.3174857 35a3e57b-5...
     9: epidermoid...  1.50121808  6.0154760  15.1348701 ef321445-4...
    10: epidermoid...  3.26037808  1.4132620   1.0598757 a082244f-7...
    11: epidermoid...  5.61554081 14.2947658 190.6847463 e81ab9b2-e...
    12: epidermoid...  6.31483565  7.2108301  56.9256552 27bf14f7-1...
    13: epidermoid...  4.37209028 11.2866437 102.3585892 69dd7388-b...
    14: epidermoid...  1.73582221 12.4313366  85.9460384 ab405882-6...
    15: epidermoid...  3.20132588  2.0423095   0.4498203 7d89b046-6...
    16: epidermoid...  7.96612816  4.1607570  15.9018697 94e0fef1-a...
    17: epidermoid...  6.54252912  8.2916677  70.7576626 1b9570fa-9...
    18: epidermoid... -4.75513837  6.9177940 102.0197365 2662be4e-1...
    19: epidermoid...  4.19204135  2.5382659   6.1094548 dcc39eba-6...
    20: epidermoid...  5.48606043 11.9217347 132.5953556 6d81d042-b...
    21: epidermoid... -3.23541916 10.8270793   3.2442248 af3601e6-8...
    22: epidermoid...  4.97085941  2.2457813  13.3856850 bd3e9392-6...
    23: epidermoid...  5.32566821  1.2673408  15.5328179 f10598f3-5...
    24: epidermoid...  5.30045237  2.2250024  16.3908171 1e510e45-c...
    25: epidermoid...  3.86403155  9.9987132  70.3598458 2ea06202-e...
    26: epidermoid...  3.44394833 12.5082648 110.1875329 25e9b41e-c...
    27: epidermoid... -0.99278963 10.1381499  21.1547023 5172ee01-e...
    28: epidermoid...  8.09033743  7.4592244  42.3237264 02b19f9c-4...
    29: epidermoid...  0.63755606  6.3856652  19.5325223 774d20f2-1...
    30: epidermoid...  4.00247436 13.2625288 137.4481805 d4e9ffa5-0...
    31: epidermoid... -1.21529599  1.3641864  59.0507331 039264c2-1...
    32: epidermoid...  2.93665547 11.1822829  77.0220012 7491f222-7...
    33: epidermoid...  0.28527886  2.6807953  27.4835781 aa8bee47-7...
    34: epidermoid... -3.45080201 13.7284569   1.3404785 57347268-2...
    35: epidermoid...  6.86733104 14.9931306 209.2914233 002cbe28-b...
    36: epidermoid...  4.61655644 14.4826136 180.0848133 c5ad3fcb-c...
    37: epidermoid...  6.94309535  0.7327462  17.7837192 44a9432c-7...
    38: epidermoid...  4.83612065  3.4031468  15.5060351 c75b22c2-3...
    39: epidermoid...  2.59257195  0.9194675   5.1310350 ead8c51d-5...
    40: pestersome...  9.89986971  7.9807093  27.2250681 75fb0536-f...
    41: epidermoid...  3.57895983  5.2501728  12.1360089 b27d173c-4...
    42: pestersome...  6.46044154 11.2222327 121.7149530 25ab87de-5...
    43: epidermoid...  9.34704144 10.5533942  66.7383631 cc6a901b-e...
    44: pestersome...  4.68249469  3.6781205  14.9941391 6f22cf50-a...
    45: epidermoid...  6.76700047  6.2480844  44.5349915 4435e3a2-6...
    46: pestersome...  8.40822212  6.0879464  23.7554389 598871de-5...
    47: epidermoid... -1.30041734 12.4506518  29.8911928 e0742a86-c...
    48: pestersome...  4.27293376 10.5908766  87.5065787 76876876-7...
    49: epidermoid... -3.21490982  4.6271818  61.6497906 aa29a8dc-c...
    50: pestersome...  5.00527837  8.6832005  67.7236037 b680e1c6-e...
    51: epidermoid... -2.37502459  2.5139888  66.9984963 e986e70d-9...
    52: pestersome...  0.98645650  0.7909500  29.4704479 113e7fc6-e...
    53: epidermoid... -3.42754423 10.8475950   5.3041770 46f65164-a...
    54: pestersome...  1.23447520  5.2916753  14.2914719 bf762765-f...
    55: epidermoid... -3.21596031 14.8525869   6.1755468 74641755-5...
    56: pestersome... -0.37167292  9.7196244  28.6201016 ea187039-e...
    57: epidermoid...  7.82880015 11.9218369 119.7376159 5942e566-4...
    58: pestersome...  8.60183611  4.6469985  11.1909757 a4fbc12a-6...
    59: epidermoid... -4.05677037  6.9439966  62.4941829 c9ca3bf3-5...
    60: pestersome...  0.77880226 12.7362919  79.2039065 76b76ab4-1...
    61: epidermoid...  2.51198009  1.7286952   3.4239227 42ac0fb3-8...
    62: pestersome...  3.62990091 12.9760629 123.6462813 e2284ee3-6...
    63: epidermoid...  1.38305397  9.8908510  45.9554830 37f78c2d-8...
    64: pestersome... -2.58549572  3.9176196  51.7009643 666522ad-2...
    65: epidermoid... -1.90751992 14.8943813  35.8625026 2f44f0cc-1...
    66: pestersome... -0.07033515  9.7197590  32.5901048 fa7c783d-8...
    67: epidermoid...  8.77111352  7.8626874  36.9971805 8201ab60-1...
    68: pestersome...  3.01550507 10.8248997  71.8684241 0573f8c9-5...
    69: epidermoid...  1.31558673  8.6183991  32.5718533 9585a9d2-4...
    70: pestersome... -1.15884539 14.2980997  53.2862697 7680fdac-6...
    71: epidermoid...  5.82587978 11.1285266 118.9370486 c2e89b54-7...
    72: pestersome...  1.39748261 13.6001203 103.2788728 b9cf57f1-1...
    73: epidermoid... -0.88561756 11.2408371  29.9893102 811a5028-2...
    74: pestersome...  8.95033304  8.3307292  40.2321902 5a31def4-8...
    75: epidermoid... -0.87779577  2.0090048  46.2479441 9091c935-d...
    76: pestersome... -0.96747374  1.9560078  47.9915717 0b138228-2...
    77: pestersome... -4.64311329 12.5477208  22.4908155 42b7ba7e-0...
    78: epidermoid...  0.73517854  3.0474433  20.5530316 e0329cfc-e...
    79: pestersome...  1.88719319  8.1363475  28.9130572 fae4120a-f...
    80: epidermoid... -0.58035429  2.1649189  41.0915909 5b9bd78f-4...
    81: epidermoid...  3.64730936  5.1226918  11.8977504 cb83644a-d...
    82: pestersome...  3.35181305 14.0141244 142.1563996 50540083-a...
    83: pestersome...  2.46428058  6.0238642  12.5118601 5f85877b-c...
    84: epidermoid...  1.56268211  4.6813251  10.8054288 c40afde7-c...
    85: pestersome...  6.77944275  4.6690435  30.8443045 5dfdb40c-2...
    86: epidermoid... -0.61390923  6.6978631  17.9563017 b594c80b-6...
    87: pestersome... -3.97450179 12.8032579   5.9835096 0980d0eb-e...
    88: epidermoid... -2.66924164 12.2127818   2.5395186 76a1c454-1...
    89: pestersome...  6.32960832 10.5122199 108.1485961 62a054a4-d...
    90: epidermoid... -4.03286678  7.0036660  60.4545728 c0a483d9-c...
    91: pestersome... -2.01232321  2.1047415  63.9779241 3bf40856-a...
    92: epidermoid...  3.60299421  5.0369755  10.9766878 38aecce0-3...
    93: pestersome...  0.91463108  7.3152475  22.9489019 87f7e691-a...
    94: epidermoid... -3.49650262  4.4163064  77.1725423 3dffcd8b-9...
    95: pestersome... -2.93395575 13.6398720   4.0574257 cf6d5358-d...
            worker_id          x1         x2           y          keys
               <char>       <num>      <num>       <num>        <char>

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
    1: epidermoid...  9660 runnervm1l...     FALSE terminated
    2: pestersome...  9662 runnervm1l...     FALSE terminated

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

    [1] "bleakish_zebrafish"             "nonrationalistical_mockingbird"

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
    1: authorized...  9910 runnervm1l...     FALSE running
    2: misanthrop...  9912 runnervm1l...     FALSE running

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
    1: authorized...  9910 runnervm1l...     FALSE running
    2: misanthrop...  9912 runnervm1l...     FALSE running

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
