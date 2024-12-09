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
start_worker_mirai = function(
  network_id,
  worker_id = NULL,
  config = NULL,
  remote = TRUE,
  packages = NULL,
  globals = NULL,
  worker_args = list(),
  worker_loop = NULL,
  worker_loop_args = list()
  ) {
  timestamp_start = Sys.time()

  checkmate::assert_string(network_id)
  worker_id = checkmate::assert_string(worker_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
  checkmate::assert_flag(remote)
  checkmate::assert_list(config)
  checkmate::assert_character(packages, null.ok = TRUE)
  checkmate::assert_list(globals, null.ok = TRUE)
  checkmate::assert_list(worker_args, null.ok = TRUE)
  checkmate::assert_function(worker_loop)
  checkmate::assert_list(worker_loop_args, null.ok = TRUE)

  # connect to redis
  if (!is.null(config$port)) config$port = as.integer(config$port)
  if (!is.null(config$timeout)) config$timeout = as.integer(config$timeout)
  config = redux::redis_config(config = config)
  r = redux::hiredis(config)

  # load packages and globals to worker environment
  envir = .GlobalEnv
  mlr3misc::walk(packages, function(package) library(package, character.only = TRUE))
  mlr3misc::iwalk(globals, function(value, name) assign(name, value, envir))

  # initialize rush worker
  rush = invoke(rush::RushWorker$new,
    network_id = network_id,
    worker_id = worker_id,
    config = config,
    remote = remote,
    .args = worker_args)

  lg$debug("Worker %s started", rush$worker_id)
  lg$debug("Time to start worker %i seconds", as.integer(difftime(Sys.time(), timestamp_start, units = "secs")))

  # run worker loop
  mlr3misc::invoke(worker_loop, rush = rush, .args = worker_loop_args)

  rush$set_terminated()

  invisible(TRUE)
}


# start_remote_workers = function(
#   worker_loop,
#   ...,
#   n_workers = NULL,
#   globals = NULL,
#   packages = NULL,
#   lgr_thresholds = NULL,
#   lgr_buffer_size = 0
#   ) {
#   n_workers = assert_count(n_workers %??% rush_env$n_workers)

#   # check number of daemons
#   if (!daemons()$connections) {
#     stop("No daemons available. Start daemons with `mirai::daemons()`")
#   }
#   if (n_workers > sum(daemons()$daemons[,2])) {
#     warningf("Number of workers %i exceeds number of available daemons %i", n_workers, sum(daemons()$daemons[,2]))
#   }

#   # reduce redis config
#   config = mlr3misc::discard(unclass(self$config), is.null)

#   # generate worker ids
#   worker_ids = adjective_animal(n = n_workers)

#   # start rush worker with mirai
#   self$processes_mirai = c(self$processes_mirai, set_names(map(worker_ids, function(worker_id) {
#     # suppress missing packages warning from mirai when rush is used in another package
#     suppressWarnings({mirai({
#       rush::start_worker_mirai(
#         network_id,
#         worker_id,
#         config,
#         remote = TRUE,
#         packages,
#         globals,
#         worker_args,
#         worker_loop,
#         worker_loop_args)
#       },
#       .args = list(
#         network_id = self$network_id,
#         worker_id = worker_id,
#         config = config,
#         packages = packages,
#         globals = globals,
#         worker_args = list(lgr_thresholds = NULL, lgr_buffer_size = lgr_buffer_size),
#         worker_loop = worker_loop,
#         worker_loop_args = list(...)),
#       dispatcher = "process",
#       retry = TRUE)
#   })}), worker_ids))

#   return(invisible(worker_ids))
# }
