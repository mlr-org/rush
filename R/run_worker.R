#' @title Run a Worker.
#'
#' @description
#' Runs a worker.
#' The function initializes the [RushWorker] instance and invokes the worker loop.
#' This function is normally not called by the user.
#'
#' @param args (named `list()`)\cr
#' Named arguments passed to the worker loop.
#'
#' @template param_worker_loop
#' @template param_instance_id
#' @template param_config
#' @template param_host
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_lgr_thresholds
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

  # without waiting, the heartbeat process continues even though worker_loop has crashed
  if (!is.null(rush$heartbeat)) Sys.sleep(1)

  # run worker loop
  invoke(worker_loop, rush = rush, .args = args)
}
