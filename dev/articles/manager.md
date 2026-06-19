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
    1: zebraprint...  8884 runnervm7b...     FALSE running
    2: juice_elep...  8882 runnervm7b...     FALSE running

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
    1: juice_elep...  8882 runnervm7b...     FALSE    running
    2: zebraprint...  8884 runnervm7b...     FALSE terminated

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

            worker_id          x1         x2          y          keys
               <char>       <num>      <num>      <num>        <char>
     1: broad_tape...  3.02597419  1.5650505   1.104946 b2e73bb6-2...
     2: broad_tape...  5.69857849  9.9841653  96.482686 0513e6a3-1...
     3: broad_tape... -3.74478018 12.6528261   3.344025 150141ee-8...
     4: broad_tape...  6.90243310  6.9379639  51.097214 fb747918-5...
     5: broad_tape... -2.49737831  1.3764941  90.756086 d4358566-1...
     6: broad_tape... -4.96054221  7.4074413 105.796685 d6eac8e0-2...
     7: broad_tape... -3.21031310  3.2691968  84.538155 8682874d-d...
     8: broad_tape... -3.69419759 10.6608892  10.717017 a97a0ae3-8...
     9: broad_tape... -2.06090519  0.8954838  85.282815 cc20ee96-1...
    10: broad_tape...  4.23200038  0.2487153   7.330256 c2d4d8b9-0...
    11: broad_tape...  4.82633046  5.0282275  24.784792 8e58410d-f...
    12: broad_tape...  5.35233817  7.6117730  57.071999 79f78062-0...
    13: broad_tape...  5.32037768 13.8038072 174.615565 3b718e45-0...
    14: broad_tape...  6.02925653  9.0532349  82.544218 ce4d3f64-8...
    15: broad_tape...  4.59912308  1.8152734   9.076741 5cae0c68-5...
    16: broad_tape...  6.59530005  9.3980541  87.622671 25aeee66-0...
    17: broad_tape...  8.52011067  5.8966418  20.704808 e72366ae-3...
    18: broad_tape...  3.09658505  9.1917616  47.761281 bed0e0c5-d...
    19: broad_tape...  6.64418375  8.7152449  76.544540 61c1d487-3...
    20: broad_tape...  8.65312728  7.0673386  29.808447 2f51a835-7...
    21: broad_tape...  0.03379168  5.3268487  19.980433 e6880704-d...
    22: broad_tape...  4.46611654 14.0586554 166.166213 212f43c8-a...
    23: broad_tape... -2.86420421  2.4543823  84.742494 ee375ad7-0...
    24: broad_tape...  3.84358439  7.2461410  32.424545 bfb7159e-7...
    25: broad_tape... -1.31989228  5.0799298  22.919218 ccd80e87-7...
    26: broad_tape...  4.17709842  8.6022814  54.050391 32bb1402-e...
    27: broad_tape...  8.69650741 11.2718530  90.118760 d6c33897-c...
    28: broad_tape... -4.31636400 11.5827392  19.940133 52678bd7-b...
    29: broad_tape...  1.55438591  8.9596984  36.386877 6a5e4c85-f...
    30: broad_tape... -2.67751670  9.8628053   3.168362 e70e2908-1...
    31: broad_tape...  2.85816907  3.8849664   2.681400 0d689d28-6...
    32: broad_tape...  8.08906554  2.0682478   8.003011 743434f3-8...
    33: broad_tape...  6.55711182  0.2925000  19.926241 e9e51942-c...
    34: broad_tape...  4.89675782  5.4617389  29.045575 240a271b-f...
    35: broad_tape... -1.48332576  5.9370489  18.171967 385c30f6-6...
    36: broad_tape...  2.40515619  5.2929223   8.519825 19e8cb72-a...
    37: broad_tape... -4.35920828  7.5032843  68.922445 4ec7bc36-2...
    38: broad_tape... -3.44389035  6.4194439  44.312223 ef112864-e...
    39: broad_tape... -1.11148970 10.7444482  22.185950 87634edb-3...
    40: antischool...  4.00268068 12.2412105 114.875877 c8a63fce-5...
    41: broad_tape...  3.92082016  4.8170372  12.601303 276950f7-f...
    42: antischool...  2.63623114 12.6160866  99.885222 ff173515-a...
    43: broad_tape...  9.44686051 12.9758949 110.276847 54374251-d...
    44: broad_tape...  8.12060114  8.1992502  51.091172 142ff066-c...
    45: antischool...  9.80153646  0.3513370   7.121996 275012cc-4...
    46: antischool...  5.88112594  2.7223255  21.442185 0e340d30-1...
    47: broad_tape... -1.80383975 11.7277033  13.718817 0125181f-d...
    48: antischool...  6.04542919  3.1999039  23.742706 04c29662-e...
    49: broad_tape...  7.17206615 13.1527101 158.194373 5da23e3c-3...
    50: antischool... -1.14064148  0.1626922  75.168670 c133be57-b...
    51: broad_tape...  4.58496585  9.9350600  81.311476 017e0c39-e...
    52: antischool... -0.73591215  0.5594185  61.763504 05b3545e-e...
    53: broad_tape...  4.89913044  7.6596550  52.184546 c65cd0df-6...
    54: broad_tape...  0.91325102  4.1705206  16.102582 46af9698-b...
    55: antischool... -0.86167088  8.2711832  16.898825 a912e780-0...
    56: broad_tape...  6.18200419 10.3573597 105.286859 f2796036-6...
    57: antischool... -1.06435705 13.2883683  44.338847 982b2f11-b...
    58: antischool...  6.87200587  5.1441397  33.830317 3a2e7563-c...
    59: broad_tape...  5.09702456  0.1196239  14.867146 da019db0-3...
    60: broad_tape... -3.51272294  0.1233502 171.650702 d454c15e-8...
    61: antischool... -4.87170729  5.8315660 132.259509 d544ca20-6...
    62: broad_tape...  3.55471616 11.2455635  87.151461 051e2385-5...
    63: antischool...  4.45646320  7.4346365  43.111240 b7f10dca-6...
    64: broad_tape...  4.18472393  4.7910888  15.334991 17264a9c-2...
    65: antischool... -3.21428488  3.2445535  85.170478 49d28cf5-f...
    66: antischool... -1.48502608  5.0698937  23.628154 78514874-f...
    67: broad_tape...  8.42314338  7.7082814  40.210706 8895f50c-c...
    68: broad_tape...  3.62356665  5.8426187  16.807079 fa56a19d-d...
    69: antischool... -0.97015838  1.6737861  51.329182 bfe72a4e-3...
    70: antischool... -4.16720645  9.2401646  36.779658 3ec0b332-e...
    71: broad_tape...  6.96840425  1.4479799  17.505226 b6b6b024-e...
    72: antischool...  5.35846727  5.0332365  30.620529 a84ee4bd-8...
    73: broad_tape...  0.15485149  6.9209230  20.842764 f85812eb-1...
    74: antischool...  2.65766938  9.2602141  44.764856 43b98128-d...
    75: broad_tape...  5.17446709  3.3734262  18.902854 5ce05e95-3...
    76: antischool...  3.26373105  5.1191285   9.098044 cc9cd588-6...
    77: broad_tape...  7.08628676  2.9199019  19.596044 9a61ddb2-5...
    78: antischool...  1.20730976 13.9638792 107.447122 5806a821-d...
    79: broad_tape...  4.73573076  7.1555697  43.811692 07b10c05-5...
    80: broad_tape...  5.40481718  7.7888181  59.916179 fcf84f46-e...
    81: antischool...  4.68255612 12.4261047 131.729508 c26fce8a-7...
    82: broad_tape...  5.50337276 13.6549171 173.107070 9b07a4e8-5...
    83: antischool... -2.51160911  6.2550571  23.009318 11666955-b...
    84: broad_tape...  1.33090753  1.0608519  21.582504 2cfd267c-e...
    85: antischool...  7.04312138  6.1911785  41.884284 c465485c-6...
    86: antischool...  4.15632204  8.3948289  50.874936 0a6a00ac-4...
    87: broad_tape... -0.64073265  2.1089538  42.337309 ffacfbf1-a...
    88: broad_tape...  5.87608770  5.8064455  40.888519 200b2311-1...
    89: antischool...  8.96949255 14.7959701 162.113643 167d4df8-3...
            worker_id          x1         x2          y          keys
               <char>       <num>      <num>      <num>        <char>

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
    1: antischool...  8882 runnervm7b...     FALSE terminated
    2: broad_tape...  8884 runnervm7b...     FALSE terminated

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

    [1] "amphisbaenoid_lamb" "genealogical_yeti" 

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
    1: submissive...  9134 runnervm7b...     FALSE running
    2: imparisyll...  9136 runnervm7b...     FALSE running

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
    1: submissive...  9134 runnervm7b...     FALSE running
    2: imparisyll...  9136 runnervm7b...     FALSE running

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
