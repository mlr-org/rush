skip_if_no_redis()

test_that("simple errors are pushed as failed tasks", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = fail_worker_loop,
    n_workers = 1)
  rush$wait_for_workers(1, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)
  Sys.sleep(2)

  # check task count
  expect_equal(rush$n_tasks, 2)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$n_failed_tasks, 1)

  # check keys in sets
  expect_character(rush$tasks, len = 2)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_string(rush$finished_tasks)
  expect_string(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  data = rush$fetch_finished_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "keys"))
  expect_data_table(data, nrows = 1)

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "keys"))
  expect_data_table(data, nrows = 1)
})

# test_that("printing logs with redis appender works", {
#   skip_on_cran()

#   lg_rush = lgr::get_logger("mlr3/rush")
#   old_threshold_rush = lg_rush$threshold
#   on.exit(lg_rush$set_threshold(old_threshold_rush))
#   lg_rush$set_threshold("info")

#   config = start_flush_redis()
#   rush = rsh(network_id = "test-rush", config = config)
#   worker_loop = function(rush) {
#     while(!rush$terminated) {
#       task = rush$pop_task(fields = c("xs"))
#       if (!is.null(task)) {
#         tryCatch({
#           fun = function(x1, x2, ...) {
#             lg = lgr::get_logger("mlr3/rush")
#             lg$info("test-1-info")
#             lg$warn("test-1-warn")
#             lg$error("test-1-error")
#             list(y = x1 + x2)
#           }
#           ys = mlr3misc::invoke(fun, .args = task$xs)
#           rush$finish_tasks(task$key, yss = list(ys))
#         }, error = function(e) {
#           condition = list(message = e$message)
#           rush$fail_tasks(task$key, conditions = list(condition))
#         })
#       }
#     }

#     return(NULL)
#   }

#   worker_ids = rush$start_local_workers(
#     worker_loop = worker_loop,
#     n_workers = 2,
#     lgr_thresholds = c("mlr3/rush" = "info"))
#   rush$wait_for_workers(2, timeout = 5)

#   xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))
#   keys = rush$push_tasks(xss)

#   Sys.sleep(5)

#   expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")
#   expect_silent(rush$print_log())

#   xss = list(list(x1 = 3, x2 = 2))
#   keys = rush$push_tasks(xss)

#   Sys.sleep(5)

#   expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")

#
# })
