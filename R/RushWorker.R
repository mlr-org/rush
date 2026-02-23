#' @title Rush Worker
#'
#' @description
#' [RushWorker] inherits all methods from [Rush].
#' Upon initialization, the worker registers itself in the Redis database.
#'
#' @template param_network_id
#' @template param_config
#' @template param_worker_id
#' @template param_heartbeat_period
#' @template param_heartbeat_expire
#'
#' @return Object of class [R6::R6Class] and `RushWorker` with worker methods.
#' @export
RushWorker = R6::R6Class("RushWorker",
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
      ) { # nolint
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

        # wait until heartbeat process is able to work
        Sys.sleep(1)

        r$SADD(private$.get_key("heartbeat_keys"), heartbeat_key)
      }

      # register worker ids
      r$SADD(private$.get_key("worker_ids"), self$worker_id)
      r$SADD(private$.get_key("running_worker_ids"), self$worker_id)

      # register worker info in
      r$command(c(
        "HSET", private$.get_key(self$worker_id),
        "worker_id", self$worker_id,
        "pid", Sys.getpid(),
        "hostname", rush::get_hostname(),
        "heartbeat", heartbeat_key))
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
      r$command(c("SMOVE", private$.get_key("running_worker_ids"), private$.get_key("terminated_worker_ids"), self$worker_id))
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
