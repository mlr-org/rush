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
    1: noetic_uly...  8900 runnervmmk...     FALSE running
    2: stoutish_t...  8898 runnervmmk...     FALSE running

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
    1: stoutish_t...  8898 runnervmmk...     FALSE    running
    2: noetic_uly...  8900 runnervmmk...     FALSE terminated

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

            worker_id           x1         x2          y          keys
               <char>        <num>      <num>      <num>        <char>
     1: overaggres...  3.475346030  4.0623328   5.061735 0a34e232-b...
     2: overaggres... -3.348108067 10.7746205   4.610704 82a77229-a...
     3: overaggres... -1.457242978  6.9526345  13.780794 6c19cba4-3...
     4: overaggres...  7.271669916  5.1896102  30.740730 fb4dbc34-8...
     5: overaggres...  0.610516801  1.4733432  30.850128 9c69fedc-9...
     6: overaggres...  5.544545055 12.9917535 157.398550 d583a72a-1...
     7: overaggres... -2.505824773  0.7898429 102.463496 67fd65b1-a...
     8: overaggres...  8.109911865  5.3111319  21.421851 9e0c25c6-9...
     9: overaggres...  2.525088640 13.1805140 109.819237 510f4c32-3...
    10: overaggres... -1.341758647  3.7528685  33.479951 c89ab772-b...
    11: overaggres...  7.701650429 10.8381489 100.439916 72699669-e...
    12: overaggres...  0.094271221  7.5582891  22.473935 ee0f39c6-5...
    13: overaggres...  5.488055778  0.3995770  17.296053 29973078-7...
    14: overaggres...  2.205931450 14.3423089 130.293245 ed762e6a-a...
    15: overaggres...  5.878047689  0.5699147  19.114671 45302228-0...
    16: overaggres...  7.267578370  5.1423795  30.413430 4c061fa1-5...
    17: overaggres... -4.219608043  5.5590868  94.887953 c03ce98d-a...
    18: overaggres... -1.893173891  3.3882296  44.019891 6fc0f69a-0...
    19: overaggres...  0.377152469 13.4092144  82.784855 03d4d092-a...
    20: overaggres... -3.974047507  2.1740401 152.159390 656f7e12-9...
    21: overaggres... -1.917936367  0.8384403  82.236382 3564e94a-b...
    22: overaggres...  5.112797477  8.0969852  60.765165 d1602526-d...
    23: overaggres...  8.487686938  8.5354709  49.707960 597dbc74-a...
    24: overaggres...  8.192640425 12.1986887 118.469333 493ec268-7...
    25: overaggres...  7.503147335  5.3086731  29.121165 7f580a8d-b...
    26: overaggres...  7.423095252 14.3814044 185.025258 a0a9438c-e...
    27: overaggres... -2.674015143  5.7658438  30.736687 2ceda5cb-2...
    28: overaggres... -2.090064838  2.7516542  56.201934 0bf7d9a4-a...
    29: overaggres...  3.983952619  5.8567784  20.805739 7d040f7a-f...
    30: overaggres... -2.254433468  0.8421915  92.340779 604edb0c-8...
    31: overaggres...  6.883832658  1.9337613  18.511332 be5b09d5-5...
    32: overaggres...  8.562209335 10.4541484  77.896829 97ceafac-e...
    33: overaggres...  2.779459573 11.2807998  76.822845 d06b2fd8-5...
    34: overaggres...  8.994083058 11.6402224  91.611438 756055b7-6...
    35: overaggres...  4.793639353  7.8300771  52.910620 5b729f2a-0...
    36: overaggres...  9.411372125  4.5854552   4.900531 743745da-9...
    37: overaggres...  0.902614175  9.7849694  42.125369 d95536e0-b...
    38: overaggres... -0.351846052  1.0279082  49.794890 e2a4e0b3-9...
    39: apothecial...  2.007035873  2.8375260   6.181467 ac00762a-e...
    40: overaggres... -0.957466658  2.2270238  44.851960 6c1277a3-b...
    41: apothecial...  9.661050090  5.2449791   7.236022 22f87564-2...
    42: overaggres... -3.021430154  4.0136528  64.058712 46b5fda8-a...
    43: apothecial...  1.235302528 10.6099947  53.851820 4366737d-b...
    44: overaggres... -2.499785605  9.0750858   5.235094 67934c1a-8...
    45: apothecial... -4.930627985  3.7369068 187.669231 6e59d039-e...
    46: overaggres...  6.630216955  5.0831474  34.683931 cecef3fc-4...
    47: apothecial...  3.085941964  9.5200124  52.270215 0f0493d7-b...
    48: overaggres...  0.380138103  5.0715500  19.033689 067f0b37-8...
    49: apothecial... -2.013934079  2.5427659  57.528238 81e45295-8...
    50: overaggres...  4.087477283  6.6516781  29.370058 3d740681-7...
    51: apothecial... -3.565530954  8.5080875  24.373957 6fe21421-5...
    52: overaggres... -4.980991016  5.8350092 140.183717 249b19dd-3...
    53: apothecial... -3.432454775  5.2224023  61.058204 0d129d7f-3...
    54: overaggres...  8.581176465 13.4492716 138.035985 fc554735-2...
    55: apothecial... -4.094209000  8.8844119  38.042428 e86fe69e-3...
    56: overaggres... -3.379967710  9.9347388   9.198577 f91fde54-5...
    57: apothecial...  5.059010120  0.4020475  13.988944 5deb086d-e...
    58: overaggres... -4.628478707  3.4804405 169.306495 de1f7304-8...
    59: apothecial...  0.343379897  1.4763381  34.980723 dc4918c6-b...
    60: overaggres... -2.031033944  6.5714697  15.936241 e20d6795-d...
    61: apothecial... -1.781921531 12.1940635  16.677628 eabb6de8-3...
    62: overaggres...  7.170303201  2.8376288  18.649946 eac9d0f9-1...
    63: apothecial...  9.052587515  6.4415497  19.225115 41741246-f...
    64: overaggres...  9.382117790 14.2305736 139.441928 19fe0768-8...
    65: apothecial...  3.786060227  3.2078047   4.233096 e3b49e7a-1...
    66: overaggres...  9.404997384 11.5962373  83.900472 a2eac662-2...
    67: apothecial...  3.170566228  8.3656787  37.772710 6f1cc2b6-b...
    68: overaggres... -1.929819190  5.1442730  26.058776 2a357d89-f...
    69: apothecial...  7.904379993  2.6856157  10.943055 9c0f022c-c...
    70: overaggres... -4.457309291  4.4033532 134.303113 36404e2f-7...
    71: apothecial...  9.190920657 11.9846290  94.745914 69cb7745-e...
    72: overaggres...  0.002986961  4.3960231  22.159588 64bc674d-4...
    73: apothecial...  2.954764013  1.2111055   2.039029 af3bbea9-0...
    74: overaggres...  4.502000301  3.2429984  11.198229 4d906368-3...
    75: apothecial...  1.295700195 10.5487190  53.491675 901cfdd7-7...
    76: overaggres...  0.168086381 11.7487881  55.618820 4d7f174b-6...
    77: apothecial...  8.329519691  9.2349666  62.287899 8ab0e60e-8...
    78: apothecial...  3.058040262  6.7326241  19.717211 eed20704-3...
    79: overaggres... -2.453296159  6.1895424  22.766722 56c8132b-f...
    80: overaggres... -0.373686401 11.9901388  47.855440 42c84f9c-c...
    81: apothecial... -0.423081399 13.7090775  67.932019 c8f7811b-2...
    82: apothecial...  6.731731196  3.1223304  22.580827 00ff9f1a-8...
    83: overaggres...  4.778906296  1.8282720  10.872326 4934791a-0...
            worker_id           x1         x2          y          keys
               <char>        <num>      <num>      <num>        <char>

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
    1: apothecial...  8898 runnervmmk...     FALSE terminated
    2: overaggres...  8900 runnervmmk...     FALSE terminated

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

    [1] "fake_scarab"               "interhemispheric_stallion"

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
    1: titanous_w...  9153 runnervmmk...     FALSE running
    2: palaeologi...  9151 runnervmmk...     FALSE running

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
    1: titanous_w...  9153 runnervmmk...     FALSE running
    2: palaeologi...  9151 runnervmmk...     FALSE running

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
