#' @title Rush Controller
#'
#' @description
#' [Rush] is the controller in a centralized rush network.
#' The controller starts and stops the workers, pushes tasks to the workers and fetches results.
#'
#' @section Local Workers:
#' A local worker runs on the same machine as the controller.
#' We recommend to use the `future` package to spawn local workers.
#' The `future` backend `multisession` spawns workers on the local machine.
#' As many rush workers can be started as there are future workers available.
#'
#' @section Remote Workers:
#' A remote worker runs on a different machine than the controller.
#' Remote workers can be started with a script or with the `future` package.
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
#' @template param_network_id
#' @template param_config
#' @template param_worker_loop
#' @template param_globals
#' @template param_packages
#' @template param_host
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#' @template param_lgr_thresholds
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

    #' @field promises ([future::Future()])\cr
    #' List of futures running [run_worker].
    promises = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(network_id = NULL, config = NULL) {
      self$network_id = assert_string(network_id, null.ok = TRUE) %??% uuid::UUIDgenerate()
      self$config = assert_class(config, "redis_config", null.ok = TRUE) %??% redux::redis_config()
      self$connector = redux::hiredis(self$config)
      private$.pid_exists = choose_pid_exists()
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
      catf(str_indent("* Running Workers:", self$n_workers))
      catf(str_indent("* Queued Tasks:", self$n_queued_tasks))
      catf(str_indent("* Queued Priority Tasks:", self$n_queued_priority_tasks))
      catf(str_indent("* Running Tasks:", self$n_running_tasks))
      catf(str_indent("* Finished Tasks:", self$n_finished_tasks))
      catf(str_indent("* Failed Tasks:", self$n_failed_tasks))
    },

    #' @description
    #' Start workers with the future package.
    #' Alternatively, use `$create_worker_script()` to create a script for starting workers.
    #'
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
    #' If `NULL` the maximum number of free workers is used.
    #' @param await_workers (`logical(1)`)\cr
    #' Whether to wait until all workers are available.
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    #'
    #' @return (`character()`)\cr
    #' Worker ids.
    start_workers = function(
      worker_loop = fun_loop,
      n_workers = NULL,
      globals = NULL,
      packages = NULL,
      host = "local",
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      lgr_thresholds = NULL,
      await_workers = TRUE,
      ...) {

      assert_character(globals, null.ok = TRUE)
      assert_character(packages, null.ok = TRUE)
      assert_count(n_workers, positive = TRUE, null.ok = TRUE)
      assert_choice(host, c("local", "remote"))
      assert_count(heartbeat_period, positive = TRUE, null.ok = TRUE)
      assert_count(heartbeat_expire, positive = TRUE, null.ok = TRUE)
      assert_named(lgr_thresholds)
      assert_flag(await_workers)
      dots = list(...)
      r = self$connector

      # check free workers
      if (is.null(n_workers)) n_workers = future::nbrOfWorkers()
      if (n_workers > future::nbrOfFreeWorkers()) {
        stopf("No more than %i rush workers can be started. For starting more workers, change the number of workers in the future plan.", future::nbrOfFreeWorkers())
      }

      # start workers
      network_id = self$network_id
      config = self$config
      worker_ids = uuid::UUIDgenerate(n = n_workers)
      self$promises = c(self$promises, setNames(map(worker_ids, function(worker_id) {
        future::future(run_worker(
            worker_loop = worker_loop,
            network_id = network_id,
            config = config,
            host = host,
            worker_id = worker_id,
            heartbeat_period = heartbeat_period,
            heartbeat_expire = heartbeat_expire,
            lgr_thresholds = lgr_thresholds,
            args = dots),
          seed = TRUE,
          globals = c(globals, "run_worker", "worker_loop", "network_id", "config", "worker_id", "host", "heartbeat_period", "heartbeat_expire", "lgr_thresholds", "dots"),
          packages = packages)
      }), worker_ids))


      if (await_workers) self$await_workers(n_workers)

      return(invisible(worker_ids))
    },

    #' @description
    #' Create script to start workers.
    #' The worker is started with [start_worker()].
    #'
    #' @param ... (`any`)\cr
    #' Arguments passed to `worker_loop`.
    create_worker_script = function(
      worker_loop = fun_loop,
      globals = NULL,
      packages = NULL,
      host = "local",
      heartbeat_period = NULL,
      heartbeat_expire = NULL,
      lgr_thresholds = NULL,
      ...) {

      assert_function(worker_loop)
      assert_character(globals, null.ok = TRUE)
      assert_character(packages, null.ok = TRUE)
      assert_choice(host, c("local", "remote"))
      assert_count(heartbeat_period, positive = TRUE, null.ok = TRUE)
      assert_count(heartbeat_expire, positive = TRUE, null.ok = TRUE)
      assert_named(lgr_thresholds)
      dots = list(...)
      r = self$connector

      # identify globals by name
      # returns a named list of values of the globals
      globals = globalsByName(globals)

      # serialize arguments needed for starting the worker
      args = list(
        worker_loop = worker_loop,
        globals = globals,
        packages = packages,
        host = host,
        heartbeat_period = heartbeat_period,
        heartbeat_expire = heartbeat_expire,
        lgr_thresholds = lgr_thresholds,
        args = dots)
      bin_args = redux::object_to_bin(args)
      r$command(list("SET", private$.get_key("worker_script"), bin_args))

      lg$info("Start worker with:")
      lg$info("Rscript -e 'rush::start_worker(%s, url = \"%s\")'", self$network_id, self$config$url)
      lg$info("See ?rush::start_worker for more details.")

      return(invisible(self))
    },

    #' @description
    #' Wait until `n` workers are available.
    #'
    #' @param n (`integer(1)`)\cr
    #' Number of workers to wait for.
    await_workers = function(n) {
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
      assert_character(worker_ids, null.ok = TRUE)
      worker_ids = worker_ids %??% self$worker_ids
      r = self$connector

      if (type == "terminate") {

        lg$debug("Terminating %i worker(s) %s", length(worker_ids), as_short_string(worker_ids))

        # Push terminate signal to worker
        cmds = map(worker_ids, function(worker_id) {
          c("SET", private$.get_worker_key("terminate", worker_id), "TRUE")
        })
        r$pipeline(.commands = cmds)

      } else if (type == "kill") {
        running_workers = self$worker_states[list("running"), worker_id, on = "state", nomatch = NULL]
        worker_info = self$worker_info[list(running_workers), , on = "worker_id"]

        # kill local
        local_workers = worker_info[list("local", worker_ids), , on = c("host", "worker_id"), nomatch = NULL]

        if (nrow(local_workers)) {
          tools::pskill(local_workers$pid)
          cmds = map(local_workers$worker_id, function(worker_id) {
            c("HSET", private$.get_key(worker_id), "state", "killed")
          })
          r$pipeline(.commands = cmds)
        }

        # kill remote
        remote_workers = worker_info[list("remote", worker_ids), worker_id, on = c("host", "worker_id"), nomatch = NULL]

        if (length(remote_workers)) {
          # push kill signal to heartbeat
          cmds = unlist(map(remote_workers, function(worker_id) {
            list(
              c("LPUSH", private$.get_worker_key("kill", worker_id), "TRUE"),
              c("HSET", private$.get_key(worker_id), "state", "killed"))
          }), recursive = FALSE)
          r$pipeline(.commands = cmds)
        }
      }

      return(invisible(self))
    },

    #' @description
    #' Detect lost workers.
    #' The state of the worker is changed to `"lost"`.
    #' Local workers without a heartbeat are checked with `tools::pskill()`.
    #' Checking local workers on windows might be very slow.
    #' Workers with a heartbeat process are checked with the heartbeat.
    detect_lost_workers = function() {
      r = self$connector

      # get info of running workers
      # optimized to quickly get the info of running workers
      worker_info = self$worker_info
      worker_states = private$.worker_states(worker_info$worker_id)
      worker_info = worker_info[worker_states == "running", ]
      lost_workers = character(0)

      if (any(worker_info$heartbeat)) {
        # check local and remote workers started with a heartbeat
        # comes with an overhead for running the heartbeat process
        heartbeat_workers = worker_info[list(TRUE), worker_id, on = c("heartbeat"), nomatch = NULL]

        if (length(heartbeat_workers)) {
          lost = map_lgl(heartbeat_workers, function(worker_id) as.logical(!r$command(c("EXISTS", private$.get_worker_key("heartbeat", worker_id)))))
          lost_workers = heartbeat_workers[lost]
        }
      }

      if (any(worker_info$host %in% "local") && !is.null(private$.pid_exists)) {
        # check local workers without a heartbeat
        # covers local workers started with future and batch
        # fastest method on unix systems
        # on windows, heartbeat might be faster
        pid_exists = private$.pid_exists
        local_workers = worker_info[list("local", FALSE), list(worker_id, pid), on = c("host", "heartbeat"), nomatch = NULL]

        lost = map_lgl(local_workers$pid, function(pid) !pid_exists(pid))
        lost_workers = c(lost_workers, local_workers$worker_id[lost])
      }

      if (length(lost_workers)) {
        # update state
        r$pipeline(.commands = map(lost_workers, function(worker_id) c("HSET", private$.get_key(worker_id), "state", "lost")))

        lg$error("Lost %i worker(s): %s", length(lost_workers), str_collapse(lost_workers))
      }

      return(invisible(self))
    },

    #' @description
    #' Detect lost tasks.
    #' Changes the state of tasks to `"lost"` if the worker crashed.
    detect_lost_tasks = function() {
      r = self$connector
      if (!self$n_workers) return(invisible(self))
      self$detect_lost_workers()
      running_tasks = self$fetch_running_tasks(fields = "worker_extra")

      lost_workers = self$worker_states[list("lost"), worker_id, on = c("state"), nomatch = NULL]

      if (length(lost_workers)) {
        bin_state = redux::object_to_bin(list(state = "lost"))
        keys = running_tasks[lost_workers, keys, on = "worker_id"]

        cmds = unlist(map(keys, function(key) {
          list(
            c("HSET", key, "state", list(bin_state)),
            c("SREM", private$.get_key("running_tasks"), key),
            c("RPUSH", private$.get_key("failed_tasks"), key))
        }), recursive = FALSE)
        r$pipeline(.commands = cmds)
      }

      return(invisible(self))
    },

    #' @description
    #' Stop workers and delete data stored in redis.
    reset = function() {
      r = self$connector

      # stop workers
      self$stop_workers()

      # reset fields set by starting workers
      self$promises = NULL

      # remove worker info, heartbeat, terminate and kill
      walk(self$worker_ids, function(worker_id) {
        r$DEL(private$.get_key(worker_id))
        r$DEL(private$.get_worker_key("terminate", worker_id))
        r$DEL(private$.get_worker_key("kill", worker_id))
        r$DEL(private$.get_worker_key("heartbeat", worker_id))
        r$DEL(private$.get_worker_key("queued_tasks", worker_id))
        r$DEL(private$.get_worker_key("log", worker_id))
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
      r$DEL(private$.get_key("worker_script"))
      r$DEL(private$.get_key("terminate_on_idle"))

      # reset counters and caches
      private$.cached_results = data.table()
      private$.cached_data = data.table()
      private$.cached_worker_info = data.table()
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
      cmds =  map(worker_ids, function(worker_id) c("LRANGE", private$.get_worker_key("log", worker_id), 0, -1))
      bin_logs = unlist(setNames(r$pipeline(.commands = cmds), worker_ids), recursive = FALSE)
      rbindlist(map(bin_logs, redux::bin_to_object), use.names = TRUE, fill = TRUE, idcol = "worker_id")
    },

    #' @description
    #' Pushes a task to the queue.
    #' Task is added to queued tasks.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #' @param terminate_workers (`logical(1)`)\cr
    #' Whether to stop the workers after evaluating the tasks.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_tasks = function(xss, extra = NULL, terminate_workers = FALSE) {
      assert_list(xss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      assert_flag(terminate_workers)
      r = self$connector

      lg$debug("Pushing %i task(s) to the shared queue", length(xss))

      keys = self$write_hashes(xs = xss, xs_extra = extra, state = "queued")
      r$command(c("LPUSH", private$.get_key("queued_tasks"), keys))
      r$command(c("SADD", private$.get_key("all_tasks"), keys))
      if (terminate_workers) r$command(c("SET", private$.get_key("terminate_on_idle"), "TRUE"))

      return(invisible(keys))
    },

    #' @description
    #' Pushes a task to the queue of a specific worker.
    #' Task is added to queued priority tasks.
    #' A worker evaluates the tasks in the priority queue before the normal queue.
    #' If `priority` is `NA` the task is added to the normal queue.
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
      assert_subset(priority, c(NA_character_, self$worker_ids))
      r = self$connector

      lg$debug("Pushing %i task(s) to %i priority queue(s) and %i task(s) to the default queue",
        sum(!is.na(priority)), length(unique(priority[!is.na(priority)])), sum(is.na(priority)))

      keys = self$write_hashes(xs = xss, xs_extra = extra, state = "queued")
      cmds = pmap(list(priority, keys), function(worker_id, key) {
        if (is.na(worker_id)) {
          c("LPUSH", private$.get_key("queued_tasks"), key)
        } else {
          c("LPUSH", private$.get_worker_key("queued_tasks", worker_id), key)
        }
      })
      r$pipeline(.commands = cmds)
      r$command(c("SADD", private$.get_key("all_tasks"), keys))

      return(invisible(keys))
    },

    #' @description
    #' Fetch latest results from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #'
    #' @return `data.table()`\cr
    #' Latest results.
    fetch_latest_results = function(fields = "ys") {
      r = self$connector

      if (self$n_finished_tasks == private$.n_seen_results) return(data.table())
      keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), private$.n_seen_results, -1))

      # increase seen results counter
      private$.n_seen_results = private$.n_seen_results + length(keys)

      # read results from hashes
      rbindlist(self$read_hashes(keys, "ys"), use.names = TRUE, fill = TRUE)
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
    block_latest_results = function(fields = "ys", timeout = Inf) {
      start_time = Sys.time()
      while(start_time + timeout > Sys.time()) {
        latest_results = self$fetch_latest_results(fields)
        if (nrow(latest_results)) break
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
    fetch_results = function(fields = "ys", reset_cache = FALSE) {
      r = self$connector
      assert_character(fields)
      assert_flag(reset_cache)
      if (reset_cache) private$.cached_results = data.table()

      if (self$n_finished_tasks > nrow(private$.cached_results)) {
        keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), nrow(private$.cached_results), -1))

        lg$debug("Caching %i result(s)", length(keys))

        # cache results
        results = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
        results[, keys := unlist(keys)]
        private$.cached_results = rbindlist(list(private$.cached_results, results))
      }

      private$.cached_results
    },

    #' @description
    #' Fetch queued tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "state")`.
    #'
    #' @return `data.table()`\cr
    #' Table of queued tasks.
    fetch_queued_tasks = function(fields = c("xs", "xs_extra", "state")) {
      r = self$connector
      assert_character(fields)

      keys = self$queued_tasks
      if (is.null(keys)) return(data.table())

      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Fetch queued priority tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "state")`.
    #'
    #' @return `data.table()`\cr
    #' Table of queued priority tasks.
    fetch_priority_tasks = function(fields = c("xs", "xs_extra", "state")) {
      r = self$connector
      assert_character(fields)

      cmds = map(self$worker_ids, function(worker_id)  c("LRANGE", private$.get_worker_key("queued_tasks", worker_id), "0", "-1"))
      if (!length(cmds)) return(data.table())

      keys = unlist(r$pipeline(.commands = cmds))
      if (is.null(keys)) return(data.table())

      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Fetch running tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "state")`.
    #'
    #' @return `data.table()`\cr
    #' Table of running tasks.
    fetch_running_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "state")) {
      r = self$connector
      assert_character(fields)

      keys = self$running_tasks
      if (is.null(keys)) return(data.table())

      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Fetch finished tasks from the data base.
    #' Finished tasks are cached.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "state")`.
    #' @param reset_cache (`logical(1)`)\cr
    #' Whether to reset the cache.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    fetch_finished_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "state"), reset_cache = FALSE) {
      r = self$connector
      assert_character(fields)
      assert_flag(reset_cache)
      if (reset_cache) private$.cached_data = data.table()

      if (self$n_finished_tasks > nrow(private$.cached_data)) {
        keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), nrow(private$.cached_data), -1))

        lg$debug("Caching %i finished task(s)", length(keys))

        # cache results
        data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
        data[, keys := unlist(keys)]
        private$.cached_data = rbindlist(list(private$.cached_data, data), use.names = TRUE, fill = TRUE)
      }

      private$.cached_data
    },

    #' @description
    #' Block process until a new finished task is available.
    #' Returns all finished tasks or `NULL` if no new task is available after `timeout` seconds.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "state")`.
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for a result in seconds.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    block_finished_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "state"), timeout = Inf) {
      start_time = Sys.time()
      while(start_time + timeout > Sys.time()) {
        if (self$n_finished_tasks > nrow(private$.cached_data)) return(self$fetch_finished_tasks(fields))
        Sys.sleep(0.01)
      }
      NULL
    },

    #' @description
    #' Fetch failed tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "condition", "state")`.
    #'
    #' @return `data.table()`\cr
    #' Table of failed tasks.
    fetch_failed_tasks = function(fields = c("xs", "worker_extra", "condition", "state")) {
      r = self$connector
      assert_character(fields)

      keys = self$failed_tasks
      if (is.null(keys)) return(data.table())

      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
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
    fetch_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "condition", "state")) {
      r = self$connector
      assert_character(fields)

      keys = self$tasks
      if (is.null(keys)) return(data.table())

      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Wait until tasks are finished.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to wait for.
    #' @param detect_lost_tasks (`logical(1)`)\cr
    #' Whether to detect failed tasks.
    #' Comes with an overhead.
    await_tasks = function(keys, detect_lost_tasks = FALSE) {
      assert_character(keys, min.len = 1)
      assert_flag(detect_lost_tasks)

      while (any(keys %nin% c(self$finished_tasks, self$failed_tasks))) {
        if (detect_lost_tasks) self$detect_lost_tasks()
        Sys.sleep(0.01)
      }

      invisible(self)
    },

    #' @description
    #' Writes a list to redis hashes.
    #' The function serializes each element and writes it to a new hash.
    #' The name of the argument defines the field into which the serialized element is written.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4))` writes `serialize(list(x1 = 1, x2 = 2))` at field `xs` into a hash and `serialize(list(x1 = 3, x2 = 4))` at field `xs` into another hash.
    #' The function can iterate over multiple lists simultaneously.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))` creates two hashes with the fields `xs` and `ys`.
    #' Different lengths are recycled.
    #' The stored elements should be lists themselves.
    #' The reading functions combine the hashes to a table where the names of the inner lists are the column names.
    #' For example, `xs = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4)), ys = list(list(y = 3), list(y = 7))` becomes `data.table(x1 = c(1, 3), x2 = c(2, 4), y = c(3, 7))`.
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
    #' @param state (`character(1)`)\cr
    #' Status of the hashes.
    #'
    #' @return (`character()`)\cr
    #' Keys of the hashes.
    write_hashes = function(..., .values = list(), keys = NULL, state = NA) {
      values = discard(c(list(...), .values), function(l) !length(l))
      assert_list(values, names = "unique", types = "list", min.len = 1)
      fields = names(values)
      keys = assert_character(keys %??% uuid::UUIDgenerate(n = length(values[[1]])), len = length(values[[1]]), .var.name = "keys")
      bin_state = redux::object_to_bin(list(state = state))

      lg$debug("Writting %i hash(es) with %i field(s)", length(keys), length(fields))

      # construct list of redis commands to write hashes
      cmds = pmap(c(list(key = keys), values), function(key, ...) {
          # serialize lists
          bin_values = map(list(...), redux::object_to_bin)

          lg$debug("Serialzing %i value(s) to %s",
            length(bin_values), format(Reduce(`+`, map(bin_values, object.size))))

          # merge fields and values alternatively
          # c and rbind are fastest option in R
          # data is not copied
          c("HSET", key, c(rbind(fields, bin_values)), "state", list(bin_state))
        })

      self$connector$pipeline(.commands = cmds)

      invisible(keys)
    },

    #' @description
    #' Reads redis hashes written with `$write_hashes()`.
    #' The function reads the values of the `fields` in the hashes stored at `keys`.
    #' The values of a hash are deserialized and combined into a single list.
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

      lg$debug("Reading %i hash(es) with %i field(s)",
        length(keys), length(fields))

      # construct list of redis commands to read hashes
      cmds = map(keys, function(key) c("HMGET", key, fields))

      # list of hashes
      # first level contains hashes
      # second level contains fields
      # the values of the fields are serialized lists
      hashes = self$connector$pipeline(.commands = cmds)

      # unserialize lists of the second level
      # combine elements of the third level to one list
      map(hashes, function(hash) unlist(map_if(hash, function(x) !is.null(x), redux::bin_to_object), recursive = FALSE))
    }
  ),

  active = list(

    #' @field n_workers (`integer(1)`)\cr
    #' Number of running workers.
    n_workers = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector
      as.integer(r$SCARD(private$.get_key("worker_ids"))) %??% 0
    },

    #' @field worker_ids (`character()`)\cr
    #' Ids of workers.
    worker_ids = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("worker_ids")))
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
      unlist(r$LRANGE(private$.get_key("failed_tasks"), 0, -1))
    },

    #' @field tasks (`character()`)\cr
    #' Keys of all tasks.
    tasks = function() {
      r = self$connector
      unlist(r$SMEMBERS(private$.get_key("all_tasks")))
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
      as.integer(r$LLEN(private$.get_key("failed_tasks"))) %??% 0
    },

    #' @field n_tasks (`integer(1)`)\cr
    #' Number of all tasks.
    n_tasks = function() {
      r = self$connector
      as.integer(r$SCARD(private$.get_key("all_tasks"))) %??% 0
    },

    #' @field data ([data.table::data.table])\cr
    #' Contains all performed function calls.
    data = function(rhs) {
      assert_ro_binding(rhs)
      self$fetch_finished_tasks()
      private$.cached_data
    },

    #' @field worker_info ([data.table::data.table()])\cr
    #' Contains information about the workers.
    worker_info = function(rhs) {
      assert_ro_binding(rhs)

      # worker info is cached so that functions like detect_lost_workers run fast
      if (nrow(private$.cached_worker_info) == self$n_workers) return(private$.cached_worker_info)
      r = self$connector

      fields = c("worker_id", "pid", "host", "heartbeat")
      worker_info = set_names(rbindlist(map(self$worker_ids, function(worker_id) {
        r$command(c("HMGET", private$.get_key(worker_id), fields))
      })), fields)

      # fix types
      worker_info[, heartbeat := as.logical(heartbeat)]
      worker_info[, pid := as.integer(pid)][]

      # cache result
      private$.cached_worker_info = worker_info
      worker_info
    },

    #' @field worker_states ([data.table::data.table()])\cr
    #' Contains the states of the workers.
    worker_states = function(rhs) {
      assert_ro_binding(rhs)
      r = self$connector

      fields = c("worker_id", "state")
      set_names(rbindlist(map(self$worker_ids, function(worker_id) {
        r$command(c("HMGET", private$.get_key(worker_id), fields))
      })), fields)
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

    .cached_results = data.table(),

    .cached_data = data.table(),

    .cached_worker_info = data.table(),

    .n_seen_results = 0,

    .pid_exists = NULL,

    .snapshot_schedule = NULL,

    # prefix key with instance id
    .get_key = function(key) {
      sprintf("%s:%s", self$network_id, key)
    },

    # prefix key with instance id and worker id
    .get_worker_key = function(key, worker_id = NULL) {
      worker_id = worker_id %??% self$worker_id
      sprintf("%s:%s:%s", self$network_id, worker_id, key)
    },

    # quick access to the worker states
    # helpful to subset worker info
    # returns a character vector of the states
    .worker_states = function(worker_ids) {
      r = self$connector

      cmds = map(worker_ids, function(worker_id) {
        c("HGET", private$.get_key(worker_id), "state")
      })

      unlist(r$pipeline(.commands = cmds))
    }
  )
)
