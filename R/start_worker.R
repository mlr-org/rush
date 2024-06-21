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
#' @param ... (`any`)\cr
#' Arguments passed to [redux::redis_config].
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
  remote = TRUE,
  ...
  ) {
  checkmate::assert_string(network_id)
  worker_id = checkmate::assert_string(worker_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
  checkmate::assert_flag(remote)

  # connect to redis
  config = list(...)
  if (!is.null(config$port)) config$port = as.integer(config$port)
  if (!is.null(config$timeout)) config$timeout = as.integer(config$timeout)
  config = redux::redis_config(config = config)
  r = redux::hiredis(config)

  # register to pre-started workers
  r$SADD(sprintf("%s:pre_worker_ids", network_id), worker_id)

  # wait for start arguments
  while (!r$EXISTS(sprintf("%s:start_args", network_id))) {
    lg$debug("Wait for start arguments for network '%s'.", network_id)
    Sys.sleep(1)
  }

  # get start arguments
  bin_start_args = r$command(list("GET", sprintf("%s:start_args", network_id)))
  start_args = redux::bin_to_object(bin_start_args)

  # load large object from disk
  if (inherits(start_args, "rush_large_object")) {
    start_args = readRDS(start_args$path)
  }

  # load packages and globals to worker environment
  envir = .GlobalEnv
  mlr3misc::walk(start_args$packages, function(package) library(package, character.only = TRUE))
  mlr3misc::iwalk(start_args$globals, function(value, name) assign(name, value, envir))

  # initialize rush worker
  rush = invoke(rush::RushWorker$new,
    network_id = network_id,
    worker_id = worker_id,
    config = config,
    remote = remote,
    .args = start_args$worker_args)

  lg$debug("Worker %s started.", rush$worker_id)

  # run worker loop
  mlr3misc::invoke(start_args$worker_loop, rush = rush, .args = start_args$worker_loop_args)

  rush$set_terminated()

  invisible(NULL)
}
