#' @title Start a worker
#'
#' @description
#' Starts a worker.
#' The function loads the globals and packages, initializes the [RushWorker] instance and invokes the worker loop.
#' This function is called by `$start_local_workers()` or by the user after creating the worker script with `$create_worker_script()`.
#' Use with caution.
#' The global environment is changed.
#'
#' @note
#' The function initializes the connection to the Redis data base.
#' It loads the packages and copies the globals to the global environment of the worker.
#' The function initialize the [RushWorker] instance and starts the worker loop.
#'
#' @param remote (`logical(1)`)\cr
#' Whether the worker is on a remote machine.
#' @param config (`list()`)\cr
#' Configuration for the Redis connection.
#'
#' @template param_network_id
#' @template param_worker_id
#'
#' @return `NULL`
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \dontrun{
#'   rush::start_worker(
#'    network_id = 'test-rush',
#'    remote = TRUE,
#'    url = 'redis://127.0.0.1:6379',
#'    scheme = 'redis',
#'    host = '127.0.0.1',
#'    port = '6379')
#' }
start_worker = function(
  network_id,
  worker_id = NULL,
  config = NULL,
  remote = TRUE,
  wait_for_workers = NULL
  ) {
  timestamp_start = Sys.time()

  checkmate::assert_string(network_id)
  worker_id = checkmate::assert_string(worker_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
  checkmate::assert_flag(remote)

  # connect to redis
  if (!is.null(config$port)) config$port = as.integer(config$port)
  if (!is.null(config$timeout)) config$timeout = as.integer(config$timeout)
  config = redux::redis_config(config = config)
  r = redux::hiredis(config)

  timestamp_connected = Sys.time()

  # get start arguments
  bin_start_args = r$command(list("GET", sprintf("%s:start_args", network_id)))

  timestamp_loaded = Sys.time()

  start_args = redux::bin_to_object(bin_start_args)

  timestamp_unserialized = Sys.time()

  # load large object from disk
  if (inherits(start_args, "rush_large_object")) {
    start_args = readRDS(start_args$path)
  }

  timestamp_loaded_large_object = Sys.time()

  # load packages and globals to worker environment
  envir = .GlobalEnv
  mlr3misc::walk(start_args$packages, function(package) library(package, character.only = TRUE))
  mlr3misc::iwalk(start_args$globals, function(value, name) assign(name, value, envir))

  timestamp_globals = Sys.time()

  # initialize rush worker
  rush = invoke(rush::RushWorker$new,
    network_id = network_id,
    worker_id = worker_id,
    config = config,
    remote = remote,
    .args = start_args$worker_args)

  lg$debug("Worker %s started", rush$worker_id)
  lg$debug("Time to connect %i seconds", as.integer(difftime(timestamp_connected, timestamp_start, units = "secs")))
  lg$debug("Time to load objects %i seconds", as.integer(difftime(timestamp_loaded, timestamp_connected, units = "secs")))
  lg$debug("Start argument size %i bytes", object.size(bin_start_args))
  lg$debug("Time to unserialize objects %i seconds", as.integer(difftime(timestamp_unserialized, timestamp_loaded, units = "secs")))
  lg$debug("Time to load large object %i seconds", as.integer(difftime(timestamp_loaded_large_object, timestamp_loaded, units = "secs")))
  lg$debug("Time to load packages and globals %i seconds", as.integer(difftime(timestamp_globals, timestamp_loaded_large_object, units = "secs")))

  timestamp_wait = Sys.time()
  if (!is.null(wait_for_workers)) {
    while (rush$n_running_workers != wait_for_workers) {
      Sys.sleep(5)
    }
  }

  lg$debug("Time to wait for other workers %i seconds", as.integer(difftime(Sys.time(), timestamp_wait, units = "secs")))

  # run worker loop
  mlr3misc::invoke(start_args$worker_loop, rush = rush, .args = start_args$worker_loop_args)

  rush$set_terminated()

  invisible(TRUE)
}
