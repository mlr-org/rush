#' @param restart (`logical(1)`)\cr
#' Whether to restart lost workers started with `$start_workers()`.
#' `$detect_lost_workers()` starts a new worker with a new worker id for each lost worker.
#' The new worker runs on the same compute profile and stores the id of the lost worker in `restarted_from`.
#' Default is `FALSE`.
