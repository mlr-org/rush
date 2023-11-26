#' @title Get the computer name of the current host
#'
#' @description
#' Returns the computer name of the current host.
#' First it tries to get the computer name from the environment variables `HOST`, `HOSTNAME` or `COMPUTERNAME`.
#' If this fails it tries to get the computer name from the function `Sys.info()`.
#' Finally, if this fails it queries the computer name from the command `uname -n`.
#' Copied from the `R.utils` package.
#'
#' @export
get_hostname = function() {
  host = Sys.getenv(c("HOST", "HOSTNAME", "COMPUTERNAME"))
  host = host[host != ""]
  if (length(host) == 0) {
    # Sys.info() is not implemented on all machines, if not it returns NULL,
    # which the below code will handle properly.
    host = Sys.info()["nodename"]
    host = host[host != ""]
    if (length(host) == 0) {
      host <- readLines(pipe("/usr/bin/env uname -n"))
    }
  }
  host[1]
}

# internal pid_exists functions from parallelly package by Henrik Bengtsson
# for more information see
# https://github.com/HenrikBengtsson/parallelly/blob/78a1b44021df2973d05224bfaa0b1a7abaf791ff/R/utils%2Cpid.R
choose_pid_exists = function() {
    os = .Platform$OS.type
    pid_check = NULL

    suppressWarnings({
      if (os == "unix") {
        if (isTRUE(pid_exists_by_pskill(Sys.getpid())) && getRversion() >= "3.5.0") {
          pid_check = pid_exists_by_pskill
        } else if (isTRUE(pid_exists_by_ps(Sys.getpid()))) {
          pid_check = pid_exists_by_ps
        }
      } else if (os == "windows") {
        if (isTRUE(pid_exists_by_tasklist(Sys.getpid()))) {
          pid_check = pid_exists_by_tasklist
        } else if (isTRUE(pid_exists_by_tasklist_filter(Sys.getpid()))) {
          pid_check = pid_exists_by_tasklist_filter
        }
      }
    })

    pid_check
}

pid_exists_by_tasklist_filter = function(pid, debug = FALSE) {
  for (kk in 1:5) {
    res = tryCatch({
      args = c("/FI", shQuote(sprintf("PID eq %.0f", pid)), "/NH")
      out = system2("tasklist", args = args, stdout = TRUE, stderr = "")
      if (debug) {
        cat(sprintf("Call: tasklist %s\n", paste(args, collapse = " ")))
        print(out)
        str(out)
      }
      out = gsub("(^[ ]+|[ ]+$)", "", out)
      out = out[nzchar(out)]
      if (debug) {
        cat("Trimmed:\n")
        print(out)
        str(out)
      }
      out = grepl(sprintf(" %.0f ", pid), out)
      if (debug) {
        cat("Contains PID: ", paste(out, collapse = ", "), "\n", sep = "")
      }
      any(out)
    }, error = function(ex) NA)
    if (isTRUE(res)) return(res)
    Sys.sleep(0.1)
  }
  res
}

pid_exists_by_tasklist = function(pid, debug = FALSE) {
  for (kk in 1:5) {
    res = tryCatch({
      out = system2("tasklist", stdout = TRUE, stderr = "")
      if (debug) {
        cat("Call: tasklist\n")
        print(out)
        str(out)
      }
      out = gsub("(^[ ]+|[ ]+$)", "", out)
      out = out[nzchar(out)]
      skip = grep("^====", out)[1]
      if (!is.na(skip)) out = out[seq(from = skip + 1L, to = length(out))]
      if (debug) {
        cat("Trimmed:\n")
        print(out)
        str(out)
      }
      out = strsplit(out, split = "[ ]+", fixed = FALSE)

      n = lengths(out)
      n = sort(n)[round(length(n) / 2)]
      drop = n - 2L
      out = lapply(out, FUN = function(x) rev(x)[-seq_len(drop)][1])
      out = unlist(out, use.names = FALSE)
      if (debug) {
        cat("Extracted: ", paste(sQuote(out), collapse = ", "), "\n", sep = "")
      }
      out = as.integer(out)
      if (debug) {
        cat("Parsed: ", paste(sQuote(out), collapse = ", "), "\n", sep = "")
      }
      out = (out == pid)
      if (debug) {
        cat("Equals PID: ", paste(out, collapse = ", "), "\n", sep = "")
      }
      any(out)
    }, error = function(ex) NA)
    if (isTRUE(res)) return(res)
    Sys.sleep(0.1)
  }
  res
}

pid_exists_by_pskill = function(pid, debug = FALSE) {
  tryCatch({
    as.logical(tools::pskill(pid, signal = 0L))
  }, error = function(ex) NA)
}

pid_exists_by_ps = function(pid, debug = FALSE) {
  tryCatch({
    out = suppressWarnings({
      system2("ps", args = pid, stdout = TRUE, stderr = FALSE)
    })

    status = attr(out, "status")
    if (is.numeric(status) && status < 0) return(NA)
    out = gsub("(^[ ]+|[ ]+$)", "", out)
    out = out[nzchar(out)]
    out = strsplit(out, split = "[ ]+", fixed = FALSE)
    out = lapply(out, FUN = function(x) x[1])
    out = unlist(out, use.names = FALSE)
    out = suppressWarnings(as.integer(out))
    any(out == pid)
  }, error = function(ex) NA)
}
