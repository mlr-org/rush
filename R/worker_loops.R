

#' @title Single Task Worker Loop
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function and pushes the results.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param rush (`character(1)`)\cr
#' Rush worker instance.
#'
#' @export
fun_loop = function(fun, rush) {
  assert_function(fun)

  while(!rush$terminate) {
    task = rush$pop_task()
    if (!is.null(task)) {
      tryCatch({
        ys = mlr3misc::invoke(fun, rush = rush, .args = c(task$xs, rush$constants))
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_results(task$key, conditions = list(condition), status = "failed")
      })
    }
    rush$write_log()
  }
  return(NULL)
}
