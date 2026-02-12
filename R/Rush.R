#' @title Rush Manager
#'
#' @description
#' The `Rush` manager is responsible for starting, observing, and stopping workers within a rush network.
#' It is initialized using the [rsh()] function, which requires a network ID and a config argument.
#' The config argument is a configuration used to connect to the Redis database via the \CRANpkg{redux} package.
#'
#' @section Tasks:
#' Tasks are the unit in which workers exchange information.
#' The main components of a task are the key, computational state, input (`xs`), and output (`ys`).
#' The key is a unique identifier for the task in the Redis database.
#' The four possible computational states are `"running"`, `"finished"`, `"failed"`, and `"queued"`.
#' The input `xs` and output `ys` are lists that can contain arbitrary data.
#'
#' Methods to create a task:
#'
#' * `$push_running_tasks(xss)`: Create running tasks
#' * `$push_finished_tasks(xss, yss)`: Create finished tasks.
#' * `$push_failed_tasks(xss, conditions)`: Create failed tasks.
#' * `$push_tasks(xss)`: Create queued tasks.
#'
#' These methods return the key of the created tasks.
#' The methods work on multiple tasks at once, so `xss` and `yss` are lists of inputs and outputs.
#'
#' Methods to change the state of an existing task:
#'
#' * `$finish_tasks(keys, yss)`: Save the output of tasks and mark them as finished.
#' * `$fail_tasks(keys, conditions)`: Mark tasks as failed and optionally save the condition objects.
#' * `$pop_task()`: Pop a task from the queue and mark it as running.
#'
#' The following methods are used to fetch tasks:
#'
#' * `$fetch_tasks()`: Fetch all tasks.
#' * `$fetch_finished_tasks()`: Fetch finished tasks.
#' * `$fetch_failed_tasks()`: Fetch failed tasks.
#' * `$fetch_tasks_with_state()`: Fetch tasks with different states at once.
#'
#' The methods return a `data.table()` with the tasks.
#'
#' Tasks have the following fields:
#'
#' * `xs`: The input of the task.
#' * `ys`: The output of the task.
#' * `xs_extra`: Metadata created when creating the task.
#' * `ys_extra`: Metadata created when finishing the task.
#' * `condition`: Condition object when the task failed.
#' * `worker_id`: The id of the worker that created the task.
#'
#' @section Workers:
#' Local workers run on the same machine as the manager and are spawned with the `$start_local_workers()` method via the \CRANpkg{processx} package.
#' Remote workers run on a different machine and are spawned with the `$start_remote_workers()` method via the \CRANpkg{mirai} package.
#' Workers can also be started with a script anywhere using the `$worker_script()` method.
#' The only requirement is that the worker can connect to the Redis database.
#'
#' @section Worker Loop:
#' The worker loop is the main function that is run on the workers.
#' It is defined by the user and is passed to the `$start_local_workers()` and `$start_remote_workers()` methods.
#' The worker loop is a function that takes the input of a task and returns the output of the task.
#'
#' @template param_network_id
#' @template param_config
#' @template param_worker_loop
#' @template param_packages
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_message_log
#' @template param_output_log
#'
#' @return Object of class [R6::R6Class] and `Rush`.
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#' config_local = redux::redis_config()
#' rush = rsh(network_id = "test_network", config = config_local)
#' rush
#' }
Rush = R6::R6Class("Rush",
  public = list(

    #' @field processes_processx ([processx::process])\cr
    #' List of processes started with `$start_local_workers()`.
    processes_processx = NULL,

    #' @field processes_mirai ([mirai::mirai])\cr
    #' List of mirai processes started with `$start_remote_workers()`.
    processes_mirai = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(network_id = NULL, config = NULL) {
      private$.network_id = assert_string(network_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
      private$.config = assert_class(config, "redis_config", null.ok = TRUE) %??% rush_env$config %??% redux::redis_config()
      if (!redux::redis_available(private$.config)) {
        stop("Can't connect to Redis. Check the configuration.")
      }
      private$.connector = redux::hiredis(private$.config)
    },

    #' @description
    #' Helper for print outputs.
    #'
    #' @param ... (ignored).
    #'
    #' @return (`character()`).
    format = function(...) {
      sprintf("<%s>", class(self)[1L])
    },

    #' @description
    #' Print method.
    #'
    #' @return (`character()`).
    print = function() {
      catn(format(self))
      catf(str_indent("* Running Workers:", self$n_running_workers))
      catf(str_indent("* Queued Tasks:", self$n_queued_tasks))
      catf(str_indent("* Running Tasks:", self$n_running_tasks))
      catf(str_indent("* Finished Tasks:", self$n_finished_tasks))
      catf(str_indent("* Failed Tasks:", self$n_failed_tasks))
    },

    #' @description
    #' Reconnect to Redis.
    #' The connection breaks when the Rush object is saved to disk.
    #' Call this method to reconnect after loading the object.
    reconnect = function() {
      private$.connector = redux::hiredis(private$.config)
    },

    #' @description
    #' Start workers locally with `processx`.
    #' The [processx::process] are stored in `$processes_processx`.
    #' Alternatively, use `$start_remote_workers()` to start workers on remote machines with `mirai`.
    #' Parameters set by [rush_plan()] have precedence over the parameters set here.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
    #' Default is `NULL`, which means the number of workers is set by [rush_plan()].
    #' If `rush_plan()` is not called, the default is `1`.
    #' @param supervise (`logical(1)`)\cr
    #' Whether to kill the workers when the main R process is shut down.
    start_local_workers = function(
      worker_loop,
      ...,
      n_workers = NULL,
      packages = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = NULL,
      supervise = TRUE,
      message_log = NULL,
      output_log = NULL
      ) {
      n_workers = assert_count(n_workers %??% rush_env$n_workers %??% 1, .var.name = "n_workers")
      lgr_thresholds = assert_vector(rush_env$lgr_thresholds %??% lgr_thresholds, names = "named", null.ok = TRUE, .var.name = "lgr_thresholds")
      lgr_buffer_size = assert_count(rush_env$lgr_buffer_size %??% lgr_buffer_size %??% 0, .var.name = "lgr_buffer_size")
      assert_flag(supervise)

      r = private$.connector

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        packages = packages
      )

      lg$info("Starting %i worker(s)", n_workers)

      # convert arguments to character
      config = mlr3misc::discard(unclass(self$config), is.null)
      # redux cannot handle the url field
      # it is derived from the other fields so we remove it
      config$url = NULL
      config = paste(imap(config, function(value, name) sprintf("%s = %s", name, shQuote(value, type = "sh"))), collapse = ", ")
      config = paste0("list(", config, ")")
      lgr_thresholds = paste(imap(lgr_thresholds, function(value, name) sprintf("%s = %s", shQuote(name, type = "sh"), shQuote(value, type = "sh"))), collapse = ", ")
      lgr_thresholds = paste0("c(", lgr_thresholds, ")")
      message_log = if (is.null(message_log)) "NULL" else shQuote(message_log, type = "sh")
      output_log = if (is.null(output_log)) "NULL" else shQuote(output_log, type = "sh")

      # generate worker ids
      worker_ids = adjective_animal(n = n_workers)

      self$processes_processx = c(self$processes_processx, set_names(map(worker_ids, function(worker_id) {
       processx::process$new("Rscript",
        args = c("-e", sprintf("rush::start_worker(network_id = %s, worker_id = %s, config = %s, remote = FALSE, lgr_thresholds = %s, lgr_buffer_size = %i, message_log = %s, output_log = %s)",
          shQuote(private$.network_id, type = "sh"), shQuote(worker_id, type = "sh"), config, lgr_thresholds, lgr_buffer_size, message_log, output_log)),
        supervise = supervise, stderr = "|")
      }), worker_ids))

      return(invisible(worker_ids))
    },

    #' @description
    #' Start workers on remote machines with `mirai`.
    #' The [mirai::mirai] are stored in `$processes_mirai`.
    #' Parameters set by [rush_plan()] have precedence over the parameters set here.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
    #' Default is `NULL`, which means the number of workers is set by [rush_plan()].
    #' If `rush_plan()` is not called, the default is `1`.
    start_remote_workers = function(
      worker_loop,
      ...,
      n_workers = NULL,
      packages = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = NULL,
      message_log = NULL,
      output_log = NULL
      ) {
      n_workers = assert_count(n_workers %??% rush_env$n_workers %??% 1, .var.name = "n_workers")
      lgr_thresholds = assert_vector(rush_env$lgr_thresholds %??% lgr_thresholds, names = "named", null.ok = TRUE, .var.name = "lgr_thresholds")
      lgr_buffer_size = assert_count(rush_env$lgr_buffer_size %??% lgr_buffer_size %??% 0, .var.name = "lgr_buffer_size")

      mirai_status = status()
      # check number of daemons
      if (!mirai_status$connections) {
        stop("No daemons available. Start daemons with `mirai::daemons()`")
      }

      # mirai is only available when mirai is started with a dispatcher
      if (!is.null(mirai_status$mirai) && n_workers > mirai_status$connections - mirai_status$mirai["executing"]) {
        warningf("Number of workers %i exceeds number of available daemons %i", n_workers, mirai_status$connections - mirai_status$mirai["executing"])
      }

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        packages = packages
      )

      lg$info("Starting %i worker(s)", n_workers)

      # reduce redis config
      config = mlr3misc::discard(unclass(self$config), is.null)
      config$url = NULL

      # generate worker ids
      worker_ids = adjective_animal(n = n_workers)

      # start rush worker with mirai
      self$processes_mirai = c(self$processes_mirai, set_names(
        mirai_map(worker_ids, rush::start_worker,
          .args = list(
            network_id = private$.network_id,
            config = config,
            remote = TRUE,
            lgr_thresholds = lgr_thresholds,
            lgr_buffer_size = lgr_buffer_size,
            message_log = message_log,
            output_log = output_log)),
        worker_ids))

      return(invisible(worker_ids))
    },

    #' @description
    #' Generate a script to start workers.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    worker_script = function(
      worker_loop,
      ...,
      packages = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      message_log = NULL,
      output_log = NULL
      ) {
      lgr_thresholds = assert_vector(rush_env$lgr_thresholds %??% lgr_thresholds, names = "named", null.ok = TRUE, .var.name = "lgr_thresholds")
      lgr_buffer_size = assert_count(rush_env$lgr_buffer_size %??% lgr_buffer_size %??% 0, .var.name = "lgr_buffer_size")

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        packages = packages
      )

      # convert arguments to character
      args = list(network_id = sprintf("'%s'", private$.network_id))
      config = mlr3misc::discard(unclass(self$config), is.null)
      config$url = NULL
      config = paste(imap(config, function(value, name) sprintf("%s = '%s'", name, value)), collapse = ", ")
      args[["config"]] = paste0("list(", config, ")")
      if (!is.null(lgr_thresholds)) {
        lgr_thresholds = paste(imap(lgr_thresholds, function(value, name) sprintf("%s = '%s'", name, value)), collapse = ", ")
        args[["lgr_thresholds"]] = paste0("c(", lgr_thresholds, ")")
        args[["lgr_buffer_size"]] = lgr_buffer_size
      }
      if (!is.null(heartbeat_period)) args[["heartbeat_period"]] = heartbeat_period
      if (!is.null(heartbeat_expire)) args[["heartbeat_expire"]] = heartbeat_expire
      args = paste(imap(args, function(value, name) sprintf("%s = %s", name, value)), collapse = ", ")

      lg$info("Creating worker script")
      lg$info("Rscript -e \"rush::start_worker(%s)\"", args)
    },

    #' @description
    #' Wait until workers are registered in the network.
    #' Either `n`, `worker_ids` or both must be provided.
    #'
    #' @param n (`integer(1)`)\cr
    #' Number of workers to wait for.
    #' If `NULL`, wait for all workers in `worker_ids`.
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to wait for.
    #' If `NULL`, wait for any `n` workers to be registered.
    #' @param timeout (`numeric(1)`)\cr
    #' Timeout in seconds.
    #' Default is `Inf`.
    wait_for_workers = function(n = NULL, worker_ids = NULL, timeout = Inf) {
      assert_count(n, null.ok = TRUE)
      assert_character(worker_ids, null.ok = TRUE)
      assert_number(timeout)
      timeout = if (is.finite(timeout)) timeout else rush_config()$start_worker_timeout %??% Inf
      start_time = Sys.time()

      if (is.null(n) && is.null(worker_ids)) {
        stopf("Either `n`, `worker_ids` or both must be provided.")
      }

      if (!is.null(n) && !is.null(worker_ids) && n > length(worker_ids)) {
        stopf("Number of workers to wait for %i exceeds number of worker ids %i", n, length(worker_ids))
      }

      n = n %??% length(worker_ids)
      i = 0
      while(difftime(Sys.time(), start_time, units = "secs") < timeout) {
        n_registered_workers = if (is.null(worker_ids)) self$n_workers else length(intersect(self$worker_ids, worker_ids))

        # print updated number of registered workers
        if (n_registered_workers > i) {
          i = n_registered_workers
          lg$info("%i worker(s) registered", i)
        }

        if (n_registered_workers >= n) return(invisible(self))
        Sys.sleep(0.1)
      }

      stopf("Timeout waiting for %i worker(s)", n)

    },

    #' @description
    #' Stop workers.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be stopped.
    #' Remote workers must all be killed together.
    #' If `NULL` all workers are stopped.
    #' @param type (`character(1)`)\cr
    #' Type of stopping.
    #' Either `"terminate"` or `"kill"`.
    #' If `"kill"` the workers are stopped immediately.
    #' If `"terminate"` the workers evaluate the currently running task and then terminate.
    #' The `"terminate"` option must be implemented in the worker loop.
    stop_workers = function(type = "kill", worker_ids = NULL) {
      assert_choice(type, c("terminate", "kill"))
      worker_ids = assert_subset(worker_ids, self$running_worker_ids) %??% self$running_worker_ids
      if (is.null(worker_ids)) return(invisible(self))
      r = private$.connector

      if (type == "kill") {

        worker_ids_processx = intersect(worker_ids, names(self$processes_processx))
        if (length(worker_ids_processx)) {
          lg$debug("Killing %i local worker(s)", length(worker_ids_processx))

          walk(worker_ids_processx, function(id) {
            lg$info("Kill worker '%s'", id)

            # kill with processx
            killed = self$processes_processx[[id]]$kill()
            if (!killed) lg$error("Failed to kill worker '%s'", id)ids to be read.
          }), recursive = FALSE)

          r$pipeline(.commands = cmds)
        }
      }

      if (type == "terminate") {
        lg$debug("Terminating %i worker(s) '%s'", length(worker_ids), as_short_string(worker_ids))

        # Push terminate signal to worker
        cmds = map(worker_ids, function(worker_id) {
          c("SET", private$.get_worker_key("terminate", worker_id), "1")
        })
        r$pipeline(.commands = cmds)
      }

      return(invisible(self))
    },

    #' @description
    #' Detect lost workers.
    #' The state of the worker is changed to `"terminated"`.
    detect_lost_workers = function() {
      r = private$.connector

      running_tasks = self$fetch_running_tasks(fields = "worker_id")

      # check mirai workers
      if (length(self$processes_mirai)) {
        iwalk(self$processes_mirai[intersect(self$running_worker_ids, names(self$processes_mirai))], function(m, id) {
          if (is_mirai_error(m$data) || is_error_value(m$data)) {
            lg$error("Lost worker '%s'", id)

            # print error messages
            walk(self$processes_mirai[[id]]$data, lg$error)

            # move worker to terminated
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), id))

            # identify lost tasks
            if (nrow(running_tasks)) {
              keys = running_tasks[list(id), keys, on = "worker_id"]
              lg$error("Lost %i task(s): %s", length(keys), str_collapse(keys))

              # Replace interrupt error message
              message = if (unclass(m$data) == 19) "Worker has crashed or was killed" else as.character(m$data)

              # push failed tasks
              conditions = list(list(message = message))
              self$fail_tasks(keys, conditions = conditions)
            }
          }
        })
      }

      # check processx workers
      if (length(self$processes_processx)) {
        iwalk(self$processes_processx[intersect(self$running_worker_ids, names(self$processes_processx))], function(m, id) {
          if (!self$processes_processx[[id]]$is_alive()) {
            lg$error("Lost worker '%s'", id)
            # print error messages
            walk(self$processes_processx[[id]]$read_all_error_lines(), lg$error)

            # identify lost tasks
            if (nrow(running_tasks)) {
              keys = running_tasks[list(id), keys, on = "worker_id"]
              lg$error("Lost %i task(s): %s", length(keys), str_collapse(keys))

              # push failed tasks
              conditions = list(list(message = "Worker has crashed or was killed"))
              self$fail_tasks(keys, conditions = conditions)
            }

            # move worker to terminated
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), id))
          }
        })
      }

      # check heartbeat of workers
      heartbeat_keys = r$SMEMBERS(private$.get_key("heartbeat_keys"))
      if (length(heartbeat_keys)) {
        running = as.logical(r$pipeline(.commands = map(heartbeat_keys, function(heartbeat_key) c("EXISTS", heartbeat_key))))
        if (all(running)) return(invisible(self))

        # search for associated worker ids
        running_worker_ids = self$running_worker_ids
        expired_heartbeat_keys = heartbeat_keys[!running]
        cmds = map(running_worker_ids, function(worker_id) c("HMGET", private$.get_key(worker_id), "heartbeat"))
        all_heartbeat_keys = unlist(r$pipeline(.commands = cmds))
        lost_workers = running_worker_ids[all_heartbeat_keys %in% expired_heartbeat_keys]

        # set worker state
        cmds = map(lost_workers, function(worker_id) {
          lg$error("Lost worker '%s'", worker_id)
          c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), worker_id)
        })

        # remove heartbeat keys
        cmds = c(cmds, list(c("SREM", private$.get_key("heartbeat_keys"), expired_heartbeat_keys)))

        r$pipeline(.commands =  cmds)
      }

      return(invisible(self))
    },

    #' @description
    #' Stop workers and delete data stored in redis.
    reset = function() {
      r = private$.connector

      # stop workers
      self$stop_workers(type = "kill")

      # reset fields set by starting workers
      self$processes_processx = NULL

      # remove worker info, terminate and kill
      walk(self$worker_ids, function(worker_id) {
        r$DEL(private$.get_key(worker_id))
        r$DEL(private$.get_worker_key("terminate", worker_id))
        r$DEL(private$.get_worker_key("kill", worker_id))
        r$DEL(private$.get_worker_key("queued_tasks", worker_id))
        r$DEL(private$.get_worker_key("events", worker_id))
      })

      # remove all tasks
      walk(self$tasks, function(key) {
        r$DEL(key)
      })

      # remove lists and sets
      r$DEL(private$.get_key("queued_tasks"))
      r$DEL(private$.get_key("running_tasks"))
      r$DEL(private$.get_key("finished_tasks"))
      r$DEL(private$.get_key("failed_tasks"))
      r$DEL(private$.get_key("all_tasks"))
      r$DEL(private$.get_key("terminate"))
      r$DEL(private$.get_key("worker_ids"))
      r$DEL(private$.get_key("running_worker_ids"))
      r$DEL(private$.get_key("terminated_worker_ids"))
      r$DEL(private$.get_key("start_args"))
      r$DEL(private$.get_key("terminate_on_idle"))
      r$DEL(private$.get_key("local_workers"))
      r$DEL(private$.get_key("heartbeat_keys"))

      # be safe
      remaining_keys = private$.connector$command(c("KEYS", "*"))
      map(remaining_keys, function(key) {
        lg$debug("Found remaining key: %s", key)
        if (grepl(private$.network_id, key)) r$DEL(key)
      })

      # reset counters and caches
      private$.cached_tasks = data.table()
      private$.n_seen_results = 0

      return(invisible(self))
    },

    #' @description
    #' Reset the data stored in the Redis database.
    #' This is useful to remove all tasks but keep the workers.
    reset_data = function() {
      r = private$.connector

      # remove all tasks
      walk(self$tasks, function(key) {
        r$DEL(key)
      })

      # remove states
      r$DEL(private$.get_key("queued_tasks"))
      r$DEL(private$.get_key("running_tasks"))
      r$DEL(private$.get_key("finished_tasks"))
      r$DEL(private$.get_key("failed_tasks"))
      r$DEL(private$.get_key("all_tasks"))

      # reset counters and caches
      private$.cached_tasks = data.table()
      private$.n_seen_results = 0

      return(invisible(self))
    },

    #' @description
    #' Read log messages written with the `lgr` package by the workers.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be read log messages from.
    #' Defaults to all worker ids.
    #' @param time_difference (`logical(1)`)\cr
    #' Whether to calculate the time difference between log messages.
    #'
    #' @return `data.table()`\cr
    #' Table with level, timestamp, logger, caller and message, and optionally time difference.
    read_log = function(worker_ids = NULL, time_difference = FALSE) {
      assert_flag(time_difference)
      worker_ids = worker_ids %??% self$worker_ids
      r = private$.connector
      cmds =  map(worker_ids, function(worker_id) c("LRANGE", private$.get_worker_key("events", worker_id), 0, -1))
      worker_logs = set_names(r$pipeline(.commands = cmds), worker_ids)
      tab = rbindlist(set_names(map(worker_logs, function(logs) {
        rbindlist(map(logs, fromJSON))
      }), worker_ids), idcol = "worker_id")
      if (nrow(tab)) {
        tab[, timestamp := as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%OS")]
        setkeyv(tab, "timestamp")
        if (time_difference) {
          tab[, time_difference := difftime(timestamp, shift(timestamp, fill = timestamp[1L]), units = "secs"), by = worker_id]
        }
      }
      tab[]
    },

    #' @description
    #' Print log messages written with the `lgr` package by the workers.
    #' Log messages are printed with the original logger.
    #'
    #' @return (`Rush`)\cr
    #' Invisible self.
    print_log = function() {
      r = private$.connector

      if (!self$n_workers) return(invisible(NULL))

      cmds =  walk(self$worker_ids, function(worker_id) {
        first_event = private$.log_counter[[worker_id]] %??% 0L
        log = r$command(c("LRANGE", private$.get_worker_key("events", worker_id), first_event, -1L))
        if (length(log)) {
          tab = rbindlist(map(log, fromJSON))
          set(tab, j = "worker_id", value = worker_id)
          pwalk(tab, function(level, logger, timestamp, msg, ...) {
            pkg_logger = lgr::get_logger(logger)
            pkg_logger$log(level, "[%s] [%s] %s", worker_id, timestamp, msg)
          })
          private$.log_counter[[worker_id]] = nrow(tab) + first_event
        }
      })

      return(invisible(self))
    },

    #' @description
    #' Move tasks from queued and running to the failed and optionally save the condition.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to be moved.
    #' Defaults to all queued tasks.
    #' @param conditions (named `list()`)\cr
    #' List of lists of conditions.
    #' Defaults to `list(message = "Failed")`.
    #'
    #' @return (`Rush`)\cr
    #' Invisible self.
    fail_tasks = function(keys, conditions = NULL) {
      assert_character(keys)
      assert_list(conditions, types = "list", null.ok = TRUE)
      r = private$.connector
      if (is.null(conditions)) conditions = list(list(message = "Task failed"))

      # write condition to hash
      self$write_hashes(condition = conditions, keys = keys)

      is_running_task = as.logical(r$pipeline(.commands = map(keys, function(key) c("SISMEMBER", private$.get_key("running_tasks"), key))))
      running_tasks = keys[is_running_task]
      queued_tasks = keys[!is_running_task]

      # move keys from running to failed
      commands_running = map(running_tasks, function(key) {
        c("SMOVE", private$.get_key("running_tasks"), private$.get_key("failed_tasks"), key)
      })

      # move keys from queued to failed
      commands_queued = unlist(map(queued_tasks, function(key) {
        list(
          c("LREM", private$.get_key("queued_tasks"), 1, key),
          c("SADD", private$.get_key("failed_tasks"), key))
      }), recursive = FALSE)

      r$pipeline(.commands = c(commands_running, commands_queued))

      return(invisible(self))
    },

    #' @description
    #' Creates a task and adds it to the queue.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list()`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_tasks = function(xss, extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      r = private$.connector

      lg$debug("Pushing %i task(s) to the queue", length(xss))

      # write tasks to hashes
      keys = self$write_hashes(
        xs = xss,
        xs_extra = extra)

      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("LPUSH", private$.get_key("queued_tasks"), keys))
      r$pipeline(.commands = cmds)

      return(invisible(keys))
    },

    #' @description
    #' Creates a task and marks it as finished.
    #' See `$finish_tasks()` for moving existing tasks from running to finished.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param yss (list of named `list()`)\cr
    #' Lists of results for the function e.g. `list(list(y1, y2), list(y1, y2)))`.
    #' @param xss_extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #' @param yss_extra (`list`)\cr
    #' List of additional information stored along with the results e.g. `list(list(timestamp), list(timestamp)))`.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_finished_tasks = function(xss, yss, xss_extra = NULL, yss_extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(yss, types = "list")
      assert_list(xss_extra, types = "list", null.ok = TRUE)
      assert_list(yss_extra, types = "list", null.ok = TRUE)
      r = private$.connector

      keys = self$write_hashes(xs = xss, ys = yss, xs_extra = xss_extra, ys_extra = yss_extra)
      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("RPUSH", private$.get_key("finished_tasks"), keys))
      r$pipeline(.commands = cmds)

      return(invisible(keys))
    },

    #' @description
    #' Creates a task and marks it as failed.
    #' See `$fail_tasks()` for moving existing tasks from queued and running to failed.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param xss_extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #' @param conditions (named `list()`)\cr
    #' List of lists of conditions.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_failed_tasks = function(xss, xss_extra, conditions) {
      assert_list(xss, types = "list")
      assert_list(xss_extra, types = "list")
      assert_list(conditions, types = "list")
      r = private$.connector

      # write condition to hash
      keys = self$write_hashes(xs = xss, xs_extra = xss_extra, condition = conditions)
      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("SADD", private$.get_key("failed_tasks"), keys))
      r$pipeline(.commands = cmds)

      return(invisible(keys))
    },

    #' @description
    #' Remove all tasks from the queue.
    #' The state of the tasks is set to failed.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to be moved.
    #' Defaults to all queued tasks.
    #' @param conditions (named `list()`)\cr
    #' List of lists of conditions.
    #'
    #' @return (`Rush`)\cr
    #' Invisible self.
    empty_queue = function(keys = NULL, conditions = NULL) {
      r = private$.connector
      keys = keys %??% self$queued_tasks

      if (is.null(conditions)) {
        conditions = replicate(length(keys), list(message = "Removed from queue"), simplify = FALSE)
      }

      if (length(keys)) {
        self$fail_tasks(keys, conditions = conditions)
      }

      return(invisible(self))
    },

    #' @description
    #' Fetch all tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_id", "ys", "ys_extra", "condition")`.
    #'
    #' @return `data.table()`\cr
    #' Table of all tasks.
    fetch_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_id",  "ys_extra", "condition")) {
      keys = self$tasks
      private$.fetch_tasks(keys, fields)
    },

    #' @description
    #' Fetch queued tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra")`.
    #'
    #' @return `data.table()`\cr
    #' Table of queued tasks.
    fetch_queued_tasks = function(fields = c("xs", "xs_extra")) {
      keys = self$queued_tasks
      private$.fetch_tasks(keys, fields)
    },

    #' @description
    #' Fetch running tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_id")`.
    #'
    #' @return `data.table()`\cr
    #' Table of running tasks.
    fetch_running_tasks = function(fields = c("xs", "xs_extra", "worker_id")) {
      keys = self$running_tasks
      private$.fetch_tasks(keys, fields)
    },

    #' @description
    #' Fetch failed tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_id", "condition"`.
    #'
    #' @return `data.table()`\cr
    #' Table of failed tasks.
    fetch_failed_tasks = function(fields = c("xs", "xs_extra", "worker_id", "condition")) {
      keys = self$failed_tasks
      private$.fetch_tasks(keys, fields)
    },

    #' @description
    #' Fetch finished tasks from the data base.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_id", "ys", "ys_extra")`.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    fetch_finished_tasks = function(fields = c("worker_id", "xs", "ys", "xs_extra", "ys_extra", "condition")) {
      keys = if (self$n_finished_tasks > nrow(private$.cached_tasks)) {
         r = private$.connector
         r$command(c("LRANGE", private$.get_key("finished_tasks"), nrow(private$.cached_tasks), -1))
      }
      private$.fetch_cached_tasks(keys, fields)
    },

    #' @description
    #' Fetch tasks with different states from the data base.
    #' If tasks with different states are to be queried at the same time, this function prevents tasks from appearing twice.
    #' This could be the case if a worker changes the state of a task while the tasks are being fetched.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("worker_id", "xs", "ys", "xs_extra", "ys_extra", "condition")`.
    #' @param states (`character()`)\cr
    #' States of the tasks to be fetched.
    #' Defaults to `c("queued", "running", "finished", "failed")`.
    fetch_tasks_with_state = function(
      fields = c("worker_id", "xs", "ys", "xs_extra", "ys_extra", "condition"),
      states = c("queued", "running", "finished", "failed")
      ) {
      r = private$.connector
      assert_subset(states, c("queued", "running", "finished", "failed"), empty.ok = FALSE)

      all_keys = private$.tasks_with_state(states, only_new_keys = TRUE)

      data = imap(all_keys, function(keys, state) {
        if (state == "finished") {
          private$.fetch_cached_tasks(keys, fields)
        } else {
          private$.fetch_tasks(keys, fields)
        }
      })

      data = rbindlist(data, use.names = TRUE, fill = TRUE, idcol = "state")
      data[]
    },

    #' @description
    #' Fetch new tasks that finished after the last call of this method.
    #' Updates the cache of the finished tasks.
    #' If `timeout` is greater than 0, blocks until new tasks are available or the timeout is reached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for new results in seconds.
    #' Defaults to `0` (no waiting).
    #'
    #' @return `data.table()`\cr
    #' Table of latest results.
    fetch_new_tasks = function(
      fields = c("xs", "ys", "xs_extra", "worker_id", "ys_extra", "condition"),
      timeout = 0
      ) {
      assert_character(fields)
      assert_number(timeout, lower = 0)

      if (timeout > 0) {
        lg$debug("Wait for new tasks for at most %s seconds", as.character(timeout))
        start_time = Sys.time()
        while (start_time + timeout > Sys.time()) {
          n_new_results = self$n_finished_tasks - private$.n_seen_results
          if (n_new_results) break
          Sys.sleep(0.01)
        }
      }

      # return empty data.table if all results are fetched
      n_new_results = self$n_finished_tasks - private$.n_seen_results
      if (!n_new_results) return(data.table())

      # increase seen results counter
      private$.n_seen_results = private$.n_seen_results + n_new_results

      # fetch finished tasks to populate cache
      self$fetch_finished_tasks(fields)

      # return only the new results from the cached data.table
      tail(private$.cached_tasks, n_new_results)[]
    },

    #' @description
    #' Reset the cache of the finished tasks.
    #'
    #' @return `invisible(self)`\cr
    #' The Rush object.
    reset_cache = function() {
      private$.cached_tasks = data.table()

    },

    #' @description
    #' Wait until tasks are finished.
    #' The function also unblocks when no worker is running or all tasks failed.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to wait for.
    #' @param detect_lost_workers (`logical(1)`)\cr
    #' Whether to detect failed tasks.
    #' Comes with an overhead.
    wait_for_tasks = function(keys, detect_lost_workers = FALSE) {
      assert_character(keys, min.len = 1)
      assert_flag(detect_lost_workers)

      lg$debug("Wait for %i task(s)", length(keys))

      while (any(keys %nin% c(self$finished_tasks, self$failed_tasks)) && self$n_running_workers > 0) {
        if (detect_lost_workers) self$detect_lost_workers()
        Sys.sleep(0.01)
      }

      invisible(self)
    },

    #' @description
    #' Writes R objects to Redis hashes.
    #' The function takes the vectors in `...` as input and writes each element as a field-value pair to a new hash.
    #' The name of the argument defines the field into which the serialized element is written.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4))` writes `serialize(list(x1 = 1, x2 = 2))` at field `xs` into a hash and `serialize(list(x1 = 3, x2 = 4))` at field `xs` into another hash.
    #' The function can iterate over multiple vectors simultaneously.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))` creates two hashes with the fields `xs` and `ys`.
    #' The vectors are recycled to the length of the longest vector.
    #' Both lists and atomic vectors are supported.
    #' Arguments that are `NULL` are ignored.
    #'
    #' @param ... (named `list()`)\cr
    #' Lists to be written to the hashes.
    #' The names of the arguments are used as fields.
    #' @param .values (named `list()`)\cr
    #' Lists to be written to the hashes.
    #' The names of the list are used as fields.
    #' @param keys (character())\cr
    #' Keys of the hashes.
    #' If `NULL` new keys are generated.
    #'
    #' @return (`character()`)\cr
    #' Keys of the hashes.
    write_hashes = function(..., .values = list(), keys = NULL) {
      # discard empty lists
      values = discard(c(list(...), .values), function(l) !length(l))
      fields = names(values)
      n_hashes = max(map_int(values, length))
      if (is.null(keys)) {
        keys = UUIDgenerate(n = n_hashes)
      } else {
        assert_character(keys, min.len = n_hashes)
      }

      lg$debug("Writing %i hash(es) with %i field(s)", length(keys), length(fields))

      # construct list of redis commands to write hashes
      cmds = pmap(c(list(key = keys), values), function(key, ...) {
          # serialize value of field
          bin_values = map(list(...), redux::object_to_bin)

          lg$debug("Serialzing %i value(s) to %s", length(bin_values), format(Reduce(`+`, map(bin_values, object.size))))

          # merge fields and values alternatively
          # c and rbind are fastest option in R
          # data is not copied
          c("HSET", key, c(rbind(fields, bin_values)))
        })

      private$.connector$pipeline(.commands = cmds)

      invisible(keys)
    },

    #' @description
    #' Reads R Objects from Redis hashes.
    #' The function reads the field-value pairs of the hashes stored at `keys`.
    #' The values of a hash are deserialized and combined to a list.
    #' If `flatten` is `TRUE`, the values are flattened to a single list e.g. list(xs = list(x1 = 1, x2 = 2), ys = list(y = 3)) becomes list(x1 = 1, x2 = 2, y = 3).
    #' The reading functions combine the hashes to a table where the names of the inner lists are the column names.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))` becomes `data.table(x1 = c(1, 3), x2 = c(2, 4), y = c(3, 7))`.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the hashes.
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' @param flatten (`logical(1)`)\cr
    #' Whether to flatten the list.
    #'
    #' @return (list of `list()`)\cr
    #' The outer list contains one element for each key.
    #' The inner list is the combination of the lists stored at the different fields.
    read_hashes = function(keys, fields, flatten = TRUE) {

      lg$debug("Reading %i hash(es) with %i field(s)", length(keys), length(fields))

      # construct list of redis commands to read hashes
      cmds = map(keys, function(key) c("HMGET", key, fields))

      # list of hashes
      # first level contains hashes
      # second level contains fields
      # the values of the fields are serialized lists and atomics
      hashes = private$.connector$pipeline(.commands = cmds)

      if (flatten) {
        # unserialize elements of the second level
        # flatten elements of the third level to one list
        # using mapply instead of pmap is faster
        map(hashes, function(hash) unlist(.mapply(function(bin_value, field) {
          # unserialize value
          value = safe_bin_to_object(bin_value)
          # wrap atomic values in list and name by field
          if (is.atomic(value) && !is.null(value)) {
            # list column or column with type of value
            if (length(value) > 1) value = list(value)
            value = setNames(list(value), field)
          }
          value
        }, list(bin_value = hash, field = fields), NULL), recursive = FALSE))
      } else {
        # unserialize elements of the second level
        map(hashes, function(hash) setNames(map(hash, function(bin_value) {
          safe_bin_to_object(bin_value)
        }), fields))
      }
    },

    #' @description
    #' Reads a single Redis hash and returns the values as a list named by the fields.
    #'
    #' @param key (`character(1)`)\cr
    #' Key of the hash.
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hash.
    #'
    #' @return (list of `list()`)\cr
    #' The outer list contains one element for each key.
    #' The inner list is the combination of the lists stored at the different fields.
    read_hash = function(key, fields) {
      lg$debug("Reading hash with %i field(s)", length(fields))

      setNames(map(private$.connector$HMGET(key, fields), safe_bin_to_object), fields)
    },

    #' @description
    #' Checks whether tasks have the status `"running"`.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks.
    is_running_task = function(keys) {
      r = private$.connector
      if (!length(keys)) return(logical(0))
      as.logical(r$command(c("SMISMEMBER", private$.get_key("running_tasks"), keys)))
    },

    #' @description
    #' Checks whether tasks have the status `"failed"`.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks.
    is_failed_task = function(keys) {
      r = private$.connector
      if (!length(keys)) return(logical(0))
      as.logical(r$command(c("SMISMEMBER", private$.get_key("failed_tasks"), keys)))
    },

    #' @description
    #' Returns keys of requested states.
    #'
    #' @param states (`character()`)\cr
    #' States of the tasks.
    #'
    #' @return (Named list of `character()`).
    tasks_with_state = function(states) {
      r = private$.connector
      assert_subset(states, c("queued", "running", "finished", "failed"))
      private$.tasks_with_state(states)
    }
  ),

  active = list(

    #' @field network_id (`character(1)`)\cr
    #' Identifier of the rush network.
    network_id = function(rhs) {
      assert_ro_binding(rhs)
      private$.network_id
    },

    #' @field config ([redux::redis_config])\cr
    #' Redis configuration options.
    config = function(rhs) {
      if (missing(rhs)) return(private$.config)
      assert_class(rhs, "redis_config")
      private$.config = rhs
    },

    #' @field connector ([redux::redis_api])\cr
    #' Returns a connection to Redis.
    connector = function(rhs) {
      assert_ro_binding(rhs)
      private$.connector
    },

    #' @field n_workers (`integer(1)`)\cr
    #' Number of workers.
    n_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("worker_ids"))) %??% 0
    },

    #' @field n_running_workers (`integer(1)`)\cr
    #' Number of running workers.
    n_running_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("running_worker_ids"))) %??% 0
    },

    #' @field n_terminated_workers (`integer(1)`)\cr
    #' Number of terminated workers.
    n_terminated_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("terminated_worker_ids"))) %??% 0
    },

    #' @field worker_ids (`character()`)\cr
    #' Ids of workers.
    worker_ids = function() {
      r = private$.connector
      unlist(r$SMEMBERS(private$.get_key("worker_ids")))
    },

    #' @field running_worker_ids (`character()`)\cr
    #' Ids of running workers.
    running_worker_ids = function() {
      r = private$.connector
      unlist(r$SMEMBERS(private$.get_key("running_worker_ids")))
    },

    #' @field terminated_worker_ids (`character()`)\cr
    #' Ids of terminated workers.
    terminated_worker_ids = function() {
      r = private$.connector
      unlist(r$SMEMBERS(private$.get_key("terminated_worker_ids")))
    },

    #' @field tasks (`character()`)\cr
    #' Keys of all tasks.
    tasks = function() {
      r = private$.connector
      unlist(r$LRANGE(private$.get_key("all_tasks"), 0, -1))
    },

    #' @field queued_tasks (`character()`)\cr
    #' Keys of queued tasks.
    queued_tasks = function() {
      r = private$.connector
      unlist(r$LRANGE(private$.get_key("queued_tasks"), 0, -1))
    },

    #' @field running_tasks (`character()`)\cr
    #' Keys of running tasks.
    running_tasks = function() {
      r = private$.connector
      unlist(r$SMEMBERS(private$.get_key("running_tasks")))
    },

    #' @field finished_tasks (`character()`)\cr
    #' Keys of finished tasks.
    finished_tasks = function() {
      r = private$.connector
      unlist(r$LRANGE(private$.get_key("finished_tasks"), 0, -1))
    },

    #' @field failed_tasks (`character()`)\cr
    #' Keys of failed tasks.
    failed_tasks = function() {
      r = private$.connector
      unlist(r$SMEMBERS(private$.get_key("failed_tasks")))
    },

    #' @field n_queued_tasks (`integer(1)`)\cr
    #' Number of queued tasks.
    n_queued_tasks = function() {
      r = private$.connector
      as.integer(r$LLEN(private$.get_key("queued_tasks"))) %??% 0
    },

    #' @field n_running_tasks (`integer(1)`)\cr
    #' Number of running tasks.
    n_running_tasks = function() {
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("running_tasks"))) %??% 0
    },

    #' @field n_finished_tasks (`integer(1)`)\cr
    #' Number of finished tasks.
    n_finished_tasks = function() {
      r = private$.connector
      as.integer(r$LLEN(private$.get_key("finished_tasks"))) %??% 0
    },

    #' @field n_failed_tasks (`integer(1)`)\cr
    #' Number of failed tasks.
    n_failed_tasks = function() {
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("failed_tasks"))) %??% 0
    },

    #' @field n_tasks (`integer(1)`)\cr
    #' Number of all tasks.
    n_tasks = function() {
      r = private$.connector
      as.integer(r$LLEN(private$.get_key("all_tasks"))) %??% 0
    },

    #' @field worker_info ([data.table::data.table()])\cr
    #' Contains information about the workers.
    worker_info = function(rhs) {
      assert_ro_binding(rhs)
      if (!self$n_workers) return(data.table())
      r = private$.connector

      fields = c("worker_id", "pid", "remote", "hostname", "heartbeat")
      worker_info = set_names(rbindlist(map(self$worker_ids, function(worker_id) {
        r$command(c("HMGET", private$.get_key(worker_id), fields))
      })), fields)

      # fix type
      worker_info[, pid := as.integer(pid)][]
      worker_info[, remote := as.logical(remote)][]
      worker_info[, heartbeat := heartbeat != "NA"][]

      # get worker states as atomic operation
      r$MULTI()
      r$SMEMBERS(private$.get_key("running_worker_ids"))
      r$SMEMBERS(private$.get_key("terminated_worker_ids"))
      res = r$EXEC()
      worker_ids = list(
        running = data.table(worker_id = unlist(res[[1]])),
        terminated = data.table(worker_id = unlist(res[[2]]))
      )

      worker_states = rbindlist(worker_ids, idcol = "state", use.names = TRUE, fill = TRUE)

      worker_info[worker_states, , on = "worker_id"]
    }
  ),

  private = list(

    .network_id = NULL,

    .config = NULL,

    .connector = NULL,

    # cache for finished tasks
    .cached_tasks = data.table(),

    # counter of the seen results for the latest results methods
    .n_seen_results = 0,

    # counter for printed logs
    # zero based
    .log_counter = list(),

    # prefix key with instance id
    .get_key = function(key) {
      sprintf("%s:%s", private$.network_id, key)
    },

    # prefix key with instance id and worker id
    .get_worker_key = function(key, worker_id = NULL) {
      worker_id = worker_id %??% self$worker_id
      sprintf("%s:%s:%s", private$.network_id, worker_id, key)
    },

    # push worker config to redis
    .push_worker_config = function(
      worker_loop = NULL,
      ...,
      packages = NULL
      ) {
      assert_function(worker_loop)
      dots = list(...)
      assert_character(packages, null.ok = TRUE)

      r = private$.connector

      lg$debug("Pushing worker config to Redis")

      # arguments needed for initializing the worker
      start_args = list(
        worker_loop = worker_loop,
        worker_loop_args = dots,
        packages = c("rush", packages))

      # serialize and push arguments to redis
      # the serialize functions warns that a required package may not be available when loading the start args
      # we ensure that the package is available
      bin_start_args = suppressWarnings(redux::object_to_bin(start_args))

      # check if worker configuration exceeds the limit supported by Redis
      max_object_size = getOption("rush.max_object_size", 512)
      if (format(object.size(bin_start_args), units = "MiB") > max_object_size) {
        if (is.null(rush_env$large_objects_path)) {
          error_config("Worker configuration exceeds the %s MiB limit supported by Redis. Use a path to store large objects on disk instead.", max_object_size)
        } else {
          lg$debug("Worker configuration exceeds %s MiB. Writing to disk instead.", max_object_size)
          bin_start_args = redux::object_to_bin(store_large_object(start_args, path = rush_env$large_objects_path))
        }
      }

      lg$debug("Serializing worker configuration to %s", format(object.size(bin_start_args)))

      r$command(list("SET", private$.get_key("start_args"), bin_start_args))
    },

    # get task keys
    # finished tasks keys can be restricted to uncached tasks
    .tasks_with_state = function(states, only_new_keys = FALSE) {
      r = private$.connector

      # optionally limit finished tasks to uncached tasks
      start_finished_tasks = if (only_new_keys) nrow(private$.cached_tasks) else 0

      # get keys of tasks with different states in one transaction
      r$MULTI()
      if ("queued" %in% states) r$LRANGE(private$.get_key("queued_tasks"), 0, -1)
      if ("running" %in% states) r$SMEMBERS(private$.get_key("running_tasks"))
      if ("finished" %in% states) r$LRANGE(private$.get_key("finished_tasks"), start_finished_tasks, -1)
      if ("failed" %in% states) r$SMEMBERS(private$.get_key("failed_tasks"))
      keys = r$EXEC()
      keys = map(keys, unlist)
      states_order = c("queued", "running", "finished", "failed")
      set_names(keys, states_order[states_order %in% states])
    },

    # fetch tasks
    .fetch_tasks = function(keys, fields) {
      r = private$.connector
      assert_character(fields)

      if (!length(keys)) return(data.table())

      data = self$read_hashes(keys, fields)

      lg$debug("Fetching %i task(s)", length(data))

      tab = rbindlist(data, use.names = TRUE, fill = TRUE)
      tab[, keys := unlist(keys)]
      tab[]
    },

    # fetch and cache tasks
    .fetch_cached_tasks = function(new_keys, fields, reset_cache = FALSE) {
      r = private$.connector
      assert_flag(reset_cache)

      if (reset_cache) private$.cached_tasks = data.table()

      lg$debug("Reading %i cached task(s)", nrow(private$.cached_tasks))

      if (length(new_keys)) {

        lg$debug("Caching %i new task(s)", length(new_keys))

        # rbindlist only the new results and append to cached data.table
        data = self$read_hashes(new_keys, fields)
        new_tab = rbindlist(data, use.names = TRUE, fill = TRUE)
        if (nrow(new_tab)) new_tab[, keys := new_keys]
        private$.cached_tasks = rbindlist(list(private$.cached_tasks, new_tab), use.names = TRUE, fill = TRUE)
      }

      lg$debug("Fetching %i task(s)", nrow(private$.cached_tasks))

      private$.cached_tasks[]
    }
  )
)
