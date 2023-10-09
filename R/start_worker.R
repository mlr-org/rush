
#' @title Start a worker
#'
#' @description
#' Start a worker.
#' This function initializes the connection to the redis server, loads the packages and globals and calls [run_worker].
#' Call `$create_worker_script()` of [Rush] before calling this function.
#'
#' @param instance_id (`character(1)`)\cr
#' Identifier of the rush instance.
#' @param ... (`any`)\cr
#' Arguments passed to [redux::redis_config].
#'
#' @export
start_worker = function(
  instance_id,
  ...) {

  config = mlr3misc::invoke(redux::redis_config, args = list(...))
  r = redux::hiredis(config)
  bin_args = r$command(list("GET", sprintf("%s:worker_script", instance_id)))
  args = redux::bin_to_object(bin_args)

  # load packages and globals to worker environment
  mlr3misc::walk(args$packages, function(package) library(package, character.only = TRUE))
  walk(ls(args$env), function(name) assign(name, args$env[[name]], globalenv()))
  args$packages = args$env = NULL

  invoke(rush::run_worker, instance_id = instance_id, config = config, .args = args)
}
