# test_that("a segfault on a local worker is detected", {
#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   worker_loop = function(rush) {
#     while(TRUE) {
#       Sys.sleep(1)
#       xs = list(x1 = 1, x2 = 2)
#       key = rush$push_running_tasks(list(xs))
#       get("attach")(structure(list(), class = "UserDefinedDatabase"))
#     }
#   }

#   worker_ids = rush$start_local_workers(
#     worker_loop = worker_loop,
#     n_workers = 1,
#     lgr_thresholds = c("mlr3/rush" = "debug"))
#   rush$wait_for_workers(1, timeout = 5)

#   Sys.sleep(3)

#   expect_null(rush$lost_worker_ids)
#   rush$detect_lost_workers()
#   expect_equal(rush$lost_worker_ids, worker_ids)
#   rush$fetch_failed_tasks()

#   expect_rush_reset(rush)
# })

# test_that("a segfault on a mirai worker", {
#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   worker_loop = function(rush) {
#     while(TRUE) {
#       Sys.sleep(1)
#       xs = list(x1 = 1, x2 = 2)
#       key = rush$push_running_tasks(list(xs))
#       get("attach")(structure(list(), class = "UserDefinedDatabase"))
#     }
#   }

#   on.exit({
#     mirai::daemons(0)
#   }, add = TRUE)

#   mirai::daemons(1)
#   worker_ids = rush$start_remote_workers(
#     worker_loop = worker_loop,
#     n_workers = 1,
#     lgr_thresholds = c("mlr3/rush" = "debug"))
#   rush$wait_for_workers(1, timeout = 5)

#   Sys.sleep(3)

#   expect_null(rush$lost_worker_ids)
#   rush$detect_lost_workers()
#   expect_equal(rush$lost_worker_ids, worker_ids)
#   rush$fetch_failed_tasks()

#   expect_rush_reset(rush)
# })

# test_that("a segfault on a worker is detected via the heartbeat", {
#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   expect_data_table(rush$worker_info, nrows = 0)

#   worker_loop = function(rush) {
#     while(TRUE) {
#       Sys.sleep(1)
#       xs = list(x1 = 1, x2 = 2)
#       key = rush$push_running_tasks(list(xs))
#       get("attach")(structure(list(), class = "UserDefinedDatabase"))
#     }
#   }

#   rush$worker_script(
#     worker_loop = worker_loop,
#     heartbeat_period = 1,
#     heartbeat_expire = 2,
#     lgr_thresholds = c("mlr3/rush" = "debug"))

#   px = processx::process$new("Rscript",
#     args = c("-e", "rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0, heartbeat_period = 1, heartbeat_expire = 2)"),
#     supervise = TRUE,
#     stderr = "|", stdout = "|")

#   on.exit({
#     px$kill()
#   }, add = TRUE)

#   Sys.sleep(10)

#   expect_null(rush$lost_worker_ids)
#   rush$detect_lost_workers()
#   expect_string(rush$lost_worker_ids)

#   expect_rush_reset(rush)
# })

# test_that("segfaults on workers are detected via the heartbeat", {
#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   expect_data_table(rush$worker_info, nrows = 0)

#   worker_loop = function(rush) {
#     while(TRUE) {
#       Sys.sleep(1)
#       xs = list(x1 = 1, x2 = 2)
#       key = rush$push_running_tasks(list(xs))
#       get("attach")(structure(list(), class = "UserDefinedDatabase"))
#     }
#   }

#   rush$worker_script(
#     worker_loop = worker_loop,
#     heartbeat_period = 1,
#     heartbeat_expire = 2,
#     lgr_thresholds = c("mlr3/rush" = "debug"))

#   px_1 = processx::process$new("Rscript",
#     args = c("-e", "rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0, heartbeat_period = 1, heartbeat_expire = 2)"),
#     supervise = TRUE,
#     stderr = "|", stdout = "|")

#   px_2 = processx::process$new("Rscript",
#     args = c("-e", "rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0, heartbeat_period = 1, heartbeat_expire = 2)"),
#     supervise = TRUE,
#     stderr = "|", stdout = "|")

#   on.exit({
#     px_1$kill()
#     px_2$kill()
#   }, add = TRUE)

#   Sys.sleep(10)

#   expect_null(rush$lost_worker_ids)
#   rush$detect_lost_workers()
#   expect_character(rush$lost_worker_ids, len = 2)

