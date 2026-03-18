#' @title Default Worker Loop
#'
#' @description
#' A worker loop that pops tasks from the queue and evaluates a function on each task's input.
#' The function `fun` is called with the task's `xs` as arguments via [mlr3misc::invoke()].
#' The return value must be a named `list()` which is stored as the task's output (`ys`).
#' Errors during evaluation are caught and the task is marked as failed.
#'
#' This worker loop can be used with any of the `$start_*_workers()` methods.
#' The `fun` argument is passed through `...` and serialized to Redis.
#'
#' @param rush ([RushWorker])\cr
#' The rush worker instance.
#' @param fun (`function()`)\cr
#' Function to evaluate on each task.
#' Called with the task's `xs` as arguments.
#' Must return a named `list()`.
#'
#' @return `NULL`
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \dontrun{
#'   fun = function(x1, x2) list(y = x1 + x2)
#'
#'   rush = rsh(network_id = "test")
#'   rush$push_tasks(list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)))
#'   rush$start_local_workers(worker_loop_default, fun = fun, n_workers = 2)
#'   rush$wait_for_workers(2)
#' }
worker_loop_default = function(rush, fun) {
  assert_function(fun)
  while (!rush$terminated) {
    task = rush$pop_task(fields = "xs")
    if (!is.null(task)) {
      tryCatch({
        ys = mlr3misc::invoke(fun, .args = task$xs)
        rush$finish_tasks(task$key, yss = list(ys))
      }, error = function(e) {
        rush$fail_tasks(task$key, conditions = list(list(message = e$message)))
      })
    }
  }
  NULL
}
