#' @param config ([redux::redis_config])\cr
#' Redis configuration options.
#' If `NULL`, configuration set by [rush_plan()] is used.
#' If `rush_plan()` has not been called, the `REDIS_URL` environment variable is parsed.
#' If `REDIS_URL` is not set, a default configuration is used.
#' See [redux::redis_config] for details.
