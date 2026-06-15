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
    1: nonevolvin...  9040 runnervm1l...     FALSE running
    2: monodramat...  9038 runnervm1l...     FALSE running

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
    1: monodramat...  9038 runnervm1l...     FALSE    running
    2: nonevolvin...  9040 runnervm1l...     FALSE terminated

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

            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>
     1: inept_pinn... -1.7516251  0.3423227  86.4512069 2f033581-8...
     2: inept_pinn...  8.7501594  7.3213318  31.1943711 3c49faf2-0...
     3: inept_pinn... -2.5545510  3.9365546  50.6165008 7aed76b8-e...
     4: inept_pinn...  3.3184476  7.5529051  29.8350949 08630556-3...
     5: inept_pinn... -2.8649262  3.1037794  73.2889314 23ccdd6e-4...
     6: inept_pinn...  4.8172187 10.4348849  93.8861599 ec135f85-1...
     7: inept_pinn... -1.7492107 11.6817428  14.5585103 fbb59710-4...
     8: inept_pinn...  1.0140947  8.9384223  34.6060909 22a93c4c-e...
     9: inept_pinn... -0.2980811  3.2190238  29.8510859 8c9efe2c-5...
    10: inept_pinn... -0.1908433  6.2622759  19.4299140 eeb25e85-3...
    11: inept_pinn...  1.3786129 10.6549000  55.4403181 2e8ef7f1-6...
    12: inept_pinn...  6.5371481 12.4629112 148.0370738 7a1916d4-1...
    13: inept_pinn...  2.2754452 12.9953497 102.7420010 acba9832-8...
    14: inept_pinn... -4.2638445 13.2920060   9.2316744 694cc776-f...
    15: inept_pinn...  7.2079155  5.1068364  30.7341175 4a0f329c-8...
    16: inept_pinn...  3.6793005  0.7388654   3.0849506 feb5fc73-7...
    17: inept_pinn...  9.4245372  2.1412982   0.5091090 fbda16fa-1...
    18: inept_pinn...  6.0544602  3.2653033  24.0428380 2fc43be3-3...
    19: inept_pinn...  5.0486881 12.1580516 131.9889437 8757dbc4-7...
    20: inept_pinn...  8.4229154  0.9885602   5.4214765 307b95f1-c...
    21: inept_pinn...  0.7346290  3.3380553  19.5668260 04608349-d...
    22: inept_pinn...  2.0571689 12.9646371  99.4470413 8b9b66aa-8...
    23: inept_pinn...  8.1619572  7.1144979  37.3250266 3618fd43-f...
    24: inept_pinn...  0.3884839 12.9230750  75.4651317 5abd3ec2-7...
    25: inept_pinn...  2.0695585  6.0246322  13.0528813 2402050e-0...
    26: inept_pinn...  4.0904963  8.3587467  49.3957759 bb96b8af-0...
    27: inept_pinn...  9.2870540  7.0221181  22.2122464 9a3cb922-8...
    28: inept_pinn... -3.7942960  4.9684343  82.1201863 b8b458c0-e...
    29:    slate_foal -0.1870785 11.5939735  47.4367435 f246f6e3-c...
    30: inept_pinn...  8.6076205 14.7977593 170.5052611 22524a6c-5...
    31:    slate_foal  2.1344275 10.6967474  61.1988805 6825f92e-d...
    32: inept_pinn... -1.6030104  3.9273756  34.2512057 8c4dbd45-e...
    33:    slate_foal -2.6363907 13.4649423   7.2194920 424cd3e8-a...
    34: inept_pinn...  8.2508807  8.2375672  49.5155902 9e2f85a8-f...
    35: inept_pinn...  8.8158114 11.6312049  94.7063549 a20aaee0-0...
    36:    slate_foal  3.1937650 11.5513992  87.2124983 17fa4ba6-7...
    37: inept_pinn... -2.1148857  3.3128503  48.9984535 ed07581b-2...
    38:    slate_foal -4.5002803 14.9084961   8.7358548 4aa58a99-3...
    39: inept_pinn...  0.8265437 10.3506708  47.6176572 1f5cc76a-0...
    40:    slate_foal  4.3757715  6.7768455  34.5756215 c2c25f7c-f...
    41: inept_pinn...  6.0411140  0.7994138  19.4124197 e8820083-b...
    42:    slate_foal  0.8423389  2.5786345  21.1116442 819561c4-9...
    43: inept_pinn...  7.6837183 12.3707482 132.0287543 3eb1bf58-8...
    44:    slate_foal  7.0537109 12.7496364 150.2557583 187fed2a-e...
    45: inept_pinn...  7.2183828 12.7618893 148.3909031 8f5d3fef-4...
    46:    slate_foal -4.8451404  6.9521108 107.1508082 24e4b49f-a...
    47: inept_pinn...  6.3725448  1.3663404  19.6326888 15c42fe3-1...
    48:    slate_foal -2.0822326  7.3001510  11.9255485 992ef6c8-f...
    49: inept_pinn...  0.2462490  0.1522904  49.1636588 70b371c0-5...
    50: inept_pinn...  5.4531294 13.5677981 170.3691310 30a69611-a...
    51:    slate_foal  9.7438461  9.4288376  45.3920411 fb5ab41b-e...
    52: inept_pinn...  6.5460406 11.8788790 135.0840393 18918b8f-b...
    53:    slate_foal  4.8452953 13.4168921 157.5752165 86d4733e-1...
    54: inept_pinn...  7.5876931  4.1308128  20.1966768 a8936b1e-6...
    55:    slate_foal  8.0028546  2.5296593   9.5616065 a675facf-5...
    56: inept_pinn...  1.8754444  5.6748247  11.9831559 3c4e57db-3...
    57:    slate_foal -4.9980993  3.9122164 188.7902155 9deee9db-1...
    58: inept_pinn... -0.5971481 11.4603509  37.8667518 99e8ab51-b...
    59:    slate_foal  9.7561343 13.6213620 118.7007078 511e464d-6...
    60: inept_pinn... -3.5666919  9.6762966  14.5287802 4c283bd5-5...
    61:    slate_foal  8.7130804 11.1379810  87.3297427 2dc92dac-e...
    62: inept_pinn...  0.8121653  3.8308786  17.5304954 73bdb347-9...
    63:    slate_foal -4.2272891 14.2634166   6.1201681 2265ed1a-9...
    64: inept_pinn... -4.2544097  2.1900285 172.6632439 0348c0e6-6...
    65:    slate_foal  1.2748609  5.7590487  15.2906873 4a9e56f6-8...
    66: inept_pinn...  2.8399116 13.1587103 113.9705859 8169efad-1...
    67:    slate_foal  3.5500860  5.5163392  13.7078654 f73ba1d8-9...
    68: inept_pinn...  0.5023331  8.5783473  29.6064940 903f00ba-d...
    69:    slate_foal -4.2926841  9.5124093  38.5784849 4f533189-4...
    70: inept_pinn... -0.1117023  9.3154013  29.3768262 42ec8e7a-4...
    71:    slate_foal  3.2820152  2.7113731   0.7876149 0d407a3d-0...
    72: inept_pinn...  3.7155032  0.7099190   3.2820393 ce6dbeeb-5...
    73:    slate_foal  5.7245617 10.3715935 103.6875938 f0246c5e-2...
    74: inept_pinn...  9.6002963 14.6046591 144.0089351 e75ce385-6...
    75:    slate_foal  8.9703405  9.5797185  57.0444325 a9d2f364-8...
    76: inept_pinn... -0.3440815  4.9964998  21.4929548 c5c3538c-6...
    77:    slate_foal  0.1084193  5.6642400  19.5728667 60605b57-3...
    78: inept_pinn... -0.5700647  4.4944861  24.1096459 fcc4482a-c...
    79:    slate_foal  1.8838591  7.5452546  23.7303780 6bda4e7d-4...
    80: inept_pinn... -1.4009101  6.5993742  15.1720374 c89dd078-d...
    81:    slate_foal  6.1223948  4.9595901  34.3884207 b06fc6a8-5...
    82: inept_pinn...  3.7645105  7.2643938  31.6325814 0d1dfaa7-5...
    83:    slate_foal  2.1555692  7.0334706  19.6293577 7abacf8c-a...
    84: inept_pinn...  6.4986125 14.5875139 200.9466600 83ba39cb-3...
    85:    slate_foal  9.4827370  9.6457676  51.1289751 db1a8e1b-3...
    86: inept_pinn...  5.3903999  3.1952623  20.1061555 e532b5a4-f...
    87:    slate_foal  6.2216600  7.9022276  65.8742370 e6039c1a-c...
    88: inept_pinn...  7.5744553  6.5659441  39.7875151 c8ce638e-8...
    89:    slate_foal -1.6036540  4.1479970  32.1191959 76cbe763-a...
    90: inept_pinn...  7.6795368 13.7472477 164.2117034 18871171-4...
    91:    slate_foal  1.2189288  8.2167319  29.0288365 cd946a44-6...
    92: inept_pinn...  3.8746816  5.9910496  20.6588685 0c8f3fa7-d...
            worker_id         x1         x2           y          keys
               <char>      <num>      <num>       <num>        <char>

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
    1: inept_pinn...  9040 runnervm1l...     FALSE terminated
    2:    slate_foal  9038 runnervm1l...     FALSE terminated

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

    [1] "contextual_redstart" "unrideable_quagga"  

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
    1: sappy_nine...  9290 runnervm1l...     FALSE running
    2: archaic_al...  9292 runnervm1l...     FALSE running

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
    1: sappy_nine...  9290 runnervm1l...     FALSE running
    2: archaic_al...  9292 runnervm1l...     FALSE running

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
