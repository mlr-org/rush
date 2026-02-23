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
