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
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
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
  worker_id = NULL,
  network_id,
  config = NULL,
  remote = TRUE,
  lgr_thresholds = NULL,
  lgr_buffer_size = 0
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

  # setup logger
  if (!is.null(lgr_thresholds)) {
    assert_vector(lgr_thresholds, names = "named")
    assert_count(lgr_buffer_size)

    # add redis appender
    appender = rush::AppenderRedis$new(
      config = config,
      key = sprintf("%s:%s:%s", network_id, worker_id, "events"),
      buffer_size = lgr_buffer_size
    )
    root_logger = lgr::get_logger("root")
    root_logger$add_appender(appender)
    root_logger$remove_appender("console")

    # restore log levels
    for (package in names(lgr_thresholds)) {
      logger = lgr::get_logger(package)
      threshold = lgr_thresholds[package]
      logger$set_threshold(threshold)
    }
  }

  lg$debug("Setup worker %s at %s", worker_id, timestamp_start)

  # get start arguments
  timestamp_connected = Sys.time()
  bin_start_args = r$command(list("GET", sprintf("%s:start_args", network_id)))

  lg$debug("Downloaded start arguments %s bytes in %i seconds", format(object.size(bin_start_args), units = "MB"), as.integer(difftime(Sys.time(), timestamp_connected, units = "secs")))
  timestamp_loaded = Sys.time()

  lg$debug("Loaded %i base packages, %i other packages and %i loaded only packages", length(sessionInfo()$basePkgs), length(sessionInfo()$otherPkgs), length(sessionInfo()$loadedOnly))

  start_args = unserialize(bin_start_args)

  lg$debug("Unserialized start arguments in %i seconds", as.integer(difftime(Sys.time(), timestamp_loaded, units = "secs")))
  lg$debug("Loaded %i base packages, %i other packages and %i loaded only packages", length(sessionInfo()$basePkgs), length(sessionInfo()$otherPkgs), length(sessionInfo()$loadedOnly))

  timestamp_unserialized = Sys.time()

  # load large object from disk
  if (inherits(start_args, "rush_large_object")) {
    start_args = readRDS(start_args$path)
  }

  lg$debug("Loaded large object in %i seconds", as.integer(difftime(Sys.time(), timestamp_unserialized, units = "secs")))

  # load packages and globals to worker environment
  # envir = .GlobalEnv
  # mlr3misc::walk(start_args$packages, function(package) library(package, character.only = TRUE))
  # mlr3misc::iwalk(start_args$globals, function(value, name) assign(name, value, envir))

  lg$debug("Loaded packages and globals")

  # initialize rush worker
  rush = rush::RushWorker$new(
    network_id = network_id,
    worker_id = worker_id,
    config = config,
    remote = remote)

  lg$debug("Worker %s started in %i seconds", rush$worker_id, as.integer(difftime(Sys.time(), timestamp_start, units = "secs")))

  # run worker loop
  mlr3misc::invoke(start_args$worker_loop, rush = rush, .args = start_args$worker_loop_args)

  rush$set_terminated()

  lg$debug("Worker %s terminated after %i seconds", rush$worker_id, as.integer(difftime(Sys.time(), timestamp_start, units = "secs")))

  invisible(TRUE)
}
