

#' @title Single Task Worker Loop
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function and pushes the results.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param constants (`list`)\cr
#' List of constants passed to `fun`.
#' @param rush ([RushWorker])\cr
#' Rush worker instance.
#'
#' @export
worker_loop_default = function(fun, constants = NULL, rush) {
  assert_function(fun)
  assert_list(constants, null.ok = TRUE, names = "named")

  while(!rush$terminated) {
    task = rush$pop_task()
    if (!is.null(task)) {
      # set seed
      rush$set_seed(task$key)
      tryCatch({
        ys = mlr3misc::invoke(fun, .args = c(task$xs, constants))
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_failed(task$key, conditions = list(condition))
      })
    } else {
      if (rush$terminated_on_idle) break
    }
  }

  return(NULL)
}
