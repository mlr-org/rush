#' @import data.table
#' @import redux
#' @import mlr3misc
#' @import future
#' @import checkmate
#' @importFrom uuid UUIDgenerate
#' @importFrom callr r_bg
#' @importFrom utils str
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
