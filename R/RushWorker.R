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
#' * `$push_running_tasks(xss)`: Create running tasks evaluated by the worker.
#' * `$finish_tasks(keys, yss)`: Save the output of tasks and mark them as finished.
#' * `$fail_tasks(keys, conditions)`: Mark tasks as failed and optionally save the condition objects.
#'
#' @template param_network_id
#' @template param_config
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_xss
#' @template param_xss_extra
#' @template param_yss
#' @template param_yss_extra
#' @template param_conditions
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
      # empty string marks the absence of a heartbeat; a non-empty value is the heartbeat key
      heartbeat_key = ""
      if (!is.null(heartbeat_period)) {
        require_namespaces("callr")
        heartbeat_period = assert_int(heartbeat_period, lower = 1, coerce = TRUE)
        # expire must be >= period so the TTL outlasts the refresh interval
        heartbeat_expire = assert_int(heartbeat_expire, lower = heartbeat_period, null.ok = TRUE, coerce = TRUE)
        heartbeat_expire = heartbeat_expire %??% (heartbeat_period * 3L)

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
        while (r$command(c("TTL", heartbeat_key)) <= 0) {
          if (!self$heartbeat$is_alive()) {
            error_config(
              "Heartbeat process of worker '%s' terminated during startup: %s",
              self$worker_id,
              str_collapse(self$heartbeat$read_all_error_lines(), sep = "\n")
            )
          }
          if (difftime(Sys.time(), start_time, units = "secs") > timeout) {
            error_config(
              "Heartbeat process of worker '%s' failed to set a TTL on the heartbeat key within %s seconds",
              self$worker_id,
              timeout
            )
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
    #' Returns `NULL` if no task is available.
    #'
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for task in seconds.
    #' @param fields (`character()`)\cr
    #' Fields to be returned.
    pop_task = function(timeout = 1, fields = "xs") {
      r = self$connector

      # move task from queued to pending
      # pending is a very short state between queued and running
      # if the worker crashes between popping the task and marking it as running,
      # $detect_lost_workers() can find the task in the pending list and mark it as failed
      key = r$command(c(
        "BLMOVE",
        private$.get_key("queued_tasks"),
        private$.get_worker_key("pending_task"),
        "RIGHT",
        "LEFT",
        timeout
      ))

      if (is.null(key)) {
        return(NULL)
      }

      # mark the task as running only while it is still in the pending list
      # $detect_lost_workers() moves pending tasks to failed when this worker is declared lost,
      # in which case the task is skipped instead of being marked as running
      acquired = r$command(list(
        "EVAL",
        lua_mark_running,
        "3",
        private$.get_worker_key("pending_task"),
        private$.get_key("running_tasks"),
        key,
        redux::object_to_bin(self$worker_id)
      ))

      if (!acquired) {
        # the task was already moved to failed by $detect_lost_workers() while this worker was processing it
        # only happens when the worker is wrongly declared lost
        lg$warn("Task '%s' was marked as failed while the worker popped it", key)
        return(NULL)
      }

      task = self$read_hash(key = key, fields = fields)
      task$key = key
      task
    },

    #' @description
    #' Create running tasks.
    #'
    #' @param extra (`list`)\cr
    #' Deprecated argument for additional information stored along with the task.
    #' Use `xss_extra` instead.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_running_tasks = function(xss, xss_extra = NULL, extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(xss_extra, types = "list", null.ok = TRUE)
      assert_list(extra, types = "list", null.ok = TRUE)
      xss_extra = xss_extra %??% extra

      if (!length(xss)) {
        return(invisible(character()))
      }
      r = self$connector

      lg$debug("Pushing %i running task(s).", length(xss))

      keys = self$write_hashes(xs = xss, xs_extra = xss_extra, worker_id = list(self$worker_id))

      # mark key as running
      r$pipeline(
        .commands = list(
          "MULTI",
          c("SADD", private$.get_key("running_tasks"), keys),
          c("RPUSH", private$.get_key("all_tasks"), keys),
          "EXEC"
        )
      )

      invisible(keys)
    },

    #' @description
    #' Save the output of tasks and mark them as finished.
    #'
    #' @param keys (`character(1)`)\cr
    #' Keys of the associated tasks.
    #' @param extra (named `list()`)\cr
    #' Deprecated argument for additional information stored along with the results.
    #' Use `yss_extra` instead.
    #'
    #' @return (`RushWorker`)\cr
    #' Invisible self.
    finish_tasks = function(keys, yss, yss_extra = NULL, extra = NULL) {
      assert_character(keys)
      assert_list(yss, types = "list")
      assert_list(yss_extra, types = "list", null.ok = TRUE)
      yss_extra = yss_extra %??% extra
      r = self$connector

      # write results to hashes
      self$write_hashes(
        ys = yss,
        ys_extra = yss_extra,
        keys = keys
      )

      # move keys from running to finished
      # keys of finished tasks are stored in a list i.e. the are ordered by time
      # each rush instance only needs to record how many results it has already seen
      # to cheaply get the latest results and cache the finished tasks
      # under some conditions a set would be more advantageous e.g. to check if a task is finished,
      # but at the moment a list seems to be the better option
      # the move is guarded so a task that was already moved to failed stays failed (first writer wins)
      moved = unlist(r$command(c(
        "EVAL",
        lua_move_set_to_list,
        "2",
        private$.get_key("running_tasks"),
        private$.get_key("finished_tasks"),
        keys
      )))

      n_discarded = length(keys) - length(moved)
      if (n_discarded) {
        # the task was already moved to failed by $detect_lost_workers() while this worker was processing it
        # only happens when the worker is wrongly declared lost
        lg$warn("Discarding the result(s) of %i task(s) that are no longer running", n_discarded)
      }

      invisible(self)
    },

    #' @description
    #' Move running tasks to failed and optionally save the condition objects.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the running tasks to be moved.
    #'
    #' @return (`RushWorker`)\cr
    #' Invisible self.
    fail_tasks = function(keys, conditions = NULL) {
      assert_character(keys)
      assert_list(conditions, types = "list", null.ok = TRUE)
      r = self$connector
      conditions = conditions %??% list(list(message = "Task failed"))

      # write the conditions before the move so a task is never visible as failed without its condition
      self$write_hashes(condition = wrap_conditions(conditions), keys = keys)

      # move keys from running to failed
      # the move is guarded so a task that was already moved to finished stays finished (first writer wins)
      # a task that finished concurrently keeps the condition on its hash but is not marked as failed
      moved = unlist(r$command(c(
        "EVAL",
        lua_move_set_to_set,
        "2",
        private$.get_key("running_tasks"),
        private$.get_key("failed_tasks"),
        keys
      )))

      n_discarded = length(keys) - length(moved)
      if (n_discarded) {
        lg$warn("Discarding the failed state of %i task(s) that are no longer running", n_discarded)
      }

      invisible(self)
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

      cmds = list(c(
        "SMOVE",
        private$.get_key("running_worker_ids"),
        private$.get_key("terminated_worker_ids"),
        self$worker_id
      ))

      if (!is.null(self$heartbeat)) {
        heartbeat_key = private$.get_worker_key("heartbeat")
        cmds = c(
          cmds,
          list(
            c("DEL", heartbeat_key),
            c("SREM", private$.get_key("heartbeat_keys"), heartbeat_key)
          )
        )
      }

      r$pipeline(.commands = cmds)
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
