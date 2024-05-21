#' @title Start a worker
#'
#' @description
#' Starts a worker.
#' The function loads the globals and packages, initializes the [RushWorker] instance and invokes the worker loop.
#' This function is called by `$start_workers()` or by the user after creating the worker script with `$create_worker_script()`.
#'
#' @note
#' The function initializes the connection to the Redis data base.
#' It loads the packages and copies the globals to the global environment of the worker.
#' The function initialize the [RushWorker] instance and starts the worker loop.
#'
#' @param hostname (`character(1)`)\cr
#' Hostname of the rush controller instance.
#' Used to determine if the worker is started on a local or remote host.
#' @param ... (`any`)\cr
#' Arguments passed to [redux::redis_config].
#'
#' @template param_network_id
#' @template param_worker_id
#'
#' @export
start_worker = function(
  network_id,
  worker_id = NULL,
  hostname,
  ...) {
  checkmate::assert_string(network_id)
  checkmate::assert_string(worker_id, null.ok = TRUE)
  checkmate::assert_string(hostname)

  # connect to redis
  config = list(...)
  if (!is.null(config$port)) config$port = as.integer(config$port)
  if (!is.null(config$timeout)) config$timeout = as.integer(config$timeout)
  config = redux::redis_config(config = config)
  r = redux::hiredis(config)

  # get start arguments
  bin_start_args = r$command(list("GET", sprintf("%s:start_args", network_id)))
  if (is.null(bin_start_args)) {
    stopf("No start arguments found for network '%s'.", network_id)
  }
  start_args = redux::bin_to_object(bin_start_args)

  # load large object from disk
  if (inherits(start_args, "rush_large_object")) {
    start_args = readRDS(start_args$path)
  }

  # load packages and globals to worker environment
  mlr3misc::walk(start_args$packages, function(package) library(package, character.only = TRUE))
  mlr3misc::iwalk(start_args$globals, function(value, name) assign(name, value, .GlobalEnv))

  # initialize rush worker
  host = if (rush::get_hostname() == hostname) "local" else "remote"
  rush = invoke(rush::RushWorker$new,
    network_id = network_id,
    worker_id = worker_id,
    config = config,
    host = host,
    .args = start_args$worker_args)

  lg$debug("Worker %s started.", rush$worker_id)

  # run worker loop
  mlr3misc::invoke(start_args$worker_loop, rush = rush, .args = start_args$worker_loop_args)

  rush$set_terminated()

  return(NULL)
}
