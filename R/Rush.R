#' @title Rush Controller
#'
#' @description
#' The `Rush` controller manages workers in a rush network.
#'
#' @section Local Workers:
#' A local worker runs on the same machine as the controller.
#' Local workers are spawned with the `$start_local_workers() method via the \CRANpkg{processx} package.
#'
#' @section Remote Workers:
#' A remote worker runs on a different machine than the controller.
#' Remote workers are spawned with the `$start_remote_workers() method via the \CRANpkg{mirai} package.
#'
#' @section Script Workers:
#' Workers can be started with a script anywhere.
#' The only requirement is that the worker can connect to the Redis database.
#' The script is created with the `$worker_script()` method.
#'
#' @template param_network_id
#' @template param_config
#' @template param_worker_loop
#' @template param_globals
#' @template param_packages
#' @template param_remote
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_seed
#' @template param_data_format
#' @template param_message_log
#' @template param_output_log
#'
#' @return Object of class [R6::R6Class] and `Rush` with controller methods.
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'    rush = rsh(network_id = "test_network", config = config_local)
#'    rush
#' }
Rush = R6::R6Class("Rush",
  public = list(

    #' @field network_id (`character(1)`)\cr
    #' Identifier of the rush network.
    network_id = NULL,

    #' @field config ([redux::redis_config])\cr
    #' Redis configuration options.
    config = NULL,

    #' @field connector ([redux::redis_api])\cr
    #' Returns a connection to Redis.
    connector = NULL,

    #' @field processes_processx ([processx::process])\cr
    #' List of processes started with `$start_local_workers()`.
    processes_processx = NULL,

    #' @field processes_mirai ([mirai::mirai])\cr
    #' List of mirai processes started with `$start_remote_workers()`.
    processes_mirai = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(network_id = NULL, config = NULL, seed = NULL) {
      self$network_id = assert_string(network_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
      self$config = assert_class(config, "redis_config", null.ok = TRUE) %??% rush_env$config
      if (is.null(self$config)) self$config = redux::redis_config()
      if (!redux::redis_available(self$config)) {
        stop("Can't connect to Redis. Check the configuration.")
      }
      self$connector = redux::hiredis(self$config)

      if (!is.null(seed)) {
        if (is_lecyer_cmrg_seed(seed)) {
          # use supplied L'Ecuyer-CMRG seed
          private$.seed = seed
        } else {
          # generate new L'Ecuyer-CMRG seed
          assert_count(seed)

          # save old rng state and kind and switch to L'Ecuyer-CMRG
          oseed = get_random_seed()
          okind = RNGkind("L'Ecuyer-CMRG")[1]

          # restore old rng state and kind
          on.exit(set_random_seed(oseed, kind = okind), add = TRUE)

          set.seed(seed)
          private$.seed = get_random_seed()
        }
      }
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
      catf(str_indent("* Queued Priority Tasks:", self$n_queued_priority_tasks))
      catf(str_indent("* Running Tasks:", self$n_running_tasks))
      catf(str_indent("* Finished Tasks:", self$n_finished_tasks))
      catf(str_indent("* Failed Tasks:", self$n_failed_tasks))
    },

    #' @description
    #' Reconnect to Redis.
    #' The connection breaks when the Rush object is saved to disk.
    #' Call this method to reconnect after loading the object.
    reconnect = function() {
      self$connector = redux::hiredis(self$config)
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
      worker_loop = NULL,
      ...,
      n_workers = NULL,
      globals = NULL,
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

      r = self$connector

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        globals = globals,
        packages = packages
      )

      lg$info("Starting %i worker(s)", n_workers)

      # convert arguments to character
      config = mlr3misc::discard(unclass(self$config), is.null)
      config = paste(imap(config, function(value, name) sprintf("%s = '%s'", name, value)), collapse = ", ")
      config = paste0("list(", config, ")")
      lgr_thresholds = paste(imap(lgr_thresholds, function(value, name) sprintf("'%s' = '%s'", name, value)), collapse = ", ")
      lgr_thresholds = paste0("c(", lgr_thresholds, ")")
      message_log = if(is.null(message_log)) "NULL" else sprintf("'%s'", message_log)
      output_log = if(is.null(output_log)) "NULL" else sprintf("'%s'", output_log)

      # generate worker ids
      worker_ids = adjective_animal(n = n_workers)

      self$processes_processx = c(self$processes_processx, set_names(map(worker_ids, function(worker_id) {
       processx::process$new("Rscript",
        args = c("-e", sprintf("rush::start_worker(network_id = '%s', worker_id = '%s', config = %s, remote = FALSE, lgr_thresholds = %s, lgr_buffer_size = %i, message_log = %s, output_log = %s)",
          self$network_id, worker_id, config, lgr_thresholds, lgr_buffer_size, message_log, output_log)),
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
      globals = NULL,
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

      # $mirai is only available when mirai is started with a dispatcher
      if (!is.null(mirai_status$mirai) && n_workers > mirai_status$connections - mirai_status$mirai["executing"]) {
        warningf("Number of workers %i exceeds number of available daemons %i", n_workers, mirai_status$connections - mirai_status$mirai["executing"])
      }

      # push worker config to redis
      private$.push_worker_config(
        worker_loop = worker_loop,
        ...,
        globals = globals,
        packages = packages
      )

      lg$info("Starting %i worker(s)", n_workers)

      # reduce redis config
      config = mlr3misc::discard(unclass(self$config), is.null)

      # generate worker ids
      worker_ids = adjective_animal(n = n_workers)

      # start rush worker with mirai
      self$processes_mirai = c(self$processes_mirai, set_names(
        mirai_map(worker_ids, rush::start_worker,
          .args = list(
            network_id = self$network_id,
            config = config,
            remote = TRUE,
            lgr_thresholds,
            lgr_buffer_size,
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
      globals = NULL,
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
        globals = globals,
        packages = packages
      )

      # convert arguments to character
      args = list(network_id = sprintf("'%s'", self$network_id))
      config = mlr3misc::discard(unclass(self$config), is.null)
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
    #' Restart workers.
    #' If the worker is is still running, it is killed and restarted.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be restarted.
    #' @param supervise (`logical(1)`)\cr
    #' Whether to kill the workers when the main R process is shut down.
    restart_workers = function(worker_ids, supervise = TRUE) {
      assert_subset(unlist(worker_ids), self$worker_ids)
      r = self$connector
      restarted_worker_ids = character(0)

      # restart mirai workers
      worker_id_mirai = intersect(worker_ids, names(self$processes_mirai))
      if (length(worker_id_mirai)) {
        mirai_status = status()
        # check number of daemons
        if (!mirai_status$connections) {
          stop("No daemons available. Start daemons with `mirai::daemons()`")
        }
        if (length(worker_id_mirai) > mirai_status$connections - mirai_status$mirai["executing"]) {
          warningf("Number of workers %i exceeds number of available daemons %i", n_workers, mirai_status$connections - mirai_status$mirai["executing"])
        }

        # stop running workers
        self$stop_workers(type = "kill", intersect(self$running_worker_ids, worker_id_mirai))

        lg$info("Restarting %i worker(s): %s", length(worker_id_mirai), str_collapse(worker_id_mirai))

        # reduce redis config
        config = mlr3misc::discard(unclass(self$config), is.null)

        r$command(c("SREM", private$.get_key("killed_worker_ids"), worker_id_mirai))
        r$command(c("SREM", private$.get_key("lost_worker_ids"), worker_id_mirai))

        # start rush worker with mirai
        new_processes = set_names(
          mirai_map(worker_id_mirai, rush::start_worker,
            .args = list(
              network_id = self$network_id,
              config = config,
              remote = TRUE,
              lgr_thresholds = c("mlr3/rush" = "debug"))), # FIXME LOG Level
          worker_id_mirai)

        self$processes_mirai = insert_named(self$processes_mirai, new_processes)
        restarted_worker_ids = c(restarted_worker_ids, worker_id_mirai)
      }

      # restart processx workers
      worker_id_processx = intersect(worker_ids, names(self$processes_processx))
      if (length(worker_id_processx)) {
        # stop running workers
        self$stop_workers(type = "kill", intersect(self$running_worker_ids, worker_id_processx))

        lg$info("Restarting %i worker(s): %s", length(worker_id_processx), str_collapse(worker_id_processx))

        # redis config to string
        config = mlr3misc::discard(unclass(self$config), is.null)
        config = paste(imap(config, function(value, name) sprintf("%s = '%s'", name, value)), collapse = ", ")
        config = paste0("list(", config, ")")

        r$command(c("SREM", private$.get_key("killed_worker_ids"), worker_id_processx))
        r$command(c("SREM", private$.get_key("lost_worker_ids"), worker_id_processx))

        new_processes = set_names(map(worker_id_processx, function(worker_id) {
          processx::process$new("Rscript",
            args = c("-e", sprintf("rush::start_worker(network_id = '%s', worker_id = '%s', config = %s, remote = FALSE)",
              self$network_id, worker_id, config)),
            supervise = supervise, stderr = "|") # , stdout = "|"
        }), worker_ids)
        self$processes_processx = insert_named(self$processes_processx, new_processes)
        restarted_worker_ids = c(restarted_worker_ids, worker_id_processx)
      }

      return(invisible(restarted_worker_ids))
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
      r = self$connector

      if (type == "kill") {

        worker_ids_processx = intersect(worker_ids, names(self$processes_processx))
        if (length(worker_ids_processx)) {
          lg$debug("Killing %i local worker(s)", length(worker_ids_processx))

          walk(worker_ids_processx, function(id) {
            lg$info("Kill worker '%s'", id)

            # kill with processx
            killed = self$processes_processx[[id]]$kill()
            if (!killed) lg$error("Failed to kill worker '%s'", id)

            # move worker to killed
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("killed_worker_ids"), id))
          })
        }

        worker_ids_mirai = intersect(worker_ids, names(self$processes_mirai))
        if (length(worker_ids_mirai)) {
          lg$debug("Killing %i remote worker(s)", length(worker_ids_mirai))

          walk(worker_ids_mirai, function(id) {
            lg$info("Kill worker '%s'", id)

            # kill with mirai
            killed = stop_mirai(self$processes_mirai[[id]])
            if (!killed) lg$error("Failed to kill worker '%s'", id)

            # move worker to killed
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("killed_worker_ids"), id))
          })
        }

        worker_ids_heartbeat = self$worker_info[heartbeat == TRUE, worker_id]
        if (length(worker_ids_heartbeat)) {
          lg$debug("Killing %i worker(s) with heartbeat", length(worker_ids_heartbeat))

          cmds= unlist(map(worker_ids_heartbeat, function(worker_id) {
            list(
              c("LPUSH", private$.get_worker_key("kill", worker_id), "TRUE"),
              c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("killed_worker_ids"), worker_id))
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
    #' The state of the worker is changed to `"lost"`.
    #'
    #' @param restart_local_workers (`logical(1)`)\cr
    #' Whether to restart lost workers.
    #' Ignored for remote workers.
    detect_lost_workers = function(restart_local_workers = FALSE) {
      assert_flag(restart_local_workers)
      r = self$connector

      running_tasks = self$fetch_running_tasks(fields = "worker_extra")

      # check mirai workers
      if (length(self$processes_mirai)) {
        iwalk(self$processes_mirai[intersect(self$running_worker_ids, names(self$processes_mirai))], function(m, id) {
          if (is_mirai_error(m$data) || is_error_value(m$data)) {
            lg$error("Lost worker '%s'", id)

            # print error messages
            walk(self$processes_mirai[[id]]$data, lg$error)

            # move worker to lost
            r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("lost_worker_ids"), id))

            # identify lost tasks
            if (nrow(running_tasks)) {
              keys = running_tasks[list(id), keys, on = "worker_id"]
              lg$error("Lost %i task(s): %s", length(keys), str_collapse(keys))

              # Replace interrupt error message
              message = if (unclass(m$data) == 19) "Worker has crashed or was killed" else as.character(m$data)

              # push failed tasks
              conditions = list(list(message = message))
              self$push_failed(keys, conditions = conditions)
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
              self$push_failed(keys, conditions = conditions)
            }

            if (restart_local_workers) {
              lg$debug("Restarting lost worker '%s'", id)
              self$restart_workers(id)
            } else {
              # move worker to lost
              r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("lost_worker_ids"), id))
            }
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
          c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("lost_worker_ids"), worker_id)
        })

        # remove heartbeat keys
        cmds = c(cmds, list(c("SREM", "heartbeat_keys", heartbeat_keys)))

        r$pipeline(.commands =  cmds)
      }

      return(invisible(self))
    },

    #' @description
    #' Stop workers and delete data stored in redis.
    #' @param type (`character(1)`)\cr
    #' Type of stopping.
    #' Either `"terminate"` or `"kill"`.
    #' If `"terminate"` the workers evaluate the currently running task and then terminate.
    #' If `"kill"` the workers are stopped immediately.
    reset = function(type = "kill") {
      r = self$connector

      # stop workers
      if (!is.null(type)) self$stop_workers(type = type)

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
      r$DEL(private$.get_key("killed_worker_ids"))
      r$DEL(private$.get_key("lost_worker_ids"))
      r$DEL(private$.get_key("pre_worker_ids"))
      r$DEL(private$.get_key("start_args"))
      r$DEL(private$.get_key("terminate_on_idle"))
      r$DEL(private$.get_key("local_workers"))
      r$DEL(private$.get_key("heartbeat_keys"))

      # be safe
      remaining_keys = self$connector$command(c("KEYS", "*"))
      map(remaining_keys, function(key) {
        lg$debug("Found remaining key: %s", key)
        if (grepl(self$network_id, key)) r$DEL(key)
      })

      # reset counters and caches
      private$.cached_tasks = list()
      private$.n_seen_results = 0

      return(invisible(self))
    },

    #' @description
    #' Read log messages written with the `lgr` package from a worker.
    #'
    #' @param worker_ids (`character(1)`)\cr
    #' Worker ids.
    #' If `NULL` all worker ids are used.
    #' @param time_difference (`logical(1)`)\cr
    #' Whether to calculate the time difference between log messages.
    #' @return ([data.table::data.table()]) with level, timestamp, logger, caller and message, and optionally time difference.
    read_log = function(worker_ids = NULL, time_difference = FALSE) {
      assert_flag(time_difference)
      worker_ids = worker_ids %??% self$worker_ids
      r = self$connector
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
    #' Print log messages written with the `lgr` package from a worker.
    print_log = function() {
      r = self$connector

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
      return(invisible(NULL))
    },

    #' @description
    #' Pushes a task to the queue.
    #' Task is added to queued tasks.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list()`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #' @param seeds (`list()`)\cr
    #' List of L'Ecuyer-CMRG seeds for each task e.g `list(list(c(104071, 490840688, 1690070564, -495119766, 503491950, 1801530932, -1629447803)))`.
    #' If `NULL` but an initial seed is set, L'Ecuyer-CMRG seeds are generated from the initial seed.
    #' If `NULL` and no initial seed is set, no seeds are used for the random number generator.
    #' @param timeouts (`integer()`)\cr
    #' Timeouts for each task in seconds e.g. `c(10, 15)`.
    #' A single number is used as the timeout for all tasks.
    #' If `NULL` no timeout is set.
    #' @param max_retries (`integer()`)\cr
    #' Number of retries for each task.
    #' A single number is used as the number of retries for all tasks.
    #' If `NULL` tasks are not retried.
    #' @param terminate_workers (`logical(1)`)\cr
    #' Whether to stop the workers after evaluating the tasks.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_tasks = function(xss, extra = NULL, seeds = NULL, timeouts = NULL, max_retries = NULL, terminate_workers = FALSE) {
      assert_list(xss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      assert_list(seeds, types = "numeric", null.ok = TRUE)
      assert_numeric(timeouts, null.ok = TRUE)
      assert_numeric(max_retries, null.ok = TRUE)
      assert_flag(terminate_workers)
      r = self$connector

      lg$debug("Pushing %i task(s) to the shared queue", length(xss))

      if (!is.null(private$.seed) && is.null(seeds)) {

        lg$debug("Creating %i L'Ecuyer-CMRG seeds", length(xss))

        seeds = make_rng_seeds(length(xss), private$.seed)
        # store last seed for next push
        private$.seed = seeds[[length(seeds)]]
      }

      # write tasks to hashes
      keys = self$write_hashes(
        xs = xss,
        xs_extra = extra,
        seed = seeds,
        timeout = timeouts,
        max_retries = max_retries)

      cmds = list(
        c("RPUSH", private$.get_key("all_tasks"), keys),
        c("LPUSH", private$.get_key("queued_tasks"), keys))
      r$pipeline(.commands = cmds)
      if (terminate_workers) r$command(c("SET", private$.get_key("terminate_on_idle"), 1))

      return(invisible(keys))
    },

    #' @description
    #' Pushes a task to the queue of a specific worker.
    #' Task is added to queued priority tasks.
    #' A worker evaluates the tasks in the priority queue before the shared queue.
    #' If `priority` is `NA` the task is added to the shared queue.
    #' If the worker is lost or worker id is not known, the task is added to the shared queue.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #' @param priority (`character()`)\cr
    #' Worker ids to which the tasks should be pushed.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_priority_tasks = function(xss, extra = NULL, priority = NULL) {
      assert_list(xss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      assert_character(priority, len = length(xss))

      # redirect to shared queue when worker is lost or worker id is not known
      priority[priority %nin% self$running_worker_ids] = NA_character_
      r = self$connector

      lg$debug("Pushing %i task(s) to %i priority queue(s) and %i task(s) to the shared queue.",
        sum(!is.na(priority)), length(unique(priority[!is.na(priority)])), sum(is.na(priority)))

      keys = self$write_hashes(xs = xss, xs_extra = extra)
      cmds = pmap(list(priority, keys), function(worker_id, key) {
        if (is.na(worker_id)) {
          c("LPUSH", private$.get_key("queued_tasks"), key)
        } else {
          c("LPUSH", private$.get_worker_key("queued_tasks", worker_id), key)
        }
      })
      r$pipeline(.commands = cmds)
      r$command(c("RPUSH", private$.get_key("all_tasks"), keys))

      return(invisible(keys))
    },

    #' @description
    #' Pushes failed tasks to the data base.
    #' Tasks are moved from queued and running to failed.
    #'
    #' @param keys (`character(1)`)\cr
    #' Keys of the associated tasks.
    #' @param conditions (named `list()`)\cr
    #' List of lists of conditions.
    push_failed = function(keys, conditions) {
      assert_character(keys)
      assert_list(conditions, types = "list")
      r = self$connector

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
    #' Empty the queue of tasks.
    #' Moves tasks from queued to failed.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to be moved.
    #' Defaults to all queued tasks.
    #' @param conditions (named `list()`)\cr
    #' List of lists of conditions.
    empty_queue = function(keys = NULL, conditions = NULL) {
      r = self$connector
      keys = keys %??% self$queued_tasks

      if (is.null(conditions)) {
        conditions = replicate(length(keys), list(message = "Removed from queue"), simplify = FALSE)
      }

      if (length(keys)) {
        self$push_failed(keys, conditions = conditions)
      }

      return(invisible(self))
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
    fetch_queued_tasks = function(fields = c("xs", "xs_extra"), data_format = "data.table") {
      keys = self$queued_tasks
      private$.fetch_tasks(keys, fields, data_format)
    },

    #' @description
    #' Fetch queued priority tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra")`.
    #'
    #' @return `data.table()`\cr
    #' Table of queued priority tasks.
    fetch_priority_tasks = function(fields = c("xs", "xs_extra"), data_format = "data.table") {
      assert_character(fields)
      assert_choice(data_format, c("data.table", "list"))
      r = self$connector

      cmds = map(self$worker_ids, function(worker_id)  c("LRANGE", private$.get_worker_key("queued_tasks", worker_id), "0", "-1"))
      if (!length(cmds)) {
        data = if (data_format == "list") list() else data.table()
        return(data)
      }

      keys = unlist(r$pipeline(.commands = cmds))
      private$.fetch_tasks(keys, fields, data_format)
    },

    #' @description
    #' Fetch running tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra")`.
    #'
    #' @return `data.table()`\cr
    #' Table of running tasks.
    fetch_running_tasks = function(fields = c("xs", "xs_extra", "worker_extra"), data_format = "data.table") {
      keys = self$running_tasks
      private$.fetch_tasks(keys, fields, data_format)
    },

    #' @description
    #' Fetch finished tasks from the data base.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra")`.
    #' @param reset_cache (`logical(1)`)\cr
    #' Whether to reset the cache.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    fetch_finished_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"), reset_cache = FALSE, data_format = "data.table") {
      keys = if (self$n_finished_tasks > length(private$.cached_tasks)) {
         r = self$connector
         r$command(c("LRANGE", private$.get_key("finished_tasks"), length(private$.cached_tasks), -1))
      }
      private$.fetch_cached_tasks(keys, fields, reset_cache, data_format)
    },

    #' @description
    #' Block process until a new finished task is available.
    #' Returns all finished tasks or `NULL` if no new task is available after `timeout` seconds.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra")`.
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for a result in seconds.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    wait_for_finished_tasks = function(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra"),
      timeout = Inf,
      data_format = "data.table"
      ) {
      assert_number(timeout, lower = 0)
      start_time = Sys.time()

      lg$debug("Wait for new tasks for at least %s seconds", as.character(timeout))

      while(start_time + timeout > Sys.time()) {
        if (self$n_finished_tasks > length(private$.cached_tasks)) {
          return(self$fetch_finished_tasks(fields, data_format = data_format))
        }
        Sys.sleep(0.01)
      }
      NULL
    },

    #' @description
    #' Fetch finished tasks from the data base that finished after the last fetch.
    #' Updates the cache of the finished tasks.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #'
    #' @return `data.table()`\cr
    #' Latest results.
    fetch_new_tasks = function(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"),
      data_format = "data.table"
      ) {
      assert_character(fields)
      assert_choice(data_format, c("data.table", "list"))
      r = self$connector
      start_time = Sys.time()

      # return empty data.table or list if all results are fetched
      n_new_results = self$n_finished_tasks - private$.n_seen_results
      if (!n_new_results) {
        data = if (data_format == "list") list() else data.table()
        return(data)
      }

      # increase seen results counter
      private$.n_seen_results = private$.n_seen_results + n_new_results

      # fetch finished tasks
      data = self$fetch_finished_tasks(fields, data_format = "list")
      data = tail(data, n_new_results)
      if (data_format == "list") return(data)
      # it is much faster to only convert the new results to data.table instead of doing it in fetch_finished_tasks
      tab = rbindlist(data, use.names = TRUE, fill = TRUE)
      tab[, keys := names(data)]
      tab[]
    },

    #' @description
    #' Block process until a new finished task is available.
    #' Returns new tasks or `NULL` if no new task is available after `timeout` seconds.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra")`.
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for new result in seconds.
    #'
    #' @return `data.table() | list()`.
    wait_for_new_tasks = function(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"),
      timeout = Inf,
      data_format = "data.table"
      ) {
      assert_number(timeout, lower = 0)
      start_time = Sys.time()

      lg$debug("Wait for new tasks for at least %s seconds", as.character(timeout))

      while(start_time + timeout > Sys.time()) {
        n_new_results = self$n_finished_tasks - private$.n_seen_results
        if (n_new_results) {
          return(self$fetch_new_tasks(fields, data_format = data_format))
        }
        Sys.sleep(0.01)
      }
      if (data_format == "list") return(NULL)
      data.table()
    },

    #' @description
    #' Fetch failed tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "condition"`.
    #'
    #' @return `data.table()`\cr
    #' Table of failed tasks.
    fetch_failed_tasks = function(fields = c("xs", "worker_extra", "condition"), data_format = "data.table") {
      keys = self$failed_tasks
      private$.fetch_tasks(keys, fields, data_format)
    },

    #' @description
    #' Fetch all tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "condition", "state")`.
    #'
    #' @return `data.table()`\cr
    #' Table of all tasks.
    fetch_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_extra",  "ys_extra", "condition"), data_format = "data.table") {
      keys = self$tasks
      private$.fetch_tasks(keys, fields, data_format)
    },

    #' @description
    #' Fetch tasks with different states from the data base.
    #' If tasks with different states are to be queried at the same time, this function prevents tasks from appearing twice.
    #' This could be the case if a worker changes the state of a task while the tasks are being fetched.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "ys", "xs_extra", "worker_extra", "ys_extra")`.
    #' @param states (`character()`)\cr
    #' States of the tasks to be fetched.
    #' Defaults to `c("queued", "running", "finished", "failed")`.
    #' @param reset_cache (`logical(1)`)\cr
    #' Whether to reset the cache of the finished tasks.
    fetch_tasks_with_state = function(
      fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra", "condition"),
      states = c("queued", "running", "finished", "failed"),
      reset_cache = FALSE,
      data_format = "data.table"
      ) {
      r = self$connector
      assert_subset(states, c("queued", "running", "finished", "failed"), empty.ok = FALSE)

      all_keys = private$.tasks_with_state(states, only_new_keys = TRUE)

      data = imap(all_keys, function(keys, state) {
        if (state == "finished") {
          private$.fetch_cached_tasks(keys, fields, reset_cache, data_format)
        } else {
          private$.fetch_tasks(keys, fields, data_format)
        }
      })

      if (data_format == "list") return(data)
      data = rbindlist(data, use.names = TRUE, fill = TRUE, idcol = "state")
      data[]
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

      lg$debug("Writting %i hash(es) with %i field(s)", length(keys), length(fields))

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

      self$connector$pipeline(.commands = cmds)

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
      hashes = self$connector$pipeline(.commands = cmds)

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

      setNames(map(self$connector$HMGET(key, fields), safe_bin_to_object), fields)
    },

    #' @description
    #' Checks whether tasks have the status `"running"`.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks.
    is_running_task = function(keys) {
      r = self$connector
      if (!length(keys)) return(logical(0))
      as.logical(r$command(c("SMISMEMBER", private$.get_key("running_tasks"), keys)))
    },

    #' @description
    #' Checks whether tasks have the status `"failed"`.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks.
    is_failed_task = function(keys) {
      r = self$connector
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
      r = self$connector
      assert_subset(states, c("queued", "running", "finished", "failed"))
      private$.tasks_with_state(states)
    }
  ),

  active = list(

    #' @field n_workers (`integer(1)`)\cr
    #' Number of workers.
    n_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("worker_ids"))) %??% 0
    },

    #' @field n_running_workers (`integer(1)`)\cr
    #' Number of running workers.
    n_running_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("running_worker_ids"))) %??% 0
    },

    #' @field n_terminated_workers (`integer(1)`)\cr
    #' Number of terminated workers.
    n_terminated_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("terminated_worker_ids"))) %??% 0
    },

    #' @field n_killed_workers (`integer(1)`)\cr
    #' Number of killed workers.
    n_killed_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("killed_worker_ids"))) %??% 0
    },

    #' @field n_lost_workers (`integer(1)`)\cr
    #' Number of lost workers.
    #' Run `$detect_lost_workers()` to update the number of lost workers.
    n_lost_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("lost_worker_ids"))) %??% 0
    },

    #' @field n_pre_workers (`integer(1)`)\cr
    #' Number of workers that are not yet completely started.
    n_pre_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("pre_worker_ids"))) %??% 0
    },

    #' @field worker_ids (`character()`)\cr
    #' Ids of workers.
    worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("worker_ids")))
    },

    #' @field running_worker_ids (`character()`)\cr
    #' Ids of running workers.
    running_worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("running_worker_ids")))
    },

    #' @field terminated_worker_ids (`character()`)\cr
    #' Ids of terminated workers.
    terminated_worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("terminated_worker_ids")))
    },

    #' @field killed_worker_ids (`character()`)\cr
    #' Ids of killed workers.
    killed_worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("killed_worker_ids")))
    },

    #' @field lost_worker_ids (`character()`)\cr
    #' Ids of lost workers.
    lost_worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("lost_worker_ids")))
    },

    #' @field pre_worker_ids (`character()`)\cr
    #' Ids of workers that are not yet completely started.
    pre_worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("pre_worker_ids")))
    },

    #' @field tasks (`character()`)\cr
    #' Keys of all tasks.
    tasks = function() {
      r = self$connector
      unlist(r$LRANGE(private$.get_key("all_tasks"), 0, -1))
    },

    #' @field queued_tasks (`character()`)\cr
    #' Keys of queued tasks.
    queued_tasks = function() {
      r = self$connector
      unlist(r$LRANGE(private$.get_key("queued_tasks"), 0, -1))
    },

    #' @field running_tasks (`character()`)\cr
    #' Keys of running tasks.
    running_tasks = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("running_tasks")))
    },

    #' @field finished_tasks (`character()`)\cr
    #' Keys of finished tasks.
    finished_tasks = function() {
      r = self$connector
      unlist(r$LRANGE(private$.get_key("finished_tasks"), 0, -1))
    },

    #' @field failed_tasks (`character()`)\cr
    #' Keys of failed tasks.
    failed_tasks = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("failed_tasks")))
    },

    #' @field n_queued_tasks (`integer(1)`)\cr
    #' Number of queued tasks.
    n_queued_tasks = function() {
      r = self$connector
      as.integer(r$LLEN(private$.get_key("queued_tasks"))) %??% 0
    },

    #' @field n_queued_priority_tasks (`integer(1)`)\cr
    #' Number of queued priority tasks.
    n_queued_priority_tasks = function() {
      r = self$connector
      cmds = map(self$worker_ids, function(worker_id)  c("LLEN", private$.get_worker_key("queued_tasks", worker_id)))
      sum(unlist(r$pipeline(.commands = cmds))) %??% 0
    },

    #' @field n_running_tasks (`integer(1)`)\cr
    #' Number of running tasks.
    n_running_tasks = function() {
      r = self$connector
      as.integer(r$SCARD(private$.get_key("running_tasks"))) %??% 0
    },

    #' @field n_finished_tasks (`integer(1)`)\cr
    #' Number of finished tasks.
    n_finished_tasks = function() {
      r = self$connector
      as.integer(r$LLEN(private$.get_key("finished_tasks"))) %??% 0
    },

    #' @field n_failed_tasks (`integer(1)`)\cr
    #' Number of failed tasks.
    n_failed_tasks = function() {
      r = self$connector
      as.integer(r$SCARD(private$.get_key("failed_tasks"))) %??% 0
    },

    #' @field n_tasks (`integer(1)`)\cr
    #' Number of all tasks.
    n_tasks = function() {
      r = self$connector
      as.integer(r$LLEN(private$.get_key("all_tasks"))) %??% 0
    },

    #' @field worker_info ([data.table::data.table()])\cr
    #' Contains information about the workers.
    worker_info = function(rhs) {
      assert_ro_binding(rhs)
      if (!self$n_workers) return(data.table())
      r = self$connector

      fields = c("worker_id", "pid", "remote", "hostname", "heartbeat")
      worker_info = set_names(rbindlist(map(self$worker_ids, function(worker_id) {
        r$command(c("HMGET", private$.get_key(worker_id), fields))
      })), fields)

      # fix type
      worker_info[, remote := as.logical(remote)][]
      worker_info[, heartbeat := heartbeat != "NA"][]
      worker_info[, pid := as.integer(pid)][]

      # worker states
      worker_ids = list(
        running = data.table(worker_id = self$running_worker_ids),
        terminated =  data.table(worker_id = self$terminated_worker_ids),
        killed =  data.table(worker_id = self$killed_worker_ids),
        lost =  data.table(worker_id = self$lost_worker_ids)
      )

      worker_states = rbindlist(worker_ids, idcol = "state", use.names = TRUE, fill = TRUE)

      worker_info[worker_states, , on = "worker_id"]
    },

    #' @field worker_states ([data.table::data.table()])\cr
    #' Contains the states of the workers.
    worker_states = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector

      worker_ids = list(
        running = data.table(worker_id = self$running_worker_ids),
        terminated =  data.table(worker_id = self$terminated_worker_ids),
        killed =  data.table(worker_id = self$killed_worker_ids),
        lost =  data.table(worker_id = self$lost_worker_ids)
      )

      rbindlist(worker_ids, idcol = "state", use.names = TRUE, fill = TRUE)
    },

    #' @field all_workers_terminated (`logical(1)`)\cr
    #' Whether all workers are terminated.
    all_workers_terminated = function(rhs) {
      assert_ro_binding(rhs)
      # return FALSE if no workers were started yet
      if (!self$n_workers) return(FALSE)
      self$n_workers == self$n_terminated_workers
    },

    #' @field all_workers_lost (`logical(1)`)\cr
    #' Whether all workers are lost.
    #' Runs `$detect_lost_workers()` to detect lost workers.
    all_workers_lost = function(rhs) {
      assert_ro_binding(rhs)
      # return FALSE if no workers were started yet
      if (!self$n_workers) return(FALSE)
      self$detect_lost_workers()
      self$n_workers == self$n_lost_workers
    },

    #' @field priority_info ([data.table::data.table])\cr
    #' Contains the number of tasks in the priority queues.
    priority_info = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      map_dtr(self$worker_ids, function(worker_id) {
        list(worker_id = worker_id, n_tasks =  as.integer(r$LLEN(private$.get_worker_key("queued_tasks", worker_id))))
      })
    },

    #' @field snapshot_schedule (`character()`)\cr
    #' Set a snapshot schedule to periodically save the data base on disk.
    #' For example, `c(60, 1000)` saves the data base every 60 seconds if there are at least 1000 changes.
    #' Overwrites the redis configuration file.
    #' Set to `NULL` to disable snapshots.
    #' For more details see [redis.io](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/).
    snapshot_schedule = function(rhs) {
      if (missing(rhs)) return(private$.snapshot_schedule)
      assert_integerish(rhs, min.len = 2, null.ok = TRUE)
      if (is.null(rhs)) rhs = ""
      r = self$connector
      r$command(c("CONFIG", "SET", "save", str_collapse(rhs, sep = " ")))
      private$.snapshot_schedule = rhs
    },

    #' @field redis_info (`list()`)\cr
    #' Information about the Redis server.
    redis_info = function() {
      redux::redis_info(self$connector)
    }
  ),

  private = list(

    # cache for finished tasks
    .cached_tasks = list(),

    # counter of the seen results for the latest results methods
    .n_seen_results = 0,

    .snapshot_schedule = NULL,

    .seed = NULL,

    # counter for printed logs
    # zero based
    .log_counter = list(),

    # prefix key with instance id
    .get_key = function(key) {
      sprintf("%s:%s", self$network_id, key)
    },

    # prefix key with instance id and worker id
    .get_worker_key = function(key, worker_id = NULL) {
      worker_id = worker_id %??% self$worker_id
      sprintf("%s:%s:%s", self$network_id, worker_id, key)
    },

    # push worker config to redis
    .push_worker_config = function(
      worker_loop = NULL,
      ...,
      globals = NULL,
      packages = NULL
      ) {
      assert_function(worker_loop)
      dots = list(...)
      assert_character(globals, null.ok = TRUE)
      assert_character(packages, null.ok = TRUE)

      r = self$connector

      lg$debug("Pushing worker config to Redis")

      # find globals
      if (!is.null(globals)) {
        global_names = if (!is.null(names(globals))) names(globals) else globals
        globals = set_names(map(globals, function(global) {
          value = get(global, envir = parent.frame(), inherits = TRUE)
          if (is.null(value)) stopf("Global `%s` not found", global)
          value
        }), global_names)
      }

      # arguments needed for initializing the worker
      start_args = list(
        worker_loop = worker_loop,
        worker_loop_args = dots,
        globals = globals,
        packages = c("rush", packages))

      # serialize and push arguments to redis
      # the serialize functions warns that a required package may not be available when loading the start args
      # we ensure that the package is available
      bin_start_args = suppressWarnings(redux::object_to_bin(start_args))

      if (object.size(bin_start_args) > 5369e5) {
        if (is.null(rush_env$large_objects_path)) {
          stop("Worker configuration is larger than 512 MiB. Redis does not support values larger than 512 MiB. Set a path for large objects to store on disk.")
        } else {
          lg$debug("Worker configuration is larger than 512 MiB. Writing to disk.")
          bin_start_args = redux::object_to_bin(store_large_object(start_args, path = rush_env$large_objects_path))
        }
      }

      lg$debug("Serializing worker configuration to %s", format(object.size(bin_start_args)))

      r$command(list("SET", private$.get_key("start_args"), bin_start_args))
    },

    # get task keys
    # finished tasks keys can be restricted to uncached tasks
    .tasks_with_state = function(states, only_new_keys = FALSE) {
      r = self$connector

      # optionally limit finished tasks to uncached tasks
      start_finished_tasks = if (only_new_keys) length(private$.cached_tasks) else 0

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
    .fetch_tasks = function(keys, fields, data_format = "data.table") {
      r = self$connector
      assert_character(fields)
      assert_choice(data_format, c("data.table", "list"))

      if (!length(keys)) {
        data = if (data_format == "list") list() else data.table()
        return(data)
      }

      data = self$read_hashes(keys, fields)

      lg$debug("Fetching %i task(s)", length(data))

      if (data_format == "list") return(set_names(data, keys))
      tab = rbindlist(data, use.names = TRUE, fill = TRUE)
      tab[, keys := unlist(keys)]
      tab[]
    },

    # fetch and cache tasks
    .fetch_cached_tasks = function(new_keys, fields, reset_cache = FALSE, data_format = "data.table") {
      r = self$connector
      assert_flag(reset_cache)
      assert_choice(data_format, c("data.table", "list"))

      if (reset_cache) private$.cached_tasks = list()

      lg$debug("Reading %i cached task(s)", length(private$.cached_tasks))

      if (length(new_keys)) {

        lg$debug("Caching %i new task(s)", length(new_keys))

        # bind new results to cached results
        data = set_names(self$read_hashes(new_keys, fields), new_keys)
        private$.cached_tasks = c(private$.cached_tasks, data)
      }

      lg$debug("Fetching %i task(s)", length(private$.cached_tasks))

      if (data_format == "list") return(private$.cached_tasks)
      tab = rbindlist(private$.cached_tasks, use.names = TRUE, fill = TRUE)
      if (nrow(tab)) tab[, keys := names(private$.cached_tasks)]
      tab[]
    }
  )
)
