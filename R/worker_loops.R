

#' @title Single Task Worker Loop
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function and pushes the results.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param rush ([RushWorker])\cr
#' Rush worker instance.
#'
#' @export
worker_loop_default = function(fun, rush) {
  assert_function(fun)

  while(!rush$terminated) {
    task = rush$pop_task()
    if (!is.null(task)) {
      tryCatch({
        ys = mlr3misc::invoke(fun, rush = rush, .args = task$xs)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_results(task$key, conditions = list(condition), state = "failed")
      })
    } else {
      if (rush$terminated_on_idle) break
    }
    rush$write_log()
  }

  return(NULL)
}
