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
    1: econometri...  9013 runnervm1l...     FALSE running
    2: unreligion...  9011 runnervm1l...     FALSE running

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
    1: econometri...  9013 runnervm1l...     FALSE    running
    2: unreligion...  9011 runnervm1l...     FALSE terminated

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

             worker_id         x1         x2          y          keys
                <char>      <num>      <num>      <num>        <char>
      1: paralytic_...  6.1433827  6.0987753  44.515435 8a81a195-e...
      2: paralytic_...  2.2479395  0.2163456  12.156046 1cdb4abe-0...
      3: paralytic_...  3.5025575  2.3281699   1.117703 f215732f-1...
      4: paralytic_... -1.6733068  3.2801130  42.019540 613ed3d5-0...
      5: paralytic_...  9.0501144  9.1988443  50.368910 f2eddc9a-b...
      6: paralytic_... -1.7919045  0.7951360  79.661648 08cd4582-4...
      7: paralytic_... -1.7316772 10.0244191   9.237990 934926ae-4...
      8: paralytic_... -0.9034127  0.3516353  67.662538 c594abed-d...
      9: paralytic_... -4.3550265  1.5723120 197.331673 8ffcdb3b-4...
     10: paralytic_...  9.2845495  9.0066419  44.679898 43a05645-6...
     11: paralytic_...  7.2431722  0.9969618  15.570938 ec93c9bf-e...
     12: paralytic_...  3.0818369 13.8321580 132.897326 d644c8dd-f...
     13: paralytic_...  6.4097460  8.4665419  73.701452 b82a8ffc-d...
     14: paralytic_...  0.8667493 10.2502578  46.826089 971d1e3f-e...
     15: paralytic_... -3.0288583  3.9917924  64.681783 dcd92fac-5...
     16: paralytic_...  1.1108120  9.9084391  44.699443 b2c6dcb4-8...
     17: paralytic_... -0.9191246 11.4049532  30.515631 e176a58d-7...
     18: paralytic_... -3.3357273  2.0400748 115.204112 9c715640-4...
     19: paralytic_...  4.1544376 14.4446767 169.448830 78fa0522-c...
     20: paralytic_... -4.1129685  1.7827096 172.249958 390873e5-c...
     21: paralytic_...  1.8814986  8.3121842  30.580705 eb66c0ff-6...
     22: paralytic_...  8.8490649 11.6273131  94.012067 ad2196f1-d...
     23: paralytic_...  5.3398517  0.9684671  15.684187 c22eedfb-c...
     24: paralytic_... -2.8487642  6.7130688  24.516443 003e0d3e-9...
     25: paralytic_...  4.2702760  6.5927827  31.227104 daa6532d-4...
     26: paralytic_...  2.3905817 13.2862987 110.160367 d4d4b06b-f...
     27: paralytic_...  2.5738708 10.7144659  65.187575 fa0fb7a5-a...
     28: paralytic_...  1.3523820  8.0500694  27.811202 683a9f98-5...
     29: paralytic_... -0.2826503  7.0174198  19.531622 dcb964e7-5...
     30: paralytic_... -2.2044921  7.8992422   9.319058 34173bcb-e...
     31: paralytic_...  7.6581870  7.9521534  54.956061 0d158b9c-a...
     32: paralytic_... -0.8754054  7.7203065  16.203946 61e8b9cc-a...
     33: paralytic_... -1.8867172  3.3798423  44.017397 dd1b4478-7...
     34: paralytic_...  8.2363200  7.1432277  36.538458 9cd2d78e-d...
     35: paralytic_...  6.8847241  3.5512949  23.606756 423d377e-5...
     36: paralytic_... -2.2886511 13.2393681  12.211630 f438b79d-e...
     37: configurat...  4.8334625  3.4677458  15.749538 53755562-5...
     38: paralytic_...  4.4842074  6.5456905  33.683853 d12f2768-b...
     39: configurat...  7.7172691  2.9196619  13.583713 b6b2daf3-c...
     40: paralytic_...  3.7741450 12.6885846 120.090991 424ab742-b...
     41: configurat...  4.8053256  9.9072469  84.372701 980b3447-7...
     42: paralytic_...  3.3478637  3.1206481   1.603467 ec98a9b0-5...
     43: paralytic_...  7.4742345  5.8327758  33.913923 7216f1b7-7...
     44: configurat... -3.7019179  7.4700764  40.208061 69b0ff8c-b...
     45: paralytic_... -4.6507517 10.5752603  41.002325 e7ba911e-8...
     46: configurat... -1.8525464  9.3726255   7.330622 58a43085-2...
     47: paralytic_... -3.2670650  3.9189839  75.461873 d2ef2152-a...
     48: configurat...  8.7618705  9.5714954  60.174871 0d17a285-0...
     49: paralytic_...  1.7948616  4.9310635   9.747478 11e9654d-c...
     50: configurat...  7.8717743 14.6534442 183.458954 e53920bb-a...
     51: paralytic_...  4.1912874  9.5786430  68.898752 63fa6a15-4...
     52: configurat...  7.4991783  5.7802483  33.143002 350185a3-c...
     53: paralytic_... -3.8923611 14.1962309   2.981221 63766666-7...
     54: configurat...  9.5303088  9.2823186  45.567547 09de9071-2...
     55: paralytic_... -3.2350430 14.8245522   5.840019 7cf6191e-6...
     56: configurat...  7.0050833  6.2081886  42.386083 6dc7de4b-6...
     57: paralytic_...  8.1071845  2.6961257   8.822881 0a262520-a...
     58: configurat...  2.2819724  8.1051134  29.379291 b6b3c859-7...
     59: paralytic_...  9.0611373  1.2406239   1.918284 3dad5134-c...
     60: configurat...  3.8903263 14.6181007 168.206352 b8f52051-1...
     61: paralytic_...  7.1853958 14.3586970 188.213150 cc2e346a-f...
     62: configurat...  5.7015403  2.6597242  20.377936 cac93367-0...
     63: paralytic_...  0.7383443  3.9283732  18.036542 08ef24e4-f...
     64: configurat...  8.0100337  0.6773461   9.252155 2c1ef227-c...
     65: paralytic_... -1.4942415  0.1477524  83.305082 9eaa6e95-8...
     66: configurat... -0.2470375  4.5712580  22.658764 5f4aba7b-1...
     67: paralytic_... -4.2657094  6.4684332  81.044128 56badedd-b...
     68: configurat... -1.1195266  3.8301074  31.109158 b589d210-4...
     69: paralytic_...  7.3425918  2.6632733  16.616187 5134a12a-8...
     70: configurat...  6.6452899  0.4488452  19.441331 66bfc38d-2...
     71: paralytic_...  8.8774066  2.1495414   1.810316 3e5947b2-2...
     72: configurat...  1.2980511  8.0066753  27.446989 42d4c41e-8...
     73: paralytic_...  7.3104986  4.9192434  28.289445 364ff6ed-e...
     74: configurat...  3.4669617 14.8496276 165.118054 49030162-a...
     75: paralytic_... -0.7720086 12.2545789  41.371585 f3df9d5f-0...
     76: configurat...  6.5222039  8.9421943  80.594283 6fc2326a-2...
     77: paralytic_...  3.8207193 13.9422638 149.842571 9b03a65d-1...
     78: configurat... -3.0142498  9.0028858   9.285692 957db2c1-2...
     79: paralytic_... -1.9337619  1.8228159  66.466484 6dc24157-a...
     80: configurat...  8.4513835  9.2980707  61.175536 0ec7fb00-a...
     81: paralytic_...  1.9865367  1.0780886  11.275122 8b5c8766-6...
     82: configurat... -0.6976276  2.2006229  42.085088 3abbd5ad-3...
     83: configurat...  0.1962966  3.9677919  22.392542 d05e2516-1...
     84: paralytic_...  8.3928219 12.8778419 129.077598 df5a42cb-8...
     85: configurat...  4.7259252  6.0301562  31.905684 257c151b-8...
     86: paralytic_...  1.4859077  7.8386147  26.167058 d44d97bf-3...
     87: configurat... -4.7140811  9.0910186  63.050835 3a4ff804-f...
     88: paralytic_... -3.9083219  4.7486530  92.291327 99b250cf-0...
     89: configurat...  5.9548122  6.9766762  53.583520 de18e2ca-0...
     90: paralytic_...  6.1232675  7.0373275  54.752670 b30c20b3-7...
     91: configurat...  6.2891882  9.2235291  85.590485 14f38f81-f...
     92: paralytic_...  1.4905789 13.1529992  96.115688 420cc2a0-b...
     93: paralytic_...  7.5400357  5.0309930  26.558624 25779621-0...
     94: configurat...  4.2039183  3.4597407   8.812530 f2640aa8-c...
     95: configurat...  7.6331161  0.3597117  13.141269 e7d9bc07-4...
     96: paralytic_...  8.4641768  7.5118109  37.306480 b189b4ba-c...
     97: configurat... -0.9064956 14.9707726  71.004159 06c09bf7-d...
     98: paralytic_...  2.4644797 14.3257767 133.927981 5255f7ce-a...
     99: configurat...  7.1477743  6.4328658  43.362686 5d04cbf3-8...
    100: paralytic_...  6.4752213  3.2640400  24.061716 297452df-7...
             worker_id         x1         x2          y          keys
                <char>      <num>      <num>      <num>        <char>

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
    1: configurat...  9013 runnervm1l...     FALSE terminated
    2: paralytic_...  9011 runnervm1l...     FALSE terminated

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

    [1] "offended_frigatebird"    "rockbound_affenpinscher"

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
    1: citatory_c...  9268 runnervm1l...     FALSE running
    2: carefree_d...  9266 runnervm1l...     FALSE running

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
    1: citatory_c...  9268 runnervm1l...     FALSE running
    2: carefree_d...  9266 runnervm1l...     FALSE running

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
