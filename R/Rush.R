#' @title Rush
#'
#' @description
#' The `Rush` class manages a rush network by starting, monitoring, and stopping workers.
#' It shares all task-related methods (e.g., fetching results, pushing tasks) with [RushWorker].
#' A `Rush` instance is created with the [rsh()] function which requires a network ID and a config argument
#' to connect to the Redis database via the \CRANpkg{redux} package.
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
#' When tasks are fetched, the `xss` and `yss` are unpacked
#' so that the names of their inner elements become the columns of the returned table.
#' For example, a `xss` stored as `list(list(x1 = 2, x2 = 3), list(x1 = 4, x2 = 5))` yields `x1` and `x2` columns,
#' not a `xs` column.
#' The inner element names must therefore be unique across these fields.
#'
#' Methods to change the state of an existing task:
#'
#' * `$finish_tasks(keys, yss)`: Save the output of tasks and mark them as finished.
#' * `$fail_tasks(keys, conditions)`: Mark tasks as failed and optionally save the condition objects.
#' * `$pop_task()`: Pop a task from the queue and mark it as running.
#'
#' The methods `$pop_task()`, `$push_running_tasks(xss)`, `$finish_tasks(keys, yss)`, and
#' `$fail_tasks(keys, conditions)` are only available on [RushWorker].
#'
#' The following methods are used to fetch tasks:
#'
#' * `$fetch_tasks()`: Fetch all tasks.
#' * `$fetch_finished_tasks()`: Fetch finished tasks.
#' * `$fetch_failed_tasks()`: Fetch failed tasks.
#' * `$fetch_tasks_with_state()`: Fetch tasks with different states at once.
#' * `$fetch_new_tasks()`: Fetch new tasks and optionally block until new tasks are available.
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
#' Workers are spawned with the `$start_workers()` method on `mirai` daemons.
#' Use [mirai::daemons()] to start daemons.
#' Workers can be started on the
#'  * [local machine](https://mirai.r-lib.org/articles/mirai.html#local-daemons),
#'  * [remote machine](https://mirai.r-lib.org/articles/mirai.html#remote-daemons---ssh-direct)
#'  * or [HPC cluster](https://mirai.r-lib.org/articles/mirai.html#hpc-clusters)
#' using the \CRANpkg{mirai} package.
#'
#' Alternatively, workers can be started locally with the `$start_local_workers()` method
#' via the \CRANpkg{processx} package.
#' Or a help script can be generated with the `$worker_script()` method that can be run anywhere.
#' The only requirement is that the worker can connect to the Redis database.
#'
#' @section Worker Loop:
#' The worker loop is the main function that is run on the workers.
#' It is defined by the user and is passed to the `$start_workers()` method.
#'
#' @section Debugging:
#' The `mirai::mirai` objects started with `$start_workers()` are stored in `$processes_mirai`.
#' Standard output and error of the workers can be written to log files
#' with the `message_log` and `output_log` arguments of `$start_workers()`.
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
#' @template param_xss
#' @template param_xss_extra
#' @template param_yss
#' @template param_yss_extra
#' @template param_conditions
#'
#' @return Object of class [R6::R6Class] and `Rush`.
#' @export
#' @examples
#' if (redux::redis_available()) {
#'   config_local = redux::redis_config()
#'   rush = rsh(network_id = "test_network", config = config_local)
#'   rush
#' }
Rush = R6::R6Class(
  "Rush",
  public = list(
    #' @field processes_processx ([processx::process])\cr
    #' List of processes started with `$start_local_workers()`.
    processes_processx = NULL,

    #' @field processes_mirai ([mirai::mirai])\cr
    #' List of mirai processes started with `$start_workers()`.
    processes_mirai = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(network_id = NULL, config = NULL) {
      private$.network_id = assert_string(network_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
      private$.config = assert_class(config, "redis_config", null.ok = TRUE) %??%
        rush_env$config %??%
        redux::redis_config()
      if (!redux::redis_available(private$.config)) {
        error_config("Can't connect to Redis. Check the configuration.")
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
      cat_cli({
        cli::cli_h1("{.cls {class(self)[1L]}}")
        cli::cli_li("Running Workers: {self$n_running_workers}")
        cli::cli_li("Queued Tasks: {self$n_queued_tasks}")
        cli::cli_li("Running Tasks: {self$n_running_tasks}")
        cli::cli_li("Finished Tasks: {self$n_finished_tasks}")
        cli::cli_li("Failed Tasks: {self$n_failed_tasks}")
      })
    },

    #' @description
    #' Reconnect to Redis.
    #' The connection breaks when the Rush object is saved to disk.
    #' Call this method to reconnect after loading the object.
    reconnect = function() {
      private$.connector = redux::hiredis(private$.config)
    },

    #' @description
    #' Start workers to run the worker loop in `mirai::daemons()`.
    #' Initializes a [RushWorker] in each process and starts the worker loop.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
    start_workers = function(
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
      lgr_thresholds = assert_lgr_thresholds(lgr_thresholds)
      lgr_buffer_size = assert_lgr_buffer_size(lgr_buffer_size)

      mirai_status = status()
      # check number of daemons
      if (!mirai_status$connections) {
        error_config("No daemons available. Start daemons with `mirai::daemons()`")
      }

      # mirai is only available when mirai is started with a dispatcher
      if (!is.null(mirai_status$mirai) && n_workers > mirai_status$connections - mirai_status$mirai["executing"]) {
        warning_config(
          "Number of workers %i exceeds number of available daemons %i",
          n_workers,
          mirai_status$connections - mirai_status$mirai["executing"]
        )
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
      self$processes_mirai = c(
        self$processes_mirai,
        set_names(
          mirai_map(
            worker_ids,
            rush::start_worker,
            .args = list(
              network_id = private$.network_id,
              config = config,
              lgr_thresholds = lgr_thresholds,
              lgr_buffer_size = lgr_buffer_size,
              message_log = message_log,
              output_log = output_log
            )
          ),
          worker_ids
        )
      )

      invisible(worker_ids)
    },

    #' @description
    #' Start workers locally with `processx`.
    #' Initializes a [RushWorker] in each process and starts the worker loop.
    #' Use `$wait_for_workers()` to wait until the workers are registered in the network.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
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
      lgr_thresholds = assert_lgr_thresholds(lgr_thresholds)
      lgr_buffer_size = assert_lgr_buffer_size(lgr_buffer_size)
      assert_flag(supervise)

      r = private$.connector

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        packages = packages
      )

      lg$info("Starting %i worker(s)", n_workers)

      # prepare config for serialization
      # redux cannot handle the url field, it is derived from the other fields
      config = mlr3misc::discard(unclass(self$config), is.null)
      config$url = NULL

      # generate worker ids
      worker_ids = adjective_animal(n = n_workers)

      self$processes_processx = c(
        self$processes_processx,
        set_names(
          map(worker_ids, function(worker_id) {
            # serialize arguments to a temp file to avoid string interpolation
            args = list(
              network_id = private$.network_id,
              worker_id = worker_id,
              config = config,
              lgr_thresholds = lgr_thresholds,
              lgr_buffer_size = lgr_buffer_size,
              message_log = message_log,
              output_log = output_log
            )
            args_file = tempfile(fileext = ".rds")
            saveRDS(args, args_file)

            # deparse() escapes the path as an R string literal e.g. backslashes in windows paths
            expr = sprintf(
              "args = readRDS(%1$s); unlink(%1$s); do.call(rush::start_worker, args)",
              deparse(args_file)
            )

            processx::process$new(
              "Rscript",
              args = c("-e", expr),
              supervise = supervise,
              stderr = "|"
            )
          }),
          worker_ids
        )
      )

      invisible(worker_ids)
    },

    #' @description
    #' Start workers to run the worker loop in `mirai::daemons()`.
    #' Initializes a [RushWorker] in each process and starts the worker loop.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
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
      warn_deprecated("$start_remote_workers()")
      self$start_workers(
        worker_loop = worker_loop,
        ...,
        n_workers = n_workers,
        packages = packages,
        lgr_thresholds = lgr_thresholds,
        lgr_buffer_size = lgr_buffer_size,
        message_log = message_log,
        output_log = output_log
      )
    },

    #' @description
    #' Generate a script to start workers.
    #' Run this script `n` times to start `n` workers.
    #' The logged variant of the script redacts the Redis password.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #'
    #' @return (`character(1)`)\cr
    #' Shell command to start a worker.
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
      lgr_thresholds = assert_lgr_thresholds(lgr_thresholds)
      lgr_buffer_size = assert_lgr_buffer_size(lgr_buffer_size)

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        packages = packages
      )

      # convert arguments to character
      format_config = function(config) {
        fields = imap(config, function(value, name) sprintf("%s = %s", name, shQuote(value, type = "sh")))
        paste0("list(", paste(fields, collapse = ", "), ")")
      }
      args = list(network_id = shQuote(private$.network_id, type = "sh"))
      config = mlr3misc::discard(unclass(self$config), is.null)
      config$url = NULL
      args[["config"]] = format_config(config)
      if (!is.null(lgr_thresholds)) {
        lgr_thresholds = paste(
          imap(lgr_thresholds, function(value, name) {
            sprintf("%s = %s", shQuote(name, type = "sh"), shQuote(value, type = "sh"))
          }),
          collapse = ", "
        )
        args[["lgr_thresholds"]] = paste0("c(", lgr_thresholds, ")")
        args[["lgr_buffer_size"]] = lgr_buffer_size
      }
      if (!is.null(heartbeat_period)) {
        args[["heartbeat_period"]] = heartbeat_period
      }
      if (!is.null(heartbeat_expire)) {
        args[["heartbeat_expire"]] = heartbeat_expire
      }
      if (!is.null(message_log)) {
        args[["message_log"]] = shQuote(message_log, type = "sh")
      }
      if (!is.null(output_log)) {
        args[["output_log"]] = shQuote(output_log, type = "sh")
      }
      format_args = function(args) {
        paste(imap(args, function(value, name) sprintf("%s = %s", name, value)), collapse = ", ")
      }
      script = sprintf("Rscript -e \"rush::start_worker(%s)\"", format_args(args))

      lg$info("Creating worker script")
      # log a variant with the password redacted to keep credentials out of log streams
      if (!is.null(config$password)) {
        config$password = "<redacted>"
        args[["config"]] = format_config(config)
      }
      lg$info("%s", sprintf("Rscript -e \"rush::start_worker(%s)\"", format_args(args)))

      script
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
    #' Defaults to the `start_worker_timeout` set with [rush_plan()], or `Inf` if none is set.
    #' A `timeout` of `0` checks once and errors immediately if the workers are not yet registered.
    wait_for_workers = function(n = NULL, worker_ids = NULL, timeout = NULL) {
      assert_count(n, null.ok = TRUE)
      assert_character(worker_ids, null.ok = TRUE)
      assert_number(timeout, lower = 0, null.ok = TRUE)
      timeout = timeout %??% rush_config()$start_worker_timeout %??% Inf
      start_time = Sys.time()

      if (is.null(n) && is.null(worker_ids)) {
        error_config("Either `n`, `worker_ids` or both must be provided.")
      }

      if (!is.null(n) && !is.null(worker_ids) && n > length(worker_ids)) {
        error_config("Number of workers to wait for %i exceeds number of worker ids %i", n, length(worker_ids))
      }

      n = n %??% length(worker_ids)
      i = 0
      # check at least once before comparing against the timeout so `timeout = 0` means
      # "check once and fail immediately if not ready" instead of never checking
      repeat {
        n_registered_workers = if (is.null(worker_ids)) {
          self$n_workers
        } else {
          length(intersect(self$worker_ids, worker_ids))
        }

        # print updated number of registered workers
        if (n_registered_workers > i) {
          i = n_registered_workers
          lg$info("%i worker(s) registered", i)
        }

        if (n_registered_workers >= n) {
          return(invisible(self))
        }

        if (difftime(Sys.time(), start_time, units = "secs") >= timeout) {
          break
        }
        Sys.sleep(0.1)
      }

      error_timeout()
    },

    #' @description
    #' Stop workers.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be stopped.
    #' If `NULL` all workers are stopped.
    #' Ids that are not currently running are skipped with a warning.
    #' @param type (`character(1)`)\cr
    #' Type of stopping.
    #' Either `"terminate"` or `"kill"`.
    #' If `"kill"` the workers are stopped immediately,
    #' and their running tasks are marked as failed with the condition message `"Worker was killed"`.
    #' If `"terminate"` the workers evaluate the currently running task and then terminate.
    #' The `"terminate"` option must be implemented in the worker loop.
    stop_workers = function(type = "kill", worker_ids = NULL) {
      assert_choice(type, c("terminate", "kill"))
      worker_ids = assert_character(worker_ids, null.ok = TRUE)
      running_worker_ids = self$running_worker_ids
      worker_ids = worker_ids %??% running_worker_ids

      # warn about and ignore requested workers that are not running
      missing_worker_ids = setdiff(worker_ids, running_worker_ids)
      if (length(missing_worker_ids)) {
        lg$warn(
          "Cannot stop %i worker(s) that are not running: %s",
          length(missing_worker_ids),
          str_collapse(missing_worker_ids)
        )
        worker_ids = intersect(worker_ids, running_worker_ids)
      }

      if (!length(worker_ids)) {
        return(invisible(self))
      }
      r = private$.connector

      if (type == "kill") {
        worker_ids_processx = intersect(worker_ids, names(self$processes_processx))
        if (length(worker_ids_processx)) {
          lg$debug("Killing %i local worker(s)", length(worker_ids_processx))

          walk(worker_ids_processx, function(id) {
            lg$info("Kill worker '%s'", id)

            # kill with processx
            killed = self$processes_processx[[id]]$kill()
            if (!killed) {
              lg$error("Failed to kill worker '%s'", id)
            }

            # move worker to terminated
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), id))
          })
        }

        worker_ids_mirai = intersect(worker_ids, names(self$processes_mirai))
        if (length(worker_ids_mirai)) {
          lg$debug("Killing %i remote worker(s)", length(worker_ids_mirai))

          walk(worker_ids_mirai, function(id) {
            lg$info("Kill worker '%s'", id)

            # kill with mirai
            killed = stop_mirai(self$processes_mirai[[id]])
            if (!killed) {
              lg$error("Failed to kill worker '%s'", id)
            }

            # move worker to terminated
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), id))
          })
        }

        worker_ids_heartbeat = self$worker_info[heartbeat == TRUE, worker_id]
        worker_ids_heartbeat = intersect(worker_ids_heartbeat, worker_ids)
        if (length(worker_ids_heartbeat)) {
          lg$debug("Killing %i worker(s) with heartbeat", length(worker_ids_heartbeat))

          cmds = unlist(
            map(worker_ids_heartbeat, function(worker_id) {
              list(
                c("LPUSH", private$.get_worker_key("kill", worker_id), "TRUE"),
                c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), worker_id)
              )
            }),
            recursive = FALSE
          )

          r$pipeline(.commands = cmds)
        }

        # mark the tasks of the killed workers as failed
        # the moves are guarded so a task that a worker finishes before the kill takes effect stays finished
        killed_worker_ids = unique(c(worker_ids_processx, worker_ids_mirai, worker_ids_heartbeat))
        walk(killed_worker_ids, function(worker_id) {
          private$.fail_lost_tasks(worker_id, "Worker was killed")
        })
      }

      if (type == "terminate") {
        lg$debug("Terminating %i worker(s) '%s'", length(worker_ids), as_short_string(worker_ids))

        # Push terminate signal to worker
        cmds = map(worker_ids, function(worker_id) {
          c("SET", private$.get_worker_key("terminate", worker_id), "1")
        })
        r$pipeline(.commands = cmds)
      }

      invisible(self)
    },

    #' @description
    #' Detect lost workers.
    #' The state of the worker is changed to `"terminated"`.
    #'
    #' Workers started with `mirai` or `processx` are monitored through their process handle,
    #' so a worker is only declared lost after its process has actually terminated.
    #' Workers started from `$worker_script()` are monitored through a heartbeat and are declared lost
    #' when the heartbeat key expires.
    #' Because this is a timeout, `heartbeat_expire` must be larger than the longest pause a worker may
    #' experience, for example from garbage collection or swapping.
    #' If a live worker is wrongly declared lost, its running and pending tasks are marked as failed,
    #' and the results of tasks the worker finishes afterwards are discarded.
    #' Set `heartbeat_expire` conservatively to avoid discarding results.
    #'
    #' @return (`character()`)\cr
    #' Worker ids of detected lost workers.
    detect_lost_workers = function() {
      r = private$.connector
      running_worker_ids = self$running_worker_ids
      heartbeat_keys = r$SMEMBERS(private$.get_key("heartbeat_keys"))

      # collect the ids of the workers actually detected as lost in this call
      lost_worker_ids = character()

      # check mirai workers
      if (length(self$processes_mirai)) {
        running_mirai = self$processes_mirai[intersect(running_worker_ids, names(self$processes_mirai))]
        lost = map_lgl(running_mirai, function(m) is_mirai_error(m$data) || is_error_value(m$data))
        iwalk(running_mirai[lost], function(m, id) {
          # for a crashed or interrupted mirai m$data is a scalar errorValue, so derive a human-readable message
          # interrupt (19) has no message
          message = if (unclass(m$data) == 19) "Worker has crashed or was killed" else as.character(m$data)

          lg$error("Lost worker '%s': %s", id, message)

          # move worker to terminated
          r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), id))

          private$.fail_lost_tasks(id, message)
        })
        lost_worker_ids = c(lost_worker_ids, names(running_mirai)[lost])
      }

      # check processx workers
      if (length(self$processes_processx)) {
        running_processx = self$processes_processx[intersect(running_worker_ids, names(self$processes_processx))]
        lost = map_lgl(running_processx, function(p) !p$is_alive())
        iwalk(running_processx[lost], function(p, id) {
          lg$error("Lost worker '%s'", id)
          # print error messages
          # reading the error lines of a killed process may fail, so we guard against it
          try(walk(p$read_all_error_lines(), lg$error), silent = TRUE)

          # move worker to terminated
          r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), id))

          private$.fail_lost_tasks(id, "Worker has crashed or was killed")
        })
        lost_worker_ids = c(lost_worker_ids, names(running_processx)[lost])
      }

      # check heartbeat of workers
      if (length(heartbeat_keys)) {
        running = as.logical(r$pipeline(
          .commands = map(heartbeat_keys, function(heartbeat_key) c("EXISTS", heartbeat_key))
        ))
        if (!all(running)) {
          # search for associated worker ids
          expired_heartbeat_keys = heartbeat_keys[!running]
          # read the heartbeat fields of the the running workers
          cmds = map(running_worker_ids, function(worker_id) c("HMGET", private$.get_key(worker_id), "heartbeat"))
          # guard against a missing heartbeat field in an existing hash with %??% NA
          all_heartbeat_keys = map_chr(r$pipeline(.commands = cmds), function(hash) hash[[1L]] %??% NA_character_)
          lost_workers = running_worker_ids[all_heartbeat_keys %in% expired_heartbeat_keys]

          # set worker state
          cmds = map(lost_workers, function(worker_id) {
            lg$error("Lost worker '%s'", worker_id)
            c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), worker_id)
          })

          # remove heartbeat keys
          cmds = c(cmds, list(c("SREM", private$.get_key("heartbeat_keys"), expired_heartbeat_keys)))

          r$pipeline(.commands = cmds)

          walk(lost_workers, function(worker_id) {
            private$.fail_lost_tasks(worker_id, "Worker has crashed or was killed")
          })
          lost_worker_ids = c(lost_worker_ids, lost_workers)
        }
      }

      lost_worker_ids
    },

    #' @description
    #' Stop workers and delete data stored in redis.
    #'
    #' @param workers (`logical(1)`)\cr
    #' Whether to stop the workers or only delete the data.
    #' Default is `TRUE`.
    reset = function(workers = TRUE) {
      assert_flag(workers)
      r = private$.connector

      cmds = if (workers) {
        # stop workers
        self$stop_workers(type = "kill")

        # reset fields set by starting workers
        self$processes_processx = NULL
        self$processes_mirai = NULL

        # remove worker specific keys
        cmds = unlist(
          map(self$worker_ids, function(worker_id) {
            list(
              c("DEL", private$.get_key(worker_id)),
              c("DEL", private$.get_worker_key("terminate", worker_id)),
              c("DEL", private$.get_worker_key("kill", worker_id)),
              c("DEL", private$.get_worker_key("events", worker_id))
            )
          }),
          recursive = FALSE
        )

        # remove network specific keys
        c(
          cmds,
          list(
            c("DEL", private$.get_key("terminate")),
            c("DEL", private$.get_key("worker_ids")),
            c("DEL", private$.get_key("running_worker_ids")),
            c("DEL", private$.get_key("terminated_worker_ids")),
            c("DEL", private$.get_key("start_args")),
            c("DEL", private$.get_key("heartbeat_keys"))
          )
        )
      }

      # remove all tasks, lists, and sets
      cmds = c(cmds, map(self$tasks, function(key) c("DEL", key)))
      # pending tasks hold task data referencing the deleted hashes, so clear them on every reset (also workers = FALSE)
      cmds = c(
        cmds,
        map(self$worker_ids, function(worker_id) c("DEL", private$.get_worker_key("pending_task", worker_id)))
      )
      cmds = c(
        cmds,
        list(
          c("DEL", private$.get_key("queued_tasks")),
          c("DEL", private$.get_key("running_tasks")),
          c("DEL", private$.get_key("finished_tasks")),
          c("DEL", private$.get_key("failed_tasks")),
          c("DEL", private$.get_key("all_tasks"))
        )
      )
      # wrap the deletions in MULTI/EXEC so a concurrent reader (e.g. $detect_lost_workers()) never observes a
      # half-reset network, such as a worker still in `running_worker_ids` after its hash has been deleted
      r$pipeline(.commands = c(list("MULTI"), cmds, list("EXEC")))

      # reset counters and caches
      private$.cached_tasks = data.table()
      private$.n_seen_results = 0
      private$.n_consumed_tasks = 0L
      private$.log_counter = list()

      invisible(self)
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
    #' Table with columns `worker_id`, `level`, `timestamp`, `logger`, `caller` and `msg`,
    #' and optionally `time_difference`.
    read_log = function(worker_ids = NULL, time_difference = FALSE) {
      assert_flag(time_difference)
      worker_ids = worker_ids %??% self$worker_ids
      r = private$.connector
      cmds = map(worker_ids, function(worker_id) c("LRANGE", private$.get_worker_key("events", worker_id), 0, -1))
      worker_logs = set_names(r$pipeline(.commands = cmds), worker_ids)
      tab = rbindlist(
        set_names(
          map(worker_logs, function(logs) {
            rbindlist(map(logs, fromJSON))
          }),
          worker_ids
        ),
        idcol = "worker_id"
      )
      if (nrow(tab)) {
        tab[, timestamp := as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%OS")]
        setkeyv(tab, "timestamp")
        if (time_difference) {
          tab[,
            time_difference := difftime(timestamp, shift(timestamp, fill = timestamp[1L]), units = "secs"),
            by = worker_id
          ]
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

      if (!self$n_workers) {
        return(invisible(self))
      }

      walk(self$worker_ids, function(worker_id) {
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

      invisible(self)
    },

    #' @description
    #' Create tasks and add them to the queue.
    #'
    #' @param extra (`list()`)\cr
    #' Deprecated argument for additional information stored along with the task.
    #' Use `xss_extra` instead.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_tasks = function(xss, xss_extra = NULL, extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(xss_extra, types = "list", null.ok = TRUE)
      assert_list(extra, types = "list", null.ok = TRUE)
      xss_extra = xss_extra %??% extra

      if (!length(xss)) {
        return(invisible(character()))
      }
      r = private$.connector

      lg$debug("Pushing %i task(s) to the queue", length(xss))

      # write tasks to hashes
      keys = self$write_hashes(
        xs = xss,
        xs_extra = xss_extra
      )

      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("LPUSH", private$.get_key("queued_tasks"), keys)
      )
      r$pipeline(.commands = cmds)

      invisible(keys)
    },

    #' @description
    #' Create finished tasks.
    #' See `$finish_tasks()` for moving existing tasks from running to finished.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_finished_tasks = function(xss, yss, xss_extra = NULL, yss_extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(yss, types = "list")
      assert_list(xss_extra, types = "list", null.ok = TRUE)
      assert_list(yss_extra, types = "list", null.ok = TRUE)
      if (!length(xss)) {
        return(invisible(character()))
      }
      r = private$.connector

      keys = self$write_hashes(xs = xss, ys = yss, xs_extra = xss_extra, ys_extra = yss_extra)
      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("RPUSH", private$.get_key("finished_tasks"), keys)
      )
      r$pipeline(.commands = cmds)

      invisible(keys)
    },

    #' @description
    #' Create failed tasks.
    #' See `$fail_tasks()` for moving existing tasks from queued and running to failed.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_failed_tasks = function(xss, xss_extra = NULL, conditions = NULL) {
      assert_list(xss, types = "list")
      assert_list(xss_extra, types = "list", null.ok = TRUE)
      assert_list(conditions, types = "list", null.ok = TRUE)

      if (!length(xss)) {
        return(invisible(character()))
      }
      conditions = conditions %??% list(list(message = "Task failed"))
      r = private$.connector

      keys = self$write_hashes(xs = xss, xs_extra = xss_extra, condition = wrap_conditions(conditions))
      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("SADD", private$.get_key("failed_tasks"), keys)
      )
      r$pipeline(.commands = cmds)

      invisible(keys)
    },

    #' @description
    #' Remove all tasks from the queue.
    #' The state of the tasks is set to failed.
    #' The condition message is set to `"Removed from queue"`.
    #'
    #' @return (`Rush`)\cr
    #' Invisible self.
    empty_queue = function() {
      r = private$.connector

      # atomically read all queued task keys (LRANGE) and clear the queue (DEL)
      # the pipeline returns one reply per command; the EXEC reply [[4]] holds the results of the queued
      # commands, so [[4]][[1]] is the LRANGE result (the task keys) and [[4]][[2]] is the DEL count
      keys = unlist(r$pipeline(
        .commands = list(
          c("MULTI"),
          c("LRANGE", private$.get_key("queued_tasks"), 0, -1L),
          c("DEL", private$.get_key("queued_tasks")),
          c("EXEC")
        )
      )[[4]][[1]])

      # nothing to do if the queue was already empty
      if (!length(keys)) {
        return(invisible(self))
      }

      self$write_hashes(condition = wrap_conditions(list(list(message = "Removed from queue"))), keys = keys)

      # add to failed tasks
      r$command(c("SADD", private$.get_key("failed_tasks"), keys))

      invisible(self)
    },

    #' @description
    #' Deprecated method to move tasks from queued and running to failed.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to be moved.
    #' Defaults to all queued tasks.
    #'
    #' @return (`Rush`)\cr
    #' Invisible self.
    fail_tasks = function(keys, conditions = NULL) {
      warn_deprecated(
        "$fail_tasks()"
      )

      self$empty_queue()

      invisible(self)
    },

    #' @description
    #' Fetch all tasks from the database.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "ys", "xs_extra", "worker_id", "ys_extra", "condition")`.
    #'
    #' @return `data.table()`\cr
    #' Table of all tasks.
    fetch_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_id", "ys_extra", "condition")) {
      keys = self$tasks
      private$.fetch_tasks(keys, fields)
    },

    #' @description
    #' Fetch queued tasks from the database.
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
    #' Fetch running tasks from the database.
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
    #' Fetch failed tasks from the database.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_id", "condition")`.
    #'
    #' @return `data.table()`\cr
    #' Table of failed tasks.
    fetch_failed_tasks = function(fields = c("xs", "xs_extra", "worker_id", "condition")) {
      keys = self$failed_tasks
      private$.fetch_tasks(keys, fields)
    },

    #' @description
    #' Fetch finished tasks from the database.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("worker_id", "xs", "ys", "xs_extra", "ys_extra", "condition")`.
    #' If the fields change between calls,
    #' fields requested only by a later call remain `NA` for the already cached tasks.
    #' Use `$reset_cache()` to reset the cache in this case.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    fetch_finished_tasks = function(fields = c("worker_id", "xs", "ys", "xs_extra", "ys_extra", "condition")) {
      keys = if (self$n_finished_tasks > private$.n_consumed_tasks) {
        r = private$.connector
        r$command(c("LRANGE", private$.get_key("finished_tasks"), private$.n_consumed_tasks, -1))
      }
      private$.fetch_cached_tasks(keys, fields)
    },

    #' @description
    #' Fetch tasks with different states from the database.
    #' If tasks with different states are to be queried at the same time,
    #' this function prevents tasks from appearing twice.
    #' This could be the case if a worker changes the state of a task while the tasks are being fetched.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("worker_id", "xs", "ys", "xs_extra", "ys_extra", "condition")`.
    #' If the fields change between calls,
    #' fields requested only by a later call remain `NA` for the already cached tasks.
    #' Use `$reset_cache()` to reset the cache in this case.
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
    #' Fetch new tasks that finished after the last call of this function.
    #' Updates the cache of the finished tasks.
    #' If `timeout` is set, blocks until new tasks are available or the timeout is reached.
    #'
    #' "New" is tracked relative to previous calls of this method only.
    #' `$fetch_finished_tasks()` grows the same cache but does not advance this counter,
    #' so a task already returned by `$fetch_finished_tasks()` is returned again by the next `$fetch_new_tasks()`.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' If the fields change between calls,
    #' fields requested only by a later call remain `NA` for the already cached tasks.
    #' Use `$reset_cache()` to reset the cache in this case.
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
          # unblock when there are cached but unseen rows or unconsumed entries in the finished tasks list
          if (
            nrow(private$.cached_tasks) > private$.n_seen_results ||
              self$n_finished_tasks > private$.n_consumed_tasks
          ) {
            break
          }
          Sys.sleep(0.01)
        }
      }

      # fetch finished tasks to populate cache
      self$fetch_finished_tasks(fields)

      # advance the seen counter by the actual number of newly cached rows,
      n_new_results = nrow(private$.cached_tasks) - private$.n_seen_results
      if (!n_new_results) {
        return(data.table())
      }
      private$.n_seen_results = nrow(private$.cached_tasks)

      # return only the new results from the cached data.table
      tail(private$.cached_tasks, n_new_results)[]
    },

    #' @description
    #' Reset the cache of the finished tasks.
    #'
    #' @return (`Rush`)\cr
    #' Invisible self.
    reset_cache = function() {
      private$.cached_tasks = data.table()
      private$.n_seen_results = 0
      private$.n_consumed_tasks = 0L

      invisible(self)
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

      keys = unique(keys)
      r = private$.connector
      # number of completed (finished or failed) tasks already checked against the awaited keys
      # initialized to -1 so the first iteration always performs a full membership check
      n_seen = -1L

      repeat {
        # read the running-worker, finished-task and failed-task counters in a single pipeline (one round-trip per spin)
        counters = r$pipeline(
          .commands = list(
            c("SCARD", private$.get_key("running_worker_ids")),
            c("LLEN", private$.get_key("finished_tasks")),
            c("SCARD", private$.get_key("failed_tasks"))
          )
        )
        if (counters[[1]] == 0L) {
          break
        }

        # reading `$finished_tasks` (LRANGE) and `$failed_tasks` (SMEMBERS) is expensive on large runs,
        # so only re-check membership when the cheap counters report a newly completed task
        n_completed = counters[[2]] + counters[[3]]
        if (n_completed > n_seen) {
          n_seen = n_completed
          if (!any(keys %nin% c(self$finished_tasks, self$failed_tasks))) break
        }
        if (detect_lost_workers) {
          self$detect_lost_workers()
        }
        Sys.sleep(0.01)
      }

      invisible(self)
    },

    #' @description
    #' Writes R objects to Redis hashes.
    #' The function takes the vectors in `...` as input and writes each element as a field-value pair to a new hash.
    #' The name of the argument defines the field into which the serialized element is written.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4))` writes
    #' `serialize(list(x1 = 1, x2 = 2))` at field `xs` into a hash
    #' and `serialize(list(x1 = 3, x2 = 4))` at field `xs` into another hash.
    #' The function can iterate over multiple vectors simultaneously.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)),
    #' ys = list(list(y = 3), list(y = 7))` creates two hashes with the fields `xs` and `ys`.
    #' All value lists must either have the same length (the number of hashes) or length 1,
    #' in which case the value is broadcast across all hashes.
    #' Other length mismatches raise an error.
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
      lens = map_int(values, length)
      if (is.null(keys)) {
        n_hashes = if (length(lens)) max(lens) else 0L
        keys = UUIDgenerate(n = n_hashes)
      } else {
        assert_character(keys)
        n_hashes = length(keys)
      }

      # every value list must be length 1 (broadcast) or length n_hashes
      if (any(lens != 1L & lens != n_hashes)) {
        error_input(
          "All value lists must have length 1 or %i (the number of hashes); got %s",
          n_hashes,
          str_collapse(sprintf("%s=%i", fields, lens))
        )
      }

      lg$debug("Writing %i hash(es) with %i field(s)", length(keys), length(fields))

      # construct list of redis commands to write hashes
      # one hash per iteration
      cmds = pmap(c(list(key = keys), values), function(key, ...) {
        # serialize value of field
        bin_values = map(list(...), redux::object_to_bin)

        lg$debug("Serializing %i value(s) to %s", length(bin_values), format(Reduce(`+`, map(bin_values, object.size))))

        # merge fields and values alternatively
        # HSET expects `c(field1, value1, field2, value2, ...)`
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
    #' If `flatten` is `TRUE`, the values are flattened to a single list e.g.
    #' `list(xs = list(x1 = 1, x2 = 2), ys = list(y = 3))` becomes `list(x1 = 1, x2 = 2, y = 3)`.
    #' The reading functions combine the hashes to a table where the names of the inner lists are the column names.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)),
    #' ys = list(list(y = 3), list(y = 7))` becomes
    #' `data.table(x1 = c(1, 3), x2 = c(2, 4), y = c(3, 7))`.
    #' Names must be unique across the flattened fields.
    #' Colliding names produce duplicate columns, of which only the first is reachable by name.
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
      # List
      #   Hash 1
      #     Field 1 (serialized list or atomic)
      #     Field 2
      #   Hash 2
      #     Field 1
      #     Field 2
      hashes = private$.connector$pipeline(.commands = cmds)

      if (flatten) {
        # unserialize elements / fields of the second level
        # flatten elements / fields of the second level to one list
        # e.g. list(hash1 = list(field1 = list(x1 = 1, x2 = 2), field2 = list(y = 3)))
        # becomes list(hash1 = list(x1 = 1, x2 = 2, y = 3))
        # using mapply instead of pmap is faster
        map(hashes, function(hash) {
          result = unlist(
            .mapply(
              function(bin_value, field) {
                # unserialize value
                value = safe_bin_to_object(bin_value)
                # wrap atomic values in list and name by field
                if (is.atomic(value) && !is.null(value)) {
                  value = setNames(list(value), field)
                }
                value
              },
              list(bin_value = hash, field = fields),
              NULL
            ),
            recursive = FALSE
          )
          # wrap vectors in list to create list columns
          # rbindlist would expand a vector into multiple rows
          lens = lengths(result)
          if (any(lens > 1L)) {
            idx = lens > 1L
            result[idx] = lapply(result[idx], list)
          }
          result
        })
      } else {
        # unserialize elements of the second level
        # e.g. list(hash1 = list(field1 = list(x1 = 1, x2 = 2), field2 = list(y = 3)))
        # becomes list(hash1 = list(field1 = list(x1 = 1, x2 = 2), field2 = list(y = 3)))
        map(hashes, function(hash) {
          setNames(
            map(hash, function(bin_value) {
              safe_bin_to_object(bin_value)
            }),
            fields
          )
        })
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
      if (!length(keys)) {
        return(logical(0))
      }
      as.logical(r$command(c("SMISMEMBER", private$.get_key("running_tasks"), keys)))
    },

    #' @description
    #' Checks whether tasks have the status `"failed"`.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks.
    is_failed_task = function(keys) {
      r = private$.connector
      if (!length(keys)) {
        return(logical(0))
      }
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
    #' Assigning a new configuration does not affect the live connection.
    #' Call `$reconnect()` afterwards to connect with the new configuration.
    config = function(rhs) {
      if (missing(rhs)) {
        return(private$.config)
      }
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
      as.integer(r$SCARD(private$.get_key("worker_ids")))
    },

    #' @field n_running_workers (`integer(1)`)\cr
    #' Number of running workers.
    n_running_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("running_worker_ids")))
    },

    #' @field n_terminated_workers (`integer(1)`)\cr
    #' Number of terminated workers.
    n_terminated_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("terminated_worker_ids")))
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
      as.integer(r$LLEN(private$.get_key("queued_tasks")))
    },

    #' @field n_running_tasks (`integer(1)`)\cr
    #' Number of running tasks.
    n_running_tasks = function() {
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("running_tasks")))
    },

    #' @field n_finished_tasks (`integer(1)`)\cr
    #' Number of finished tasks.
    n_finished_tasks = function() {
      r = private$.connector
      as.integer(r$LLEN(private$.get_key("finished_tasks")))
    },

    #' @field n_failed_tasks (`integer(1)`)\cr
    #' Number of failed tasks.
    n_failed_tasks = function() {
      r = private$.connector
      as.integer(r$SCARD(private$.get_key("failed_tasks")))
    },

    #' @field n_tasks (`integer(1)`)\cr
    #' Number of all tasks.
    n_tasks = function() {
      r = private$.connector
      as.integer(r$LLEN(private$.get_key("all_tasks")))
    },

    #' @field worker_info ([data.table::data.table()])\cr
    #' Contains information about the workers.
    worker_info = function(rhs) {
      assert_ro_binding(rhs)
      if (!self$n_workers) {
        return(data.table())
      }
      r = private$.connector

      fields = c("worker_id", "pid", "hostname", "heartbeat")
      cmds = map(self$worker_ids, function(worker_id) c("HMGET", private$.get_key(worker_id), fields))
      worker_info = set_names(rbindlist(r$pipeline(.commands = cmds)), fields)

      # fix type
      worker_info[, pid := as.integer(pid)][]
      worker_info[, heartbeat := nzchar(heartbeat)][]

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

    # number of entries of the finished tasks list already read from redis
    # advances even when a task is dropped because its hash is missing,
    # so it can be larger than nrow(.cached_tasks)
    # integer (not double) so it never serializes to scientific notation (e.g. "1e+05") in redis LRANGE indices
    .n_consumed_tasks = 0L,

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
      worker_loop = crate(worker_loop, .parent = topenv(environment(worker_loop)))
      dots = list(...)
      assert_character(packages, null.ok = TRUE)

      r = private$.connector

      lg$debug("Pushing worker config to Redis")

      # arguments needed for initializing the worker
      start_args = list(
        worker_loop = worker_loop,
        worker_loop_args = dots,
        packages = c("rush", packages)
      )

      # serialize and push arguments to redis
      # the serialize functions warns that a required package may not be available when loading the start args
      # we ensure that the package is available
      bin_start_args = suppressWarnings(redux::object_to_bin(start_args))

      # check if worker configuration exceeds the limit supported by Redis
      max_object_size = getOption("rush.max_object_size", 512)
      if (as.numeric(object.size(bin_start_args)) / (1024^2) > max_object_size) {
        if (is.null(rush_env$large_objects_path)) {
          error_config(
            paste(
              "Worker configuration exceeds the %s MiB limit supported by Redis.",
              "Use a path to store large objects on disk instead."
            ),
            max_object_size
          )
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

      # optionally limit finished tasks to unconsumed tasks
      start_finished_tasks = if (only_new_keys) private$.n_consumed_tasks else 0

      # get keys of tasks with different states in one transaction
      r$MULTI()
      if ("queued" %in% states) {
        r$LRANGE(private$.get_key("queued_tasks"), 0, -1)
      }
      if ("running" %in% states) {
        r$SMEMBERS(private$.get_key("running_tasks"))
      }
      if ("finished" %in% states) {
        r$LRANGE(private$.get_key("finished_tasks"), start_finished_tasks, -1)
      }
      if ("failed" %in% states) {
        r$SMEMBERS(private$.get_key("failed_tasks"))
      }
      keys = r$EXEC()
      keys = map(keys, unlist)
      states_order = c("queued", "running", "finished", "failed")
      set_names(keys, states_order[states_order %in% states])
    },

    # fetch tasks
    .fetch_tasks = function(keys, fields) {
      r = private$.connector
      assert_character(fields)

      if (!length(keys)) {
        return(data.table())
      }

      data = self$read_hashes(keys, fields)

      # tasks can disappear from the database e.g. when redis evicts keys under memory pressure
      # drop them so keys and rows stay aligned
      missing = map_lgl(data, is.null)
      if (any(missing)) {
        lg$warn("Removing %i task(s) with missing data", sum(missing))
        data = data[!missing]
        keys = keys[!missing]
      }

      lg$debug("Fetching %i task(s)", length(data))

      if (!length(data)) {
        return(data.table())
      }

      tab = rbindlist(data, use.names = TRUE, fill = TRUE)
      tab[, keys := unlist(keys)]
      tab[]
    },

    # fetch and cache tasks
    .fetch_cached_tasks = function(new_keys, fields) {
      r = private$.connector

      lg$debug("Reading %i cached task(s)", nrow(private$.cached_tasks))

      if (length(new_keys)) {
        lg$debug("Caching %i new task(s)", length(new_keys))

        data = self$read_hashes(new_keys, fields)

        # the consumed counter advances even for dropped tasks so they are never read again
        private$.n_consumed_tasks = private$.n_consumed_tasks + length(new_keys)

        # tasks can disappear from the database e.g. when redis evicts keys under memory pressure
        # drop them so keys and rows stay aligned
        missing = map_lgl(data, is.null)
        if (any(missing)) {
          lg$warn("Removing %i task(s) with missing data", sum(missing))
          data = data[!missing]
          new_keys = new_keys[!missing]
        }

        if (length(data)) {
          # rbindlist only the new results and append to cached data.table
          new_tab = rbindlist(data, use.names = TRUE, fill = TRUE)
          new_tab[, keys := unlist(new_keys)]
          private$.cached_tasks = rbindlist(list(private$.cached_tasks, new_tab), use.names = TRUE, fill = TRUE)
        }
      }

      lg$debug("Fetching %i task(s)", nrow(private$.cached_tasks))

      private$.cached_tasks[]
    },

    # move pending and running tasks of a lost worker to failed state
    .fail_lost_tasks = function(worker_id, message) {
      r = private$.connector

      # read the running tasks only now, after the worker has been flagged lost and moved to terminated
      running_tasks = self$fetch_running_tasks(fields = "worker_id")
      running_keys = if (nrow(running_tasks)) running_tasks[list(worker_id), keys, on = "worker_id"]
      running_keys = running_keys[!is.na(running_keys)]

      # popped from the queue into the pending list but not yet marked as running when the worker was lost
      pending_keys = unlist(r$command(c("LRANGE", private$.get_worker_key("pending_task", worker_id), 0, -1)))

      keys = c(running_keys, pending_keys)
      if (!length(keys)) {
        lg$debug("Worker '%s' has no running or pending tasks", worker_id)
        return(invisible(NULL))
      }

      # write the conditions before the moves so a task is never visible as failed without its condition
      self$write_hashes(condition = wrap_conditions(list(list(message = message))), keys = keys)

      # the moves are guarded so a key is only failed while it is still in its source (first writer wins)
      # if the worker is alive and finishes or pops a task concurrently, the state set by the first actor stays
      moved = c(
        if (length(running_keys)) {
          unlist(r$command(c(
            "EVAL",
            lua_move_set_to_set,
            "2",
            private$.get_key("running_tasks"),
            private$.get_key("failed_tasks"),
            running_keys
          )))
        },
        if (length(pending_keys)) {
          unlist(r$command(c(
            "EVAL",
            lua_move_list_to_set,
            "2",
            private$.get_worker_key("pending_task", worker_id),
            private$.get_key("failed_tasks"),
            pending_keys
          )))
        }
      )

      if (length(moved)) {
        lg$error("Lost %i task(s): %s", length(moved), str_collapse(moved))
      }

      invisible(NULL)
    }
  )
)
