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
    1: sinless_ma... 12203 runnervm46...     FALSE running
    2: frozen_gan... 12205 runnervm46...     FALSE running

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
    1: frozen_gan... 12205 runnervm46...     FALSE    running
    2: sinless_ma... 12203 runnervm46...     FALSE terminated

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
     1: unaggressi... -2.63897119 13.5116359   7.4028085 197d0b10-3...
     2: unaggressi... -0.10263076  7.9896233  22.8819224 c836009a-4...
     3: unaggressi...  1.91046266 13.0895889 100.0909066 46eceecd-f...
     4: unaggressi...  5.41240671 12.0731709 135.0599474 7e14f13b-7...
     5: unaggressi...  5.13326406 11.3375599 116.0005106 fcd20a2c-b...
     6: unaggressi... -0.01215425  7.0184506  20.5995792 72e6a76e-f...
     7: unaggressi...  2.08609427  2.8668503   5.4089188 3ecc0ae4-5...
     8: unaggressi...  8.01629876  1.1970792   8.5680444 b371b916-4...
     9: unaggressi... -4.13351485  7.8288696  53.1475848 f7aaf5c1-6...
    10: unaggressi...  1.73134872  6.2328377  15.2308258 6a684b97-a...
    11: unaggressi...  6.74726949 14.2935792 191.5348931 555327d9-b...
    12: unaggressi...  6.12641230 12.8720532 158.1083316 0bfe539b-d...
    13: unaggressi...  5.42988717 14.3115968 189.0964551 4ad8cc9b-1...
    14: unaggressi...  6.49956949  9.2490385  85.5743505 cb9fcf97-e...
    15: unaggressi...  9.23198354 10.4461799  66.6565008 49789142-6...
    16: unaggressi... -2.17043653  9.9345277   4.5975754 44f3ff66-4...
    17: unaggressi...  4.97672731  3.6201414  17.9901125 37f9ebf3-d...
    18: unaggressi...  7.93480965 11.2606398 104.3978099 4522c6ef-2...
    19: unaggressi...  1.42143974 13.5176725 102.0391840 23dac327-0...
    20: unaggressi... -0.16412469  1.2598712  44.5213126 4bf746e3-7...
    21: unaggressi...  6.00466264  8.0731810  67.8412077 967216d3-b...
    22: unaggressi...  2.11100483 11.5033010  73.7421456 cb883ee2-0...
    23: unaggressi... -1.53044792 10.0458877  12.0969310 5c2d1cfc-4...
    24: unaggressi...  6.99040446  7.5872150  58.2604148 a5ac3660-b...
    25: unaggressi...  4.71702097  0.3073502  11.1673775 8aae209e-4...
    26: unaggressi... -2.66891114  9.0987204   5.7322421 3f8e7c92-7...
    27: unaggressi... -4.89937344  8.9894355  74.3386494 5753ff09-8...
    28: unaggressi... -0.52729473  2.5186566  37.2767679 fb8447f5-5...
    29: unaggressi... -2.80223268 11.1680139   1.0393358 8f305321-b...
    30: unaggressi... -0.88818228 13.3246051  49.8029919 c29f050b-2...
    31: unaggressi...  3.68218273  3.8761574   5.7072805 c2409e01-5...
    32: unaggressi... -2.82717500  4.7144931  47.3490614 a9532df8-8...
    33: unaggressi...  9.05640224  9.6359889  56.6070268 f2b2177c-6...
    34: unaggressi...  8.50965579  5.7543453  19.6935699 b2ba74db-d...
    35: unaggressi...  0.39256128  6.3553658  19.7937597 84cf1a09-1...
    36: unaggressi...  1.27808934  6.1595837  16.7017483 1d621c13-4...
    37: unaggressi...  6.69302884 11.9429525 135.6242441 08bcebe3-b...
    38: unaggressi...  2.02529953  2.8787522   5.9675124 bdc25725-e...
    39: unaggressi...  9.49908566  1.9524974   0.7676590 05fca2d7-e...
    40: cosmogonic...  4.29446647  0.7593675   6.7242067 dcd7244b-e...
    41: unaggressi...  4.80771445 10.8819737 102.0725708 1e0a321e-d...
    42: cosmogonic...  3.75749935 12.8479843 123.2568914 8f18addf-9...
    43: unaggressi...  9.79650478  7.6450291  24.4659292 e0bdb089-b...
    44: unaggressi...  5.88764785  9.5219863  89.6622812 079a4a22-6...
    45: cosmogonic...  9.83717237 10.8210375  64.8227197 aa6684e4-9...
    46: unaggressi...  3.25774973  9.1954560  49.5928674 8a9453b9-9...
    47: cosmogonic...  5.55085261  0.4781222  17.5863156 ed1d7360-6...
    48: unaggressi... -0.04165202  3.9146959  24.2241114 c9687d7d-6...
    49: cosmogonic... -3.13593325  5.2539697  49.5021657 e7dfca00-3...
    50: unaggressi...  0.87298409 13.0612037  85.9281677 5e8e1f4b-1...
    51: cosmogonic... -3.35295162 11.6027664   2.0180451 85699b2e-3...
    52: unaggressi...  0.22140728  6.0329960  19.5113933 35381b33-3...
    53: cosmogonic...  9.21545544  5.7408729  12.4189434 e7f1ba2e-8...
    54: unaggressi... -0.56506270  5.8756562  19.2435609 57490171-f...
    55: cosmogonic... -3.16132913  2.1250755 104.3868523 a1a0bab4-7...
    56: unaggressi...  8.15376434  1.2426256   7.3004931 9ff2f16c-5...
    57: cosmogonic...  7.85153975 10.2495084  87.1439225 be0a827e-d...
    58: unaggressi...  6.19482871  1.4176432  19.6667022 d446ce1a-3...
    59: cosmogonic...  4.81580258  6.8874449  41.8602620 157879c0-5...
    60: unaggressi...  9.03687583  0.6661501   3.3645343 dd10e52a-9...
    61: cosmogonic... -1.78747278  5.5588435  21.6165151 af0c324e-6...
    62: unaggressi...  3.72678304 11.4671532  94.2378130 cc85dd22-2...
    63: cosmogonic...  2.74466899  1.8701075   1.6843235 41899973-d...
    64: unaggressi... -3.41324348  4.3502170  74.4892889 941ac52c-2...
    65: cosmogonic... -2.04673857  6.2435311  18.2394644 328a36f3-4...
    66: unaggressi... -1.73871355  2.6982592  50.1207379 6751193f-2...
    67: cosmogonic... -4.39117425 11.9693595  19.2913362 eb6c147a-c...
    68: unaggressi...  5.89958565  1.2895633  18.9376669 0b5ff4ae-9...
    69: cosmogonic... -0.18829439 13.4851857  70.9980883 8e700625-4...
    70: unaggressi... -0.32798229  6.3959369  19.1098535 1e5c2114-d...
    71: cosmogonic...  4.60453680  5.6183816  26.6719000 76ff99a7-6...
    72: unaggressi... -3.61167185 14.4524731   2.4782018 24137790-8...
    73: cosmogonic...  3.79103580 11.0444466  87.3875220 03a25ae2-f...
    74: unaggressi... -3.24988441 12.9973292   0.6662533 a666bb17-7...
    75: cosmogonic...  4.08767689 14.5241541 170.0553826 fc750cf8-5...
    76: unaggressi...  0.61850306  2.0186822  27.1035967 1dac023c-0...
    77: cosmogonic...  0.53861096  1.5997925  31.0623458 3087d833-7...
    78: unaggressi... -0.21706149 13.1915371  66.1622079 da36caa7-1...
    79: cosmogonic... -0.21333717  3.9727651  25.0139040 db6c0520-3...
    80: unaggressi...  0.12546387  6.7999489  20.5218378 f61b5be5-5...
    81: cosmogonic...  7.63751816 10.2967508  91.5696475 30a8518c-9...
    82: unaggressi...  2.59435182 13.0960995 109.0394579 519fca32-c...
    83: cosmogonic...  5.27679442  8.6033466  69.9635131 1a507da0-6...
    84: unaggressi...  7.67614328  3.5490208  16.3384427 dd8c6af0-f...
    85: cosmogonic...  6.00569012 11.4211424 125.7377518 1a6ba1a1-d...
    86: unaggressi...  8.87727989  6.7628616  23.9946163 061cc935-9...
    87: cosmogonic...  4.41182055 14.0001202 163.5892876 a1982a83-9...
    88: unaggressi...  4.11525806 14.8252882 178.5016615 d498848d-d...
    89: cosmogonic...  2.68888561  8.6438061  37.2366518 ca9c206f-d...
    90: unaggressi...  5.73483807  7.1631015  54.6966056 889a7ebb-5...
    91: unaggressi...  0.72315749  7.7955813  25.4873313 cd41e851-b...
    92: cosmogonic...  8.51935199 10.5683461  80.6554076 29bc48c5-4...
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
    1: cosmogonic... 12205 runnervm46...     FALSE terminated
    2: unaggressi... 12203 runnervm46...     FALSE terminated

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

    [1] "astrophysical_italiangreyhound" "polyphagous_caterpillar"       

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
    1: insomniac_... 12498 runnervm46...     FALSE running
    2: dripping_w... 12500 runnervm46...     FALSE running

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
    1: insomniac_... 12498 runnervm46...     FALSE running
    2: dripping_w... 12500 runnervm46...     FALSE running

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
