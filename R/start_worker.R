
#' @title Start a worker
#'
#' @description
#' Starts a worker.
#' The function is called by the user after creating the worker script with `$create_worker_script()` of [Rush].
#' The function is started with `Rscript -e 'start_worker(network_id, url, ...)'`.
#'
#' @note
#' The function initializes the connection to the Redis data base.
#' It loads the packages and copies the globals to the global environment of the worker.
#' The function calls [run_worker] to initialize the [RushWorker] instance and starts the worker loop.
#' This function is only called when the worker is started with a script.
#'
#' @param ... (`any`)\cr
#' Arguments passed to [redux::redis_config].
#'
#' @template param_network_id
#'
#' @export
start_worker = function(
  network_id,
  ...) {
  checkmate::assert_string(network_id)

  config = mlr3misc::invoke(redux::redis_config, args = list(...))
  r = redux::hiredis(config)
  bin_args = r$command(list("GET", sprintf("%s:worker_script", network_id)))
  args = redux::bin_to_object(bin_args)

  # load packages and globals to worker environment
  mlr3misc::walk(args$packages, function(package) library(package, character.only = TRUE))
  mlr3misc::iwalk(args$globals, function(value, name) assign(name, value, .GlobalEnv))
  args$packages = args$globals = NULL

  mlr3misc::invoke(rush::run_worker, network_id = network_id, config = config, .args = args)
}
