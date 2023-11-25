#' @title Create Rush Plan
#'
#' @description
#' Stores a redis config file ([redux::redis_config()]) that can be used by `Rush` to connect to a redis server.
#'
#' @param config [redux::redis_config()]\cr
#' A redis config file.
#'
#' @export
rush_plan = function(config, n_workers) {
  assert_class(config, "redis_config")
  assert_count(n_workers)
  assign("config", config, rush_env)
  assign("n_workers", n_workers, rush_env)
}

#' @title Get Rush Config
#'
#' @description
#' Returns the redis config file ([redux::redis_config()]) that was set by [rush_plan()].
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
#' Returns `TRUE` if a redis config file ([redux::redis_config()]) has been set by [rush_plan()].
#'
#' @return `logical(1)`
#'
#' @export
rush_available = function() {
  exists("config", rush_env)
}

rush_env = new.env(parent = emptyenv())
