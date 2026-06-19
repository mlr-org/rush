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
    1: bleareyed_...  8821 runnervm7b...     FALSE running
    2: climatolog...  8823 runnervm7b...     FALSE running

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
    1: climatolog...  8823 runnervm7b...     FALSE    running
    2: bleareyed_...  8821 runnervm7b...     FALSE terminated

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
     1: sopping_ur...  7.5510717  7.29074321  48.1801777 821f420a-1...
     2: sopping_ur...  4.2668593 10.18639268  80.2590370 4a70f75b-3...
     3: sopping_ur...  6.1858235  5.07598821  35.3800299 df240ac9-5...
     4: sopping_ur...  7.4198111 14.90681947 199.1010491 ce3000ff-7...
     5: sopping_ur...  6.5447757  5.42097775  37.7982373 ea64f6e5-a...
     6: sopping_ur... -2.4303349  2.08974705  75.6795170 3149c005-0...
     7: sopping_ur... -2.6017540  3.92968158  51.9691793 4ae84c74-f...
     8: sopping_ur... -1.1042611  2.09416079  48.2012956 7a32e34e-5...
     9: sopping_ur...  6.2423060  7.62310959  62.1592102 9248ddc7-1...
    10: sopping_ur...  4.3761685 14.54752241 176.8323896 b6102d63-f...
    11: sopping_ur...  9.1632165  2.96028299   1.2103976 f8c4db8a-8...
    12: sopping_ur...  2.3166700 10.58697470  60.9515145 cfebca9d-f...
    13: sopping_ur...  5.9821820  1.16460763  19.1743011 53e809ae-c...
    14: sopping_ur...  6.0978633 11.04106544 118.2915520 9e1aa261-2...
    15: sopping_ur...  2.5392276  6.29636041  14.3709885 3259737e-0...
    16: sopping_ur...  2.2997728  1.07846615   7.3853713 61ad2573-4...
    17: sopping_ur...  2.7376593  7.81799144  28.2824757 a697495a-a...
    18: sopping_ur...  9.1130398  9.88258315  59.5054502 0600ac40-e...
    19: sopping_ur...  8.2059208  2.01172090   6.8290514 17d32069-d...
    20: sopping_ur... -1.2018857 13.73837388  45.2597408 947d713e-9...
    21: sopping_ur...  2.1333281 10.58413283  59.5131785 7ce6b777-a...
    22: sopping_ur...  8.9706718  8.58108584  43.1348639 b81e5bf9-4...
    23: sopping_ur... -1.4953130  2.66443985  46.7754440 d9eef728-4...
    24: sopping_ur... -2.0259069  9.85143197   5.7886669 451bac29-f...
    25: sopping_ur...  5.8515752 13.17959824 164.3888470 3f4c9c5e-9...
    26: sopping_ur... -1.3598420  8.10230924  12.1011159 c669a4b7-b...
    27: sopping_ur...  2.8719048 14.37062311 141.7821736 06e036c0-d...
    28: sopping_ur...  4.3391039  5.87427752  25.4026833 17edd1a7-e...
    29: sopping_ur... -3.5211319 10.03644419  11.1256080 a4b0b613-5...
    30: sopping_ur...  2.9477683  2.92330162   0.8200410 cc08204a-1...
    31: sopping_ur...  2.0652969  6.56038987  16.3090457 89e544a2-7...
    32: sopping_ur... -1.9305122  7.06145639  12.8325529 a3962d33-6...
    33: sopping_ur... -4.3545373  2.11107171 182.7027186 66c3fb61-6...
    34: paleogeolo... -4.5591362  2.09559554 200.2372933 275fd395-d...
    35: sopping_ur... -4.6507424  1.20100329 234.2604806 c0322edc-3...
    36: paleogeolo... -3.5449607  4.71711874  74.2417796 cc04e0f0-5...
    37: sopping_ur... -0.8277812 12.37349183  41.1721639 180d6ab0-a...
    38: sopping_ur... -2.8094311 11.73297938   0.9813009 fd86176a-7...
    39: paleogeolo...  4.9876228  8.85775968  70.0988080 c3a0bf9d-9...
    40: sopping_ur...  6.4138733  1.87013749  20.1035768 4f631832-e...
    41: paleogeolo...  2.1603719  4.27590010   5.8961513 efe138c5-6...
    42: sopping_ur... -3.9462174  1.70808558 161.7055989 9d18f479-a...
    43: paleogeolo...  9.6847641  9.67260266  49.2954434 1c1136e3-5...
    44: sopping_ur...  3.2426148  5.62801227  12.2150145 52c3faba-a...
    45: paleogeolo...  1.7938459 14.07189018 118.3609562 575e8d7f-2...
    46: sopping_ur...  7.5566056  6.63551908  40.7500422 6490f652-9...
    47: paleogeolo...  3.2724976  0.07759352   4.8796850 fb93e775-e...
    48: sopping_ur... -3.7006766  6.94434352  46.9464036 6fd8edc1-e...
    49: paleogeolo... -0.7613002  4.60580710  24.1375685 f0930685-d...
    50: sopping_ur...  5.7488518 12.40411102 145.5976309 d5db8ba8-0...
    51: paleogeolo...  5.6243751 14.16977824 187.4954441 ee599489-f...
    52: sopping_ur...  0.1184713 14.31786981  91.8631895 569971ad-7...
    53: paleogeolo... -1.1033235 13.92560669  50.4754103 257bac79-f...
    54: sopping_ur... -3.9284924  6.09602089  69.6442926 ca3e606c-c...
    55: paleogeolo... -1.5232166 11.75996919  19.6737604 9f1a3ebe-6...
    56: sopping_ur...  6.8292271  0.79140411  18.3386944 e0567f0e-a...
    57: paleogeolo...  4.3284745  5.14339770  19.4501735 620300bf-0...
    58: sopping_ur... -0.4800613  3.71729699  27.9817039 2e98a75b-2...
    59: paleogeolo...  8.3252954 12.33618418 118.6891862 d96ca202-1...
    60: sopping_ur...  7.6493619  1.27172391  11.9638407 bda08d26-4...
    61: paleogeolo...  9.5908231  7.71408544  26.4936775 381e369d-e...
    62: sopping_ur...  6.4964599  0.87981834  19.4387756 ffd5a6f9-d...
    63: paleogeolo...  9.0416937  9.60839596  56.4114419 8e6b6a12-3...
    64: sopping_ur... -1.1809160  8.97684986  14.4908195 1d711a20-2...
    65: paleogeolo...  5.0904583  4.14023504  21.9220825 fb47b928-c...
    66: sopping_ur...  1.5669612 10.92576063  60.4817834 761290cf-d...
    67: paleogeolo...  6.0116274  0.94142086  19.2756635 1cda721f-0...
    68: sopping_ur...  4.7563055  6.58769054  37.8280035 23918b0c-5...
    69: paleogeolo...  3.2931054  1.27135769   1.2972324 c3feb271-5...
    70: sopping_ur... -1.4444071  8.59360482  11.2110126 b5f6c3b9-5...
    71: paleogeolo...  2.9409107 10.96706012  73.3575286 0f04dd87-e...
    72: sopping_ur... -4.3228285  8.72254557  49.5379139 a59fb549-6...
    73: paleogeolo...  1.4890107  6.63705065  18.1853586 a9f12494-5...
    74: sopping_ur...  7.0741999  4.07017520  24.9549200 ff8e296f-3...
    75: paleogeolo...  0.4903750  6.45830294  19.9290898 74734748-8...
    76: sopping_ur...  2.9864090  4.15847381   3.6085565 02623b4d-2...
    77: paleogeolo...  7.9393688  3.33742054  12.5313045 007b79ed-d...
    78: sopping_ur... -3.0188905 13.89875770   4.1438013 3c1a2341-f...
    79: paleogeolo...  6.3278894  0.78986044  19.6897517 6d4a4dc5-e...
    80: sopping_ur...  9.2533444  6.20055973  15.4874666 68c07fa8-1...
    81: paleogeolo... -3.2469814  7.06056959  30.3626500 149dd18d-3...
    82: sopping_ur... -0.3713055  5.58490435  19.9960549 d4d3505d-3...
    83: paleogeolo...  3.2250393  7.10996104  24.4328539 1acea9cd-1...
    84: paleogeolo... -2.9327253  1.22083181 112.0746807 4436843c-e...
    85: sopping_ur... -4.6490960 14.31764625  12.9038837 688a3cf8-6...
    86: paleogeolo...  8.4014883  2.73084663   5.9692715 7290bd8e-5...
    87: sopping_ur... -4.3088876 11.38823904  21.1918158 d686ae73-b...
    88: paleogeolo...  6.2728264  2.02924053  20.4656726 be5f6b28-9...
    89: sopping_ur...  2.6740315  0.25847852   7.2336638 93e8e60d-4...
    90: paleogeolo...  4.8259038 10.97568037 104.1661802 6440016c-7...
    91: sopping_ur...  1.2702231 13.08406359  92.0039612 50254962-0...
    92: paleogeolo... -2.0905154  2.02442920  67.1256293 6abd68c9-d...
    93: sopping_ur... -0.3988672  9.20688899  25.3586130 831ca1e6-b...
    94: paleogeolo...  9.3701923  3.93748407   2.6866852 ff2eaf4a-9...
    95: sopping_ur... -0.2443057 14.96841398  92.7940927 01a47b2a-d...
    96: paleogeolo...  9.6671002 14.21498799 133.5731748 3a290125-b...
    97: sopping_ur...  8.7709109 14.80946406 167.0074337 6b96509f-0...
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
    1: sopping_ur...  8821 runnervm7b...     FALSE terminated
    2: paleogeolo...  8823 runnervm7b...     FALSE terminated

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

    [1] "semiphilosophical_kangaroo" "ventriloquial_harpyeagle"  

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
    1: unkindhear...  9074 runnervm7b...     FALSE running
    2: unchildlik...  9076 runnervm7b...     FALSE running

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
    1: unkindhear...  9074 runnervm7b...     FALSE running
    2: unchildlik...  9076 runnervm7b...     FALSE running

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