#   expect_rush_reset(rush)
# })

# test_that("a simple error is catched", {
#   skip_on_cran()

#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)

#   worker_loop = function(rush) {
#     while(!rush$terminated && !rush$terminated_on_idle) {
#       task = rush$pop_task(fields = c("xs", "seed"))
#       if (!is.null(task)) {
#         tryCatch({
#           fun = function(x1, x2, ...) {
#             if (x1 < 1) stop("Test error")
#             list(y = x1 + x2)
#           }
#           ys = with_rng_state(fun, args = c(task$xs), seed = task$seed)
#           rush$push_results(task$key, yss = list(ys))
#         }, error = function(e) {
#           condition = list(message = e$message)
#           rush$push_failed(task$key, conditions = list(condition))
#         })
#       }
#     }

#     return(NULL)
#   }

#   worker_ids = rush$start_local_workers(
#     worker_loop = worker_loop,
#     n_workers = 4,
#     lgr_thresholds = c("mlr3/rush" = "debug"))
#   rush$wait_for_workers(2, timeout = 5)

#   xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
#   keys = rush$push_tasks(xss)
#   rush$wait_for_tasks(keys, detect_lost_workers = TRUE)
#   Sys.sleep(2)

#   # check task count
#   expect_equal(rush$n_tasks, 2)
#   expect_equal(rush$n_queued_tasks, 0)
#   expect_equal(rush$n_running_tasks, 0)
#   expect_equal(rush$n_finished_tasks, 1)
#   expect_equal(rush$n_failed_tasks, 1)

#   # check keys in sets
#   expect_character(rush$tasks, len = 2)
#   expect_null(rush$queued_tasks)
#   expect_null(rush$running_tasks)
#   expect_string(rush$finished_tasks)
#   expect_string(rush$failed_tasks)

#   # check fetching
#   expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
#   expect_data_table(rush$fetch_running_tasks(), nrows = 0)
#   expect_data_table(rush$fetch_tasks(), nrows = 2)

#   data = rush$fetch_finished_tasks()
#   expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "keys"))
#   expect_data_table(data, nrows = 1)

#   data = rush$fetch_failed_tasks()
#   expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "keys"))
#   expect_data_table(data, nrows = 1)

#   expect_rush_reset(rush)
# })

# test_that("a lost task is detected", {
#   skip_on_cran()

#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   worker_loop = function(rush) {
#     while(TRUE) {
#       Sys.sleep(1)
#       xs = list(x1 = 1, x2 = 2)
#       key = rush$push_running_tasks(list(xs))
#       get("attach")(structure(list(), class = "UserDefinedDatabase"))
#     }
#   }

#   worker_ids = rush$start_local_workers(
#     worker_loop = worker_loop,
#     n_workers = 1,
#     lgr_thresholds = c("mlr3/rush" = "debug"))
#   rush$wait_for_workers(1, timeout = 5)

#   Sys.sleep(5)

#   rush$detect_lost_workers()

#   # check task count
#   expect_equal(rush$n_tasks, 1)
#   expect_equal(rush$n_queued_tasks, 0)
#   expect_equal(rush$n_running_tasks, 0)
#   expect_equal(rush$n_finished_tasks, 0)
#   expect_equal(rush$n_failed_tasks, 1)

#   # check keys in sets
#   expect_character(rush$tasks, len = 1)
#   expect_null(rush$queued_tasks)
#   expect_null(rush$running_tasks)
#   expect_null(rush$finished_tasks)
#   expect_string(rush$failed_tasks)

#   # check fetching
#   expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
#   expect_data_table(rush$fetch_running_tasks(), nrows = 0)
#   expect_data_table(rush$fetch_tasks(), nrows = 1)

#   data = rush$fetch_failed_tasks()
#   expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "keys"))
#   expect_data_table(data, nrows = 1)
#   expect_equal(data$message, "Worker has crashed or was killed")

#   expect_class(rush$detect_lost_workers(), "Rush")

#   expect_rush_reset(rush)
# })

# test_that("restarting a remote worker works", {
#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   worker_loop = function(rush) {
#     while(TRUE) {
#       Sys.sleep(1)
#       xs = list(x1 = 1, x2 = 2)
#       key = rush$push_running_tasks(list(xs))
#       get("attach")(structure(list(), class = "UserDefinedDatabase"))
#     }
#   }

