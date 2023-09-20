#' @title Heartbeat Loop
#'
#' @description
#' Heartbeat loop that updates the heartbeat key and checks for kill key.
#'
#' @param instance_id (`character(1)`)\cr
#' Identifier of the rush instance.
#' @param config ([redux::redis_config])\cr
#' Redis configuration.
#' @param worker_id (`character(1)`)\cr
#' Identifier of the worker.
#' @param period (`numeric(1)`)\cr
#' Period of the heartbeat.
#' @param expire (`numeric(1)`)\cr
#' Expiration of the heartbeat.
#' @param pid (`numeric(1)`)\cr
#' Process ID of the worker.
#'
#' @export
fun_heartbeat = function(instance_id, config, worker_id, period, expire, pid) {
  r = redux::hiredis(config)
  worker_id_key = sprintf("%s:%s", instance_id, worker_id)
  worker_ids_key = sprintf("%s:worker_ids", instance_id)
  heartbeat_key = sprintf("%s:%s:heartbeat", instance_id, worker_id)
  kill_key = sprintf("%s:%s:kill", instance_id, worker_id)

  repeat {
    r$command(c("EXPIRE", heartbeat_key, expire))
    kill = r$command(c("BLPOP", kill_key, period))[[2]]
    if (!is.null(kill)) {
      r$command(c("DEL", heartbeat_key, kill_key))
      r$command(c("HSET", worker_id_key, "status", "killed"))
      tools::pskill(pid, tools::SIGKILL)
      break
    }
  }
}
