#' @title Create Rush Plan
#'
#' @description
#' Stores the number of workers and Redis configuration options ([redux::redis_config]) for [Rush].
#' The function tests the connection to Redis and throws an error if the connection fails.
#'
#' @param config ([redux::redis_config])\cr
#' Configuration options used to connect to Redis.
#' If `NULL`, the `REDIS_URL` environment variable is parsed.
#' If `REDIS_URL` is not set, a default configuration is used.
#' See [redux::redis_config] for details.
#'
#' @template param_n_workers
#'
#' @export
rush_plan = function(n_workers, config = NULL) {
  assert_count(n_workers)
  config = assert_class(config, "redis_config", null.ok = TRUE)
  if (is.null(config)) config = redux::redis_config()
  if (!redux::redis_available(config)) {
    stop("Can't connect to Redis. Check the configuration.")
  }
  assign("n_workers", n_workers, rush_env)
  assign("config", config, rush_env)
}

#' @title Get Rush Config
#'
#' @description
#' Returns the redis config file ([redux::redis_config]) that was set by [rush_plan()].
#'
#' @return [redux::redis_config()]\cr
#' A redis config file.
#'
#' @export
rush_config = function() {
  list(config = rush_env$config, n_workers = rush_env$n_workers)
}

#' @title Rush Available
#'
#' @description
#' Returns `TRUE` if a redis config file ([redux::redis_config]) has been set by [rush_plan()].
#'
#' @return `logical(1)`
#'
#' @export
rush_available = function() {
  exists("config", rush_env)
}

rush_env = new.env(parent = emptyenv())
