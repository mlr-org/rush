#' @title Experiment Worker Loop
#'
#' @description
#' A worker loop for the batchtools-style experiment framework ([RushExperiment]).
#' Pops tasks from the queue, generates problem instances, and evaluates algorithms.
#'
#' Each task's `xs` contains:
#' * `problem`: Name of the problem.
#' * `algorithm`: Name of the algorithm.
#' * `prob_pars`: Named list of problem parameters.
#' * `algo_pars`: Named list of algorithm parameters.
#' * `repl`: Replication number.
#'
#' The problem function is called as `fun(data, ...)` with `prob_pars`.
#' The algorithm function is called as `fun(data, instance, ...)` with `algo_pars`.
#'
#' @param rush ([RushWorker])\cr
#' The rush worker instance.
#' @param problems (named `list()`)\cr
#' Registered problems. Each element is a list with `fun` and `data`.
#' @param algorithms (named `list()`)\cr
#' Registered algorithms. Each element is a list with `fun`.
#'
#' @return `NULL`
#' @export
worker_loop_experiment = function(rush, problems, algorithms) {
  while (!rush$terminated) {
    task = rush$pop_task(fields = "xs")
    if (!is.null(task)) {
      tryCatch({
        xs = task$xs
        prob = problems[[xs$problem]]
        algo = algorithms[[xs$algorithm]]

        # generate problem instance
        instance = mlr3misc::invoke(prob$fun, data = prob$data, .args = xs$prob_pars)

        # run algorithm on instance
        ys = mlr3misc::invoke(algo$fun, data = prob$data, instance = instance, .args = xs$algo_pars)

        rush$finish_tasks(task$key, yss = list(ys))
      }, error = function(e) {
        rush$fail_tasks(task$key, conditions = list(list(message = e$message)))
      })
    }
  }
  NULL
}
