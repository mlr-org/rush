#' @title Rush
#'
#' @description
#' Rush
#'
#' @export
RushWorker = R6::R6Class("RushWorker",
  inherit = Rush,
  public = list(

    #' @field worker_id (`character(1)`)\cr
    #' Identifier of the worker.
    worker_id = NULL,

    #' @field constants (`list()`)\cr
    #' List of constants.
    constants = NULL,

    #' @field host (`character(1)`)\cr
    #' Local or remote host.
    host = NULL,

    #' @field heartbeat (`callr::RBackgroundProcess`)\cr
    #' Background process for the heartbeat.
    heartbeat = NULL,

    #' @field lgr_buffer ([lgr::AppenderBuffer])\cr
    #' Buffer that saves all log messages.
    lgr_buffer = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    #'
    #' @param instance_id (`character(1)`)\cr
    #' Identifier of the rush instance.
    #' @param config ([redux::redis_config])\cr
    #' Redis configuration.
    #' @param host (`character(1)`)\cr
    #' Local or remote host.
    #' @param worker_id (`character(1)`)\cr
    #' Identifier of the worker.
    #' @param heartbeat_period (`numeric(1)`)\cr
    #' Period of the heartbeat.
    #' @param heartbeat_expire (`numeric(1)`)\cr
    #' Expiration of the heartbeat.
    #' @param lgr_thresholds (named `character()` or `numeric()`)\cr
    #' Logger thresholds.
    #' If `NULL`, no log messages are saved.
    initialize = function(instance_id, config = redux::redis_config(), host, worker_id = NULL, heartbeat_period = NULL, heartbeat_expire = NULL, lgr_thresholds = NULL) {
      self$host = assert_choice(host, c("local", "remote"))
      self$worker_id = assert_string(worker_id %??% uuid::UUIDgenerate())

      super$initialize(instance_id = instance_id, config = config)

      # set terminate key
      r = self$connector
      r$command(c("SET", private$.get_worker_key("terminate"), "FALSE"))

      # start heartbeat
      assert_numeric(heartbeat_period, null.ok = TRUE)
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
    #' If `finished` the tasks are moved to the finished tasks.
    #' If `error` the tasks are moved to the failed tasks.
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

      # move key from running to finished
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
    }
  ),

  active = list(

    #' @field terminate (`logical(1)`)\cr
    #' Whether to shutdown the worker.
    terminate = function() {
      r = self$connector
      r$GET(private$.get_worker_key("terminate")) == "TRUE"
    }
  )
)
