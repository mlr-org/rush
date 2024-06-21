#' @title Heartbeat Loop
#'
#' @description
#' The heartbeat loop updates the heartbeat key if the worker is still alive.
#' If the kill key is set, the worker is killed.
#' This function is called in a callr session.
#'
#' @param pid (`integer(1)`)\cr
#' Process ID of the worker.
#' @param config ([redux::redis_config])\cr
#' Redis configuration options.
#'
#' @template param_network_id
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#'
#' @return `NULL`
#' @keywords internal
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'
#'    rush_plan(
#'      config = config_local,
#'      n_workers = 2,
#'      lgr_thresholds = c(rush = "info"))
#'
#'    rush = rsh(network_id = "test_network")
#'
#'    fun = function(x1, x2, ...) list(y = x1 + x2)
#'    rush$start_local_workers(
#'      fun = fun,
#'      heartbeat_period = 3,
#'      heartbeat_expire = 9)
#'
#'    rush$stop_workers()
#' }
heartbeat = function(network_id, config, worker_id, heartbeat_period, heartbeat_expire, pid) {
  r = redux::hiredis(config)
  worker_id_key = sprintf("%s:%s", network_id, worker_id)
  heartbeat_key = sprintf("%s:%s:heartbeat", network_id, worker_id)
  kill_key = sprintf("%s:%s:kill", network_id, worker_id)

  repeat {
    r$command(c("EXPIRE", heartbeat_key, heartbeat_expire))
    kill = r$command(c("BLPOP", kill_key, heartbeat_period))[[2]]
    if (!is.null(kill)) {
      r$command(c("DEL", heartbeat_key, kill_key))
      r$command(c("HSET", worker_id_key, "state", "killed"))
      tools::pskill(pid, tools::SIGKILL)
      break
    }
  }

  return(NULL)
}
