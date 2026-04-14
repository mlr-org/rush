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
    1: handsewn_h...  9127 runnervm35...     FALSE running
    2: incorporat...  9125 runnervm35...     FALSE running

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
    1: incorporat...  9125 runnervm35...     FALSE    running
    2: handsewn_h...  9127 runnervm35...     FALSE terminated

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

            worker_id            x1         x2          y          keys
               <char>         <num>      <num>      <num>        <char>
     1: average_bl... -0.5558789569 14.3945769  73.956540 0eddabc0-d...
     2: average_bl...  4.5036334700  7.1334959  40.284234 daa2e8e5-7...
     3: average_bl...  8.1863291417  0.8353949   7.496170 77a7cd92-7...
     4: average_bl...  4.9167880236 14.2485649 179.673950 b9fed78c-7...
     5: average_bl... -1.2035267556  5.3560131  20.991517 1691d761-9...
     6: average_bl...  2.4399289611  5.6583449  10.353203 36e43405-0...
     7: average_bl...  0.7732368006  6.4977401  19.598070 2ea0a1b1-0...
     8: average_bl...  4.8421578766  9.2729714  74.454305 ad9eac19-2...
     9: average_bl... -4.6770712635  6.1212275 112.652454 80d4d4b5-0...
    10: average_bl...  9.1597735487  6.1248335  15.665884 409ec5f9-4...
    11: average_bl... -3.8068863207  1.4837799 157.379942 3bbac8be-5...
    12: average_bl...  6.6541841985  5.2141521  35.632485 316771a3-f...
    13: average_bl...  5.3321680355  6.5739989  44.601861 93d94e49-9...
    14: average_bl...  4.8323385779  2.1859055  11.888884 c9a3a71a-a...
    15: average_bl...  8.2630931397  3.3184741   8.899680 ac7c81d5-4...
    16: average_bl...  8.5369465013  4.0092809   8.698465 d31b724e-e...
    17: average_bl...  6.2629772508 14.5875791 201.530870 4fafac11-9...
    18: average_bl...  7.0068712631 13.8533429 177.538257 a24e3940-2...
    19: average_bl... -2.8628533952  3.9596381  59.375512 ea5142d9-e...
    20: average_bl...  8.2905084499 11.3610918  99.578175 e7df1f0f-c...
    21: average_bl... -3.8627251339  7.2207823  49.771763 0f957a27-9...
    22: average_bl... -2.0408167538 13.0300837  16.174554 f5b85b07-5...
    23: average_bl...  6.3546580546  9.2668496  86.227099 c19e6f01-e...
    24: average_bl... -4.9058443972  6.9968126 110.256479 1d4ec619-7...
    25: average_bl... -3.0729365882  0.8152651 128.005369 f3c57bd5-0...
    26: average_bl...  2.4055708014 10.4607097  59.761183 ec680c40-b...
    27: average_bl...  6.8932167927  6.8825852  50.532465 1b989744-b...
    28: average_bl... -0.1529445038  6.0043383  19.548639 de65b844-5...
    29: average_bl...  8.2509018844  6.0514638  25.548167 39ca9ccf-c...
    30: average_bl...  1.8020350649  2.0251237  10.129109 6dcef341-6...
    31: average_bl...  3.8662435811  4.4163377   9.772950 0e28ed42-1...
    32: average_bl...  2.8226041647  1.4940781   1.969785 6c1ff1b1-7...
    33: average_bl...  3.4104448532  8.3566714  40.206361 83ab7c2e-c...
    34: average_bl... -0.3480272082 13.3177021  64.564001 f8b383e6-7...
    35: technical_...  9.4193595343  3.9203122   2.500177 2fff2ff8-f...
    36: average_bl...  2.7310168157 14.6667302 146.392671 e0072c6f-0...
    37: average_bl...  0.0181914968  0.1751925  53.192953 ab0ee481-1...
    38: technical_...  7.7755117631  4.8253907  22.246090 73e1fe65-1...
    39: average_bl...  3.5871019648 12.4664080 111.862557 0dcb849f-f...
    40: technical_... -3.9597897112 13.1210147   4.892933 ed1c953f-9...
    41: average_bl... -0.3912402867  8.4384598  22.102189 83265457-c...
    42: technical_...  0.4627749967  0.6953951  39.712977 05c9ccf1-8...
    43: average_bl...  3.5252492370  3.7081976   4.031614 e0d2b2b4-8...
    44: technical_... -4.2075394921 11.2350960  19.406303 9bdc17f0-e...
    45: average_bl... -4.2982451872 11.5209919  19.874564 d091f0ab-0...
    46: technical_... -3.2703061973  1.0539643 133.475999 2be641b8-7...
    47: average_bl...  7.9195233579 11.3845370 107.114903 8c0557f8-a...
    48: technical_...  2.7302735573  3.1416981   1.473410 1245e22e-a...
    49: average_bl... -0.6301935043  4.8763695  22.501009 ca2b9eb0-4...
    50: technical_...  5.9158565315 12.2809537 143.846990 f810b1e9-8...
    51: average_bl...  7.5175695351 14.7167836 192.211553 f0ef8c82-a...
    52: technical_...  0.0008731289 13.1382797  70.576986 340b1fe8-7...
    53: average_bl...  0.6336930119  0.5388271  38.028305 af82fac1-4...
    54: technical_...  9.6441820045 14.2532173 134.884943 4f0f9e5e-0...
    55: average_bl... -3.0152420670 10.9485986   1.524674 f3bdb927-f...
    56: technical_...  1.7327636819 11.2573877  66.627178 bd12538a-6...
    57: average_bl...  3.4200641004 12.5522418 110.690280 b1d5956e-e...
    58: technical_...  2.6884600367 14.5980045 144.004558 5dcc4546-b...
    59: average_bl...  6.9621177235 10.3982160 102.426930 b0d42766-d...
    60: technical_...  9.7001004737  5.8682242  10.689533 8e2b4dcd-1...
    61: average_bl... -1.5640134121  5.4374546  21.406891 1647d56e-f...
    62: technical_... -1.9872919361  1.0440547  80.575214 bd16a3b7-4...
    63: average_bl...  8.0959901444 14.2178259 167.356921 41ccf83a-6...
    64: technical_... -2.5626173494  7.4741995  13.883860 d0fcab07-e...
    65: average_bl... -1.1109440520 13.9625182  50.682271 7929b4ed-b...
    66: average_bl... -3.5009190296  5.5651326  58.620672 debb90cc-6...
    67: technical_...  8.5330831841 11.2564223  92.910252 72153817-b...
    68: average_bl...  2.9219289747  8.6525219  39.068392 f048ed1e-9...
    69: technical_...  2.7421044745  8.1154139  31.494803 a9ef7369-d...
    70: average_bl...  5.1157239240  3.0115365  16.910908 94d0a08d-9...
    71: technical_...  3.5265113282 11.6561448  94.458340 e9df5acc-a...
    72: average_bl... -2.1191956023 14.7891316  28.382659 7a770809-e...
    73: technical_...  4.8257662015 10.6364904  97.734213 76ae64b7-e...
    74: average_bl...  2.8559328450 12.9834333 110.515084 46163f87-4...
    75: technical_...  4.4267424268  6.3367174  30.822569 b0745206-e...
    76: technical_...  7.2139808048 11.7830990 126.858577 cb2dc9cd-8...
    77: average_bl... -0.8309814562 10.4396560  25.641467 5adb4b88-e...
    78: average_bl... -4.9990499252 11.9733755  39.872082 2bdb3cc9-5...
    79: technical_...  5.6661212837  4.1851135  27.167782 c0adf663-e...
    80: technical_...  8.7657024137  6.2083502  20.328772 dfdd9872-c...
    81: average_bl... -1.6635534938 10.6994947  11.981470 c2125a7c-a...
    82: technical_...  2.5526901407  4.2836157   4.279035 4b277239-8...
    83: average_bl... -1.2084560973  9.1012116  14.382189 b7605983-3...
    84: average_bl... -3.1533786983  2.4217885  98.043666 e3d84fc2-e...
    85: technical_...  8.6177900451  9.2641580  57.907605 b0a3caf1-6...
    86: average_bl...  5.5241576638  6.6751639  47.490888 46f2f543-6...
    87: technical_...  4.2227089599  4.6613479  14.960710 d2d6329d-e...
            worker_id            x1         x2          y          keys
               <char>         <num>      <num>      <num>        <char>

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
    1: technical_...  9125 runnervm35...     FALSE terminated
    2: average_bl...  9127 runnervm35...     FALSE terminated

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

    [1] "seasonal_abyssiniangroundhornbill" "harebrained_cicada"               

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
    1: choosable_...  9416 runnervm35...     FALSE running
    2: watery_bur...  9418 runnervm35...     FALSE running

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
    1: choosable_...  9416 runnervm35...     FALSE running
    2: watery_bur...  9418 runnervm35...     FALSE running

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
