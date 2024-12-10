#' @import data.table
#' @import redux
#' @import mlr3misc
#' @import checkmate
#' @import mirai
#' @importFrom R6 R6Class
#' @importFrom processx process
#' @importFrom uuid UUIDgenerate
#' @importFrom utils str object.size
#' @importFrom jsonlite fromJSON
#' @importFrom parallel nextRNGStream nextRNGSubStream
#' @importFrom ids adjective_animal
"_PACKAGE"

.onLoad = function(libname, pkgname) {
  # setup logger
  lg = lgr::get_logger(pkgname)
  assign("lg", lg, envir = parent.env(environment()))
  f = function(event) {
    event$msg = paste0("[rush] ", event$msg)
    TRUE
  }
  lg$set_filters(list(f))
  if (Sys.getenv("IN_PKGDOWN") == "true") {
    lg$set_threshold("warn")
  }
} # nocov end
