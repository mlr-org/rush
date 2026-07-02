#' @title Assertion for Rush Objects
#'
#' @description
#' Most assertion functions ensure the right class attribute, and optionally additional properties.
#' If an assertion fails, an exception is raised.
#' Otherwise, the input object is returned invisibly.
#'
#' @return Exception if the assertion fails, otherwise the input object invisibly.
#' @name rush_assertions
#' @keywords internal
#' @examples
#' if (redux::redis_available()) {
#'    config_local = redux::redis_config()
#'    rush = rsh(network_id = "test_network", config = config_local)
#'
#'    assert_rush(rush)
#' }
NULL

#' @export
#' @param rush ([Rush]).
#' @param null_ok (`logical(1)`).
#'  If `TRUE`, `NULL` is allowed.
#' @rdname rush_assertions
assert_rush = function(rush, null_ok = FALSE) {
  if (null_ok && is.null(rush)) {
    return(invisible(NULL))
  }
  assert_r6(rush, "Rush")
  invisible(rush)
}

#' @export
#' @param rushs (list of [Rush]).
#' @param null_ok (`logical(1)`).
#'  If `TRUE`, `NULL` is allowed.
#' @rdname rush_assertions
assert_rushs = function(rushs, null_ok = FALSE) {
  if (null_ok && is.null(rushs)) {
    return(invisible(NULL))
  }
  invisible(map(rushs, assert_rush))
}

#' @export
#' @param worker ([RushWorker]).
#' @param null_ok (`logical(1)`).
#'  If `TRUE`, `NULL` is allowed.
#' @rdname rush_assertions
assert_rush_worker = function(worker, null_ok = FALSE) {
  if (null_ok && is.null(worker)) {
    return(invisible(NULL))
  }
  assert_r6(worker, "RushWorker")
  invisible(worker)
}

#' @export
#' @param workers (list of [RushWorker]).
#' @param null_ok (`logical(1)`).
#'  If `TRUE`, `NULL` is allowed.
#' @rdname rush_assertions
assert_rush_workers = function(workers, null_ok = FALSE) {
  if (null_ok && is.null(workers)) {
    return(invisible(NULL))
  }
  invisible(map(workers, assert_rush_worker))
}

assert_lgr_thresholds = function(lgr_thresholds) {
  assert_vector(
    lgr_thresholds %??% rush_env$lgr_thresholds,
    names = "named",
    null.ok = TRUE,
    .var.name = "lgr_thresholds"
  )
}

assert_lgr_buffer_size = function(lgr_buffer_size) {
  assert_count(
    lgr_buffer_size %??% rush_env$lgr_buffer_size %??% 0,
    .var.name = "lgr_buffer_size"
  )
}
