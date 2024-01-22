#' @title Rush Controller
#'
#' @description
#' [Rush] is the controller in a centralized rush network.
#' The controller starts and stops the workers, pushes tasks to the workers and fetches results.
#'
#' @section Local Workers:
#' A local worker runs on the same machine as the controller.
#' Local workers are are spawned with the `$start_workers() method via the `processx` package.
#'
#' @section Remote Workers:
#' A remote worker runs on a different machine than the controller.
#' Remote workers are started manually with the `$create_worker_script()` method.
#' Remote workers can be started on any system as long as the system has access to Redis and all required packages are installed.
#' Only a heartbeat process can kill remote workers.
#' The heartbeat process also monitors the remote workers for crashes.
#'
#' @section Stopping Workers:
#' Local and remote workers can be terminated with the `$stop_workers(type = "terminate")` method.
#' The workers evaluate the currently running task and then terminate.
#' The option `type = "kill"` stops the workers immediately.
#' Killing a local worker is done with the `tools::pskill()` function.
#' Remote workers are killed by pushing a kill signal to the heartbeat process.
#' Without a heartbeat process a remote worker cannot be killed (see section heartbeat).
#'
#' @section Heartbeat:
#' The heartbeat process periodically signals that a worker is still alive.
#' This is implemented by setting a [timeout](https://redis.io/commands/expire/) on the heartbeat key.
#' Furthermore, the heartbeat process can kill the worker.
#'
#' @section Data Structure:
#' Rush writes a task and its result and additional meta information into a Redis [hash](https://redis.io/docs/data-types/hashes/).
#'
#' ```
#' key : xs | ys | extra | state
#' ```
#'
#' The key of the hash identifies the task in Rush.
#' The fields are written by different methods, e.g. `$push_result()` writes `ys` when the result is available.
#' The value of a field is a serialized list e.g. unserializing `xs` gives `list(x1 = 1, x2 = 2)`.
#' This data structure allows to quickly convert a hash into a row and to join multiple hashes into a table.
#' For example, three hashes from the above example are converted to the following table.
#'
#' ```
#' | key | x1 | x2 | y | timestamp | state   |
#' | 1.. |  3 |  4 | 7 |  12:04:11 | finished |
#' | 2.. |  1 |  4 | 5 |  12:04:12 | finished |
#' | 3.. |  1 |  1 | 2 |  12:04:13 | finished |
#' ```
#' Notice that a value of a field can store multiple columns of the table.
#'
#' The methods `$push_tasks()` and `$push_results()` write into multiple hashes.
#' For example, `$push_tasks(xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))` writes `xs` in two hashes.
#'
#' @section Task States:
#' A task can go through four states `"queued"`, `"running"`, `"finished"` or `"failed"`.
#' Internally, the keys of the tasks are pushed through Redis [lists](https://redis.io/docs/data-types/lists/) and [sets](https://redis.io/docs/data-types/sets/) to keep track of their state.
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
#' If only the result of the function evaluation is needed, `$fetch_results()` and `$fetch_latest_results()` are faster.
#' The methods `$fetch_results()` and `$fetch_finished_tasks()` cache the already queried data.
#' The `$block_*()` variants wait until a new result is available.
#'
#' @section Error Handling:
#' When evaluating tasks in a distributed system, many things can go wrong.
#' Simple R errors in the worker loop are caught and written to the archive.
#' The task is marked as `"failed"`.
#' If the connection to a worker is lost, it looks like a task is `"running"` forever.
#' The methods `$detect_lost_workers()` and `$detect_lost_tasks()` detect lost workers.
#' Running these methods periodically adds a small overhead.
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
#' @template param_host
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_lgr_thresholds
#' @template param_lgr_buffer_size
#' @template param_seed
#' @template param_data_format
#'
#'
#' @export
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
    #' List of processes started with `$start_workers()`.
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
      private$.hostname = get_hostname()

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
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    start_workers = function(
      n_workers = NULL,
      wait_for_workers = TRUE,
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

      worker_ids = uuid::UUIDgenerate(n = n_workers)
      self$processes = c(self$processes, set_names(map(worker_ids, function(worker_id) {
       processx::process$new("Rscript",
        args = c("-e", sprintf("rush::start_worker(network_id = '%s', worker_id = '%s', hostname = '%s', url = '%s')",
          self$network_id, worker_id, private$.hostname, self$config$url)),
        supervise = supervise, stdout = "|", stderr = "|") # , stdout = "|", stderr = "|"
      }), worker_ids))

      if (wait_for_workers) self$wait_for_workers(n_workers)

      return(invisible(worker_ids))
    },

    #' @description
    #' Restart workers.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be restarted.
    restart_workers = function(worker_ids) {
      assert_subset(unlist(worker_ids), self$worker_ids)
      r = self$connector

      lg$error("Restarting %i worker(s): %s", length(worker_ids), str_collapse(worker_ids))
      processes = set_names(map(worker_ids, function(worker_id) {
        # restart worker
        processx::process$new("Rscript",
          args = c("-e", sprintf("rush::start_worker(network_id = '%s', worker_id = '%s', hostname = '%s', url = '%s')",
            self$network_id, worker_id, private$.hostname, self$config$url)))
      }), worker_ids)
      self$processes = insert_named(self$processes, processes)

      return(invisible(worker_ids))
    },

    #' @description
    #' Create script to start workers.
    #' The worker is started with [start_worker()].
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    create_worker_script = function(
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

      lg$info("Start worker with:")
      lg$info("Rscript -e 'rush::start_worker(network_id = '%s', hostname = '%s', url = '%s')'",
        self$network_id, private$.hostname, self$config$url)
      lg$info("See ?rush::start_worker for more details.")

      return(invisible(self))
    },

    #' @description
    #' Wait until `n` workers are available.
    #'
    #' @param n (`integer(1)`)\cr
    #' Number of workers to wait for.
    wait_for_workers = function(n) {
      assert_count(n)
      while(self$n_workers < n) Sys.sleep(0.01)

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
        local_workers = worker_info[list("local"), worker_id, on = c("host"), nomatch = NULL]
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
        remote_workers = worker_info [list("remote"), worker_id, on = c("host"), nomatch = NULL]
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
    #' @param restart_workers (`logical(1)`)\cr
    #' Whether to restart lost workers.
    #' @param restart_tasks (`logical(1)`)\cr
    #' Whether to restart lost tasks.
    detect_lost_workers = function(restart_workers = FALSE, restart_tasks = FALSE) {
      assert_flag(restart_workers)
      assert_flag(restart_tasks)
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
      lost_workers_local = if (length(local_workers)) {
        lg$debug("Checking %i worker(s) with process id", length(local_workers))
        running = map_lgl(local_workers, function(worker_id) self$processes[[worker_id]]$is_alive())
        if (all(running)) return(invisible(self))

        # search for associated worker ids
        lost_workers = local_workers[!running]
        lg$error("Lost %i worker(s): %s", length(lost_workers), str_collapse(lost_workers))

        if (restart_workers) {
          self$restart_workers(unlist(lost_workers))
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
      self$stop_workers(type = type)

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
      r$DEL(private$.get_key("start_args"))
      r$DEL(private$.get_key("terminate_on_idle"))
      r$DEL(private$.get_key("local_workers"))
      r$DEL(private$.get_key("heartbeat_keys"))

      # reset counters and caches
      private$.cached_results_dt = data.table()
      private$.cached_tasks_dt = data.table()
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

    read_tasks = function(keys, fields = c("status", "seed", "timeout", "max_retries", "n_retries")) {
      r = self$connector
      map(keys, function(key) {
        task = setNames(map(r$HMGET(key, fields), safe_bin_to_object), fields)
        task$key = key
        task
      })
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
    #' @param next_seed (`logical(1)`)\cr
    #' Whether to change the seed of the task.
    retry_tasks = function(keys, ignore_max_retires = FALSE, next_seed = FALSE) {
      assert_character(keys)
      assert_flag(ignore_max_retires)
      assert_flag(next_seed)
      tasks = self$read_tasks(keys, fields = c("seed", "max_retries", "n_retries"))
      keys = map_chr(tasks, "key")
      seeds = map(tasks, "seed")
      n_retries = map_int(tasks, function(task) task$n_retries  %??% 0L)
      max_retries = map_dbl(tasks, function(task) task$max_retries  %??% Inf)
      failed = self$is_failed_task(keys)
      retrieable = n_retries < max_retries

      if (!all(failed)) lg$error("Not all task(s) failed: %s", str_collapse(keys[!failed]))

      if (ignore_max_retires) {
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
    #' Fetch latest results from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #'
    #' @return `data.table()`\cr
    #' Latest results.
    fetch_latest_results = function(fields = "ys", data_format = "data.table") {
      assert_character(fields)
      assert_choice(data_format, c("data.table", "list"))
      r = self$connector

      # return empty data.table or list if all results are fetched
      if (self$n_finished_tasks == private$.n_seen_results) {
        data = if (data_format == "list") list() else data.table()
        return(data)
      }
      keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), private$.n_seen_results, -1))

      # increase seen results counter
      private$.n_seen_results = private$.n_seen_results + length(keys)

      # read results from hashes
      data = self$read_hashes(keys, "ys")
      if (data_format == "list") return(set_names(data, keys))
      rbindlist(data, use.names = TRUE, fill = TRUE)
    },

    #' @description
    #' Block process until a new result is available.
    #' Returns latest results or `NULL` if no result is available after `timeout` seconds.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for a result in seconds.
    #'
    #' @return `data.table()`\cr
    #' Latest results.
    wait_for_latest_results = function(fields = "ys", timeout = Inf, data_format = "data.table") {
      start_time = Sys.time()
      while(start_time + timeout > Sys.time()) {
        latest_results = self$fetch_latest_results(fields, data_format = data_format)
        if (length(latest_results)) break
        Sys.sleep(0.01)
      }
      latest_results
    },

    #' @description
    #' Fetch results from the data base.
    #' Results are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `"ys"`.
    #' @param reset_cache (`logical(1)`)\cr
    #' Whether to reset the cache.
    #'
    #' @return `data.table()`
    #' Results.
    fetch_results = function(fields = "ys", reset_cache = FALSE, data_format = "data.table") {
      assert_character(fields)
      assert_flag(reset_cache)
      assert_choice(data_format, c("data.table", "list"))
      r = self$connector

      if (data_format == "data.table") {
        private$.fetch_cache_dt(fields, ".cached_results_dt", reset_cache)
      } else {
        private$.fetch_cache_list(fields, ".cached_results_list", reset_cache)
      }
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
      private$.fetch_default(keys, fields, data_format)
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
      private$.fetch_default(keys, fields, data_format)
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
      private$.fetch_default(keys, fields, data_format)
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
    fetch_finished_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra"), reset_cache = FALSE, data_format = "data.table") {
      r = self$connector
      assert_character(fields)
      assert_flag(reset_cache)
      assert_choice(data_format, c("data.table", "list"))

      if (data_format == "data.table") {
        private$.fetch_cache_dt(fields, cache = ".cached_tasks_dt", reset_cache)
      } else {
        private$.fetch_cache_list(fields, cache = ".cached_tasks_list", reset_cache)
      }
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
    wait_for_finished_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_extra", "ys_extra"), timeout = Inf, data_format = "data.table") {
      start_time = Sys.time()

      while(start_time + timeout > Sys.time()) {
        if (data_format == "data.table" && self$n_finished_tasks > nrow(private$.cached_tasks_dt)) {
          return(self$fetch_finished_tasks(fields, data_format = data_format))
        } else if (data_format == "list" && self$n_finished_tasks > length(private$.cached_tasks_list)) {
          return(self$fetch_finished_tasks(fields, data_format = data_format))
         }
        Sys.sleep(0.01)
      }
      NULL
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
      private$.fetch_default(keys, fields, data_format)
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
    fetch_tasks = function(fields = c("xs", "ys", "xs_extra", "worker_extra",  "ys_extra", "condition", "state"), data_format = "data.table") {
      keys = self$tasks
      private$.fetch_default(keys, fields, data_format)
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
    #' Reads Redis hashes and combines the values of the fields into a list.
    #' The function reads the values of the `fields` in the hashes stored at `keys`.
    #' The values of a hash are deserialized and combined into a single list.
    #'
    #' The reading functions combine the hashes to a table where the names of the inner lists are the column names.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))` becomes `data.table(x1 = c(1, 3), x2 = c(2, 4), y = c(3, 7))`.
    #' Vectors in list columns must be wrapped in lists.
    #' Otherwise, `$read_values()` will expand the table by the length of the vectors.
    #' For example, `xs = list(list(x1 = 1, x2 = 2)), xs_extra = list(list(extra = c("A", "B", "C"))) does not work.
    #' Pass `xs_extra = list(list(extra = list(c("A", "B", "C"))))` instead.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the hashes.
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #'
    #' @return (list of `list()`)\cr
    #' The outer list contains one element for each key.
    #' The inner list is the combination of the lists stored at the different fields.
    read_hashes = function(keys, fields) {

      lg$debug("Reading %i hash(es) with %i field(s)", length(keys), length(fields))

      # construct list of redis commands to read hashes
      cmds = map(keys, function(key) c("HMGET", key, fields))

      # list of hashes
      # first level contains hashes
      # second level contains fields
      # the values of the fields are serialized lists and atomics
      hashes = self$connector$pipeline(.commands = cmds)

      # unserialize lists of the second level
      # combine elements of the third level to one list
      # using mapply instead of pmap is somehow faster
      map(hashes, function(hash) unlist(.mapply(function(bin_value, field) {
        value = safe_bin_to_object(bin_value)
        if (is.atomic(value) && !is.null(value)) {
          # list column or column with type of value
          if (length(value) > 1) value = list(value)
          value = setNames(list(value), field)
        }
        value
      }, list(bin_value = hash, field = fields), NULL), recursive = FALSE))
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

    #' @field data ([data.table::data.table])\cr
    #' Contains all performed function calls.
    data = function(rhs) {
      assert_ro_binding(rhs)
      self$fetch_finished_tasks()
      private$.cached_tasks_dt
    },

    #' @field worker_info ([data.table::data.table()])\cr
    #' Contains information about the workers.
    worker_info = function(rhs) {
      assert_ro_binding(rhs)
      if (!self$n_running_workers) return(data.table())
      r = self$connector

      fields = c("worker_id", "pid", "host", "hostname", "heartbeat")
      worker_info = set_names(rbindlist(map(self$worker_ids, function(worker_id) {
        r$command(c("HMGET", private$.get_key(worker_id), fields))
      })), fields)

      # fix type
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
    #' For more details see [redis.io](https://redis.io/docs/management/persistence/#snapshotting).
    snapshot_schedule = function(rhs) {
      if (missing(rhs)) return(private$.snapshot_schedule)
      assert_integerish(rhs, min.len = 2, null.ok = TRUE)
      if (is.null(rhs)) rhs = ""
      r = self$connector
      r$command(c("CONFIG", "SET", "save", str_collapse(rhs, sep = " ")))
      private$.snapshot_schedule = rhs
    }
  ),

    private = list(

    # cache of the finished tasks and results
    # we split the data.table and list caches so that a key can be set on the data.table
    .cached_results_dt = data.table(),

    .cached_results_list = list(),

    .cached_tasks_dt = data.table(),

    .cached_tasks_list = list(),

    # counter of the seen results for the latest results methods
    .n_seen_results = 0,

    # cached pid_exists function
    .pid_exists = NULL,

    .snapshot_schedule = NULL,

    .hostname = NULL,

    .seed = NULL,

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
      assert_vector(lgr_thresholds, names = "named", null.ok = TRUE)
      assert_count(lgr_buffer_size)
      assert_function(worker_loop)
      dots = list(...)
      r = self$connector

      # find globals
      if (!is.null(globals)) {
        globals = set_names(map(globals, function(global) {
          value = get(global, envir = parent.frame(), inherits = TRUE)
          if (is.null(value)) stopf("Global `%s` not found", global)
          value
        }), globals)
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
        packages = packages,
        worker_args = worker_args)

      # serialize and push arguments to redis
      r$command(list("SET", private$.get_key("start_args"), redux::object_to_bin(start_args)))
    },

    # fetch tasks
    .fetch_default = function(keys, fields, data_format = "data.table") {
      r = self$connector
      assert_character(fields)
      assert_choice(data_format, c("data.table", "list"))

      if (is.null(keys)) {
        data = if (data_format == "list") list() else data.table()
        return(data)
      }

      data = self$read_hashes(keys, fields)
      if (data_format == "list") return(set_names(data, keys))
      data = rbindlist(data, use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    # fetch and cache tasks as data.table
    .fetch_cache_dt = function(fields, cache, reset_cache = FALSE) {
      r = self$connector
      if (reset_cache) private[[cache]] = data.table()

      if (self$n_finished_tasks > nrow(private[[cache]])) {

        # get keys of new results
        keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), nrow(private[[cache]]), -1))

        lg$debug("Caching %i finished task(s)", length(keys))

        # bind new results to cached results
        data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
        data[, keys := unlist(keys)]
        private[[cache]] = rbindlist(list(private[[cache]], data), use.names = TRUE, fill = TRUE)
     }

     private[[cache]]
    },

    # fetch and cache tasks as list
    .fetch_cache_list = function(fields, cache, reset_cache = FALSE) {
      r = self$connector
      if (reset_cache) private[[cache]] = list()

      if (self$n_finished_tasks > length(private[[cache]])) {

        # get keys of new results
        keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), length(private[[cache]]), -1))

        lg$debug("Caching %i finished task(s)", length(keys))

        # bind new results to cached results
        data = set_names(self$read_hashes(keys, fields), keys)
        private[[cache]] = c(private[[cache]], data)
      }

      private[[cache]]
    }
  )
)
