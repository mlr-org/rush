#' @title Rush Worker
#'
#' @description
#' [RushWorker] runs on a worker and executes tasks.
#' The rush worker inherits from [Rush] and adds methods to pop tasks from the queue and push results to the data base.
#'
#' @note
#' The worker registers itself in the data base of the rush network.
#'
#' @section Logging:
#' The worker logs all messages written with the `lgr` package to the data base.
#' The `lgr_thresholds` argument defines the logging level for each logger e.g. `c(rush = "debug")`.
#' Saving log messages adds a small overhead but is useful for debugging.
#' By default, no log messages are stored.
#'
#' @template param_instance_id
#' @template param_config
#' @template param_host
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_lgr_thresholds
#'
#' @export
RushWorker = R6::R6Class("RushWorker",
  inherit = Rush,
  public = list(

    #' @field worker_id (`character(1)`)\cr
    #' Identifier of the worker.
    worker_id = NULL,

    #' @field host (`character(1)`)\cr
    #' Worker is started on a local or remote host.
    host = NULL,

    #' @field heartbeat ([callr::r_process])\cr
    #' Background process for the heartbeat.
    heartbeat = NULL,

    #' @field lgr_buffer ([lgr::AppenderBuffer])\cr
    #' Buffer that saves all log messages.
    lgr_buffer = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(instance_id, config = redux::redis_config(), host, worker_id = NULL, heartbeat_period = NULL, heartbeat_expire = NULL, lgr_thresholds = NULL) {
      self$host = assert_choice(host, c("local", "remote"))
      self$worker_id = assert_string(worker_id %??% uuid::UUIDgenerate())

      super$initialize(instance_id = instance_id, config = config)

      # start heartbeat
      assert_numeric(heartbeat_period, null.ok = TRUE)
      r = self$connector
      if (!is.null(heartbeat_period)) {
        assert_numeric(heartbeat_expire, null.ok = TRUE)
        heartbeat_expire = heartbeat_expire %??% heartbeat_period * 3
        r$SET(private$.get_worker_key("heartbeat"), heartbeat_period)
        heartbeat_args = list(
          instance_id = self$instance_id,
          config = self$config,
          worker_id = self$worker_id,
          period = heartbeat_period,
          expire = heartbeat_expire,
          pid = Sys.getpid()
        )
        self$heartbeat = callr::r_bg(fun_heartbeat, args = heartbeat_args, supervise = TRUE)
      }

      # save logging on worker
      if (!is.null(lgr_thresholds)) {
        self$lgr_buffer = lgr::AppenderBuffer$new()
        for (package in names(lgr_thresholds)) {
          logger = lgr::get_logger(package)
          threshold = lgr_thresholds[package]
          logger$set_threshold(threshold)
          logger$add_appender(self$lgr_buffer)
        }
      }

      # register worker
      r$SADD(private$.get_key("worker_ids"), self$worker_id)
      r$command(c(
        "HSET", private$.get_key(self$worker_id),
        "worker_id", self$worker_id,
        "pid", Sys.getpid(),
        "status", "running",
        "host", self$host,
        "heartbeat", as.character(!is.null(self$heartbeat))))
    },

    #' @description
    #' Pop a task from the queue.
    #' Task is moved to the running tasks.
    #'
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for task in seconds.
    pop_task = function(timeout = 1) {
      r = self$connector

      key = r$command(c("BLMPOP", timeout, 2, private$.get_worker_key("queued_tasks"), private$.get_key("queued_tasks"), "RIGHT"))[[2]][[1]]

      if (is.null(key)) return(NULL)
      self$write_hashes(worker_extra = list(list(pid = Sys.getpid(), worker_id = self$worker_id)), keys = key, status = "running")

      # move key from queued to running
      r$command(c("SADD", private$.get_key("running_tasks"), key))
      list(key = key, xs = redux::bin_to_object(r$HGET(key, "xs")))
    },

    #' @description
    #' Pushes results to the data base.
    #'
    #' @param keys (`character(1)`)\cr
    #' Keys of the associated tasks.
    #' @param yss (named `list()`)\cr
    #' List of lists of named results.
    #' @param extra (named `list()`)\cr
    #' List of lists of additional information stored along with the results.
    #' @param conditions (named `list()`)\cr
    #' List of lists of conditions.
    #' @param status (`character(1)`)\cr
    #' Status of the tasks.
    #' If `"finished"` the tasks are moved to the finished tasks.
    #' If `"error"` the tasks are moved to the failed tasks.
    push_results = function(keys, yss = list(), extra = list(), conditions = list(), status = "finished") {
      assert_string(keys)
      assert_list(yss, types = "list")
      assert_list(extra, types = "list")
      assert_list(conditions, types = "list")
      assert_choice(status, c("finished", "failed"))
      r = self$connector

      # write result to hash
      self$write_hashes(ys = yss, ys_extra = extra, condition = conditions, keys = keys, status = status)

      destination = if (status == "finished") "finished_tasks" else "failed_tasks"

      # move key from running to finished or failed
      # keys of finished and failed tasks are stored in a list i.e. the are ordered by time.
      # each rush instance only needs to record how many results it has already seen
      # to cheaply get the latest results and cache the finished tasks
      # under some conditions a set would be more advantageous e.g. to check if a task is finished,
      # but at the moment a list seems to be the better option
      r$pipeline(.commands = list(
        c("SREM", private$.get_key("running_tasks"), keys),
        c("RPUSH", private$.get_key(destination), keys)
      ))

      return(invisible(self))
    },

    #' @description
    #' Write log message written with the `lgr` package to the database.
    write_log = function() {
      if (!is.null(self$lgr_buffer)) {
        r = self$connector
        tab = self$lgr_buffer$dt
        if (nrow(tab)) {
          bin_log = redux::object_to_bin(self$lgr_buffer$dt)
          r$command(list("RPUSH", private$.get_worker_key("log"), bin_log))
          self$lgr_buffer$flush()
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Mark the worker as terminated.
    #' Last step in the worker loop before the worker terminates.
    set_terminated = function() {
      r = self$connector
      lg$debug("Worker %s terminated", self$worker_id)
      self$write_log()
      r$command(c("HSET", private$.get_key(self$worker_id), "status", "terminated"))
      return(invisible(self))
    }
  ),

  active = list(

    #' @field terminated (`logical(1)`)\cr
    #' Whether to shutdown the worker.
    #' Used in the worker loop to determine whether to continue.
    terminated = function() {
      r = self$connector
      r$GET(private$.get_worker_key("terminate")) %??% "FALSE" == "TRUE"
    },

    #' @field terminate_on_idle (`logical(1)`)\cr
    #' Whether to shutdown the worker if no tasks are queued.
    #' Used in the worker loop to determine whether to continue.
    terminated_on_idle = function() {
      r = self$connector
      r$GET(private$.get_key("terminate_on_idle")) %??% "FALSE" == "TRUE" && !as.logical(self$n_queued_tasks)
    }
  )
)
