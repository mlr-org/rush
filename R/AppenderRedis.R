#' @title Log to Redis Database
#'
#' @description
#' [AppenderRedis] writes log messages to a Redis database.
#' This [lgr::Appender] is created internally by [RushWorker] when logger thresholds are passed via [rush_plan()].
#'
#' @param config ([redux::redis_config])\cr
#' Redis configuration options.
#' @param key (`character(1)`)\cr
#' Key of the list holding the log messages in the Redis data store.
#' @param threshold (`integer(1)` | `character(1)`)\cr
#' Threshold for the log messages.
#' @param layout ([lgr::Layout])\cr
#' Layout for the log messages.
#' The default layout strips custom fields from the log events, because they might not be JSON-serializable.
#' The stripping is scoped to this appender, so other appenders on the same logger still see the custom fields.
#' @param buffer_size (`integer(1)`)\cr
#' Size of the buffer.
#' @param flush_threshold (`character(1)`)\cr
#' Threshold for flushing the buffer.
#' @param flush_on_exit (`logical(1)`)\cr
#' Flush the buffer on exit.
#' @param flush_on_rotate (`logical(1)`)\cr
#' Flush the buffer on rotate.
#' @param should_flush (`function`)\cr
#' Function that determines if the buffer should be flushed.
#' @param filters (`list`)\cr
#' List of filters.
#'
#' @return Object of class [R6::R6Class] and `AppenderRedis` with methods for writing log events to Redis databases.
#' @export
#' @examples
#' if (redux::redis_available()) {
#'    config_local = redux::redis_config()
#'
#'    rush_plan(
#'      config = config_local,
#'      n_workers = 2,
#'      lgr_thresholds = c(rush = "info"))
#'
#'    rush = rsh(network_id = "test_network")
#'    rush
#' }
AppenderRedis = R6::R6Class(
  "AppenderRedis",
  inherit = lgr::AppenderMemory,
  cloneable = FALSE,
  public = list(
    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function(
      config,
      key,
      threshold = NA_integer_,
      layout = lgr::LayoutJson$new(
        timestamp_fmt = "%Y-%m-%d %H:%M:%OS3",
        # custom fields might not be JSON-serializable, so only the standard fields are written to Redis.
        transform_event = function(event) {
          values = event$values
          values[intersect(names(values), c("level", "timestamp", "logger", "caller", "msg", "rawMsg"))]
        }
      ),
      buffer_size = 0,
      flush_threshold = "error",
      flush_on_exit = TRUE,
      flush_on_rotate = TRUE,
      should_flush = NULL,
      filters = NULL
    ) {
      require_namespaces(c("redux", "data.table"))
      assert_class(config, "redis_config")
      private$.connector = redux::hiredis(config)
      private$.key = assert_string(key)

      # appender
      self$set_threshold(threshold)
      self$set_layout(layout)
      self$set_filters(filters)

      # buffer
      private$initialize_buffer(buffer_size)

      # flush conditions
      self$set_should_flush(should_flush)
      self$set_flush_threshold(flush_threshold)
      self$set_flush_on_exit(flush_on_exit)
      self$set_flush_on_rotate(flush_on_rotate)
    },

    #' @description
    #' Sends the buffer's contents to the Redis data store, and then clears the buffer.
    flush = function() {
      # convert event to JSON and push to Redis
      cmds = map(private$.buffer_events, function(event) {
        json_event = private$.layout$format_event(event)
        c("RPUSH", private$.key, json_event)
      })
      # no error handling needed: lgr's Logger$log() wraps appender calls in tryCatch
      # and demotes errors to warnings, so a Redis failure cannot crash the computation
      private$.connector$pipeline(.commands = cmds)

      private$insert_pos = 0L
      private$.buffer_events = list()
      invisible(self)
    }
  ),

  private = list(
    .connector = NULL,
    .key = NULL
  )
)
