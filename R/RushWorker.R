#' @title Rush Worker
#'
#' @description
#' [RushWorker] inherits all methods from [Rush].
#' Upon initialization, the worker registers itself in the Redis database as a running worker.
#' This class is usually not constructed directly by the user.
#'
#' In addition to the inherited methods, the worker provides methods that require a worker identity:
#'
#' * `$pop_task()`: Pop a task from the queue and mark it as running.
#' * `$push_running_tasks(xss)`: Create running tasks owned by the worker.
#'
#' @template param_network_id
#' @template param_config
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#'
#' @return Object of class [R6::R6Class] and `RushWorker`.
#' @export
RushWorker = R6::R6Class(
  "RushWorker",
  inherit = Rush,
  public = list(
    #' @field worker_id (`character(1)`)\cr
    #' Identifier of the worker.
    worker_id = NULL,

    #' @field heartbeat (`callr::r_bg`)\cr
    #' Background process for the heartbeat.
    heartbeat = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(
      network_id,
      config = NULL,
      worker_id = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL
    ) {
      super$initialize(network_id = network_id, config = config)

      self$worker_id = assert_string(worker_id %??% ids::adjective_animal(1))
      r = self$connector

      # setup heartbeat
      heartbeat_key = NA_character_
      if (!is.null(heartbeat_period)) {
        require_namespaces("callr")
        assert_number(heartbeat_period)
        assert_number(heartbeat_expire, null.ok = TRUE)
        heartbeat_expire = heartbeat_expire %??% (heartbeat_period * 3)

        # set heartbeat key
        heartbeat_key = private$.get_worker_key("heartbeat")
        r$SET(heartbeat_key, heartbeat_period)

        # start heartbeat process
        heartbeat_args = list(
          network_id = self$network_id,
          config = self$config,
          worker_id = self$worker_id,
          heartbeat_key = heartbeat_key,
          heartbeat_period = heartbeat_period,
          heartbeat_expire = heartbeat_expire,
          pid = Sys.getpid()
        )
        self$heartbeat = callr::r_bg(heartbeat, args = heartbeat_args, supervise = TRUE)

        # wait until heartbeat process has set the first EXPIRE on the key
        # the key is created with SET (no TTL), the heartbeat loop adds a TTL via EXPIRE
        timeout = 5
        start_time = Sys.time()
        while (difftime(Sys.time(), start_time, units = "secs") < timeout) {
          if (r$command(c("TTL", heartbeat_key)) > 0) {
            break
          }
          Sys.sleep(0.1)
        }

        r$SADD(private$.get_key("heartbeat_keys"), heartbeat_key)
      }

      # register worker ids and worker info
      r$MULTI()
      r$SADD(private$.get_key("worker_ids"), self$worker_id)
      r$SADD(private$.get_key("running_worker_ids"), self$worker_id)
      r$command(c(
        "HSET",
        private$.get_key(self$worker_id),
        "worker_id",
        self$worker_id,
        "pid",
        Sys.getpid(),
        "hostname",
        rush::get_hostname(),
        "heartbeat",
        heartbeat_key
      ))
      r$EXEC()
    },

    #' @description
    #' Pop a task from the queue and mark it as running.
    #'
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for task in seconds.
    #' @param fields (`character()`)\cr
    #' Fields to be returned.
    pop_task = function(timeout = 1, fields = "xs") {
      r = self$connector

      key = r$command(c("BLMPOP", timeout, 1, private$.get_key("queued_tasks"), "RIGHT"))[[2]][[1]]

      if (is.null(key)) {
        return(NULL)
      }
      self$write_hashes(worker_id = list(self$worker_id), keys = key)

      # move key from queued to running
      r$command(c("SADD", private$.get_key("running_tasks"), key))

      task = self$read_hash(key = key, fields = fields)
      task$key = key
      task
    },

    #' @description
    #' Create running tasks.
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

      keys = self$write_hashes(xs = xss, xs_extra = extra, worker_id = list(self$worker_id))
      r$command(c("SADD", private$.get_key("running_tasks"), keys))
      r$command(c("RPUSH", private$.get_key("all_tasks"), keys))

      return(invisible(keys))
    },

    #' @description
    #' Mark the worker as terminated.
    #' Last step in the worker loop before the worker terminates.
    #'
    #' @return (`RushWorker`)\cr
    #' Invisible self.
    set_terminated = function() {
      r = self$connector
      lg$debug("Worker %s terminated", self$worker_id)
      r$command(c(
        "SMOVE",
        private$.get_key("running_worker_ids"),
        private$.get_key("terminated_worker_ids"),
        self$worker_id
      ))
      invisible(self)
    }
  ),

  active = list(
    #' @field terminated (`logical(1)`)\cr
    #' Whether to shutdown the worker.
    #' Used in the worker loop to determine whether to continue.
    terminated = function() {
      r = self$connector
      as.logical(r$EXISTS(private$.get_worker_key("terminate")))
    }
  )
)
