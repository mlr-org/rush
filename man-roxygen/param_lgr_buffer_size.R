#' @param lgr_buffer_size (`integer(1)`)\cr
#' By default (`lgr_buffer_size = 0`), the log messages are directly saved in the Redis data store.
#' If `lgr_buffer_size > 0`, the log messages are buffered and saved in the Redis data store when the buffer is full.
#' This improves the performance of the logging.
