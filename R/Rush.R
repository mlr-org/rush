#' @title Rush Controller
#'
#' @description
#' The [Rush] class is the controller of the asynchronous parallelization.
#' It manages the workers and the tasks.
#'
#' @section Local Workers:
#' A local worker runs on the same machine as the controller.
#' We recommend to use the `future` package to spawn local workers.
#' The `future` backends `multisession` and `multicore` run workers on the local machine.
#' As many rush workers can be started as there are future workers available.
#' With `future`, crashed workers can be easily identified without a heartbeat process.
#' It is also possible to spawn local workers with a batch script but a heartbeat process is required to check for crashed workers.
#'
#' @section Remote Workers:
#' A remote worker runs on a different machine than the controller.
#' Remote workers can be started with a batch script or with the `future` package.
#' Only a heartbeat process can kill remote workers.
#' The heartbeat process also monitors the remote workers for crashes.
#'
#' @section Stopping Workers:
#' Local and remote workers can be terminated with the `stop_workers(type = "terminate")` method.
#' The workers evaluate the currently running task and then terminate.
#' The option `type = "kill"` stops the workers immediately.
#' Killing a local worker is done with the `tools::pskill()` function.
#' Remote workers are killed by pushing a kill signal to the heartbeat process.
#' Without a heartbeat process a remote worker cannot be killed (see section heartbeat).
#'
#' @section Heartbeat:
#' The heartbeat process periodically signals that a worker is still alive.
#'
#' @section Error Handling:
#' When evaluating tasks in a distributed system, many things can go wrong.
#'
#' @export
Rush = R6::R6Class("Rush",
  public = list(

    #' @field instance_id (`character(1)`)\cr
    #' Identifier of the instance.
    instance_id = NULL,

    #' @field config ([redux::redis_config])\cr
    #' Redis configuration.
    config = NULL,

    #' @field promises ([future::Future()])\cr
    #' List of futures.
    promises = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    #'
    #' @param instance_id (`character(1)`)\cr
    #' Identifier of the instance.
    #' @param config ([redux::redis_config])\cr
    #' Redis configuration.
    initialize = function(instance_id, config = redux::redis_config()) {
      self$instance_id = assert_string(instance_id)
      self$config = assert_class(config, "redis_config")
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
    #' Start workers.
    #'
    #' @param fun (`function`)\cr
    #' Function to be executed by the workers.
    #' Function must return a named list.
    #' @param as_list (`logical(1)`)\cr
    #' Whether the function takes a list of arguments (`fun(xs = list(x1, x2)`) or named arguments (`fun(x1, x2)`).
    #' @param n_workers (`integer(1)`)\cr
    #' Number of workers to be started.
    #' If `NULL` the maximum number of free workers is used.
    #' @param globals (`character()`)\cr
    #' Global variables to be loaded by the workers.
    #' @param packages (`character()`)\cr
    #' Packages to be loaded by the workers.
    #' @param host (`character(1)`)\cr
    #' Local or remote host.
    #' @param heartbeat_period (`integer(1)`)\cr
    #' Period of the heartbeat in seconds.
    #' @param heartbeat_expire (`integer(1)`)\cr
    #' Time to live of the heartbeat in seconds.
    start_workers = function(fun, as_list = FALSE, n_workers = NULL, globals = NULL, packages = NULL, host = "local", heartbeat_period = NULL, heartbeat_expire = NULL) {
      assert_function(fun)
      assert_flag(as_list)
      assert_character(globals, null.ok = TRUE)
      assert_character(packages, null.ok = TRUE)
      assert_count(n_workers, positive = TRUE, null.ok = TRUE)
      assert_choice(host, c("local", "remote"))
      assert_count(heartbeat_period, positive = TRUE, null.ok = TRUE)
      assert_count(heartbeat_expire, positive = TRUE, null.ok = TRUE)

      # check free workers
      free_workers = future::nbrOfWorkers() - self$n_workers
      if (is.null(n_workers)) n_workers = future::nbrOfWorkers()
      if (n_workers > free_workers) stop("Not enough free workers.")

      r = self$connector

      # choose wrapper function
      worker_loop = if (as_list) list_fun_loop else fun_loop

      # start workers
      instance_id = self$instance_id
      config = self$config
      worker_ids = uuid::UUIDgenerate(n = n_workers)
      self$promises = c(self$promises, setNames(map(worker_ids, function(worker_id) {
        future::future(worker_loop(
          fun = fun,
          instance_id = instance_id,
          config = config,
          host = host,
          initializer = "future",
          worker_id = worker_id,
          heartbeat_period = heartbeat_period,
          heartbeat_expire = heartbeat_expire),
          seed = TRUE,
          globals = c(globals, "worker_loop", "fun", "instance_id", "config", "worker_id", "host", "heartbeat_period", "heartbeat_expire"), packages = packages)
      }), worker_ids))

      # increase number of running workers
      private$.n_workers = self$n_workers + n_workers

      return(invisible(worker_ids))
    },

    #' @description
    #' Create batch script to start workers.
    #'
    #' @param fun (`function`)\cr
    #' Function to be executed by the workers.
    #' Function must return a named list.
    #' @param as_list (`logical(1)`)\cr
    #' Whether the function takes a list of arguments (`fun(xs = list(x1, x2)`) or named arguments (`fun(x1, x2)`).
    #' @param globals (`character()`)\cr
    #' Global variables to be loaded by the workers.
    #' @param packages (`character()`)\cr
    #' Packages to be loaded by the workers.
    create_worker_script = function(fun, as_list = FALSE, globals = NULL, packages = NULL) {
      r = self$connector

      # serialize objects needed to create rush instance
      bin_fun = redux::object_to_bin(fun)
      bin_globals = map(globals, function(global) redux::object_to_bin(get(global)))
      bin_packages = redux::object_to_bin(packages)
      r$command(c("HMSET", private$.get_key("worker_script"), "fun", "packages", bin_packages, "globals", bin_globals))

      # TODO: implement script to start loops on worker
      code = c("#!/usr/bin/env Rscript", "rush::run_worker_script()")
      writeLines(code, con = "worker_script")
    },

    #' @description
    #' Wait until `n` workers are available.
    #'
    #' @param n (`integer(1)`)\cr
    #' Number of workers to wait for.
    await_workers = function(n) {
      assert_count(n)
      while(self$n_workers < n) Sys.sleep(0.01)
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

        # Push terminate signal to worker
        cmds = unlist(map(worker_ids, function(worker_id) {
          list(
            c("SET", private$.get_worker_key("terminate", worker_id), "TRUE"),
            c("HSET", private$.get_key(worker_id), "status", "terminated"))
        }), recursive = FALSE)
        r$pipeline(.commands = cmds)

      } else if (type == "kill") {
        worker_info = self$worker_info(worker_ids = worker_ids)

        # kill local
        local_workers = worker_info[list("running", "local"), , on = c("status", "host"), nomatch = NULL]

        if (nrow(local_workers)) {
          tools::pskill(local_workers$pid)
          cmds = map(local_workers$worker_id, function(worker_id) {
            c("HSET", private$.get_key(worker_id), "status", "killed")
          })
          r$pipeline(.commands = cmds)
        }

        # kill remote
        remote_workers = worker_info[list("running", "remote"), worker_id, on = c("status", "host"), nomatch = NULL]

        if (length(remote_workers)) {
          # push kill signal to heartbeat
          cmds = unlist(map(remote_workers, function(worker_id) {
            list(
              c("LPUSH", private$.get_worker_key("kill", worker_id), "TRUE"),
              c("HSET", private$.get_key(worker_id), "status", "killed"))
          }), recursive = FALSE)
          r$pipeline(.commands = cmds)
        }
      }

      invisible(self)
    },

    #' @description
    #' Get status of workers.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Worker ids to be checked.
    #' If `NULL` all workers are checked.
    worker_info = function(worker_ids = NULL) {
      assert_character(worker_ids, null.ok = TRUE)
      worker_ids = worker_ids %??% self$worker_ids
      if (!length(worker_ids)) return(data.table())
      r = self$connector

      fields = c("worker_id", "status", "pid", "host", "initializer", "heartbeat")
      worker_info = set_names(rbindlist(map(worker_ids, function(worker_id) {
        r$command(c("HMGET", private$.get_key(worker_id), fields))
      }), use.names = FALSE), fields)

      # fix types
      worker_info[, heartbeat := as.logical(heartbeat)]
      worker_info[, pid := as.integer(pid)][]
    },

    #' @description
    #' Detect lost workers.
    #' Workers can only be detected if they were started with `future` or a heartbeat.
    #'
    #' @param worker_ids (`character()`)\cr
    #' Workers to be checked.
    detect_lost_workers = function(worker_ids = NULL) {
      r = self$connector
      assert_character(worker_ids, null.ok = TRUE)
      worker_ids = worker_ids %??% self$worker_ids
      worker_info = self$worker_info(worker_ids)

      # check workers started with future
      future_workers = worker_info[list("running", "future"), worker_id, on = c("status", "initializer"), nomatch = NULL]

      iwalk(self$promises[future_workers], function(promise, worker_id) {
        # resolved signals a FutureError when the connection is invalid
        # it is very cumbersome to find out if a process is still running on windows
        # so we leave this to future
        tryCatch(future::resolved(promise), error = function(ex) {
          r$command(c("HSET", private$.get_key(worker_id), "status", "lost"))
        })
      })

      # check workers started with a heartbeat
      heartbeat_workers = worker_info[list("running", TRUE), worker_id, on = c("status", "heartbeat"), nomatch = NULL]

      walk(heartbeat_workers, function(worker_id) {
        # heartbeat key is deleted when the heartbeat process is stopped
        if (!r$command(c("EXISTS", private$.get_worker_key("heartbeat", worker_id)))) {
          r$command(c("HSET", private$.get_key(worker_id), "status", "lost"))
        }
      })

      invisible(NULL)
    },

    #' @description
    #' Detect failed tasks.
    detect_failed_tasks = function() {
      r = self$connector
      self$detect_lost_workers()
      running_tasks = self$fetch_running_tasks(fields = "worker_extra")
      worker_info = self$worker_info()

      lost_workers = worker_info[list("lost"), worker_id, on = c("status")]

      if (length(lost_workers)) {
        bin_status = redux::object_to_bin(list(status = "segfault"))
        keys = running_tasks[lost_workers, keys, on = "worker_id"]

        cmds = unlist(map(keys, function(key) {
          list(
            c("HSET", key, "status", list(bin_status)),
            c("SREM", private$.get_key("running_tasks"), key),
            c("RPUSH", private$.get_key("failed_tasks"), key))
        }), recursive = FALSE)
        r$pipeline(.commands = cmds)
      }

      invisible(NULL)
    },

    #' @description
    #' Reset the data base.
    reset = function() {
      r = self$connector
      self$stop_workers()
      self$promises = NULL
      self$constants = NULL
      r$DEL(private$.get_key("queued_tasks"))
      walk(self$worker_ids, function(worker_id) {
        private$.get_key(sprintf("%s:%s", private$.get_key("queued_tasks"), worker_id))
      })
      r$DEL(private$.get_key("running_tasks"))
      r$DEL(private$.get_key("finished_tasks"))
      r$DEL(private$.get_key("failed_tasks"))
      r$DEL(private$.get_key("terminate"))
      r$DEL(private$.get_key("worker_ids"))
      private$.n_workers = NULL
      private$.cached_results = data.table()
      private$.cached_data = data.table()
      private$.n_seen_results = 0

      self$register_worker()
      invisible(self)
    },

    #' @description
    #' Pushes a task to the queue.
    #' Task is added to queued tasks.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    #'
    #' @return (`character()`)\cr
    #' Keys of the tasks.
    push_tasks = function(xss, extra = list()) {
      assert_list(xss, types = "list", min.len = 1)
      assert_list(extra, types = "list")
      r = self$connector

      lg$info("Sending %i task(s)", length(xss))

      keys = self$write_hashes(xs = xss, xs_extra = extra, status = "queued")
      r$command(c("LPUSH", private$.get_key("queued_tasks"), keys))
      r$command(c("SADD", private$.get_key("all_tasks"), keys))

      invisible(keys)
    },

    #' @description
    #' Pushes a task to the queue of a specific worker.
    #' Task is added to queued priority tasks.
    #' A worker evaluates the tasks in the priority queue before the normal queue.
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
      assert_subset(priority, self$worker_ids)
      r = self$connector

      lg$info("Sending %i task(s)", length(xss))

      keys = self$write_hashes(xs = xss, xs_extra = extra, status = "queued")
      cmds = pmap(list(priority, keys), function(worker_id, key) c("LPUSH", sprintf("%s:%s", private$.get_key("queued_tasks"), worker_id), key))

      r$pipeline(.commands = cmds)
      r$command(c("SADD", private$.get_key("all_tasks"), keys))

      invisible(keys)
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
    #' Defaults to `c("xs", "xs_extra", "status")`.
    #'
    #' @return `data.table()`\cr
    #' Table of queued tasks.
    fetch_queued_tasks = function(fields = c("xs", "xs_extra", "status")) {
      r = self$connector
      assert_character(fields)

      if (!self$n_queued_tasks) return(data.table())
      keys = self$queued_tasks
      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Fetch running tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "status")`.
    #'
    #' @return `data.table()`\cr
    #' Table of running tasks.
    fetch_running_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "status")) {
      r = self$connector
      assert_character(fields)

      if (!self$n_running_tasks) return(data.table())
      keys = self$running_tasks
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
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "status")`.
    #' @param reset_cache (`logical(1)`)\cr
    #' Whether to reset the cache.
    #'
    #' @return `data.table()`\cr
    #' Table of finished tasks.
    fetch_finished_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "status"), reset_cache = FALSE) {
      r = self$connector
      assert_character(fields)
      assert_flag(reset_cache)
      if (reset_cache) private$.cached_data = data.table()

      if (self$n_finished_tasks > nrow(private$.cached_data)) {
        keys = r$command(c("LRANGE", private$.get_key("finished_tasks"), nrow(private$.cached_data), -1))

        # cache results
        data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
        data[, keys := unlist(keys)]
        private$.cached_data = rbindlist(list(private$.cached_data, data), use.names = TRUE, fill = TRUE)
      }

      private$.cached_data
    },

    #' @description
    #' Fetch failed tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "condition", "status")`.
    #'
    #' @return `data.table()`\cr
    #' Table of failed tasks.
    fetch_failed_tasks = function(fields = c("xs", "worker_extra", "condition", "status")) {
      r = self$connector
      assert_character(fields)

      if (!self$n_failed_tasks) return(data.table())
      keys = self$failed_tasks
      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Fetch all tasks from the data base.
    #'
    #' @param fields (`character()`)\cr
    #' Fields to be read from the hashes.
    #' Defaults to `c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "condition", "status")`.
    #'
    #' @return `data.table()`\cr
    #' Table of all tasks.
    fetch_tasks = function(fields = c("xs", "xs_extra", "worker_extra", "ys", "ys_extra", "condition", "status")) {
      r = self$connector
      assert_character(fields)

      if (!self$n_tasks) return(data.table())
      keys = self$tasks
      data = rbindlist(self$read_hashes(keys, fields), use.names = TRUE, fill = TRUE)
      data[, keys := unlist(keys)]
      data[]
    },

    #' @description
    #' Wait until tasks are finished.
    #'
    #' @param keys (`character()`)\cr
    #' Keys of the tasks to wait for.
    wait_tasks = function(keys) {
      assert_character(keys, min.len = 1)
      while (TRUE) {
        if (all(keys %in% c(self$finished_tasks, self$failed_tasks))) break
        Sys.sleep(0.01)
      }
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
    #' @param status (`character(1)`)\cr
    #' Status of the hashes.
    #'
    #' @return (`character()`)\cr
    #' Keys of the hashes.
    write_hashes = function(..., .values = list(), keys = NULL, status = NA) {
      values = discard(c(list(...), .values), function(l) !length(l))
      assert_list(values, names = "unique", types = "list", min.len = 1)
      fields = names(values)
      keys = assert_character(keys %??% uuid::UUIDgenerate(n = length(values[[1]])), len = length(values[[1]]), .var.name = "keys")
      bin_status = redux::object_to_bin(list(status = status))

      # construct list of redis commands to write hashes
      cmds = pmap(c(list(key = keys), values), function(key, ...) {
          # serialize lists
          bin_values = map(list(...), redux::object_to_bin)

          # merge fields and values alternatively
          # c and rbind are fastest option in R
          # data is not copied
          c("HSET", key, c(rbind(fields, bin_values)), "status", list(bin_status))
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

  private = list(

    .n_workers = NULL,

    .cached_results = data.table(),

    .cached_data = data.table(),

    .n_seen_results = 0,

    # prefix key with instance id
    .get_key = function(key) {
      sprintf("%s:%s", self$instance_id, key)
    },

    # prefix key with instance id and worker id
    .get_worker_key = function(key, worker_id = NULL) {
      worker_id = worker_id %??% self$worker_id
      sprintf("%s:%s:%s", self$instance_id, worker_id, key)
    }
  ),

  active = list(

    #' @field connector ([redux::hiredis])\cr
    #' Redis connector.
    connector = function() {
      redux::hiredis(self$config)
    },

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
      cmds = map(self$worker_ids, function(worker_id)  c("LLEN", sprintf("%s:%s", private$.get_key("queued_tasks"), worker_id)))
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

    #' @field priority_info ([data.table::data.table])\cr
    #' Contains the number of tasks in the priority queues.
    priority_info = function() {
      r = self$connector
      map_dtr(self$worker_ids, function(worker_id) {
        list(worker_id = worker_id, n_tasks =  as.integer(r$LLEN(sprintf("%s:%s", private$.get_key("queued_tasks"), worker_id))))
      })
    }
  )
)
