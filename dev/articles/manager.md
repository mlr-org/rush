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
    1: commonplac...  8908 runnervm7b...     FALSE running
    2: defiant_ch...  8910 runnervm7b...     FALSE running

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
    1: defiant_ch...  8910 runnervm7b...     FALSE    running
    2: commonplac...  8908 runnervm7b...     FALSE terminated

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

            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>
     1: southbound... -3.66963747  5.23973364  71.2664464 0ee44e4a-9...
     2: southbound... -1.47235420  2.51802664  48.2189946 2b17dfec-2...
     3: southbound...  4.74168784  2.11775981  10.8586735 b20581af-1...
     4: southbound...  5.03444682  6.20842822  37.5094232 14da53c5-7...
     5: southbound...  1.21898791 10.05273721  46.9587962 42fbad9d-8...
     6: southbound...  1.05097474 14.97996810 125.2287848 c10aee0a-5...
     7: southbound...  7.84454525  3.66510965  14.9327123 7b0289d7-1...
     8: southbound...  1.56289013  3.29713858  10.3578699 26270e7f-d...
     9: southbound...  7.29900811  6.68313214  44.4087780 9ec7402a-9...
    10: southbound...  9.26346993 11.38094566  82.2197531 f3a2b1c0-b...
    11: southbound...  7.15748742 12.53983596 144.1498474 a2cbac82-3...
    12: southbound...  6.70339580 13.02507167 160.1123442 fbe1f977-b...
    13: southbound...  2.25977001  8.17052648  29.9807675 6ab8df0e-e...
    14: southbound...  2.62097519 13.60741977 120.2925774 c1fdf1de-3...
    15: southbound... -3.48902484 14.69963175   3.4493253 3345b64b-e...
    16: southbound... -2.48601733 10.76799276   2.3885993 37cd25fa-8...
    17: southbound...  2.21374267  3.12243749   4.2431543 84a3c6ef-c...
    18: southbound...  3.23559162  1.31368691   1.2308625 5e39a892-6...
    19: southbound... -0.72610929  5.54426861  20.0007636 84058f50-6...
    20: southbound...  4.62728121 12.73507633 137.6333335 acb2219b-6...
    21: southbound...  3.71925428  0.32489968   4.3358735 6ffd8ce2-8...
    22: southbound... -3.08842669  3.59076099  73.6308564 f681ccd2-c...
    23: southbound...  1.34177584  9.95023244  46.4393432 6fe31ece-a...
    24: southbound...  7.03739759  4.84059872  30.2703521 be5e9754-9...
    25: southbound...  7.43571410 11.78740179 123.7120585 c28ec17a-7...
    26: southbound...  5.37646971  7.12431718  51.2845982 13814fdf-5...
    27: southbound...  6.81948488  9.99236874  96.3667831 e9f5a782-d...
    28: southbound...  6.83387333  3.14044387  22.1178010 0470aba6-2...
    29: southbound...  5.85334133  5.08163730  34.5010372 4cd73c3e-6...
    30: southbound...  1.13220569 10.66385335  53.7703719 228f4985-9...
    31: southbound...  5.60359745  0.53535458  17.8320470 3d4e8d4b-4...
    32: southbound...  6.43756594  3.93584882  27.4846829 f91d4403-a...
    33: southbound...  7.22704160  1.59468926  15.7554582 500984cc-3...
    34: southbound...  5.41393264  9.61388078  87.4972710 7ce4e3b1-0...
    35: southbound... -2.39426578  1.21675460  90.0875891 6cd5afb4-1...
    36: southbound...  0.09531217  1.97598780  34.5624691 1c5526de-c...
    37: southbound...  5.44529396  1.41074289  16.4849861 882c3145-f...
    38: southbound...  2.87160174 13.90900307 131.0258493 bf2988c9-d...
    39: southbound...  5.25925132  8.02430817  61.5254907 831bba0a-2...
    40: southbound...  6.19320116 13.53633749 174.2709823 5e9d23ad-f...
    41: offcolour_...  3.81181924 10.37207571  75.7781926 ec82280f-9...
    42: southbound...  9.13179333  9.30075035  50.6760882 ec1bdd5c-3...
    43: offcolour_...  1.76319111 11.40061240  69.0851871 fdb86c29-1...
    44: southbound... -0.22147382  3.30314390  28.7047542 7ae161c6-2...
    45: offcolour_...  8.29542756  2.06802780   6.0426033 479dd600-0...
    46: southbound...  4.31931964  5.90162686  25.3832632 70c2c114-a...
    47: offcolour_...  7.00978585  0.07814679  18.4161546 9b5c3d6e-f...
    48: southbound...  5.13967277  2.16940093  14.8568546 f164887d-5...
    49: offcolour_... -2.72131849  4.80907166  43.2073908 32be6ae6-2...
    50: southbound...  3.80990527  0.38630764   4.4948055 d7294911-6...
    51: offcolour_... -4.94246630 13.96219933  21.5515271 b7eabae6-a...
    52: southbound... -3.39624058 13.18638493   0.7922331 5585a63f-e...
    53: offcolour_...  0.85786825  2.95476439  19.4307865 c3e21c6a-8...
    54: southbound...  0.35933544  5.63950014  19.0267484 7c83fa91-a...
    55: offcolour_... -2.93132914 11.90083321   0.6250988 40a74c2a-6...
    56: southbound...  3.04099655  6.11664556  14.5982284 51a4e1c9-4...
    57: offcolour_...  3.05142330  1.38844680   1.3545123 ed534309-c...
    58: southbound...  9.60602205 10.94985152  69.7397113 4f7dcc9b-7...
    59: offcolour_...  1.44627939  7.99273236  27.3878441 63617825-c...
    60: southbound...  8.22974809  2.72244323   7.6231788 9411c8a5-8...
    61: offcolour_... -0.30676116  4.61133118  22.7223669 9149d11a-a...
    62: southbound...  9.71816152  5.95468498  11.1836002 74c072ac-8...
    63: offcolour_... -0.29288722  2.91734925  31.8659245 04c96b7f-d...
    64: southbound...  9.25970322  3.35891767   1.5680865 908a5521-9...
    65: offcolour_... -3.14252074  5.79403291  42.4297429 aee99607-e...
    66: southbound...  7.75780793  9.00131373  68.2793711 1dca1ebb-7...
    67: offcolour_... -1.41937729  4.43292020  28.1466342 e0ea9b5f-c...
    68: southbound...  8.60551056  6.43112271  24.2421044 b21c8567-3...
    69: offcolour_...  0.54975581  5.05027611  18.2002132 cbbdf1ea-e...
    70: southbound... -2.57041497  6.25970087  23.8691306 e5888d0d-d...
    71: offcolour_...  8.92893953  4.42650454   7.0204847 c8ec8a83-4...
    72: southbound...  0.32794104  1.03900098  38.9192258 a722037d-7...
    73: offcolour_...  8.92666167  1.09010723   2.5582558 b2a3ff9f-d...
    74: southbound...  7.80798246  5.39566450  26.0185576 91468338-1...
    75: offcolour_... -1.40429943  5.87402257  18.4334865 e1167a5c-e...
    76: southbound...  6.82650397  0.25570265  19.0288940 032fec3f-a...
            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>

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
    1: southbound...  8908 runnervm7b...     FALSE terminated
    2: offcolour_...  8910 runnervm7b...     FALSE terminated

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

    [1] "nonspheral_kingsnake" "teensy_prawn"        

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
    1: proposed_a...  9160 runnervm7b...     FALSE running
    2: beige_squa...  9162 runnervm7b...     FALSE running

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
    1: proposed_a...  9160 runnervm7b...     FALSE running
    2: beige_squa...  9162 runnervm7b...     FALSE running

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
