#' @title Server
#'
#' @description
#' Server
#'
#' @export
Server = R6::R6Class("Server",
  public = list(

    #' @field id (`character(1)`)\cr
    #' Identifier of the server.
    id = NULL,

    #' @field config ([redux::redis_config])\cr
    #' Redis configuration.
    config = NULL,

    #' @field n_workers (`integer(1)`)\cr
    #' Number of running workers.
    n_workers = NULL,

    #' @field promises ([future::Future()])\cr
    #' List of futures.
    promises = NULL,

    #' @field constants (`list()`)\cr
    #' List of constants.
    constants = NULL,

    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    #'
    #' @param id (`character(1)`)\cr
    #' Identifier of the server.
    #' @param config ([redux::redis_config])\cr
    #' Redis configuration.
    initialize = function(id = NULL, config  = redux::redis_config()) {
      self$id = assert_string(id)
      self$config = assert_class(config, "redis_config")
      self$n_workers = 0
    },

    #' @description
    #' Helper for print outputs.
    #'
    #' @return (`character()`).
    #' @param ... (ignored).
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
      catf(str_indent("* Running Tasks:", self$n_running_tasks))
      catf(str_indent("* Finished Tasks:", self$n_finished_tasks))
      catf(str_indent("* Archived Tasks:", self$n_archived_tasks))
    },

    #' @description
    #' Start workers.
    #'
    #' @param fun (`function`)\cr
    #' Function to be executed by the workers.
    #' @param as_list (`logical(1)`)\cr
    #' Whether the function takes a list of arguments (`fun(xs = list(x1, x2)`) or named arguments (`fun(x1, x2)`).
    #' @param packages (`character()`)\cr
    #' Packages to be loaded by the workers.
    start_workers = function(fun, as_list = FALSE, packages = NULL) {
      assert_function(fun)
      assert_flag(as_list)
      assert_character(packages, null.ok = TRUE)
      self$n_workers = future::nbrOfWorkers()
      r = self$connector

      if (self$n_workers == 1) stop("Only one worker is available.")
      if (!is.null(self$promises)) stop("Workers are already running.")

      # choose wrapper function
      fun_wrapped = if (as_list) fun_wrapper_list else fun_wrapper

      # termination flag
      r$SET(private$.get_key("terminate"), "0")

      # start workers
      self$promises = replicate(self$n_workers,
        future::future(fun_wrapped(fun, self), seed = TRUE, globals = c("fun_wrapped", "fun", "self"), packages = packages)
      )

      return(invisible(self$promises))
    },

    #' @description
    #' Stop workers.
    stop_workers = function() {
      r = self$connector
      r$SET(private$.get_key("terminate"), "1")

      invisible(self)
    },

    #' @description
    #' Check if workers are running.
    #' Print error messages if not.
    check_workers = function() {
      if (!any(future::resolved(self$promises))) return(TRUE)
      cat(future::value(self$promises))
    },

    #' @description
    #' Reset the data base.
    reset = function() {
      r = self$connector
      self$stop_workers()
      self$promises = NULL
      r$DEL(private$.get_key("queued_tasks"))
      r$DEL(private$.get_key("running_tasks"))
      r$DEL(private$.get_key("finished_tasks"))
      r$DEL(private$.get_key("archived_tasks"))
      r$DEL(private$.get_key("terminate"))
      private$.cache = list()

      invisible(self)
    },

    #' @description
    #' Pushes a task to the queue.
    #'
    #' @param xss (list of named `list()`)\cr
    #' Lists of arguments for the function e.g. `list(list(x1, x2), list(x1, x2)))`.
    #' @param extra (`list`)\cr
    #' List of additional information stored along with the task e.g. `list(list(timestamp), list(timestamp)))`.
    push_tasks = function(xss, extra = NULL) {
      assert_list(xss, types = "list")
      assert_list(extra, types = "list", null.ok = TRUE)
      r = self$connector

      lg$info("Sending %i tasks(s)", length(xss))

      keys = private$.write_values(xss, "xs")
      if (!is.null(extra)) private$.write_values(extra, "x_extra", keys)
      r$command(c("LPUSH", private$.get_key("queued_tasks"), keys))

      return(invisible(keys))
    },

    #' @description
    #' Pop a task from the queue.
    #'
    #' @param timeout (`numeric(1)`)\cr
    #' Time to wait for task in seconds.
    pop_task = function(timeout = 1) {
      r = self$connector

      key = r$command(c("BRPOP", private$.get_key("queued_tasks"), timeout))[[2]]
      if (is.null(key)) return(NULL)

      # move key from queued to running
      r$command(c("SADD", private$.get_key("running_tasks"), key))
      list(key = key, xs = redux::bin_to_object(r$HGET(key, "xs")))
    },

    #' @description
    #' Pushes a result to the data base.
    #'
    #' @param key (`character(1)`)\cr
    #' Key of the associated task.
    #' @param ys (named `list()`)\cr
    #' List of results.
    #' Can contain additional information.
    push_result = function(key, ys) {
      assert_string(key)
      assert_list(ys, names = "unique")
      r = self$connector

      private$.write_values(list(ys), "ys", key)

      # move key from running to finished
      r$command(c("SREM", private$.get_key("running_tasks"), key))
      r$command(c("LPUSH", private$.get_key("finished_tasks"), key))

      return(invisible(NULL))
    },

    #' @description
    #' Sync data from the data base to the local cache.
    sync_data = function() {
      r = self$connector
      keys = r$command(list("LPOP", private$.get_key("finished_tasks"), r$LLEN(private$.get_key("finished_tasks"))))

      if (!is.null(keys)) {
        # move keys from finished to archived
        r$command(c("SADD", private$.get_key("archived_tasks"), keys))

        lg$info("Receiving %i result(s)", length(keys))
        hashes = rbindlist(private$.read_values(keys, c("xs", "x_extra", "ys")), , use.names = TRUE, fill = TRUE)
        private$.cache = rbindlist(list(private$.cache, hashes), use.names = TRUE, fill = TRUE)
      }

      invisible(private$.cache)
    }
  ),

  private = list(

    .cache = data.table(),

    .get_key = function(key) {
      sprintf("%s:%s", self$id, key)
    },

    .write_values = function(values, field, keys = NULL) {
      r = self$connector

      keys = keys %??% uuid::UUIDgenerate(n = length(values))
      bin_values = map(values, redux::object_to_bin)

      if (lg$threshold > 400) {
        lg$debug("Serializing %i objects with a size of %s", length(bin_values), format(object.size(bin_values), units = "auto"))
      }

      r$pipeline(.commands = pmap(list(keys, bin_values), function(key, bin_value) redux::redis$HSET(key, field, bin_value)))

      return(invisible(keys))
    },

    .read_values = function(keys, fields = c("xs", "ys", "x_extra")) {
      r = self$connector

      hashes = r$pipeline(.commands = map(keys, function(key) redux::redis$HMGET(key, fields)))
      map(hashes, function(hash) unlist(map_if(hash, is.raw, redux::bin_to_object), recursive = FALSE))
    }
  ),

  active = list(

    #' @field connector ([redux::hiredis])\cr
    #' Redis connector.
    connector = function() {
      redux::hiredis(self$config)
    },

    #' @field data ([data.table::data.table])\cr
    #' Contains all performed function calls.
    data = function(rhs) {
      assert_ro_binding(rhs)
      self$sync_data()
      private$.cache
    },

    #' @field terminate (`logical(1)`)\cr
    #' Whether the tuning process has been terminated.
    terminate = function() {
      r = self$connector
      r$GET(private$.get_key("terminate")) == "1"
    },

    #' @field queued_tasks (`character()`)\cr
    #' Keys of queued tasks.
    queued_tasks = function() {
      r = self$connector
      r$LRANGE(private$.get_key("queued_tasks"), 0, -1)
    },

    #' @field running_tasks (`character()`)\cr
    #' Keys of running tasks.
    running_tasks = function() {
      r = self$connector
      r$SMEMBERS(private$.get_key("running_tasks"))
    },

    #' @field finished_tasks (`character()`)\cr
    #' Keys of finished tasks.
    finished_tasks = function() {
      r = self$connector
      r$LRANGE(private$.get_key("finished_tasks"), 0, -1)
    },

    #' @field archived_tasks (`character()`)\cr
    #' Keys of archived tasks.
    archived_tasks = function() {
      r = self$connector
      r$SMEMBERS(private$.get_key("archived_tasks"))
    },

    #' @field n_queued_tasks (`integer(1)`)\cr
    #' Number of queued tasks.
    n_queued_tasks = function() {
      r = self$connector
      as.integer(r$LLEN(private$.get_key("queued_tasks"))) %??% 0
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

    #' @field n_archived_tasks (`integer(1)`)\cr
    #' Number of archived tasks.
    n_archived_tasks = function() {
      r = self$connector
      as.integer(r$SCARD(private$.get_key("archived_tasks"))) %??% 0
    },

    #' @field free_workers ([integer])\cr
    #' Number of free workers.
    free_workers = function() {
      max(0, self$n_workers - self$n_running_tasks - self$n_queued_tasks)
    }
  )
)

fun_wrapper = function(fun, server) {
  while(!server$terminate) {
    task = server$pop_task()
    if (!is.null(task)) {
      ys = mlr3misc::invoke(fun, .args = c(task$xs, server$constants))
      server$push_result(task$key, c(ys, list(pid = Sys.getpid())))
    }
  }
}

fun_wrapper_list = function(fun, server) {
  while(!server$terminate) {
    task = server$pop_task()
    if (!is.null(task)) {
      ys = mlr3misc::invoke(fun, xs = task$xs, .args = server$constants)
      server$push_result(task$key, c(ys, list(pid = Sys.getpid())))
    }
  }
}
