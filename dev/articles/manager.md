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
    1: whited_zoo...  9058 runnervm1l...     FALSE running
    2: exoskeleta...  9056 runnervm1l...     FALSE running

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
    1: exoskeleta...  9056 runnervm1l...     FALSE    running
    2: whited_zoo...  9058 runnervm1l...     FALSE terminated

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

             worker_id         x1          x2           y          keys
                <char>      <num>       <num>       <num>        <char>
      1: abyssal_eu...  5.9157729  3.25680001  23.5883099 ef5a2de7-c...
      2: abyssal_eu... -1.8448585  1.53895999  68.8182974 29e43b4c-3...
      3: abyssal_eu...  1.6253909 10.45659534  54.3954326 229b19df-a...
      4: abyssal_eu... -1.5167780  7.48153801  12.0305828 d3e95eda-0...
      5: abyssal_eu...  6.6041841  1.22502453  19.1219453 503c3b53-f...
      6: abyssal_eu... -4.1976798  3.40039322 138.8308182 a6d3b696-d...
      7: abyssal_eu...  4.9790472  0.40166134  13.2985687 60d63afe-d...
      8: abyssal_eu...  1.8974331  0.31329205  16.7281582 98b1c7a0-c...
      9: abyssal_eu...  2.5538658  9.39540409  45.7995578 3c140bd2-4...
     10: abyssal_eu... -1.5312603  0.38465761  80.1909905 b5b17b23-f...
     11: abyssal_eu...  2.8336503 11.36795118  79.0048871 9e2f7f67-0...
     12: abyssal_eu... -4.8337126 14.27979820  17.0750863 cc34ca3d-6...
     13: abyssal_eu...  3.5009313  6.70199049  23.0123736 b1ded5b5-9...
     14: abyssal_eu... -1.2690625  1.14186117  63.0644712 9c9b79ea-b...
     15: abyssal_eu...  9.5367132 14.54739523 143.8911028 fd5021d4-8...
     16: abyssal_eu... -2.2882835  2.47675527  65.1773999 eee5c232-8...
     17: abyssal_eu... -0.5132810  0.40005335  59.9787915 0b599d7f-d...
     18: abyssal_eu... -3.1209431  0.07085222 148.1336783 a8d4f466-2...
     19: abyssal_eu...  3.2282114  3.98751184   3.5990582 7e53a049-6...
     20: abyssal_eu... -0.4669586  5.05200173  21.5303060 f7395514-b...
     21: abyssal_eu...  2.9149419  2.65897810   0.6837011 8519d0fa-3...
     22: abyssal_eu...  2.4943989  2.30522301   2.6190620 e039c28f-d...
     23: abyssal_eu...  9.1429169  3.03931684   1.4037541 8c125a08-f...
     24: abyssal_eu...  5.3265001 11.89534074 130.1848309 11ca1a02-a...
     25: abyssal_eu... -0.7936207 13.66256514  56.6522223 92ff030c-7...
     26: abyssal_eu... -4.3389978  6.35696474  87.1541131 578b409b-b...
     27: abyssal_eu...  3.0934736  6.07339601  14.5508945 a62352e5-0...
     28: abyssal_eu... -3.8196869  8.44911228  32.9364140 9be37d7e-f...
     29: abyssal_eu... -2.8238528  8.24491439  11.6338016 dd9f0b03-1...
     30: abyssal_eu...  8.2161868 13.18239950 139.7270489 926f5621-a...
     31: abyssal_eu...  0.8986624  3.52437013  17.3006182 65909beb-3...
     32: abyssal_eu... -4.8706626 11.84933556  36.1870414 93baaa0e-8...
     33: abyssal_eu...  5.7913941  7.55045873  59.8716845 9be0cd58-7...
     34: abyssal_eu...  8.0986879  4.38945689  15.5465843 a174130a-d...
     35: abyssal_eu... -0.8314457  4.36441845  25.7613469 dbc3f491-f...
     36: abyssal_eu... -4.7493854  7.27229048  95.0055117 5b475f1a-b...
     37: abyssal_eu...  1.2373246  9.97651076  46.1824758 9a4e9c70-c...
     38: abyssal_eu...  1.2023454 14.77508148 123.7487255 a5bba575-5...
     39: community_...  9.4726840 13.25027993 115.6399762 2b097fff-8...
     40: abyssal_eu...  7.2063599  9.47614865  83.6355288 c3336784-d...
     41: community_...  3.0980528  0.26095423   4.6022976 f4768d2a-f...
     42: abyssal_eu... -1.2310002  0.29310115  75.0091425 3eecfe0b-a...
     43: community_...  0.8049502  0.04498639  39.2904338 a346d4f4-4...
     44: abyssal_eu...  2.0659871  9.03498961  38.7497355 24075382-3...
     45: community_... -4.8988317  3.10549801 201.9846966 7630fadd-b...
     46: abyssal_eu...  8.5398731 12.18498253 111.1497807 d2fd9c7b-a...
     47: community_...  9.1154952  8.23972485  37.0127132 23e4a49e-1...
     48: abyssal_eu...  6.4705324 12.93023805 159.1403553 00a2eb3e-0...
     49: community_...  8.8689796  0.36018977   4.6854247 b5367e32-4...
     50: abyssal_eu... -1.6090255 10.99545909  14.0436876 9afbccff-6...
     51: community_...  3.4713198 14.19160220 148.7734026 7a0a1e8e-3...
     52: abyssal_eu... -4.9226580 14.05317853  20.4836137 6590357b-e...
     53: community_...  7.0277552  6.53592766  45.5833049 7a8f158a-6...
     54: abyssal_eu...  8.9491404 11.57468661  91.1762717 0c4f3ac0-2...
     55: community_... -2.4707291 13.15194228   8.3888006 8cd66348-0...
     56: abyssal_eu...  4.5641123 10.76737588  95.8231704 c5a518a3-d...
     57: community_... -4.0878490  2.19182309 159.9593888 1992dcef-b...
     58: abyssal_eu... -0.2886788 13.38064017  66.9587988 118d1bba-f...
     59: community_...  7.3376906 13.55819607 165.5626137 550d6837-2...
     60: abyssal_eu... -3.8459619  1.21028614 167.0757867 1e073a0c-3...
     61: community_...  4.0622045  7.83206097  42.2011760 421b439c-e...
     62: abyssal_eu...  2.4676404  6.47032997  15.5370715 2e4db0bc-d...
     63: community_... -0.3338505 13.74519092  70.9040792 0527726a-3...
     64: abyssal_eu...  9.8355173  8.09183265  28.7440322 14cb28bf-7...
     65: community_...  1.4243765  4.17224203  11.4322904 7fc52ac4-8...
     66: abyssal_eu...  4.4485881 10.16386325  82.9681561 8cba7081-2...
     67: community_...  5.1973696  1.12239308  14.4855123 c46b2062-d...
     68: abyssal_eu...  3.9476748 13.09154442 132.4298224 52e17a01-f...
     69: community_...  6.7689823  8.58380450  73.8128464 785ff272-1...
     70: abyssal_eu...  9.6127247  5.07651694   6.5128566 e6029eb5-a...
     71: community_...  8.9611977  6.23219633  18.3896217 ed6961ca-d...
     72: abyssal_eu...  2.3319905 13.67843058 117.5966873 9b2770a2-2...
     73: community_...  3.8596626  8.15723517  43.4173736 41a6f052-9...
     74: abyssal_eu... -3.4098856  5.80437118  51.5027546 b51d2757-c...
     75: community_...  6.3710571 11.99926508 138.2763435 721e9e8e-d...
     76: abyssal_eu...  5.0969760  4.49118897  24.1466162 e0f4ef0d-4...
     77: community_...  3.3113249  0.40372991   3.5726096 ef420da3-f...
     78: abyssal_eu... -1.4596538  9.23023528  11.4642862 08db53d2-8...
     79: community_...  8.0205809  6.67638595  34.7362192 68aaa752-f...
     80: abyssal_eu...  4.0026825  9.19756750  59.9677975 0d3647f4-2...
     81: community_... -4.5539651 12.88769741  17.7223051 fc5cb54f-5...
     82: abyssal_eu...  2.1677520  8.62086526  34.4565118 50c0316f-8...
     83: community_... -1.5597333  3.67394913  36.3484805 99e2e68d-c...
     84: abyssal_eu... -2.7373470 13.37606501   5.3802860 e5a07fa2-a...
     85: community_...  0.9906086  8.21780621  28.7152733 d6bf1193-2...
     86: abyssal_eu... -0.4202307 14.28474909  76.4221197 fa949645-2...
     87: community_...  3.2364660 13.09809441 119.1621306 8ddd2937-f...
     88: abyssal_eu...  9.2862021  9.86044345  56.7377514 2003fd47-9...
     89: community_...  1.6596384 14.58325077 127.2793328 fb81d640-b...
     90: abyssal_eu...  1.4384516  2.71651680  12.8582574 57d5e0b2-2...
     91: community_... -2.1493993  6.25859299  18.8799014 7ade20d0-6...
     92: abyssal_eu...  5.5627221  2.86274362  20.1696486 d0d6023d-c...
     93: community_...  1.7812716 12.03989970  79.6499083 40d3c735-e...
     94: abyssal_eu...  5.2313481 11.30768054 116.7368089 a2a5053f-e...
     95: community_...  9.1168225  8.50304367  40.2322598 5a77d888-b...
     96: abyssal_eu...  1.5459109  5.94117162  14.6188856 ef6d89dc-4...
     97: community_... -0.2328642 11.55319847  46.1295578 5ebef486-2...
     98: abyssal_eu... -3.6965326  8.28672725  30.5867881 8bc8e323-4...
     99: abyssal_eu... -1.2234783  9.96680052  16.6033405 3380d74c-d...
    100: community_...  7.0939911  7.97458402  62.3646836 4b7b3c7c-0...
             worker_id         x1          x2           y          keys
                <char>      <num>       <num>       <num>        <char>

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
    1: abyssal_eu...  9058 runnervm1l...     FALSE terminated
    2: community_...  9056 runnervm1l...     FALSE terminated

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

    [1] "orcish_flatcoatretriever" "bossy_oryx"              

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
    1: semisolemn...  9308 runnervm1l...     FALSE running
    2: taxexempt_...  9310 runnervm1l...     FALSE running

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
    1: semisolemn...  9308 runnervm1l...     FALSE running
    2: taxexempt_...  9310 runnervm1l...     FALSE running

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
