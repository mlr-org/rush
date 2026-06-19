#' @param heartbeat_expire (`integer(1)`)\cr
#' Time to live of the heartbeat in seconds.
#' The heartbeat key is set to expire after `heartbeat_expire` seconds.
#' Must be at least `heartbeat_period`, otherwise a live worker is reaped as lost between two heartbeats.
#' Set it larger than the longest pause a worker may experience, for example from garbage collection or swapping,
#' because a live worker wrongly declared lost can leave a task in an inconsistent state.
