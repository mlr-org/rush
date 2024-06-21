

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
#' @return `NULL`
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'    rush = rsh(network_id = "test_network", config = config_local)
#'
#'    fun = function(x1, x2, ...) list(y = x1 + x2)
#'    rush$start_local_workers(
#'      fun = fun,
#'      worker_loop = worker_loop_default)
#'
#'    rush$stop_workers()
#' }
worker_loop_default = function(fun, constants = NULL, rush) {
  assert_function(fun)
  assert_list(constants, null.ok = TRUE, names = "named")

  while(!rush$terminated && !rush$terminated_on_idle) {
    task = rush$pop_task(fields = c("xs", "seed"))
    if (!is.null(task)) {
      tryCatch({
        # evaluate task with seed
        ys = with_rng_state(fun, args = c(task$xs, constants), seed = task$seed)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_failed(task$key, conditions = list(condition))
      })
    }
  }

  return(NULL)
}

#' @title Single Task Worker Loop with callr Encapsulation
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function in an external callr session and pushes the results.
#' Supports timeouts on the tasks.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param constants (`list`)\cr
#' List of constants passed to `fun`.
#' @param rush ([RushWorker])\cr
#' Rush worker instance.
#'
#' @return `NULL`
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'    rush = rsh(network_id = "test_network", config = config_local)
#'
#'    fun = function(x1, x2, ...) list(y = x1 + x2)
#'    rush$start_local_workers(
#'      fun = fun,
#'      worker_loop = worker_loop_callr)
#'
#'    rush$stop_workers()
#' }
worker_loop_callr = function(fun, constants = NULL, rush) {
  assert_function(fun)
  assert_list(constants, null.ok = TRUE, names = "named")

  while(!rush$terminated && !rush$terminated_on_idle) {
    task = rush$pop_task(fields = c("xs", "seed", "timeout"))
    if (!is.null(task)) {
      tryCatch({
        # use with_rng_state because callr moves rng state
        ys = callr::r(with_rng_state,
          args = list(fun = fun, args = c(task$xs, constants), seed = task$seed),
          supervise = TRUE,
          timeout = task$timeout %??% Inf)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
          if (inherits(e, "callr_timeout_error")) {
            # session has timed out
            condition = list(message = sprintf("Task timed out after %s seconds", task$timeout))
          } else if (is.null(e$parent$message)) {
            # session has crashed
            condition = list(message = "External R session has crashed or was killed")
          } else {
            # simple error
            condition = list(message = e$parent$message)
          }
          rush$push_failed(task$key, conditions = list(condition))
        }
      )
    }
  }

  return(NULL)
}
