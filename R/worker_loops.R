

#' @title Single Task Worker Loop
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function and pushes the results.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param constants (`list`)\cr
#' List of constants passed to `fun`.
#' @param rush ([RushWorker])\cr
#' Rush worker instance.
#'
#' @export
worker_loop_default = function(fun, constants = NULL, rush) {
  assert_function(fun)
  assert_list(constants, null.ok = TRUE, names = "named")

  while(!rush$terminated && !rush$terminated_on_idle) {
    task = rush$pop_task(fields = c("xs", "seed", "max_retries", "n_failures"))
    if (!is.null(task)) {
      tryCatch({
        # evaluate task with seed
        ys = with_rng_state(fun, args = c(task$xs, constants), seed = task$seed)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        if (is_retriable(task)) {
          rush$retry_task(task)
        } else {
          condition = list(message = e$message)
          rush$push_failed(task$key, conditions = list(condition))
        }
      })
    }
  }

  return(NULL)
}

# for (i in seq(task$tries %??% 1)) {
#   result = try(with_rng_state(fun, args = c(task$xs, constants), seed = task$seed), silent = TRUE)

#   if (inherits(result, "try-error")) {
#     if (i < task$tries) next() # seed could be changed here
#     condition = list(message = attr(result, "condition")$message)
#     rush$push_failed(task$key, conditions = list(condition))
#   } else {
#     rush$push_results(task$key, yss = list(result))
#     break
#   }
# }

#' @title Single Task Worker Loop with callr Encapsulation
#'
#' @description
#' Worker loop that pops a single task from the queue, executes the function in an external callr session and pushes the results.
#' Supports timeouts on the tasks.
#'
#' @param fun (`function`)\cr
#' Function to be executed.
#' @param constants (`list`)\cr
#' List of constants passed to `fun`.
#' @param rush ([RushWorker])\cr
#' Rush worker instance.
#'
#' @export
worker_loop_callr = function(fun, constants = NULL, rush) {
  assert_function(fun)
  assert_list(constants, null.ok = TRUE, names = "named")

  while(!rush$terminated && !rush$terminated_on_idle) {
    task = rush$pop_task(fields = c("xs", "seed", "timeout", "max_retries", "n_failures"))
    if (!is.null(task)) {
      tryCatch({
        ys = callr::r(with_rng_state,
          args = list(fun = fun, args = c(task$xs, constants), seed = task$seed),
          supervise = TRUE,
          timeout = task$timeout %??% Inf)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        if (is_retriable(task)) {
          rush$retry_task(task)
        } else {
          if (inherits(e, "callr_timeout_error")) {
            # session has timed out
            condition = list(message = sprintf("Task timed out after %s seconds", task$timeout))
          } else if (is.null(e$parent$message)) {
            # session has crashed
            condition = list(message = "External R session has crashed or was killed")
          } else {
            # simple error
            condition = list(message = e$parent$message)
          }
          rush$push_failed(task$key, conditions = list(condition))
        }
      })
    }
  }

  return(NULL)
}
