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
wl_random_search = function(rush) {

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
We need to export the `branin` function to the workers, so we set the
`globals` argument to `"branin"`. More on globals and the different
worker types can be found in the [Rush
Controller](https://rush.mlr-org.com/dev/articles/rush_controller.md)
vignette.

``` r
rush$start_local_workers(
  worker_loop = wl_random_search,
  n_workers = 4,
  globals = "branin")

rush
```

    <Rush>
    * Running Workers: 0
    * Queued Tasks: 0
    * Queued Priority Tasks: 0
    * Running Tasks: 0
    * Finished Tasks: 0
    * Failed Tasks: 0

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

                x1         x2           y   pid     worker_id          keys
             <num>      <num>       <num> <int>        <char>        <char>
      1:  3.367786  1.8229204   0.7221683  9952 unmetallur... ad13cb5e-0...
      2:  9.002419  2.2132475   1.2467864  9963 acidophili... 04ba2796-a...
      3:  8.914890  1.7575072   1.7223120  9978 ranidaphob... d650e9b9-b...
      4:  8.908386  2.3589451   1.7312159  9978 ranidaphob... d2b7129f-1...
      5: -3.559390 12.5558435   1.7799953  9963 acidophili... b3935212-d...
     ---
     99:  5.247815 13.7061143 171.1637358  9952 unmetallur... b7514cf8-c...
    100:  6.820841 14.1875855 188.1097817  9968 predesirou... 146e3b81-5...
    101: -4.175885  0.7861299 204.2608828  9968 predesirou... 55f54f13-f...
    102: -4.206424  0.6761029 209.9627875  9952 unmetallur... b5a7c527-c...
    103: -4.926010  1.8897009 239.5936151  9952 unmetallur... 19cd478c-6...

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

    <Rush>
    * Running Workers: 0
    * Queued Tasks: 0
    * Queued Priority Tasks: 0
    * Running Tasks: 0
    * Finished Tasks: 103
    * Failed Tasks: 0

We can stop the workers and reset the database with the `$reset()`
method.

``` r
rush$reset()

rush
```

    <Rush>
    * Running Workers: 0
    * Queued Tasks: 0
    * Queued Priority Tasks: 0
    * Running Tasks: 0
    * Finished Tasks: 0
    * Failed Tasks: 0

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
wl_median_stopping = function(rush) {
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
time we have to pass the training and test set to the workers via the
`globals` argument and the `packages` argument to load the `data.table`
and `xgboost` packages.

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
  globals = c("training_ids", "test_ids", "data", "y"))
```

We fetch the finished tasks and sort them by the objective value.

``` r
rush$fetch_finished_tasks()[order(y)]
```

    Null data.table (0 rows and 0 cols)

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

    <Rush>
    * Running Workers: 0
    * Queued Tasks: 25
    * Queued Priority Tasks: 0
    * Running Tasks: 0
    * Finished Tasks: 0
    * Failed Tasks: 0

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
wl_bayesian_optimization = function(rush) {
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

    ys = list(y = branin(xs$x1, xs$x2))
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
  globals = "branin")
```

The optimization is quickly finished and we retrieve the results.

``` r
rush$fetch_finished_tasks()[order(y)]
```

                x1          x2          y   pid     worker_id          keys
             <num>       <num>      <num> <int>        <char>        <char>
     1:  3.1900645  0.04242753   5.227519 10257 antisocial... 96db92fc-c...
     2:  9.3146022  4.71383104   5.885932 10257 antisocial... 372cf702-7...
     3:  2.2620656  0.68534852   9.521465 10257 antisocial... a3335294-d...
     4:  8.2719211  3.58204809   9.742455 10257 antisocial... a2a3c1ed-c...
     5:  1.4896436  4.81368208  11.584532 10259 daffy_kent... 260eca18-2...
     6:  4.8194191  2.77771792  13.121065 10257 antisocial... 9ad31171-e...
     7:  1.2568485  4.65679421  13.170551 10257 antisocial... 680bb0c2-b...
     8: -1.1709228  7.79746325  13.797285 10259 daffy_kent... a0bcd342-2...
     9: -4.4585296 12.59146555  17.028750 10257 antisocial... 566f07c3-0...
    10: -0.3291837  6.75580352  19.134019 10259 daffy_kent... 9d80fc36-1...
    11:  4.1144105  6.38733242  27.144769 10283 vivid_elep... f25d086c-6...
    12:  4.1529900  6.37744623  27.552917 10257 antisocial... f8838bbf-1...
    13:  6.8172954  4.62746175  30.330699 10257 antisocial... fc1cefd7-6...
    14: -2.6167447  5.59101867  31.482626 10272 material_a... 46f706e2-c...
    15:  0.9532838  8.59551962  31.522302 10257 antisocial... f9b4451d-3...
    16: -2.9934786  6.27521455  32.387854 10272 material_a... 3aef2b0e-1...
    17: -2.8819090  5.89385043  33.964043 10257 antisocial... dab912d8-0...
    18:  5.7928451  5.53313042  37.986602 10257 antisocial... 53d4c7ae-9...
    19:  7.0788219  6.37275150  43.403757 10257 antisocial... bbc76474-7...
    20:  0.2226491  0.64898434  44.395729 10259 daffy_kent... fba38245-b...
    21:  5.1139943  8.09102968  60.698539 10257 antisocial... 8470ca88-4...
    22: -4.7897698  9.41946600  62.114285 10257 antisocial... 1f2645fd-6...
    23:  8.4030487 12.83492220 127.908374 10257 antisocial... 11df48fd-7...
    24: -4.5868418  3.76779209 158.868019 10257 antisocial... 47e01cde-6...
    25:  6.6518042 13.99321742 184.437803 10257 antisocial... 3de8bbbd-3...
                x1          x2          y   pid     worker_id          keys
