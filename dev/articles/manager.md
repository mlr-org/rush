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
    1: dirgeful_c...  9177 runnervm1l...     FALSE running
    2: lexicograp...  9179 runnervm1l...     FALSE running

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
    1: dirgeful_c...  9177 runnervm1l...     FALSE    running
    2: lexicograp...  9179 runnervm1l...     FALSE terminated

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

            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>
     1: gnarled_no... -2.04475062 13.08167886  16.4234376 fe998585-a...
     2: gnarled_no...  1.37005464  2.19799317  15.3890568 10122abc-1...
     3: gnarled_no...  6.99697563  9.44029353  85.3495413 9c2a65bd-6...
     4: gnarled_no...  5.16307785  1.06608514  14.2082524 6b5b6815-0...
     5: gnarled_no...  8.76437586  3.35087623   4.3117956 4e5d9794-e...
     6: gnarled_no... -4.11451899 11.13550812  17.5547809 4091e407-c...
     7: gnarled_no... -0.81118206  2.83639841  37.2207788 55a88b39-7...
     8: gnarled_no... -2.98144221 13.35182324   2.6476635 e3901bc3-d...
     9: gnarled_no... -0.85120908  2.18591484  44.0216544 96bbbca3-c...
    10: gnarled_no...  6.44064756 12.60848547 151.7395349 94b90dd9-7...
    11: gnarled_no...  1.47756854  2.99069999  11.7769489 62b1e5ba-5...
    12: gnarled_no...  5.01685541 13.00634595 150.6943119 96b58318-9...
    13: gnarled_no... -2.85726177  0.04640181 134.3182368 63638f32-4...
    14: gnarled_no... -3.16275069  6.55426178  33.7119096 7a5254a8-f...
    15: gnarled_no... -3.37485279 10.24792036   7.3903409 32bd51b0-6...
    16: gnarled_no... -1.84687743 11.40704032  11.4913190 c7b0943b-d...
    17: gnarled_no... -2.61190428 14.60944200  14.4669353 c5eff6db-8...
    18: gnarled_no...  7.59506046 11.87145310 122.8632477 669225ba-2...
    19: gnarled_no...  3.37311004  1.05483182   1.7493272 8008008d-3...
    20: gnarled_no...  5.29483334 14.64462753 196.1814856 ebc12070-2...
    21: gnarled_no...  7.82093010  1.73733934  10.3973471 b7c4cf6a-4...
    22: gnarled_no...  3.14382517 12.70960240 109.3151625 670af8aa-b...
    23: gnarled_no... -1.67978552  1.16539553  70.9331139 f46de360-b...
    24: gnarled_no...  4.04041424  7.90691606  42.8166431 5e20e9c4-b...
    25: gnarled_no... -1.56390290  9.48695981  10.5312775 c5aad4a0-9...
    26: gnarled_no... -1.82684739 10.92807357  10.0943991 d20cd981-6...
    27: gnarled_no...  8.69391946  4.63813432  10.1977366 212e6fbc-5...
    28: gnarled_no... -4.48091967  5.57461531 110.8367367 d0fb6c8d-d...
    29: gnarled_no... -3.70913479 10.29209591  13.3848860 6851a405-1...
    30: gnarled_no...  3.08061439  4.26551046   4.1889455 78fda796-2...
    31: gnarled_no...  5.43372459 13.94481331 179.6346363 61009c6e-6...
    32: gnarled_no...  1.43419957  8.88562444  35.3420552 3831a9f2-5...
    33: gnarled_no... -2.15936782  6.29255705  18.7058293 1d499694-d...
    34: gnarled_no...  3.15491148 10.79063119  73.0913311 6d4020bf-d...
    35: gnarled_no...  7.08784776 12.26099090 138.7984725 eabcca28-b...
    36: gnarled_no...  8.91793785 11.61109822  92.4343784 946d173e-9...
    37: feathery_v...  4.75416410  4.56189210  20.6957490 35a87b5d-3...
    38: gnarled_no...  1.67200320 11.52928455  70.3264309 18e021a5-2...
    39: feathery_v...  1.11529105  7.19949197  22.1418397 d8995a33-9...
    40: gnarled_no...  3.91717586 11.38078037  95.9370740 b536c47e-b...
    41: feathery_v...  4.64339795  9.35434656  72.6865810 ca7c0695-6...
    42: gnarled_no... -4.74093952  7.35413468  92.9917057 a190501c-e...
    43: feathery_v... -0.32141529 14.88556769  89.0112444 81b00500-3...
    44: gnarled_no...  1.48620386 11.93093648  74.9867844 15bdbe96-c...
    45: feathery_v...  0.44914274 10.31021985  43.6396971 6b2c454e-8...
    46: gnarled_no... -2.23020239  5.09899970  30.0561002 84be1fc8-5...
    47: feathery_v... -1.24904352  7.71714036  13.2595577 1ccb5968-6...
    48: gnarled_no...  8.05821861  5.63797416  24.6536082 16281ecb-c...
    49: feathery_v...  5.47433793  8.54142611  71.1322572 d037a406-7...
    50: gnarled_no...  1.78784335 13.64295530 109.4473731 76662d57-d...
    51: feathery_v... -3.89826258  3.50952248 116.6089106 0f6bcf7b-6...
    52: gnarled_no... -2.92660917 10.68940476   1.7743583 6da5f552-9...
    53: feathery_v... -2.96214457  3.89520617  63.7974647 7ab46b35-f...
    54: gnarled_no...  2.21544459  8.51926880  33.5109625 40a4e86d-2...
    55: feathery_v...  4.87927704 13.87105664 169.3769645 db85dcb4-c...
    56: gnarled_no...  2.51864293  0.35383597   8.2389244 d2423a1a-c...
    57: feathery_v...  2.84574382  7.72154907  27.9020957 9e915b46-c...
    58: gnarled_no...  5.73872428  6.89568036  51.5610543 b1c7964f-e...
    59: feathery_v...  4.46197909 11.89653736 116.3226875 09148907-0...
    60: gnarled_no...  7.98907495 14.31567952 172.1743587 65f70291-7...
    61: feathery_v... -2.05795606  0.95438848  84.1477509 c37fd234-4...
    62: gnarled_no...  0.99949370  9.29819011  37.8485915 26589c1a-c...
    63: feathery_v...  8.36139723  4.07001462  10.8374799 0630f94f-0...
    64: gnarled_no... -0.25190674 13.64603260  71.6719682 b7294c8d-2...
    65: feathery_v...  8.10505660  0.13589923   9.7194637 50126745-e...
    66: gnarled_no...  5.45363000 12.13968183 136.9820293 202b2e43-1...
    67: feathery_v...  1.24509917 12.55582365  82.5811091 d922c717-2...
    68: gnarled_no...  2.89161166  0.14798366   6.1254310 8e9442e9-5...
    69: feathery_v... -0.55727073 14.98375689  83.0599801 f1054418-d...
    70: gnarled_no...  5.58648582  1.54239981  17.5259780 62a74c43-6...
    71: feathery_v...  5.22469036 14.40079257 188.6761978 01016582-3...
    72: gnarled_no...  7.42419976  7.01524394  46.6134559 35df75e0-7...
    73: feathery_v...  2.75275536 11.17469092  74.6782473 44e406f0-a...
    74: gnarled_no...  7.13204532  5.39330410  33.7610372 04558d48-b...
    75: feathery_v... -1.97579851  3.81414579  40.2607950 022ce5f3-4...
    76: gnarled_no...  0.15261858  2.40404763  30.7536492 96d0be81-9...
    77: feathery_v...  3.40187270 12.48111866 108.8885604 8e962e25-d...
    78: gnarled_no...  3.46390471  0.40443896   3.5578015 b51026f4-7...
    79: feathery_v...  0.59314632  5.87776636  18.5646389 011d943f-9...
    80: gnarled_no...  3.87464346 10.95478278  87.1741818 485ba2bc-7...
    81: feathery_v...  7.25376176  0.69846062  15.7305609 40ce92cf-d...
    82: gnarled_no... -4.30652540 14.65384354   6.5642804 51e67285-1...
    83: feathery_v...  0.05242458  9.67186158  33.6885165 d908dc53-1...
    84: gnarled_no...  0.70009100  3.80631981  18.6494557 fc1fd435-2...
    85: feathery_v... -2.66087571 10.44211126   1.9866610 06f3b864-4...
    86: gnarled_no...  7.73588952  9.17241846  71.2488839 e3daf4ed-3...
    87: feathery_v...  1.43573374  1.15571791  19.2765834 55eefa11-4...
    88: gnarled_no... -2.05609944  9.24745007   5.8469578 add16ba6-0...
    89: feathery_v... -2.99397676 12.14679426   0.5523724 955f560b-0...
    90: gnarled_no... -0.58405325 11.30418050  36.7641956 6f524ee5-b...
    91: feathery_v...  9.44485200  7.15664494  22.1588749 ec146a18-3...
    92: gnarled_no... -2.59631322  7.87003050  11.6056929 48ae3ece-f...
    93: feathery_v... -1.59533878 11.93405714  19.1659981 140799e6-6...
    94: gnarled_no...  5.20715207  4.82040820  27.5559320 f78272fd-c...
    95: feathery_v... -3.76046199  0.21121048 187.1539334 524e3916-7...
            worker_id          x1          x2           y          keys
               <char>       <num>       <num>       <num>        <char>

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
    1: gnarled_no...  9179 runnervm1l...     FALSE terminated
    2: feathery_v...  9177 runnervm1l...     FALSE terminated

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

    [1] "colossal_pinniped" "sacrilegious_joey"

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
    1: dialectica...  9430 runnervm1l...     FALSE running
    2: refillable...  9432 runnervm1l...     FALSE running

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
    1: dialectica...  9430 runnervm1l...     FALSE running
    2: refillable...  9432 runnervm1l...     FALSE running

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
