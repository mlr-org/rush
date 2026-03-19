#' @title Default Worker Loop
#'
#' @description
#' A worker loop that pops tasks from the queue and evaluates the task's `fun` field on its `xs`.
#' Each task must carry a `fun` field (a function) which is called with the task's `xs` as arguments
#' via [mlr3misc::invoke()].
#' The return value must be a named `list()` which is stored as the task's output (`ys`).
#' Errors during evaluation are caught and the task is marked as failed.
#'
#' Tasks are created with `$push_tasks(xss, funs = ...)`.
#'
#' @param rush ([RushWorker])\cr
#' The rush worker instance.
#'
#' @return `NULL`
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \dontrun{
#'   rush = rsh(network_id = "test")
#'   rush$push_tasks(
#'     xss = list(list(x1 = 1, x2 = 2)),
#'     funs = list(function(x1, x2) list(y = x1 + x2))
#'   )
#'   rush$start_local_workers(worker_loop_default, n_workers = 2)
#' }
worker_loop_default = function(rush) {
  while (!rush$terminated) {
    task = rush$pop_task(fields = c("xs", "fun"))
    if (!is.null(task)) {
      tryCatch({
        ys = mlr3misc::invoke(task$fun, .args = task$xs)
        rush$finish_tasks(task$key, yss = list(ys))
      }, error = function(e) {
        rush$fail_tasks(task$key, conditions = list(list(message = e$message)))
      })
    }
  }
  NULL
}