#   on.exit({
#     mirai::daemons(0)
#   }, add = TRUE)

#   mirai::daemons(1)
#   worker_ids = rush$start_remote_workers(
#     worker_loop = worker_loop,
#     n_workers = 1,
#     lgr_thresholds = c("mlr3/rush" = "debug"),
#     output_log = ".",
#     message_log = ".")
#   rush$wait_for_workers(1, timeout = 5)

#   Sys.sleep(3)

#   expect_null(rush$lost_worker_ids)
#   rush$detect_lost_workers()
#   expect_equal(rush$lost_worker_ids, worker_ids)
#   expect_data_table(rush$fetch_failed_tasks(), nrows = 1)

#   mirai::daemons(0)
#   mirai::daemons(1)

#   rush$restart_workers(worker_ids = worker_ids)

#   Sys.sleep(3)

#   rush$detect_lost_workers()
#   expect_equal(rush$lost_worker_ids, worker_ids)
#   expect_data_table(rush$fetch_failed_tasks(), nrows = 2)

#   expect_rush_reset(rush)
# })

# test_that("blocking on new results works", {
#   skip_on_cran()

#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   worker_loop = function(rush) {
#     while(!rush$terminated && !rush$terminated_on_idle) {
#       task = rush$pop_task(fields = c("xs", "seed"))
#       if (!is.null(task)) {
#         tryCatch({
#           # evaluate task with seed
#           fun = function(x1, x2, ...) {
#             Sys.sleep(5)
#             list(y = x1 + x2)
#           }
#           ys = with_rng_state(fun, args = c(task$xs), seed = task$seed)
#           rush$push_results(task$key, yss = list(ys))
#         }, error = function(e) {
#           condition = list(message = e$message)
#           rush$push_failed(task$key, conditions = list(condition))
#         })
#       }
#     }

#     return(NULL)
#   }

#   worker_ids = rush$start_local_workers(
#     worker_loop = worker_loop,
#     n_workers = 1,
#     lgr_thresholds = c("mlr3/rush" = "debug"))
#   rush$wait_for_workers(1, timeout = 5)

#   xss = list(list(x1 = 1, x2 = 2))
#   keys = rush$push_tasks(xss)

#   expect_data_table(rush$wait_for_new_tasks(timeout = 1), nrows = 0)
#   expect_data_table(rush$wait_for_new_tasks(timeout = 10), nrows = 1)
#   expect_data_table(rush$wait_for_new_tasks(timeout = 1), nrows = 0)

#   expect_rush_reset(rush)
# })

test_that("saving lgr logs works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  worker_ids = rush$start_local_workers(
    worker_loop = test_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(5)

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, nrows = 11)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))

  log = rush$read_log(time_difference = TRUE)
  expect_data_table(log, nrows = 11)
  expect_names(names(log), must.include = c("time_difference"))
  expect_class(log$time_difference, "difftime")

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2), list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, nrows = 26)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))

  expect_rush_reset(rush)
})

test_that("printing logs with redis appender works", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  lg_rush = lgr::get_logger("mlr3/rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush))
  lg_rush$set_threshold("info")

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config, seed = 123)
  worker_loop = function(rush) {
    while(!rush$terminated && !rush$terminated_on_idle) {
      task = rush$pop_task(fields = c("xs", "seed"))
      if (!is.null(task)) {
        tryCatch({
          # evaluate task with seed
          fun = function(x1, x2, ...) {
            lg = lgr::get_logger("mlr3/rush")
            lg$info("test-1-info")
            lg$warn("test-1-warn")
            lg$error("test-1-error")
            list(y = x1 + x2)
          }
          ys = with_rng_state(fun, args = c(task$xs), seed = task$seed)
          rush$push_results(task$key, yss = list(ys))
        }, error = function(e) {
          condition = list(message = e$message)
          rush$push_failed(task$key, conditions = list(condition))
        })
      }
    }

    return(NULL)
  }

  worker_ids = rush$start_local_workers(
    worker_loop = worker_loop,
    n_workers = 2,
    lgr_thresholds = c("mlr3/rush" = "info"))
  rush$wait_for_workers(2, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(5)

  expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")
  expect_silent(rush$print_log())

  xss = list(list(x1 = 3, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(5)

  expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")

  expect_rush_reset(rush, type = "terminate")
})
