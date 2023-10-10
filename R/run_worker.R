#' @title Run a Worker.
#'
#' @description
#' Runs a worker.
#' The function initializes the [RushWorker] instance and invokes the worker loop.
#'
#' @param worker_loop (`function`)\cr
#' Worker loop to be executed e.g. [fun_loop].
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
