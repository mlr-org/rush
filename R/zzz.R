#' @import data.table
#' @import redux
#' @import mlr3misc
#' @import checkmate
#' @import mirai
#' @importFrom R6 R6Class
#' @importFrom processx process
#' @importFrom uuid UUIDgenerate
#' @importFrom utils object.size
#' @importFrom jsonlite fromJSON
#' @importFrom ids adjective_animal
#'
#' @section Options:
#' * `rush.max_object_size`:
#'   Maximum size in MiB of the serialized worker configuration stored in Redis.
#'   Defaults to `512`.
#'   If the configuration exceeds this limit, an error is raised unless `large_objects_path` is set in [rush_plan()],
#'   in which case the configuration is written to disk instead.
#'
#' @section Environment Variables:
#' * `REDIS_URL`:
#'   Connection URL parsed by [redux::redis_config] to configure the connection to Redis.
#'   Used when no `config` is set via [rush_plan()].
#'   If unset, a default configuration is used.
"_PACKAGE"

.onLoad = function(libname, pkgname) {
  # setup logger
  lg = lgr::get_logger("mlr3/rush")
  assign("lg", lg, envir = parent.env(environment()))
  f = function(event) {
    event$msg = paste0("[rush] ", event$msg)
    TRUE
  }
  lg$set_filters(list(f))

  if (Sys.getenv("IN_PKGDOWN") == "true") {
    lg$set_threshold("warn")
  }
}
