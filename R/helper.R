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

#' @title Set RNG Sate before Running a Function
#'
#' @description
#' This function sets the rng state before running a function.
#' Use with caution.
#' The global environment is changed.
#'
#' @param fun (`function`)\cr
#' Function to run.
#' @param args (`list`)\cr
#' Arguments to pass to `fun`.
#' @param seed (`integer`)\cr
#' RNG state to set before running `fun`.
#'
#' @return `any`
#' @keywords internal
#' @export
#' @examples
#' with_rng_state(runif, list(n = 1), .Random.seed)
with_rng_state = function(fun, args, seed) {
  if (!is.null(seed)) assign(".Random.seed", seed, envir = globalenv())
  mlr3misc::invoke(fun, .args = args)
}

# checks if a seed is a valid L'Ecuyer-CMRG seed
is_lecyer_cmrg_seed = function(seed) {
  is.numeric(seed) && length(seed) == 7L && all(is.finite(seed)) && (seed[1] %% 10000L == 407L)
}

# get the current RNG state
get_random_seed = function() {
  env = globalenv()
  env$.Random.seed
}

# set the RNG state
set_random_seed = function(seed, kind = NULL) {
  env = globalenv()
  old_seed = env$.Random.seed
  if (is.null(seed)) {
    if (!is.null(kind)) RNGkind(kind)
    rm(list = ".Random.seed", envir = env, inherits = FALSE)
  } else {
    env$.Random.seed = seed
  }
  invisible(old_seed)
}

# creates n L'Ecuyer-CMRG streams
make_rng_seeds = function(n, seed) {
  seeds = vector("list", length = n)
  for (ii in seq_len(n)) {
    seeds[[ii]] = seed = parallel::nextRNGStream(seed)
  }
  seeds
}

# skips serialization of NULL
safe_bin_to_object = function(bin) {
  if (is.null(bin)) return(NULL)
  redux::bin_to_object(bin)
}
