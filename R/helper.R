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
      con = pipe("/usr/bin/env uname -n")
      on.exit(close(con))
      host = readLines(con)
    }
  }
  host[1]
}

# Generate worker ids.
# adjective_animal() samples with replacement and can collide; appending a uuid fragment makes the
# ids unique by construction, without any cross-process coordination.
generate_worker_ids = function(n = 1L) {
  paste0(adjective_animal(n), "_", strtrim(UUIDgenerate(n = n), 8L))
}

# skips serialization of NULL
safe_bin_to_object = function(bin) {
  if (is.null(bin)) {
    return(NULL)
  }
  redux::bin_to_object(bin)
}

# wrap each condition in an extra list so read_hashes() flattening keeps a single `condition` column
wrap_conditions = function(conditions) {
  map(conditions, function(condition) list(condition = list(condition)))
}
