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


#' @export
deprecated_binding = function(what, value) {
  assert_string(what)
  # build the function-expression that should be evaluated in the parent frame.
  fnq = substitute(function(rhs) {
      # don't throw a warning if we are converting the R6-object to a list, e.g.
      # when all.equals()-ing it.
      if (!identical(sys.call(-1)[[1]], quote(as.list.environment))) {
        warn_deprecated(what)
      }
      ## 'value' could be an expression that gets substituted here, which we only want to evaluate once
      x = value
      if (!missing(rhs) && !identical(rhs, x)) {
        error_mlr3(sprintf("%s read-only.", what))
      }
      x
    },
    # we substitute the 'what' constant directly, but the 'value' as expression.
    env = list(what = what, value = substitute(value))
  )
  eval.parent(fnq)
}
