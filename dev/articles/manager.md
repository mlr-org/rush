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
    1: sane_paddl...  9039 runnervm1l...     FALSE running
    2: burgundy_w...  9041 runnervm1l...     FALSE running

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
    1: burgundy_w...  9041 runnervm1l...     FALSE    running
    2: sane_paddl...  9039 runnervm1l...     FALSE terminated

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
     1: semidivine... -0.2833472  6.76794435  19.3132396 3ee21703-e...
     2: semidivine... -4.9569626 10.95089004  49.6891469 17ae9609-f...
     3: semidivine...  9.6956916 10.07402572  54.9327659 03433356-2...
     4: semidivine...  5.0157585  1.16648436  12.8786503 94452f67-e...
     5: semidivine...  5.4332929 11.73554864 128.0478861 213e3a78-c...
     6: semidivine... -1.3503115 14.28305142  46.8913242 f926ca61-8...
     7: semidivine...  7.7214148  5.02861809  24.3418983 8849206f-7...
     8: semidivine... -4.0585681 13.57212779   5.1904146 10479e40-2...
     9: semidivine...  6.4597954  0.22222351  20.2402788 f13732ab-e...
    10: semidivine...  0.4185283  1.16214674  36.3661050 9317558f-4...
    11: semidivine... -1.8095164 10.72639797   9.7557531 ac92a9d2-6...
    12: semidivine... -4.7547413  7.64515022  88.6017096 d95453eb-e...
    13: semidivine...  4.3461195  4.00224565  12.7074579 5620030f-2...
    14: semidivine...  9.9683882  4.36186342   3.7145535 6c23e02f-8...
    15: semidivine...  3.6549149  8.34986824  43.1238063 6ac51008-0...
    16: semidivine... -3.1856972  6.03227798  40.7166078 ec2ffd1e-b...
    17: semidivine...  5.9117852  1.11796010  18.9475851 f1a85950-a...
    18: semidivine... -3.2005112 12.57089740   0.4382198 58cff614-0...
    19: semidivine... -1.0209754 11.72691602  30.7570841 61ec9063-5...
    20: semidivine...  4.5266050  8.05470346  51.9449851 1d3119a7-9...
    21: semidivine...  9.7066899  0.52831622   5.5938525 751a1b25-4...
    22: semidivine... -1.5384867 10.31393187  12.7424829 e3baeb99-5...
    23: semidivine...  5.1761878 13.89748497 174.9362503 d9cd3508-1...
    24: semidivine... -2.6266022  6.87066999  19.2912550 d837f44a-5...
    25: semidivine... -1.6667550 14.42313517  38.3646453 da252040-f...
    26: semidivine... -3.0882843  3.59527482  73.5478807 6cf08af2-b...
    27: semidivine... -4.9958958  3.52001178 199.1590685 90526649-a...
    28: semidivine... -2.4487712  4.98720857  34.9284556 7320c16c-5...
    29: semidivine...  4.7545480 11.70333534 117.5297581 3560d7a6-8...
    30: semidivine... -0.7435737 13.50474373  56.1287131 f91a889f-0...
    31: semidivine...  7.1814250 10.44563551 100.8579257 424b1d7e-7...
    32: semidivine... -3.8646546  0.43305854 189.0458186 240acf54-3...
    33: semidivine...  6.0825555  2.89588653  22.6389771 93ee6044-1...
    34: semidivine...  1.5505597  5.03249929  11.6096913 0f738b7f-9...
    35: semidivine... -2.0757565 10.97980613   6.6080669 27341509-a...
    36: foil_rhino... -2.9147817  3.13538729  74.6240616 0bb58e08-1...
    37: semidivine... -0.6742726  2.93857128  35.0845621 b6de44fa-7...
    38: foil_rhino...  7.6969739 10.59442310  95.9797066 c283b179-6...
    39: semidivine...  8.6103636 10.17349713  72.2966149 5ed1e576-b...
    40: foil_rhino...  9.9360201  5.64570711   8.9464438 ea5d78fe-e...
    41: semidivine...  3.2128517 11.78199585  91.8524148 e07690fb-8...
    42: foil_rhino... -4.7523848 10.18115461  50.0758782 b41313f1-c...
    43: semidivine...  6.4608252 12.66458929 152.9657589 ce0f7429-9...
    44: foil_rhino...  0.1091271  9.88643808  36.0170736 3349a9ab-6...
    45: semidivine...  9.9011681  0.22938842   8.6321476 2af5c092-3...
    46: foil_rhino...  5.7168460 13.69894002 176.2469591 771c977a-8...
    47: semidivine...  0.4302104 10.01793901  40.6176682 78eeb4cb-e...
    48: foil_rhino...  9.2637236 10.48097329  66.7569296 4cee30a3-0...
    49: semidivine...  8.9481468  1.51168030   1.8169163 d040787e-5...
    50: foil_rhino... -4.0331857  7.48523498  53.4618320 fe6390d6-c...
    51: semidivine... -1.6569626  3.77474277  36.3915106 e0760693-b...
    52: foil_rhino...  7.9147783  4.01894866  15.7826763 00a56829-c...
    53: semidivine...  9.9966000 10.90778048  64.4649847 e267d7fb-e...
    54: foil_rhino...  1.4234870  3.20688514  12.0324175 93df212e-d...
    55: semidivine... -1.7049315  2.26812188  55.2401903 9c4a1e80-a...
    56: foil_rhino... -4.5256263  0.63664880 239.6212760 670eec36-5...
    57: semidivine...  7.2383837  7.38993536  53.2647213 85c5ed40-d...
    58: semidivine...  6.5832869  6.91698682  52.7642558 f40ef8b1-a...
    59: foil_rhino...  7.7634592 13.96435183 167.9732556 09bd3ffa-4...
    60: semidivine...  0.9407032  4.06670489  15.9607385 dc1fb75b-f...
    61: foil_rhino...  1.4399263 12.02880637  76.0985495 8413ef94-7...
    62: semidivine...  6.1628063 11.93026177 136.8696472 2b1a3cd3-d...
    63: foil_rhino... -3.8721078 10.68339791  14.5180949 d8a07ad6-0...
    64: foil_rhino... -2.4842691  4.76422404  38.2414952 c2767b5a-1...
    65: semidivine...  9.3480211  2.15867146   0.4898367 4f5bb581-5...
    66: foil_rhino...  8.2523095 13.95238759 157.2902070 8d60bd32-e...
    67: semidivine... -2.5625919  6.20902232  24.2206508 c2189426-a...
    68: foil_rhino... -0.4603834  7.17475369  18.7742962 1ec24e16-c...
    69: semidivine...  1.8266970  4.02113314   7.8168965 1acce885-d...
    70: foil_rhino...  6.5506244 10.47710062 106.8581605 cb834f6d-e...
    71: semidivine...  7.2815053  2.25376505  16.1881302 951388f2-a...
    72: semidivine... -3.4836607 13.11165424   0.9542054 4472c845-c...
    73: foil_rhino...  2.2599797  2.17544487   4.6815984 ca728e25-6...
    74: foil_rhino... -0.5491356 12.56548990  50.1417814 921a37ec-0...
    75: semidivine...  8.3437838  7.56747492  39.7444734 65861737-e...
    76: foil_rhino...  4.4613348  8.86052985  62.2228467 7b80cb2e-7...
    77: semidivine...  8.7230476 13.46904069 135.4311947 62daec9b-c...
    78: semidivine... -4.7691915  8.08511300  81.8397978 b00544c6-9...
    79: foil_rhino...  6.5577161 12.40542282 146.6377320 7cef4c29-3...
    80: foil_rhino...  9.6898300  6.79780722  17.4625691 427d5278-f...
    81: semidivine...  6.0924023  8.94485610  80.9911678 573c4ea1-f...
    82: foil_rhino...  9.0875630  6.79151667  21.9725948 de6df652-9...
    83: semidivine...  8.3037773  5.57229655  20.8838126 77d1d308-7...
    84: foil_rhino... -3.1112686  8.72208844  12.5137765 7534b635-b...
    85: semidivine... -2.3290203  9.35961229   4.4953200 61489510-c...
    86: foil_rhino...  9.4206024  7.55832709  26.2739840 8c988652-5...
    87: semidivine...  8.6898905 12.63242071 117.5276859 70431ab3-8...
    88: foil_rhino...  9.3154008 10.18220057  61.2627776 c49b11dc-f...
    89: semidivine... -4.3678593  0.74366048 222.0423498 a14ce303-b...
    90: semidivine... -1.3505529  0.02135567  82.0500220 f003991a-3...
    91: foil_rhino...  6.4679351  1.64720822  19.7269873 56a5cb11-9...
    92: semidivine... -4.0188825  9.50094643  28.6804650 6bc17eeb-b...
    93: foil_rhino...  6.5172477  4.99719430  34.4153834 5d67f7e3-3...
    94: foil_rhino... -3.8795396  2.37946045 140.7082594 1921bad1-9...
    95: semidivine... -4.5304951  5.42886835 117.1147211 c970acb8-3...
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
    1: semidivine...  9039 runnervm1l...     FALSE terminated
    2: foil_rhino...  9041 runnervm1l...     FALSE terminated

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

    [1] "vanillic_collardlizard"   "highbred_northernfurseal"

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
    1: cadaverous...  9293 runnervm1l...     FALSE running
    2: herringlik...  9295 runnervm1l...     FALSE running

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
    1: cadaverous...  9293 runnervm1l...     FALSE running
    2: herringlik...  9295 runnervm1l...     FALSE running

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
