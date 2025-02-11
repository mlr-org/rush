#' @title Create Rush Plan
#'
#' @description
#' Stores the number of workers and Redis configuration options ([redux::redis_config]) for [Rush].
#' The function tests the connection to Redis and throws an error if the connection fails.
#' This function is usually used in third-party packages to setup how workers are started.
#'
#' @param config ([redux::redis_config])\cr
#' Configuration options used to connect to Redis.
#' If `NULL`, the `REDIS_URL` environment variable is parsed.
#' If `REDIS_URL` is not set, a default configuration is used.
#' See [redux::redis_config] for details.
#' @param worker_type (`character(1)`)\cr
#' The type of worker to use.
#' Options are `"local"` to start with \CRANpkg{processx}, `"remote"` to use \CRANpkg{mirai} or `"script"` to get a script to run.
#'
#' @template param_n_workers
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
#' @template param_large_objects_path
#'
#' @return `list()` with the stored configuration.
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'    rush_plan(config = config_local, n_workers = 2)
#'
#'    rush = rsh(network_id = "test_network")
#'    rush
#' }
rush_plan = function(
  n_workers = NULL,
  config = NULL,
  lgr_thresholds = NULL,
  lgr_buffer_size = NULL,
  large_objects_path = NULL,
  worker_type = "local"
  ) {
  assert_count(n_workers, null.ok = TRUE)
  assert_class(config, "redis_config", null.ok = TRUE)
  assert_vector(lgr_thresholds, names = "named", null.ok = TRUE)
  assert_count(lgr_buffer_size, null.ok = TRUE)
  assert_string(large_objects_path, null.ok = TRUE)
  assert_choice(worker_type, c("local", "remote", "script"))
  if (is.null(config)) config = redux::redis_config()
  if (!redux::redis_available(config)) {
    stop("Can't connect to Redis. Check the configuration.")
  }
  assign("n_workers", n_workers, rush_env)
  assign("config", config, rush_env)
  assign("lgr_thresholds", lgr_thresholds, rush_env)
  assign("lgr_buffer_size", lgr_buffer_size, rush_env)
  assign("large_objects_path", large_objects_path, rush_env)
  assign("worker_type", worker_type, rush_env)
  invisible(as.list(rush_env))
}

#' @title Get Rush Config
#'
#' @description
#' Returns the rush config that was set by [rush_plan()].
#'
#' @return `list()` with the stored configuration.
#'
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'   config_local = redux::redis_config()
#'   rush_plan(config = config_local, n_workers = 2)
#'   rush_config()
#' }
rush_config = function() {
  list(
    config = rush_env$config,
    n_workers = rush_env$n_workers,
    lgr_thresholds = rush_env$lgr_thresholds,
    lgr_buffer_size = rush_env$lgr_buffer_size,
    large_objects_path = rush_env$large_objects_path,
    start_worker_timeout = rush_env$start_worker_timeout,
    worker_type = rush_env$worker_type)
}

#' @title Remove Rush Plan
#'
#' @description
#' Removes the rush plan that was set by [rush_plan()].
#'
#' @return Invisible `TRUE`. Function called for side effects.
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'   config_local = redux::redis_config()
#'   rush_plan(config = config_local, n_workers = 2)
#'   remove_rush_plan()
#' }
remove_rush_plan = function() {
  rm(list = ls(envir = rush_env), envir = rush_env)
  invisible(TRUE)
}

#' @title Rush Available
#'
#' @description
#' Returns `TRUE` if a redis config file ([redux::redis_config]) has been set by [rush_plan()].
#'
#' @return `logical(1)`
#'
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'   config_local = redux::redis_config()
#'   rush_plan(config = config_local, n_workers = 2)
#'   rush_available()
#' }
rush_available = function() {
  exists("config", rush_env)
}

rush_env = new.env(parent = emptyenv())
