#' @title Single Task Worker Loop
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function and pushes the results.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param instance_id (`character(1)`)\cr
#' Identifier of the rush instance.
#' @param config ([redux::redis_config])\cr
#' Redis configuration.
#' @param host (`character(1)`)\cr
#' Local or remote host.
#' @param worker_id (`character(1)`)\cr
#' Identifier of the worker.
#' @param heartbeat_period (`numeric(1)`)\cr
#' Period of the heartbeat.
#' @param heartbeat_expire (`numeric(1)`)\cr
#' Expiration of the heartbeat.
#'
#' @export
fun_loop = function(fun, instance_id, config, host, worker_id, heartbeat_period, heartbeat_expire) {
  rush = RushWorker$new(
    instance_id = instance_id,
    config = config,
    host = host,
    worker_id = worker_id,
    heartbeat_period = heartbeat_period,
    heartbeat_expire = heartbeat_expire)

  # without waiting, the heartbeat process continues even though fun_wrapper has crashed
  if (!is.null(rush$heartbeat)) Sys.sleep(1)

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
  }
  return(NULL)
}

#' @title Single Task Worker Loop With List Argument
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function and pushes the results.
#' The function takes a list of arguments as input i.e. `fun(xs, ...)`.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param instance_id (`character(1)`)\cr
#' Identifier of the rush instance.
#' @param config ([redux::redis_config])\cr
#' Redis configuration.
#' @param host (`character(1)`)\cr
#' Local or remote host.
#' @param worker_id (`character(1)`)\cr
#' Identifier of the worker.
#' @param heartbeat_period (`numeric(1)`)\cr
#' Period of the heartbeat.
#' @param heartbeat_expire (`numeric(1)`)\cr
#' Expiration of the heartbeat.
#'
#' @export
list_fun_loop = function(fun, instance_id, config, host, worker_id, heartbeat_period, heartbeat_expire) {
  rush = RushWorker$new(
    instance_id = instance_id,
    config = config,
    host = host,
    worker_id = worker_id,
    heartbeat_period = heartbeat_period,
    heartbeat_expire = heartbeat_expire)

  # without waiting, the heartbeat process continues even though fun_wrapper has crashed
  if (!is.null(rush$heartbeat)) Sys.sleep(1)

  while(!rush$terminate) {
    task = rush$pop_task()
    if (!is.null(task)) {
      tryCatch({
        ys = mlr3misc::invoke(fun, xs = task$xs, rush = rush, .args = rush$constants)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_results(task$key, conditions = list(condition), status = "failed")
      })
    }
  }
  return(NULL)
}
