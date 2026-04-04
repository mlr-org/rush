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
    1: nonblack_d... 12356 runnervm72...     FALSE running
    2: minimal_da... 12354 runnervm72...     FALSE running

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
    1: minimal_da... 12354 runnervm72...     FALSE    running
    2: nonblack_d... 12356 runnervm72...     FALSE terminated

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
     1: groovy_swe... -1.41870650  9.6084022  12.6438355 fd9f926d-5...
     2: groovy_swe...  5.68048914  5.6547492  38.4041231 b0505c40-5...
     3: groovy_swe...  3.88756289 10.4143220  77.7563460 ea969ef7-9...
     4: groovy_swe...  8.45757660 10.8508639  86.8304572 0c5db3b7-5...
     5: groovy_swe...  0.34657740  9.3753102  34.3301365 7b125b8f-b...
     6: groovy_swe...  4.21377046  7.9078537  45.3568096 a97f50eb-d...
     7: groovy_swe... -4.02856285 13.9291643   4.2690567 fe7ef898-9...
     8: groovy_swe...  8.16067385  2.7874507   8.4753853 1b4f9542-f...
     9: groovy_swe...  5.96716735 14.9564237 211.0483428 da4bfc65-d...
    10: groovy_swe...  3.67904970  4.5039276   8.5676841 0dbf2d0b-f...
    11: groovy_swe...  3.20352836  1.4228716   1.0632336 0849bd6b-d...
    12: groovy_swe...  7.69596341 10.6788952  97.5566679 176c3f85-7...
    13: groovy_swe...  2.36123062 11.0038256  67.8432499 dbe8c817-a...
    14: groovy_swe... -3.18880555 12.0038101   0.5567673 130b34d8-0...
    15: groovy_swe...  8.53555948  0.2146730   6.5503185 9f478013-0...
    16: groovy_swe...  7.09933065  9.9050865  92.1470502 457c0c55-8...
    17: groovy_swe...  1.67242532  5.3921730  11.8906891 774bd342-2...
    18: groovy_swe... -2.16643162  8.2382868   7.9107883 90699dd8-f...
    19: groovy_swe...  7.91538485 13.4246039 151.6996933 080c8cf4-2...
    20: groovy_swe...  7.97511358  4.7347346  19.1507066 298ebe56-9...
    21: groovy_swe... -2.29250014 12.0848827   6.7443931 b15f696f-a...
    22: groovy_swe...  6.79896378 13.5460967 171.9967322 d126a851-7...
    23: groovy_swe...  5.87753393  4.5966636  30.9912219 91c89b2f-e...
    24: groovy_swe... -0.22096847 10.5958635  37.3282161 183b32d6-1...
    25: groovy_swe... -4.01586144  5.1768393  90.2921166 242f663b-7...
    26: groovy_swe...  9.46126397  7.2140212  22.5702250 5ae0cc45-d...
    27: groovy_swe...  7.92767970  3.1314582  11.9490705 72bc4db4-0...
    28: groovy_swe... -3.34096380  4.7928978  64.0512031 1142a4cf-6...
    29: groovy_swe...  2.66669721 11.5505729  80.2453706 8c858088-9...
    30: groovy_swe...  8.84016123  1.4190406   2.3609897 beb01653-0...
    31: groovy_swe...  1.33453484  8.6629114  33.0121181 97a1a491-8...
    32: groovy_swe...  7.04047507  5.3447265  34.1716164 571413d8-0...
    33: optic_mame...  1.73374582  8.4480357  31.6656472 747978c9-0...
    34: groovy_swe... -0.67764741  2.5443581  38.5805241 e6ef7cf5-0...
    35: groovy_swe... -1.34354839  8.9077777  12.4509029 59c67992-c...
    36: optic_mame... -2.90373289  7.8760184  15.3728304 b9bece55-4...
    37: groovy_swe... -1.54381436  5.7788517  19.1758379 9d2c1250-e...
    38: optic_mame... -2.40134498 13.9985506  14.6876833 5c9f3673-3...
    39: groovy_swe...  8.75301607  2.7983809   3.1759483 6bb9388f-a...
    40: optic_mame... -3.45809030  5.7133853  54.6796020 74688560-b...
    41: groovy_swe...  0.48248231 14.6180063 106.0375093 2d127e97-4...
    42: optic_mame... -2.31316034  9.8111098   3.8240929 f55950ed-0...
    43: groovy_swe... -0.54059962 14.5274553  76.4392302 d8822dbb-f...
    44: optic_mame...  4.06107157 14.4376194 167.2636577 09801af7-b...
    45: groovy_swe...  1.98316117  4.7519182   8.1120963 5a2450c5-4...
    46: optic_mame...  5.16644924 11.5694668 121.2080852 7d54dd42-f...
    47: groovy_swe...  8.52706606  4.0290738   8.8857895 30fa4b58-d...
    48: optic_mame... -4.27335762  7.2697536  68.1803864 8a50ad69-c...
    49: groovy_swe...  3.23670216  3.6118251   2.4289007 1462f52c-0...
    50: optic_mame...  4.79272044  2.3472923  11.7860900 b8fb3c7a-a...
    51: groovy_swe...  0.57689901 10.1700853  43.5026800 07154c82-d...
    52: optic_mame... -1.36203976 13.8679302  41.8072518 308dcf2d-8...
    53: groovy_swe...  1.01215853 12.3288642  76.0452229 cd3abf86-5...
    54: optic_mame...  0.95916983  5.9835965  17.4492810 9628fe7f-d...
    55: groovy_swe... -2.04801366 13.3367850  18.0888825 e5a44e48-1...
    56: optic_mame...  6.72495128  6.9045301  51.9184786 05bf4d86-0...
    57: groovy_swe...  3.01738517 10.9898873  74.7078334 1efda89d-b...
    58: optic_mame...  4.37440142 14.8372912 184.4348782 c2db5d9c-0...
    59: groovy_swe... -1.26250408  0.2359979  76.5820020 99fe970f-2...
    60: optic_mame... -3.05747806  8.8066092  11.1061528 0ed86e75-8...
    61: groovy_swe...  4.93239202  3.9156715  18.9753767 0b3b859d-d...
    62: optic_mame...  8.07605598  7.2461921  40.0779522 75479bdf-d...
    63: groovy_swe... -2.46445062 13.0365723   7.9438102 2de2f92e-5...
    64: optic_mame... -1.87318140  1.5268763  69.6717265 28d9ca7b-4...
    65: groovy_swe...  0.06140584  1.7809430  36.5733630 7eadb4e3-e...
    66: optic_mame...  3.18601594  6.3264010  17.1010402 1899c3de-c...
    67: groovy_swe...  2.59967459  8.8786011  39.5106466 a88872f7-f...
    68: optic_mame...  5.81616427 11.2289052 120.8991121 e2693629-f...
    69: groovy_swe...  5.17609404  7.1105826  48.9571949 3fa7f592-e...
    70: optic_mame...  1.56512284  7.8251239  26.0516187 b8fb8f1e-c...
    71: groovy_swe...  4.34674261  7.0454729  37.0668891 ad637d03-5...
    72: optic_mame...  0.12907093  1.7710921  35.7279969 5c7dfe49-3...
    73: groovy_swe...  6.17522282 14.5830258 201.3902599 6eccafd2-5...
    74: optic_mame...  0.52157034  1.5002538  32.0508192 71388b1d-1...
    75: groovy_swe...  5.48028481 13.9900861 181.3394288 a70e24c6-b...
    76: optic_mame...  8.22259570 13.9045428 156.7718864 9c857d8c-d...
    77: groovy_swe... -1.92585065 14.2856872  29.1434291 ea9b7c56-8...
    78: optic_mame... -4.54830147  1.9074301 204.5396373 a789b362-f...
    79: groovy_swe... -0.66225833 11.3428404  35.4835006 ba990c06-1...
    80: optic_mame...  4.88159557 12.5418577 137.7904297 1854f6c8-b...
    81: groovy_swe...  6.19651347  2.3338322  21.0928279 2299864d-4...
    82: optic_mame... -1.27471466  2.9654318  40.6088308 c2b4c158-d...
    83: groovy_swe... -3.86629948  8.1043868  38.5726142 18cac288-c...
    84: optic_mame... -3.86611414  9.7974822  21.1841141 4dc5c16f-6...
    85: groovy_swe... -0.45059016  4.4436399  23.9324636 a01ebabc-d...
    86: optic_mame... -4.70654402  3.9408732 163.9882709 3f6e7008-6...
    87: groovy_swe...  5.45128711  5.0622614  31.6716147 f5f6f6a2-c...
    88: optic_mame... -2.05673691 14.2345356  25.0046945 9b5de42e-9...
    89: groovy_swe... -4.70160940  8.8556489  65.8893208 1672be46-0...
    90: optic_mame...  4.97685259 10.4210452  96.0892398 977959be-c...
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
    1: groovy_swe... 12356 runnervm72...     FALSE terminated
    2: optic_mame... 12354 runnervm72...     FALSE terminated

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

    [1] "tinny_gerenuk"         "incendiary_hellbender"

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
    1: houndy_dee... 12646 runnervm72...     FALSE running
    2: unsatisfie... 12648 runnervm72...     FALSE running

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
    1: houndy_dee... 12646 runnervm72...     FALSE running
    2: unsatisfie... 12648 runnervm72...     FALSE running

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
