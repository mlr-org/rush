#' @title Rush Worker
#'
#' @description
#' [RushWorker] evaluates tasks and writes results to the data base.
#' The worker inherits from [Rush].
#'
#' @note
#' The worker registers itself in the data base of the rush network.
#'
#' @template param_network_id
#' @template param_config
#' @template param_remote
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
#' @template param_seed
#'
#' @return Object of class [R6::R6Class] and `RushWorker` with worker methods.
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'    rush = rsh(network_id = "test_network", config = config_local)
#'
#'    fun = function(x1, x2, ...) list(y = x1 + x2)
#'    rush$start_local_workers(fun = fun)
#'
#'    rush$stop_workers()
#' }
RushWorker = R6::R6Class("RushWorker",
  inherit = Rush,
  public = list(

    #' @field worker_id (`character(1)`)\cr
    #' Identifier of the worker.
    worker_id = NULL,

    #' @field remote (`logical(1)`)\cr
    #' Whether the worker is on a remote machine.
    remote = NULL,

    #' @field heartbeat (`r_process``)\cr
    #' Background process for the heartbeat.
    heartbeat = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(
      network_id,
      config = NULL,
      remote,
      worker_id = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = 0,
      seed = NULL
      ) {
      super$initialize(network_id = network_id, config = config, seed = seed)

      self$remote = assert_flag(remote)
      self$worker_id = assert_string(worker_id %??% uuid::UUIDgenerate())
      r = self$connector

      # setup heartbeat
      if (!is.null(heartbeat_period)) {
        require_namespaces("callr")
        assert_numeric(heartbeat_period, null.ok = TRUE)
        assert_numeric(heartbeat_expire, null.ok = TRUE)
        heartbeat_expire = heartbeat_expire %??% heartbeat_period * 3

        # set heartbeat key
        r$SET(private$.get_worker_key("heartbeat"), heartbeat_period)

        # start heartbeat process
        heartbeat_args = list(
          network_id = self$network_id,
          config = self$config,
          worker_id = self$worker_id,
          heartbeat_period = heartbeat_period,
          heartbeat_expire = heartbeat_expire,
          pid = Sys.getpid()
        )
        self$heartbeat = callr::r_bg(heartbeat, args = heartbeat_args, supervise = TRUE)

        # wait until heartbeat process is able to work
        Sys.sleep(1)
      }

      # setup logger
      if (!is.null(lgr_thresholds)) {
        assert_vector(lgr_thresholds, names = "named")
        assert_count(lgr_buffer_size)

        # add redis appender
        appender = AppenderRedis$new(
          config = self$config,
          key = private$.get_worker_key("events"),
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

      # register worker ids
      r$SADD(private$.get_key("worker_ids"), self$worker_id)
      r$SADD(private$.get_key("running_worker_ids"), self$worker_id)

      # if worker is started with a heartbeat, monitor with heartbeat, otherwise monitor with pid
      if (!is.null(self$heartbeat)) {
        r$SADD(private$.get_key("heartbeat_keys"), private$.get_worker_key("heartbeat"))
      } else if (!self$remote) {
        r$SADD(private$.get_key("local_workers"), self$worker_id)
      }

      # register worker info in
      r$command(c(
        "HSET", private$.get_key(self$worker_id),
        "worker_id", self$worker_id,
        "pid", Sys.getpid(),
        "remote", self$remote,
        "hostname", rush::get_hostname(),
        "heartbeat", if (is.null(self$heartbeat)) NA_character_ else private$.get_worker_key("heartbeat")))

      # remove from pre-started workers
      r$SREM(sprintf("%s:pre_worker_ids", self$network_id), self$worker_id)
    },

    #' @description
    #' Push a task to running tasks without queue.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_running_tasks = function(xss, extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      r = self$connector

      lg$debug("Pushing %i running task(s).", length(xss))

      keys = self$write_hashes(xs = xss, xs_extra = extra, worker_extra = list(list(pid = Sys.getpid(), worker_id = self$worker_id)))
      r$command(c("SADD", private$.get_key("running_tasks"), keys))
      r$command(c("RPUSH", private$.get_key("all_tasks"), keys))

      return(invisible(keys))
    },

    #' @description
    #' Pop a task from the queue.
    #' Task is moved to the running tasks.
    #'
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for task in seconds.
    #' @param fields (`character()`)\cr
    #' Fields to be returned.
    pop_task = function(timeout = 1, fields = "xs") {
      r = self$connector

      key = r$command(c("BLMPOP", timeout, 2, private$.get_worker_key("queued_tasks"), private$.get_key("queued_tasks"), "RIGHT"))[[2]][[1]]

      if (is.null(key)) return(NULL)
      self$write_hashes(worker_extra = list(list(pid = Sys.getpid(), worker_id = self$worker_id)), keys = key)

      # move key from queued to running
      r$command(c("SADD", private$.get_key("running_tasks"), key))

      task = self$read_hash(key = key, fields = fields)
      task$key = key
      task
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
    push_results = function(keys, yss, extra = NULL) {
      assert_character(keys)
      assert_list(yss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      r = self$connector

      # write results to hashes
      self$write_hashes(
        ys = yss,
        ys_extra = extra,
        keys = keys)

      # move key from running to finished
      # keys of finished tasks are stored in a list i.e. the are ordered by time
      # each rush instance only needs to record how many results it has already seen
      # to cheaply get the latest results and cache the finished tasks
      # under some conditions a set would be more advantageous e.g. to check if a task is finished,
      # but at the moment a list seems to be the better option
      r$pipeline(.commands = list(
        c("SREM", private$.get_key("running_tasks"), keys),
        c("RPUSH", private$.get_key("finished_tasks"), keys)
      ))

      return(invisible(self))
    },

    #' @description
    #' Mark the worker as terminated.
    #' Last step in the worker loop before the worker terminates.
    set_terminated = function() {
      r = self$connector
      lg$debug("Worker %s terminated", self$worker_id)
      r$pipeline(.commands = list(
        c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), self$worker_id),
        c("SREM", private$.get_key("local_workers"), self$worker_id),
        c("SREM", private$.get_key("heartbeat_keys"), private$.get_worker_key("heartbeat")
      )))
      return(invisible(self))
    }
  ),

  active = list(

    #' @field terminated (`logical(1)`)\cr
    #' Whether to shutdown the worker.
    #' Used in the worker loop to determine whether to continue.
    terminated = function() {
      r = self$connector
      as.logical(r$EXISTS(private$.get_worker_key("terminate")))
    },

    #' @field terminated_on_idle (`logical(1)`)\cr
    #' Whether to shutdown the worker if no tasks are queued.
    #' Used in the worker loop to determine whether to continue.
    terminated_on_idle = function() {
      r = self$connector
      as.logical(r$EXISTS(private$.get_key("terminate_on_idle"))) && !as.logical(self$n_queued_tasks)
    }
  )
)
