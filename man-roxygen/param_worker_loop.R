#' @param worker_loop (`function`)\cr
#' Loop run on the workers.
#' Defaults to [worker_loop_default] which is called with `fun`.
#' Pass `fun` in `...`.
#' Use [worker_loop_callr] to run `fun` in an external callr session.
