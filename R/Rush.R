#' @title Rush Controller
#'
#' @description
#' [Rush] is the controller in a centralized rush network.
#' The controller starts and stops the workers, pushes tasks to the workers and fetches results.
#'
#' @section Local Workers:
#' A local worker runs on the same machine as the controller.
#' Local workers are spawned with the `$start_local_workers() method via the `processx` package.
#'
#' @section Remote Workers:
#' A remote worker runs on a different machine than the controller.
#' Remote workers are started manually with the `$create_worker_script()` and `$start_remote_workers()` methods.
#' Remote workers can be started on any system as long as the system has access to Redis and all required packages are installed.
#' Only a heartbeat process can kill remote workers.
#' The heartbeat process also monitors the remote workers for crashes.
#'
#' @section Stopping Workers:
#' Local and remote workers can be terminated with the `$stop_workers(type = "terminate")` method.
#' The workers evaluate the currently running task and then terminate.
#' The option `type = "kill"` stops the workers immediately.
#' Killing a local worker is done with the `processx` package.
#' Remote workers are killed by pushing a kill signal to the heartbeat process.
#' Without a heartbeat process a remote worker cannot be killed (see section heartbeat).
#'
#' @section Heartbeat:
#' The heartbeat process periodically signals that a worker is still alive.
#' This is implemented by setting a [timeout](https://redis.io/docs/latest/commands/expire/) on the heartbeat key.
#' Furthermore, the heartbeat process can kill the worker.
#'
#' @section Data Structure:
#' Tasks are stored in Redis [hashes](https://redis.io/docs/latest/develop/data-types/hashes/).
#' Hashes are collections of field-value pairs.
#' The key of the hash identifies the task in Redis and `rush`.
#'
#' ```
#' key : xs | ys | xs_extra
#' ```
#'
#' The field-value pairs are written by different methods, e.g. `$push_tasks()` writes `xs` and `$push_results()` writes `ys`.
#' The values of the fields are serialized lists or atomic values e.g. unserializing `xs` gives `list(x1 = 1, x2 = 2)`
#' This data structure allows quick converting of a hash into a row and joining multiple hashes into a table.
#'
#' ```
#' | key | x1 | x2 | y | timestamp |
#' | 1.. |  3 |  4 | 7 |  12:04:11 |
#' | 2.. |  1 |  4 | 5 |  12:04:12 |
#' | 3.. |  1 |  1 | 2 |  12:04:13 |
#' ```
#' When the value of a field is a named list, the field can store the cells of multiple columns of the table.
#' When the value of a field is an atomic value, the field stores a single cell of a column named after the field.
#' The methods `$push_tasks()` and `$push_results()` write into multiple hashes.
#' For example, `$push_tasks(xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))` writes `xs` in two hashes.
#'
#' @section Task States:
#' A task can go through four states `"queued"`, `"running"`, `"finished"` or `"failed"`.
#' Internally, the keys of the tasks are pushed through Redis [lists](https://redis.io/docs/latest/develop/data-types/lists/) and [sets](https://redis.io/docs/latest/develop/data-types/sets/) to keep track of their state.
#' Queued tasks are waiting to be evaluated.
#' A worker pops a task from the queue and changes the state to `"running"` while evaluating the task.
#' When the task is finished, the state is changed to `"finished" and the result is written to the data base.
#' If the task fails, the state is changed to `"failed"` instead of `"finished"`.
#'
#' @section Queues:
#' Rush uses a shared queue and a queue for each worker.
#' The shared queue is used to push tasks to the workers.
#' The first worker that pops a task from the shared queue evaluates the task.
#' The worker queues are used to push tasks to specific workers.
#'
#' @section Fetch Tasks and Results:
#' The `$fetch_*()` methods retrieve data from the Redis database.
#' A matching method is defined for each task state e.g. `$fetch_running_tasks()` and `$fetch_finished_tasks()`.
#' The methods `$fetch_new_tasks()` and `$fetch_finished_tasks()` cache the already queried data.
#' The `$wait_for_finished_tasks()` variant wait until a new result is available.
#'
#' @section Error Handling:
#' When evaluating tasks in a distributed system, many things can go wrong.
#' Simple R errors in the worker loop are caught and written to the archive.
#' The task is marked as `"failed"`.
#' If the connection to a worker is lost, it looks like a task is `"running"` forever.
#' The method `$detect_lost_workers()` identifies lost workers.
#' Running this method periodically adds a small overhead.
#'
#' @section Logging:
#' The worker logs all messages written with the `lgr` package to the data base.
#' The `lgr_thresholds` argument defines the logging level for each logger e.g. `c(rush = "debug")`.
#' Saving log messages adds a small overhead but is useful for debugging.
#' By default, no log messages are stored.
#'
#' @section Seed:
#' Setting a seed is important for reproducibility.
#' The tasks can be evaluated with a specific L'Ecuyer-CMRG seed.
#' If an initial seed is passed, the seed is used to generate L'Ecuyer-CMRG seeds for each task.
#' Each task is then evaluated with a separate RNG stream.
#' See [parallel::nextRNGStream] for more details.
#'
#' @template param_network_id
#' @template param_config
#' @template param_worker_loop
#' @template param_globals
#' @template param_packages
#' @template param_remote
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
#' @template param_seed
#' @template param_data_format
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

    #' @field processes ([processx::process])\cr
    #' List of processes started with `$start_local_workers()`.
    processes = NULL,

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
    #' The [processx::process] are stored in `$processes`.
    #' Alternatively, use `$create_worker_script()` to create a script for starting workers on remote machines.
    #' By default, [worker_loop_default()] is used as worker loop.
    #' This function takes the arguments `fun` and optionally `constants` which are passed in `...`.
    #'
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
    #' @param supervise (`logical(1)`)\cr
    #' Whether to kill the workers when the main R process is shut down.
    #' @param wait_for_workers (`logical(1)`)\cr
    #' Whether to wait until all workers are available.
    #' @param timeout (`numeric(1)`)\cr
    #' Timeout to wait for workers in seconds.
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    start_local_workers = function(
      n_workers = NULL,
      wait_for_workers = TRUE,
      timeout = Inf,
      globals = NULL,
      packages = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = 0,
      supervise = TRUE,
      worker_loop = worker_loop_default,
      ...
      ) {
      n_workers = assert_count(n_workers %??% rush_env$n_workers)
      assert_flag(wait_for_workers)
      assert_flag(supervise)
      r = self$connector

      # push worker config to redis
      private$.push_worker_config(
        globals = globals,
        packages = packages,
        heartbeat_period = heartbeat_period,
        heartbeat_expire = heartbeat_expire,
        lgr_thresholds = lgr_thresholds,
        lgr_buffer_size = lgr_buffer_size,
        worker_loop = worker_loop,
        ...
      )

      lg$info("Starting %i worker(s)", n_workers)

      # redis config to string
      config = discard(self$config, is.null)
      config = paste(imap(config, function(value, name) sprintf("%s = '%s'", name, value)), collapse = ", ")

      worker_ids = uuid::UUIDgenerate(n = n_workers)
      self$processes = c(self$processes, set_names(map(worker_ids, function(worker_id) {
       processx::process$new("Rscript",
        args = c("-e", sprintf("rush::start_worker(network_id = '%s', worker_id = '%s', remote = FALSE, %s)",
          self$network_id, worker_id, config)),
        supervise = supervise, stderr = "|") # , stdout = "|"
      }), worker_ids))

      if (wait_for_workers) self$wait_for_workers(n_workers, timeout)

      return(invisible(worker_ids))
    },

    #' @description
    #' Restart local workers.
    #' If the worker is is still running, it is killed and restarted.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be restarted.
    #' @param supervise (`logical(1)`)\cr
    #' Whether to kill the workers when the main R process is shut down.
    restart_local_workers = function(worker_ids, supervise = TRUE) {
      assert_subset(unlist(worker_ids), self$worker_ids)
      r = self$connector

      # check for remote workers
      worker_info = self$worker_info[list(worker_ids), ,  on = "worker_id"]
      if (any(worker_info$remote)) {
        stopf("Can't restart remote workers %s", as_short_string(worker_ids))
      }

      # stop running workers
      if (worker_ids %in% self$running_worker_ids) {
        self$stop_workers(type = "kill", worker_ids[worker_ids %in% self$running_worker_ids])
      }

      lg$info("Restarting %i worker(s): %s", length(worker_ids), str_collapse(worker_ids))

      # redis config to string
      config = discard(self$config, is.null)
      config = paste(imap(config, function(value, name) sprintf("%s = '%s'", name, value)), collapse = ", ")

      processes = set_names(map(worker_ids, function(worker_id) {
        # restart worker
        processx::process$new("Rscript",
        args = c("-e", sprintf("rush::start_worker(network_id = '%s', worker_id = '%s', remote = FALSE, %s)",
          self$network_id, worker_id, config)),
          supervise = supervise, stderr = "|") # , stdout = "|"
      }), worker_ids)
      self$processes = insert_named(self$processes, processes)

      return(invisible(worker_ids))
    },

    #' @description
    #' Create script to remote start workers.
    #' Run these command to pre-start a worker.
    #' The worker will wait until the start arguments are pushed with `$start_remote_workers()`.
    create_worker_script = function() {

      # redis config to string
      config = discard(self$config, is.null)
      config = paste(imap(config, function(value, name) sprintf('%s = "%s"', name, value)), collapse = ", ")

      script = sprintf('Rscript -e "rush::start_worker(network_id = "%s", remote = TRUE, %s)"', self$network_id, config)

      lg$info("Start worker with:")
      lg$info(script)
      lg$info("See ?rush::start_worker for more details.")

      return(invisible(script))
    },

    #' @description
    #' Push start arguments to remote workers.
    #' Remote workers must be pre-started with `$create_worker_script()`.
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    start_remote_workers = function(
      globals = NULL,
      packages = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = 0,
      worker_loop = worker_loop_default,
      ...
      ) {

      # push worker config to redis
      private$.push_worker_config(
        globals = globals,
        packages = packages,
        heartbeat_period = heartbeat_period,
        heartbeat_expire = heartbeat_expire,
        lgr_thresholds = lgr_thresholds,
        lgr_buffer_size = lgr_buffer_size,
        worker_loop = worker_loop,
        ...
      )

      return(invisible(self))
    },

    #' @description
    #' Wait until `n` workers are available.
    #'
    #' @param n (`integer(1)`)\cr
    #' Number of workers to wait for.
    #' @param timeout (`numeric(1)`)\cr
    #' Timeout in seconds.
    #' Default is `Inf`.
    wait_for_workers = function(n, timeout = Inf) {
      assert_count(n)
      assert_number(timeout)
      timeout = if (is.finite(timeout)) timeout else rush_config()$start_worker_timeout %??% Inf

      start_time = Sys.time()
      while(self$n_workers < n) {
        Sys.sleep(0.01)
        if (difftime(Sys.time(), start_time, units = "secs") > timeout) {
          stopf("Timeout waiting for %i worker(s)", n)
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Stop workers.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be stopped.
    #' If `NULL` all workers are stopped.
    #' @param type (`character(1)`)\cr
    #' Type of stopping.
    #' Either `"terminate"` or `"kill"`.
    #' If `"terminate"` the workers evaluate the currently running task and then terminate.
    #' If `"kill"` the workers are stopped immediately.
    stop_workers = function(type = "terminate", worker_ids = NULL) {
      assert_choice(type, c("terminate", "kill"))
      worker_ids = assert_subset(worker_ids, self$running_worker_ids) %??% self$running_worker_ids
      if (is.null(worker_ids)) return(invisible(self))
      r = self$connector

      if (type == "terminate") {

        lg$debug("Terminating %i worker(s) %s", length(worker_ids), as_short_string(worker_ids))

        # Push terminate signal to worker
        cmds = map(worker_ids, function(worker_id) {
          c("SET", private$.get_worker_key("terminate", worker_id), "1")
        })
        r$pipeline(.commands = cmds)

      } else if (type == "kill") {
        worker_info = self$worker_info[list(worker_ids), ,  on = "worker_id"]
        # kill local
        local_workers = worker_info[list(FALSE), worker_id, on = "remote", nomatch = NULL]
        lg$debug("Killing %i local worker(s) %s", length(local_workers), as_short_string(local_workers))

        # kill with processx
        walk(local_workers, function(worker_id) {
          killed = self$processes[[worker_id]]$kill()
          if (!killed) lg$error("Failed to kill worker %s", worker_id)
        })

        # set worker state
        cmds_local = map(local_workers, function(worker_id) {
           c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("killed_worker_ids"), worker_id)
        })

        # kill remote
        remote_workers = worker_info [list(TRUE), worker_id, on = "remote", nomatch = NULL]
        lg$debug("Killing %i remote worker(s) %s", length(remote_workers), as_short_string(remote_workers))

        # push kill signal to heartbeat process and set worker state
        cmds_remote = unlist(map(remote_workers, function(worker_id) {
          list(
            c("LPUSH", private$.get_worker_key("kill", worker_id), "TRUE"),
            c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("killed_worker_ids"), worker_id))
        }), recursive = FALSE)

        r$pipeline(.commands = c(cmds_local, cmds_remote))
      }

      return(invisible(self))
    },

    #' @description
    #' Detect lost workers.
    #' The state of the worker is changed to `"lost"`.
    #' Local workers without a heartbeat are checked by their process id.
    #' Checking local workers on unix systems only takes a few microseconds per worker.
    #' But checking local workers on windows might be very slow.
    #' Workers with a heartbeat process are checked with the heartbeat.
    #' Lost tasks are marked as `"lost"`.
    #'
    #' @param restart_local_workers (`logical(1)`)\cr
    #' Whether to restart lost workers.
    detect_lost_workers = function(restart_local_workers = FALSE) {
      assert_flag(restart_local_workers)
      r = self$connector

      # check workers with a heartbeat
      heartbeat_keys = r$SMEMBERS(private$.get_key("heartbeat_keys"))
      lost_workers_heartbeat = if (length(heartbeat_keys)) {
        lg$debug("Checking %i worker(s) with heartbeat", length(heartbeat_keys))
        running = as.logical(r$pipeline(.commands = map(heartbeat_keys, function(heartbeat_key) c("EXISTS", heartbeat_key))))
        if (all(running)) return(invisible(self))

        # search for associated worker ids
        heartbeat_keys = heartbeat_keys[!running]
        lost_workers = self$worker_info[heartbeat == heartbeat_keys, worker_id]

        # set worker state
        cmds = map(lost_workers, function(worker_id) {
          c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("lost_worker_ids"), worker_id)
        })

        # remove heartbeat keys
        cmds = c(cmds, list(c("SREM", "heartbeat_keys", heartbeat_keys)))
        r$pipeline(.commands =  cmds)
        lost_workers
      }

      # check local workers without a heartbeat
      local_workers = r$SMEMBERS(private$.get_key("local_workers"))
      lost_workers_local = if (length(local_workers) && !is.null(self$processes)) {
        # lg$debug("Checking %i worker(s) with process id", length(local_workers))
        running = map_lgl(local_workers, function(worker_id) self$processes[[worker_id]]$is_alive())
        if (all(running)) return(invisible(self))

        # search for associated worker ids
        lost_workers = local_workers[!running]
        lg$error("Lost %i worker(s): %s", length(lost_workers), str_collapse(lost_workers))
        walk(lost_workers, function(worker_id) {
          x = self$processes[[worker_id]]$read_all_error_lines()
          walk(x, lg$error)
        })

        if (restart_local_workers) {
          self$restart_local_workers(unlist(lost_workers))
          lost_workers
        } else {
          # set worker state
          cmds = map(lost_workers, function(worker_id) {
           c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("lost_worker_ids"), worker_id)
          })

          # remove local pids
          cmds = c(cmds, list(c("SREM", private$.get_key("local_workers"), lost_workers)))
          r$pipeline(.commands =  cmds)
          lost_workers
        }
      }

      # mark lost tasks
      lost_workers = c(lost_workers_heartbeat, lost_workers_local)
      if (length(lost_workers)) {
        running_tasks = self$fetch_running_tasks(fields = "worker_extra")
        if (!nrow(running_tasks)) return(invisible(self))
        lost_workers = unlist(lost_workers)
        keys = running_tasks[list(lost_workers), keys, on = "worker_id"]

        lg$error("Lost %i task(s): %s", length(keys), str_collapse(keys))

        conditions = list(list(message = "Worker has crashed or was killed"))
        self$push_failed(keys, conditions = conditions)
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
      self$processes = NULL

      # remove worker info, heartbeat, terminate and kill
      walk(self$worker_ids, function(worker_id) {
        r$DEL(private$.get_key(worker_id))
        r$DEL(private$.get_worker_key("terminate", worker_id))
        r$DEL(private$.get_worker_key("kill", worker_id))
        r$DEL(private$.get_worker_key("heartbeat", worker_id))
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
    read_log = function(worker_ids = NULL) {
      worker_ids = worker_ids %??% self$worker_ids
      r = self$connector
      cmds =  map(worker_ids, function(worker_id) c("LRANGE", private$.get_worker_key("events", worker_id), 0, -1))
      worker_logs = set_names(r$pipeline(.commands = cmds), worker_ids)
      tab = rbindlist(set_names(map(worker_logs, function(logs) {
        rbindlist(map(logs, fromJSON))
      }), worker_ids), idcol = "worker_id")
      if (nrow(tab)) setkeyv(tab, "timestamp")
      tab[]
    },

    #' @description
    #' Print log messages written with the `lgr` package from a worker.
    print_log = function() {
      r = self$connector

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

      # move key from running to failed
      r$pipeline(.commands = map(keys, function(key) {
        c("SMOVE", private$.get_key("running_tasks"), private$.get_key("failed_tasks"), key)
      }))

      return(invisible(self))
    },

    #' @description
    #' Retry failed tasks.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to be retried.
    #' @param ignore_max_retries (`logical(1)`)\cr
    #' Whether to ignore the maximum number of retries.
    #' @param next_seed (`logical(1)`)\cr
    #' Whether to change the seed of the task.
    retry_tasks = function(keys, ignore_max_retries = FALSE, next_seed = FALSE) {
      assert_character(keys)
      assert_flag(ignore_max_retries)
      assert_flag(next_seed)
      tasks = self$read_hashes(keys, fields = c("seed", "max_retries", "n_retries"), flatten = FALSE)
      seeds = map(tasks, "seed")
      n_retries = map_int(tasks, function(task) task$n_retries  %??% 0L)
      max_retries = map_dbl(tasks, function(task) task$max_retries  %??% Inf)
      failed = self$is_failed_task(keys)
      retrieable = n_retries < max_retries

      if (!all(failed)) lg$error("Not all task(s) failed: %s", str_collapse(keys[!failed]))

      if (ignore_max_retries) {
        keys = keys[failed]
      } else {
        if (!all(retrieable)) lg$error("Task(s) reached the maximum number of retries: %s", str_collapse(keys[!retrieable]))
        keys = keys[failed & retrieable]
      }

      if (length(keys)) {

        lg$debug("Retry %i task(s): %s", length(keys), str_collapse(keys))

        # generate new L'Ecuyer-CMRG seeds
        seeds = if (next_seed) map(seeds, function(seed) parallel::nextRNGSubStream(seed))

        self$write_hashes(n_retries = n_retries + 1L, seed = seeds, keys = keys)
        r = self$connector
        r$pipeline(.commands = list(
          c("SREM", private$.get_key("failed_tasks"), keys),
          c("RPUSH", private$.get_key("queued_tasks"), keys)
        ))
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
      data = self$fetch_finished_tasks(fields, data_format = data_format)
      tail(data, n_new_results)
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
      worker_info[, pid := as.integer(pid)][]

      worker_info
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
      self$n_workers == self$n_terminated_workers
    },

    #' @field all_workers_lost (`logical(1)`)\cr
    #' Whether all workers are lost.
    #' Runs `$detect_lost_workers()` to detect lost workers.
    all_workers_lost = function(rhs) {
      assert_ro_binding(rhs)
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
      globals = NULL,
      packages = NULL,
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      lgr_thresholds = NULL,
      lgr_buffer_size = 0,
      worker_loop = worker_loop_default,
      ...
    ) {
      assert_character(globals, null.ok = TRUE)
      assert_character(packages, null.ok = TRUE)
      assert_count(heartbeat_period, positive = TRUE, null.ok = TRUE)
      assert_count(heartbeat_expire, positive = TRUE, null.ok = TRUE)
      if (!is.null(heartbeat_period)) require_namespaces("callr")
      lgr_thresholds = assert_vector(lgr_thresholds, names = "named", null.ok = TRUE) %??% rush_env$lgr_thresholds
      assert_count(lgr_buffer_size)
      assert_function(worker_loop)
      dots = list(...)
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

      # arguments needed for initializing RushWorker
      worker_args = list(
        heartbeat_period = heartbeat_period,
        heartbeat_expire = heartbeat_expire,
        lgr_thresholds = lgr_thresholds,
        lgr_buffer_size = lgr_buffer_size)

      # arguments needed for initializing the worker
      start_args = list(
        worker_loop = worker_loop,
        worker_loop_args = dots,
        globals = globals,
        packages = c("rush", packages),
        worker_args = worker_args)

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
