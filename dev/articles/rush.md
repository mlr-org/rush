# rush - Asynchronous and Distributed Computing

*rush* is a package designed to solve large-scale problems
asynchronously across a distributed network. Employing a database
centric model, rush enables workers to communicate tasks and their
results over a shared [`Redis`](https://redis.io/) database. This
article demonstrates how to use `rush` with 3 different examples.

## Random Search

We begin with a simple random search to optimize the Branin function in
parallel. Although random search does not require communication between
workers, it is a good way to introduce the basic ideas behind `rush`.
The classic Branin function (also called the Branin-Hoo function) is a
well-known benchmark problem in global optimization. It is a
two-dimensional function that is non-convex, multimodal, and has three
global minima. The function is a toy example for optimization thats fast
to evaluate but not too simple to be solved.

``` r
branin = function(x1, x2) {
  (x2 - 5.1 / (4 * pi^2) * x1^2 + 5 / pi * x1 - 6)^2 + 10 * (1 - 1 / (8 * pi)) * cos(x1) + 10
}
```

The Branin function is usually evaluated on the domain \\x_1 \in \[-5,
10\]\\ and \\x_2 \in \[0, 15\]\\.

![](branin.png)

### Worker Loop

We define the `worker_loop` function, which runs on each worker. It
repeatedly draws tasks, evaluates them, and sends the results to the
Redis database. The function takes a single argument: a `RushWorker`
object, which handles communication with Redis. In this example, each
worker samples a random point, creates a task, evaluates it using the
Branin function, and submits the result. The optimization stops after
100 tasks have been evaluated.

``` r
wl_random_search = function(rush, branin) {

  while(rush$n_finished_tasks < 100) {

    xs = list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15))
    key = rush$push_running_tasks(xss = list(xs))

    ys = list(y = branin(xs$x1, xs$x2))
    rush$push_results(key, yss = list(ys))
  }
}
```

The most important methods of the `RushWorker` are the
`$push_running_tasks()` and `$push_results()` methods. The first method
`$push_running_tasks()` creates a new task in the Redis database. Since
it is evaluated next, the task is marked as running. The
`$push_running_tasks()` method returns a unique key that is used to
identify the task. The second method `$push_results()` is used to push
the results back to the Redis database. It takes the key of the task and
a list of results. To mark the task as running is not important for a
random search, but it is crucial for more sophisticated algorithms that
use the tasks of other workers to decide which task to evaluate next.
For example, Bayesian optimization algorithms would sample the next
point further away from the previous points to explore the search space.
The `$n_finished_tasks` shows how many tasks are finished and is used to
stop the worker loop.

### Tasks

Tasks are the unit in which workers exchange information. The main
components of a task are the key, computational state, input (`xs`), and
result (`ys`). The key is a unique identifier for the task. It
identifies the task in the Redis database. The four possible
computational states are `"running"`, `"finished"`, `"failed"`, and
`"queued"`. The `$push_running_tasks()` method marks it as `"running"`
and returns the key of the task. The `$push_results()` method marks a
task as `"finished"` and stores the result. Failed tasks can be marked
as `"failed"` with the `$push_failed()` method. The error catching must
be implemented in the worker loop (see [Error
Handling](https://rush.mlr-org.com/dev/articles/error_handling.md) for
more details). Tasks can also be pushed to a queue with the
`$push_tasks()` method which sets the state to `"queued"`. The last
example gives more details on the task queue and the different methods
to push and pop tasks. The input `xs` and result `ys` are lists that can
contain arbitrary data. Usually the methods of the `RushWorker` work on
multiple tasks at once, so `xxs` and `yss` are lists of inputs and
results.

### Controller

The Rush controller is responsible for starting, observing, and stopping
workers within the network. It is initialized using the
[`rsh()`](https://rush.mlr-org.com/dev/reference/rsh.md) function, which
requires a network ID and a config argument. The config argument is a
configuration file used to connect to the Redis database via the `redux`
package.

``` r
library(rush)

config = redux::redis_config()

rush = rsh(
  network = "test-random-search",
  config = config)
```

Workers can be started using the `$start_local_workers()` method, which
accepts the worker loop and the number of workers as arguments. The
workers are started locally with the `processx` package but it is also
possible to start workers on a remote machine (see [Rush
Controller](https://rush.mlr-org.com/dev/articles/rush_controller.md)).
We pass the `branin` function explicitly as an argument to the worker
loop. More on the different worker types can be found in the [Rush
Controller](https://rush.mlr-org.com/dev/articles/rush_controller.md)
vignette.

``` r
rush$start_local_workers(
  worker_loop = wl_random_search,
  n_workers = 4,
  branin = branin)

rush
```

    ── <Rush> ──────────────────────────────────────────────────────────────────────
    • Running Workers: 0
    • Queued Tasks: 0
    • Running Tasks: 0
    • Finished Tasks: 0
    • Failed Tasks: 0

The optimization is quickly finished and we retrieve the results. The
`$fetch_finished_tasks()` method fetches all finished tasks from the
database. The method returns a `data.table()` with the key, input, and
result. The `pid` and `worker_id` column are additional information that
are stored when the task is created. The `worker_id` is the id of the
worker that evaluated the task and the `pid` is the process id of that
worker. Further extra information can be passed as `list`s to the
`$push_running_tasks()` and `$push_results()` methods via the `extra`
argument.

``` r
rush$fetch_finished_tasks()[order(y)]
```

             worker_id        x1        x2           y
                <char>     <num>     <num>       <num>
      1: groggy_ivo...  9.299071  2.279144   0.4820939
      2: repellent_... -3.286682 11.966055   0.9348384
      3: repellent_...  3.573991  2.392554   1.4670605
      4: numb_hellb...  3.546505  2.622605   1.5867626
      5: extraterri...  9.614280  1.535704   1.7881232
     ---
     99: groggy_ivo...  4.280995 12.692740 130.0534342
    100: groggy_ivo...  5.404510 11.888559 130.9773459
    101: extraterri...  3.122540 14.107789 140.0619858
    102: groggy_ivo... -3.693031  1.638240 145.8519445
    103: repellent_...  9.107975 14.526161 152.2992314
                                         keys
                                       <list>
      1: 953b2ee4-f360-4204-aa8a-82446f1b56fd
      2: 05e28e4e-e49f-4f67-8c69-33b325415f3e
      3: d85563e3-b4eb-413a-9c28-a53e66f04448
      4: 85e92dc7-1b8d-47a7-8195-1961007f7261
      5: 3c6396a4-aa4a-4463-be8c-1b880e99b4be
     ---
     99: f1c206ef-e4b2-4ba2-ae87-f38c462b1a3b
    100: 2cc05c84-3dc0-40f9-b359-658fd7809793
    101: 58d52116-1ef3-4ded-8462-dfa126121fc3
    102: 26c60c5b-2537-4251-9826-71e503d2de79
    103: debb5db3-818d-4430-82cb-35d81748cce0

The rush controller displays how many workers are running and how many
tasks exist in each state. In this case, 103 tasks are marked as
finished, and all workers have stopped. The number slightly exceeds 100
because workers check the stopping condition independently. If several
workers evaluate the condition around the same time — when, for example,
99 tasks are finished — they may all create new tasks before detecting
that the limit has been reached. Additionally, tasks may continue to be
created while the 100th task is still being evaluated.

``` r
rush
```

    ── <Rush> ──────────────────────────────────────────────────────────────────────
    • Running Workers: 0
    • Queued Tasks: 0
    • Running Tasks: 0
    • Finished Tasks: 103
    • Failed Tasks: 0

We can stop the workers and reset the database with the `$reset()`
method.

``` r
rush$reset()

rush
```

    ── <Rush> ──────────────────────────────────────────────────────────────────────
    • Running Workers: 0
    • Queued Tasks: 0
    • Running Tasks: 0
    • Finished Tasks: 0
    • Failed Tasks: 0

To learn more about starting, stopping and observing workers, see the
[Rush
Controller](https://rush.mlr-org.com/dev/articles/rush_controller.md)
vignette.

## Median Stopping

Random search is a simple example that doesn’t rely on information from
previous tasks and therefore doesn’t require communication between
workers. Now, let’s implement a more sophisticated algorithm that uses
the results of completed tasks to decide whether to continue evaluating
the current one. We tune an XGBoost model on the mtcars dataset and use
the median stopping rule to stop the training early.

### Worker Loop

The worker starts by sampling a random hyperparameter configuration with
three parameters: maximum tree depth, lambda regularization, and alpha
regularization. These parameters control how the XGBoost model learns
from the data. The worker then trains the model incrementally, starting
with 5 boosting rounds and adding one round at a time up to 20 rounds.
After each round, the worker evaluates the model’s performance on a test
set using root mean squared error (RMSE). At this point, the worker
checks how well its model is doing compared to other workers by fetching
their completed results and comparing its performance to the median
score among all models with the same number of training rounds.

If the current model performs worse than the median, the worker stops
this hyperparameter configuration and starts over with a new one. This
early stopping mechanism prevents workers from wasting time on
poor-performing configurations. If the model performs at or above the
median, the worker continues training for one more round. The process
continues until the network has evaluated 1000 complete models across
all workers.

``` r
wl_median_stopping = function(rush, training_ids, test_ids, data, y) {
  while(rush$n_finished_tasks < 1000) {

    params = list(
      max_depth = sample(1:20, 1),
      lambda = runif(1, 0, 1),
      alpha = runif(1, 0, 1)
    )

    model = NULL
    for (iteration in seq(5, 20, by = 1)) {

      key = rush$push_running_tasks(xss = list(c(params, list(nrounds = iteration))))

      model = xgboost(
        data = as.matrix(data[training_ids, ]),
        label = y[training_ids],
        nrounds = if (is.null(model)) 5 else 1,
        params = params,
        xgb_model = model,
        verbose = 0
      )

      pred = predict(model, as.matrix(data[test_ids, ]))
      rmse = sqrt(mean((pred - y[test_ids])^2))

      rush$push_results(key, yss = list(list(rmse = rmse)))

      tasks = rush$fetch_finished_tasks()
      if (rmse > median(tasks[nrounds == iteration, rmse])) break
    }
  }
}
```

The worker loop uses a new method called `$fetch_finished_tasks()` to
fetch all finished tasks from the database. Other methods like
`$fetch_running_tasks()` and `$fetch_failed_tasks()` are also available.

We sample a training and test set from the mtcars dataset. The training
set is used to fit the model and the test set is used to evaluate the
model. Then we initialize the rush network and start the workers. This
time we pass the training/test split and the data explicitly as
arguments to the worker loop, and use the `packages` argument to load
the `data.table` and `xgboost` packages.

``` r
data(mtcars)

training_ids = sample(1:nrow(mtcars), 20)
test_ids = setdiff(1:nrow(mtcars), training_ids)
data = mtcars[, -1]
y = mtcars$mpg

config = redux::redis_config()

rush = rsh(
  network = "test-median-stopping",
  config = config)

rush$start_local_workers(
  worker_loop = wl_median_stopping,
  n_workers = 4,
  packages = c("data.table", "xgboost"),
  training_ids = training_ids,
  test_ids = test_ids,
  data = data,
  y = y)
```

We fetch the finished tasks and sort them by the objective value.

``` r
rush$fetch_finished_tasks()[order(y)]
```

            worker_id max_depth    lambda      alpha nrounds     rmse
               <char>     <int>     <num>      <num>   <num>    <num>
     1:          <NA>        NA        NA         NA      NA       NA
     2:          <NA>        NA        NA         NA      NA       NA
     3:          <NA>        NA        NA         NA      NA       NA
     4: cardiovasc...        14 0.4512315 0.75089360       5 3.854847
     5:          <NA>        NA        NA         NA      NA       NA
     6:          <NA>        NA        NA         NA      NA       NA
     7:          <NA>        NA        NA         NA      NA       NA
     8:          <NA>        NA        NA         NA      NA       NA
     9:          <NA>        NA        NA         NA      NA       NA
    10:          <NA>        NA        NA         NA      NA       NA
    11:          <NA>        NA        NA         NA      NA       NA
    12:          <NA>        NA        NA         NA      NA       NA
    13:          <NA>        NA        NA         NA      NA       NA
    14: fleshcolor...         4 0.6733517 0.36056116       5 3.854847
    15: gentile_co...        12 0.7058268 0.04810909       8 5.759707
    16:          <NA>        NA        NA         NA      NA       NA
    17:          <NA>        NA        NA         NA      NA       NA
    18:          <NA>        NA        NA         NA      NA       NA
    19: gentile_co...        12 0.7058268 0.04810909       5 3.854847
    20: gentile_co...        12 0.7058268 0.04810909       6 5.759707
    21: chaotic_mo...        18 0.3684117 0.13939877       5 3.854847
    22:          <NA>        NA        NA         NA      NA       NA
    23:          <NA>        NA        NA         NA      NA       NA
    24: gentile_co...        12 0.7058268 0.04810909       7 5.759707
    25:          <NA>        NA        NA         NA      NA       NA
    26: chaotic_mo...        18 0.3684117 0.13939877       6 5.759707
    27:          <NA>        NA        NA         NA      NA       NA
    28:          <NA>        NA        NA         NA      NA       NA
    29:          <NA>        NA        NA         NA      NA       NA
    30:          <NA>        NA        NA         NA      NA       NA
    31:          <NA>        NA        NA         NA      NA       NA
    32:          <NA>        NA        NA         NA      NA       NA
            worker_id max_depth    lambda      alpha nrounds     rmse
               <char>     <int>     <num>      <num>   <num>    <num>
                                        keys
                                      <list>
     1:                               [NULL]
     2:                               [NULL]
     3:                               [NULL]
     4: 5fafd320-76c5-4195-be84-bb33d8c26435
     5:                               [NULL]
     6:                               [NULL]
     7:                               [NULL]
     8:                               [NULL]
     9:                               [NULL]
    10:                               [NULL]
    11:                               [NULL]
    12:                               [NULL]
    13:                               [NULL]
    14: 778ad11d-dfc7-49bb-aa55-87d32d95389b
    15: f0d6995d-4821-4ffd-9137-ce7d35a0fe62
    16:                               [NULL]
    17:                               [NULL]
    18:                               [NULL]
    19: 30e892ce-1247-4bf1-9d3f-5ac2cd516ccf
    20: a32ee60b-4dcc-4596-b669-d3d65fe3dedd
    21: 1ad333d7-3485-40e3-80ee-15cf3ec508ac
    22:                               [NULL]
    23:                               [NULL]
    24: d5685fea-69b2-44cb-8474-5ef90b36421e
    25:                               [NULL]
    26: 2eb6c190-d065-4cf3-aa25-557464774740
    27:                               [NULL]
    28:                               [NULL]
    29:                               [NULL]
    30:                               [NULL]
    31:                               [NULL]
    32:                               [NULL]
                                        keys
                                      <list>

We stop the workers and reset the database.ch

``` r
rush$reset()
```

## Bayesian Optimization

We implement Asynchronous Distributed Bayesian Optimization (ADBO)
\[@egele_2023\] next. This example shows how workers use information
about running tasks and introduces task queues. ADBO runs sequential
[Bayesian
optimization](https://mlr3book.mlr-org.com/chapters/chapter5/advanced_tuning_methods_and_black_box_optimization.html#sec-bayesian-optimization)
on multiple workers in parallel. Each worker maintains its own surrogate
model (a random forest) and selects the next hyperparameter
configuration by maximizing the upper confidence bounds acquisition
function. To promote a varying exploration-exploitation tradeoff between
the workers, the acquisition functions are initialized with different
lambda values ranging from 0.1 to 10. When a worker completes an
evaluation, it asynchronously sends the result to its peers via a Redis
data base; each worker then updates its local model with this shared
information. This decentralized design enables workers to proceed
independently; eliminating the need for a central coordinator that could
become a bottleneck in large-scale optimization scenarios.

We first create a new rush network.

``` r
config = redux::redis_config()

rush = rsh(
  network = "test-bayesian-optimization",
  config = config)
```

### Queues

The queue system works by pushing and popping tasks from a queue. The
`$push_task()` method creates new tasks and pushes them to the queue. In
this example, we draw an initial design of 25 points and push them to
the queue.

``` r
xss = replicate(25, list(x1 = runif(1, -5, 10), x2 = runif(1, 0, 15)), simplify = FALSE)

rush$push_tasks(xss = xss)

rush
```

    ── <Rush> ──────────────────────────────────────────────────────────────────────
    • Running Workers: 0
    • Queued Tasks: 25
    • Running Tasks: 0
    • Finished Tasks: 0
    • Failed Tasks: 0

We see 25 queued tasks in the database. To retrieve the tasks from the
queue, we need to implement the `$pop_task()` method in the worker loop.

### Worker Loop

The worker loop pops tasks with the `$pop_task()` method from the queue.
The task is evaluated and the results are pushed back to the database
with the `$push_results()` method. If there are no more tasks in the
queue, the `$pop_task()` method returns `NULL` and the worker loop
starts the Bayesian optimization. First, a lambda value for the
acquisition function is sampled between 0.01 and 10. Then all running
and finished tasks are fetched from the database. Using
`rush$fetch_tasks_with_state()` instead of using
`$fetch_running_tasks()` and `$fetch_finished_tasks()` is important
because it prevents tasks from appearing twice. This could be the case
if a worker changes the state of a task from `"running"` to `"finished"`
while the tasks are being fetched. The missing y values of the running
tasks are imputed with the mean of the finished tasks. Then the
surrogate random forest model is fitted to the data and the acquisition
function is optimized to find the next task. Marking the task as running
is important for the Bayesian optimization algorithm, as it uses the
already sampled points of the other workers to decide which task to
evaluate next. The task is evaluated and the results are pushed back to
the database. We stop the optimization process after 100 evaluated
tasks.

``` r
wl_bayesian_optimization = function(rush, branin_fun) {
  repeat {
    task = rush$pop_task()
    if (is.null(task)) break
    ys = list(y = branin(task$xs$x1, task$xs$x2))
    rush$push_results(task$key, yss = list(ys))
  }

  lambda = runif(1, 0.01, 10)

  while(rush$n_finished_tasks < 100) {

    xydt = rush$fetch_tasks_with_state(states = c("running", "finished"))
    mean_y = mean(xydt$y, na.rm = TRUE)
    xydt["running", y := mean_y, on = "state"]

    surrogate = ranger::ranger(
      y ~ x1 + x2,
      data = xydt,
      num.trees = 100L,
      keep.inbag = TRUE)
    xdt = data.table::data.table(x1 = runif(1000, -5, 10), x2 = runif(1000, 0, 15))
    p = predict(surrogate, xdt, type = "se", se.method = "jack")
    cb = p$predictions - lambda * p$se
    xs = as.list(xdt[which.min(cb)])
    key = rush$push_running_tasks(xss = list(xs))

    ys = list(y = branin_fun(xs$x1, xs$x2))
    rush$push_results(key, yss = list(ys))
  }
}
```

We start the optimization process by starting 4 local workers that run
the Bayesian optimization worker loop.

``` r
rush$start_local_workers(
  worker_loop = wl_bayesian_optimization,
  n_workers = 4,
  branin_fun = branin)
```

The optimization is quickly finished and we retrieve the results.

``` r
rush$fetch_finished_tasks()[order(y)]
```

    Null data.table (0 rows and 0 cols)
