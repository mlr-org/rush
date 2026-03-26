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
    1: kainolopho... 27818 runnervmrg...     FALSE running
    2: tourmaline... 27816 runnervmrg...     FALSE running

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
    1: kainolopho... 27818 runnervmrg...     FALSE    running
    2: tourmaline... 27816 runnervmrg...     FALSE terminated

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
     1: dutiable_n... -1.31759502  9.8548460  14.7571685 bb76ba2d-8...
     2: dutiable_n... -0.97148477 14.3755647  60.4065446 ed22f40e-b...
     3: dutiable_n... -0.54341114 10.1816801  28.9685836 c063dd24-9...
     4: dutiable_n...  0.69944813 13.9199725  97.8080206 f7b9a550-6...
     5: dutiable_n...  3.72861538  7.1186655  29.6408064 6cf01c0a-3...
     6: dutiable_n...  1.35801875  3.8397123  12.0839856 eb7a2784-7...
     7: dutiable_n... -1.96572361  1.7721681  68.0154348 eddb2ace-e...
     8: dutiable_n... -0.91845292 14.6476630  65.9118386 3437d521-c...
     9: dutiable_n... -2.62879597 11.1895054   1.6456995 63e044cf-c...
    10: dutiable_n...  0.70614149  8.3096561  28.6568011 75a99baa-b...
    11: dutiable_n...  8.78444999  9.2273384  54.7104336 2bf4e53d-e...
    12: dutiable_n...  3.47149565  6.3925486  19.9319785 3dd00322-3...
    13: dutiable_n...  6.91477033  8.2261078  67.5153729 c23a77a9-1...
    14: dutiable_n...  9.08489745 11.7944879  92.9394694 c927bf57-b...
    15: dutiable_n...  1.20853900  4.3234358  13.4062414 58ac02d8-4...
    16: dutiable_n...  3.76459918  1.6149519   2.2521814 7ae20488-a...
    17: dutiable_n...  4.34260924 10.9197252  94.7958769 a6a0289e-a...
    18: dutiable_n...  0.84268977  1.9642136  24.1534952 a1602072-6...
    19: dutiable_n...  8.48718178 10.5592330  81.0829389 11100643-5...
    20: dutiable_n...  0.01722346  2.9424368  28.7827372 c7bce771-d...
    21: dutiable_n...  9.04433055  2.7225671   1.3867148 c3f00ee1-0...
    22: dutiable_n...  7.57912914  4.7009840  23.7801805 f8b0a4d6-5...
    23: dutiable_n...  0.61939765  4.7930499  17.8915958 fdf6a2d0-e...
    24: dutiable_n... -2.96042693  0.7218968 124.2529926 51d6ff3a-b...
    25: dutiable_n...  7.29040281 10.0819481  92.9013785 2366444f-f...
    26: dutiable_n... -3.36981199  5.8415475  49.4880449 41ae1211-6...
    27: dutiable_n... -0.44646730 14.0502459  72.1543262 cbdb64c2-2...
    28: dutiable_n...  3.54517810  9.1810053  53.0050608 8c0c4625-e...
    29: dutiable_n... -4.47417293 14.1005283  10.3146628 9a9778a6-8...
    30: dutiable_n... -4.59013297  7.6341993  79.2723629 5bdbc271-1...
    31: dutiable_n...  9.39498301  5.5371322   9.9326455 f82dd7b3-c...
    32: dutiable_n... -4.30724754 14.1573525   7.4133245 b0258107-0...
    33: dutiable_n...  0.00728328 10.9529806  44.2487680 91b78c21-1...
    34: dutiable_n...  4.55957605 11.6638416 113.2919802 df47341a-0...
    35: dutiable_n...  3.50665723  7.7095519  33.5438539 85f7515b-7...
    36: mythoclast...  4.86131102  9.9496225  85.9655738 ab49bbc3-6...
    37: dutiable_n... -2.78088816 13.9615401   7.4500949 c0226098-1...
    38: mythoclast...  0.25784065  0.6497608  43.7719654 572bef75-b...
    39: dutiable_n...  7.58398239  0.9376871  12.7395226 248246dc-8...
    40: mythoclast... -1.35308015  7.4292787  12.9970603 719d5946-f...
    41: dutiable_n...  2.94082367  3.6338903   2.0238360 9f446461-1...
    42: mythoclast...  3.43859131  5.8363651  15.1186772 d0d97dfa-9...
    43: dutiable_n...  5.38158728 14.4654601 192.5581818 736754d9-8...
    44: mythoclast... -2.60871263 14.1355016  11.3668949 dabc23ed-4...
    45: dutiable_n...  1.55652330  5.5521009  13.0830790 1ffcf269-9...
    46: mythoclast...  5.74799928 14.9073415 208.3512083 76553b7c-5...
    47: dutiable_n... -0.65710882  3.2230803  32.6455139 38a27ae3-a...
    48: mythoclast...  4.57014466  5.5875328  25.9690545 fd830804-5...
    49: dutiable_n...  7.63503015 11.6189172 116.9392242 4cb4f562-f...
    50: mythoclast...  6.17317914  4.2496771  29.4767513 83347bd5-2...
    51: dutiable_n... -4.31732328  9.1057107  44.4156713 b9b4fed7-b...
    52: mythoclast... -3.92670699 12.2198893   7.2950531 cde898cc-2...
    53: dutiable_n...  2.87639794  1.0550091   2.7953452 422afca3-b...
    54: mythoclast... -1.20724320  9.7417473  16.0781771 e813ffc5-c...
    55: dutiable_n... -3.36245385 12.8405434   0.6319408 ea39705e-b...
    56: mythoclast...  0.22460228  1.9967345  32.7003519 4340f5be-7...
    57: dutiable_n... -1.19834967 11.9184436  28.1301189 8506174a-a...
    58: mythoclast...  7.47348198  0.7348467  13.9095544 d3f83871-5...
    59: dutiable_n...  9.61123207  1.6494005   1.5392106 d70cde5f-b...
    60: mythoclast... -2.95100263  6.4256835  29.6883084 66eec13e-d...
    61: dutiable_n... -3.14133726 11.8630777   0.5670624 45a7177c-2...
    62: mythoclast... -0.11098007 13.0200472  66.3536209 0a90a468-3...
    63: dutiable_n... -4.15757662  1.4708473 183.9434967 488423e5-d...
    64: mythoclast...  4.96594406 11.3470379 113.7091773 db3f164d-4...
    65: dutiable_n... -3.34484201  8.0634751  22.7355607 45984934-b...
    66: mythoclast... -0.19976622  6.9410826  19.7930665 5f7cc5c0-1...
    67: dutiable_n... -0.81161339  7.4046565  16.6101873 77d01f1b-3...
    68: dutiable_n... -3.31545254 12.9678437   0.6161466 ce5e84e5-b...
    69: mythoclast...  4.91796811  2.6261302  13.7258548 ec1966a7-0...
    70: dutiable_n...  0.30602629  2.3292535  29.3690488 639ed6a6-c...
    71: mythoclast...  7.62659546 11.3278202 111.2051789 7fcd6a29-f...
    72: mythoclast...  1.66384661  9.5538278  43.2635281 8e57572a-9...
    73: dutiable_n...  0.24914914  3.4196813  24.1096320 d3bb309b-8...
    74: dutiable_n...  9.62109840  5.6265412   9.4684677 65a5a6dd-3...
    75: mythoclast...  7.89776207  1.5331506   9.5817738 2b17fd4d-4...
    76: mythoclast...  0.83347925  8.2648973  28.7172888 e5ac9795-c...
    77: dutiable_n...  8.73554995  0.3129263   5.2860616 3764cbbc-f...
    78: mythoclast...  6.35821689  2.4205050  21.3106114 d4e96bba-c...
    79: dutiable_n...  6.52537397  3.1476924  23.4525527 49410cb8-d...
    80: mythoclast...  6.67901749  5.1816725  35.2526774 7ad08918-2...
    81: dutiable_n... -3.56418538  3.5227569  97.1044196 d1ad89bc-1...
    82: mythoclast... -0.23330184  3.6056945  27.0295548 d64ce7b0-b...
    83: dutiable_n... -3.54986239 12.6667939   1.5603031 8a75959c-c...
    84: mythoclast... -4.09643013 11.2595232  16.2033681 2bbf4a40-9...
    85: mythoclast...  9.38937909  1.4635352   1.3677692 da87defe-6...
    86: dutiable_n...  0.01252521  7.8020224  22.9208126 cfb8b415-3...
    87: mythoclast... -0.89889816 14.4740429  64.1270328 b9cb6291-7...
    88: dutiable_n... -2.64046852  3.8780757  53.7798011 cf0ae2ee-d...
    89: mythoclast...  6.29294682  8.2861651  71.2379809 86acc78f-0...
    90: dutiable_n...  9.68869697  4.2402862   3.0824937 96601a65-5...
    91: mythoclast... -3.16033451  1.0892973 126.5302019 1b2ca9cc-f...
    92: dutiable_n... -4.79471862  1.4335978 240.8365978 e4539aa2-f...
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
    1: mythoclast... 27818 runnervmrg...     FALSE terminated
    2: dutiable_n... 27816 runnervmrg...     FALSE terminated

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

    [1] "preliterate_crocodile" "unmystic_pelican"     

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
    1: forgetful_... 28106 runnervmrg...     FALSE running
    2: confiscabl... 28108 runnervmrg...     FALSE running

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
    1: forgetful_... 28106 runnervmrg...     FALSE running
    2: confiscabl... 28108 runnervmrg...     FALSE running

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
