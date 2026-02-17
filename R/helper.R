#' @title Get the computer name of the current host
#'
#' @description
#' Returns the computer name of the current host.
#' First it tries to get the computer name from the environment variables `HOST`, `HOSTNAME` or `COMPUTERNAME`.
#' If this fails it tries to get the computer name from the function `Sys.info()`.
#' Finally, if this fails it queries the computer name from the command `uname -n`.
#' Copied from the `R.utils` package.
#'
#' @return `character(1)` of hostname.
#' @keywords internal
#' @export
#' @examples
#' get_hostname()
get_hostname = function() {
  host = Sys.getenv(c("HOST", "HOSTNAME", "COMPUTERNAME"))
  host = host[host != ""]
  if (length(host) == 0) {
    # Sys.info() is not implemented on all machines, if not it returns NULL,
    # which the below code will handle properly.
    host = Sys.info()["nodename"]
    host = host[host != ""]
    if (length(host) == 0) {
      host = readLines(pipe("/usr/bin/env uname -n"))
    }
  }
  host[1]
}

# skips serialization of NULL
safe_bin_to_object = function(bin) {
  if (is.null(bin)) return(NULL)
  redux::bin_to_object(bin)
}


#' @title Give a Warning about a Deprecated Function, Argument, or Active Binding
#'
#' @description
#' Generates a warning when a deprecated function, argument, or active binding
#' is used or accessed. A warning will only be given once per session, and all
#' deprecation warnings can be suppressed by setting the option
#' `mlr3.warn_deprecated = FALSE`.
#'
#' The warning is of the format
#' "what is deprecated and will be removed in the future."
#'
#' Use the `deprecated_binding()` helper function to create an active binding
#' that generates a warning when accessed.
#' @param what (`character(1)`)\cr
#'   A description of the deprecated entity. This should be somewhat descriptive,
#'   e.g. `"Class$method()"` or `"Argument 'foo' of Class$method()"`.\cr
#'   The `what` is used to determine if the warning has already been given, so
#'   it should be unique for each deprecated entity.
#' @keywords internal
#' @export
warn_deprecated = function(what) {
  assert_string(what)
  if (getOption("mlr3.warn_deprecated", TRUE) && !exists(what, envir = deprecated_warning_given_db)) {
    warning_mlr3(paste0(what, " is deprecated and will be removed in the future."), class = "Mlr3WarningDeprecated")
    assign(what, TRUE, envir = deprecated_warning_given_db)
  }
}

deprecated_warning_given_db = new.env(parent = emptyenv())
