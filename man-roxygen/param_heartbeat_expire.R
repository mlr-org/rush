#' @param heartbeat_expire (`integer(1)`)\cr
#' Time to live of the heartbeat in seconds.
#' The heartbeat key is set to expire after `heartbeat_expire` seconds.
#' Must be at least `heartbeat_period`, otherwise a live worker is reaped as lost between two heartbeats.
