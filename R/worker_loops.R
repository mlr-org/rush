#' @title Worker Function
#'
#' @description
#' Called on the worker.
#' Initializes the rush worker instance and invokes the worker loop.
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
#' @param lgr_thresholds (named `character()` or `numeric()`)\cr
#' Logger thresholds.
#'
#' @export
run_worker = function(worker_loop, instance_id, config, host, worker_id, heartbeat_period, heartbeat_expire, lgr_thresholds, args) {
  # initialize rush worker
  rush = RushWorker$new(
    instance_id = instance_id,
    config = config,
    host = host,
    worker_id = worker_id,
    heartbeat_period = heartbeat_period,
    heartbeat_expire = heartbeat_expire,
    lgr_thresholds = lgr_thresholds)

  # without waiting, the heartbeat process continues even though fun_wrapper has crashed
  if (!is.null(rush$heartbeat)) Sys.sleep(1)

  # run worker loop
  invoke(worker_loop, rush = rush, .args = args)
}


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
