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
    1: titanic_ge...  8861 runnervm5m...     FALSE running
    2: mountable_...  8859 runnervm5m...     FALSE running

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
    1: titanic_ge...  8861 runnervm5m...     FALSE    running
    2: mountable_...  8859 runnervm5m...     FALSE terminated

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

            worker_id          x1          x2          y          keys
               <char>       <num>       <num>      <num>        <char>
     1: nonsticky_...  2.17771979  4.37839780   6.040571 c273719f-c...
     2: nonsticky_...  1.57673880 10.81945324  59.051426 f8b52b83-9...
     3: nonsticky_...  2.72642227  8.69390972  38.093338 7c4e77f3-1...
     4: nonsticky_...  2.93382281  8.72248247  40.041221 3fec3f81-b...
     5: nonsticky_... -3.75935513 14.64246338   2.867358 6a251fb9-5...
     6: nonsticky_...  1.37698245 11.23840357  63.473546 69c4285f-4...
     7: nonsticky_... -3.68148073 14.41241649   2.407288 b510d821-0...
     8: nonsticky_... -0.28058376  0.49751780  54.738861 5b728ae5-9...
     9: nonsticky_...  3.02202679  6.64024008  18.700612 572a9172-1...
    10: nonsticky_...  0.59328965 10.75511279  49.927648 da9572b4-3...
    11: nonsticky_...  8.63271890  3.31461074   5.291086 9d0fd800-6...
    12: nonsticky_... -3.95534909  1.64329135 164.008084 c3facd83-a...
    13: nonsticky_...  9.74142210  6.89599904  18.022721 bad471bf-8...
    14: nonsticky_... -3.65857925  7.73151045  35.530518 eee24998-f...
    15: nonsticky_...  0.05027538  9.28977368  30.943260 d83dfc7e-2...
    16: nonsticky_... -4.20081041 10.31779847  26.900296 d2aa1deb-d...
    17: nonsticky_...  1.96468848  9.38451898  42.468198 4a3424f2-6...
    18: nonsticky_...  0.29010895  3.95866361  21.730513 f9c8c17d-e...
    19: nonsticky_...  3.20086956  7.90786459  32.661685 28a85d61-0...
    20: nonsticky_...  0.15467962 10.14677930  38.758420 dfafdcfd-8...
    21: nonsticky_... -4.60305998 12.54150526  21.354492 3148fbea-8...
    22: nonsticky_...  6.28731224  1.91276521  20.262401 9ad6756d-1...
    23: nonsticky_...  8.91295781  3.95597582   5.158492 a5c60d2a-c...
    24: nonsticky_...  8.09509432  0.83483354   8.265119 4eacc67e-c...
    25: nonsticky_...  5.75151230  6.80585718  50.610230 8d8d7c95-d...
    26: nonsticky_...  4.71125046  4.82487391  21.930916 b1ed1707-0...
    27: nonsticky_...  6.15545092 12.21403523 143.089193 cc630dbe-4...
    28: nonsticky_... -4.07574681  6.77635481  66.014161 7a3fad32-8...
    29: nonsticky_...  2.65993625  5.77041618  11.037332 232cb501-2...
    30: nonsticky_... -2.46374437  7.30758726  14.065311 cf9cd678-6...
    31: nonsticky_...  3.61104979  9.92572637  65.250691 4c2fe8e2-a...
    32: nonsticky_... -0.38692836 14.63309979  82.859353 cfa9bfea-2...
    33: nonsticky_...  6.04045368  6.90318912  52.998966 d9271232-1...
    34: nonsticky_... -1.33776291 11.51007150  22.138441 9f127cc8-7...
    35: ablaze_ban... -4.26908605  7.87576672  58.779317 16916f14-6...
    36: nonsticky_...  5.59343324 12.07682439 137.032060 c105e143-1...
    37: ablaze_ban...  6.95771690  9.85134903  92.687221 403d5cd7-f...
    38: nonsticky_...  5.93652589  7.36020204  58.164845 cebf72b6-a...
    39: ablaze_ban...  1.50413610  9.67790934  44.042757 cb21f4de-1...
    40: nonsticky_... -1.14863393  8.26073149  14.003052 c0041ecc-5...
    41: ablaze_ban...  7.29188917 14.79758095 198.287484 d9217ee6-b...
    42: nonsticky_...  7.05821923 13.28666412 162.892345 a3b66062-1...
    43: nonsticky_... -2.83928827  6.95312527  22.059337 6a8d26c2-7...
    44: ablaze_ban...  6.64008864  2.66798229  21.369130 325f8fef-b...
    45: nonsticky_...  7.50130382  8.08599935  58.954004 80d162b2-3...
    46: ablaze_ban...  8.16536465  2.05487448   7.249392 4b0c8249-d...
    47: nonsticky_...  5.91840497  0.82796107  19.047386 5504dd06-2...
    48: ablaze_ban... -0.94006642 14.65758332  65.326535 1309d6b9-9...
    49: nonsticky_... -4.97457805  6.66968356 121.575533 2f16be13-9...
    50: ablaze_ban...  9.75294676  0.94201459   4.236250 038b7847-f...
    51: ablaze_ban...  0.10394130  2.69710645  29.402741 c131c402-e...
    52: nonsticky_...  3.01979678 14.72754432 153.130966 4915f2e3-2...
    53: nonsticky_... -4.76967356  6.55863824 109.979625 948c03b3-4...
    54: ablaze_ban...  0.85944915  8.76348417  32.557415 fc3dd398-6...
    55: nonsticky_...  2.30292698  9.97201251  51.913219 2433aeb0-9...
    56: ablaze_ban... -2.84436511  2.30717503  86.657823 e606472e-e...
    57: nonsticky_... -3.85657526  8.98475239  28.500572 12bd976b-0...
    58: ablaze_ban...  7.52677058  4.99095483  26.420230 5bcd2ced-f...
    59: ablaze_ban...  6.09361460  5.09824183  35.427161 80901667-f...
    60: nonsticky_...  9.82376901  3.84227328   2.172504 5f5de8b5-e...
    61: ablaze_ban...  9.98912800  8.76711594  35.236649 a4501873-1...
    62: nonsticky_...  9.97005251 10.48219472  58.172932 85a7bfac-a...
    63: ablaze_ban... -1.07068139  6.01344779  17.985234 47027c23-2...
    64: nonsticky_...  1.79101508  2.18528736   9.803059 90426761-9...
    65: ablaze_ban...  3.85832352  9.70472566  65.523450 469fd8e5-9...
    66: nonsticky_... -2.87541187 14.30747477   7.827714 279341eb-3...
    67: ablaze_ban...  6.48918177 10.76701836 112.617729 16c7087b-4...
    68: nonsticky_...  7.92138169  8.39219191  56.871659 2ba38f2d-7...
    69: ablaze_ban...  6.87284222  1.39356871  18.033464 8f50be0d-0...
    70: nonsticky_...  6.85598664  0.53528045  18.460528 e9f5ca4e-a...
    71: ablaze_ban...  2.29416025  7.01399502  19.527235 e1f5220c-0...
    72: nonsticky_...  1.59196577  1.21276000  16.458032 8652588b-5...
    73: ablaze_ban... -4.67998760  1.12948055 239.162557 72df06e0-9...
    74: nonsticky_... -4.35490562  6.35619728  88.088161 0d720f17-a...
    75: nonsticky_... -0.77339961 13.50051323  55.215747 1ddf5f9d-0...
    76: ablaze_ban...  7.50650941  5.26551687  28.740186 1670102e-8...
    77: nonsticky_... -4.66394155 10.25432093  45.279113 1957d5ff-8...
    78: ablaze_ban... -2.43258995  5.84780601  25.639029 e851cd9a-c...
    79: ablaze_ban...  6.29255322  7.67829295  62.871557 e132457f-b...
    80: nonsticky_...  5.43509234  4.37751700  26.665322 14c245ca-7...
    81: ablaze_ban... -1.07389344  1.64880903  53.133121 48786cc2-e...
    82: nonsticky_...  7.13286772 10.65924833 105.433036 c1499b86-3...
    83: nonsticky_... -2.91654516  3.07953338  75.655820 22afdbd8-f...
    84: ablaze_ban...  5.44427165 14.74429814 200.835515 0db73713-3...
    85: ablaze_ban... -2.15271218 12.07525139   8.926741 412c3d8a-e...
    86: nonsticky_...  7.27550642  1.54514503  15.331931 5c5a0e58-1...
    87: ablaze_ban... -2.03871765 12.88806097  15.318876 6e511268-0...
    88: nonsticky_...  0.28471533 13.66900097  85.014696 fd34684a-0...
    89: ablaze_ban...  3.38238913  0.08214101   4.725331 44eb4d70-5...
    90: nonsticky_...  5.84739804  3.72982272  25.564683 eeeede25-f...
    91: nonsticky_...  3.24510779  3.39748995   1.893689 be5627c8-9...
    92: ablaze_ban...  7.95000468  4.92351942  20.718074 b1c0a0cc-b...
    93: nonsticky_...  2.98100004 10.54511226  66.806130 9eff938e-0...
    94: nonsticky_... -1.78516576  6.04574664  18.242950 b70c5ddb-a...
    95: ablaze_ban...  6.22868709  9.93524831  97.673345 ad4900ea-9...
    96: ablaze_ban...  7.08542549  7.86703657  61.008149 fe976ccc-3...
    97: nonsticky_...  8.21022164  1.21112562   6.836082 4e10e428-5...
    98: ablaze_ban...  8.48217875  8.64567771  51.293172 10726d73-9...
    99: nonsticky_... -3.12904762  6.13934532  37.676094 d7cbd13b-7...
            worker_id          x1          x2          y          keys
               <char>       <num>       <num>      <num>        <char>

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
    1: ablaze_ban...  8861 runnervm5m...     FALSE terminated
    2: nonsticky_...  8859 runnervm5m...     FALSE terminated

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

    [1] "semicultured_anemone_50a01a7f" "doubleedged_harrier_6b9e26a7" 

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
    1: eaved_amer...  9111 runnervm5m...     FALSE running
    2: sound_illa...  9114 runnervm5m...     FALSE running

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
    1: eaved_amer...  9111 runnervm5m...     FALSE running
    2: sound_illa...  9114 runnervm5m...     FALSE running

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

    [1] "Rscript -e 'rush::start_worker(network_id = \"random-search-network\", config = list(scheme = \"redis\", host = \"127.0.0.1\", port = \"6379\"))'"

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

    [1] "Rscript -e 'rush::start_worker(network_id = \"random-search-network\", config = list(scheme = \"redis\", host = \"127.0.0.1\", port = \"6379\"), heartbeat_period = 1L, heartbeat_expire = 3L)'"

To kill a script worker, the `$stop_workers(type = "kill")` method
pushes a kill signal to the heartbeat process, which then terminates the
main worker process.
