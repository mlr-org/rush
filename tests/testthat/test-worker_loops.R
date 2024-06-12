# default ----------------------------------------------------------------------

test_that("worker_loop_default works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_null(worker_loop_default(fun, rush = rush))
  expect_equal(rush$n_finished_tasks, 1L)

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_default works with failed task", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) stop("Simple R error")

  expect_null(worker_loop_default(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)
  expect_equal(rush$fetch_failed_tasks()$message, "Simple R error")

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_default retries failed task", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, max_retries = 2, terminate_workers = TRUE)
  fun = function(x1, x2, ...) stop("Simple R error")

  expect_null(worker_loop_default(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)
  expect_equal(rush$fetch_failed_tasks()$message, "Simple R error")

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_default sets seed is set correctly", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE, seed = 123456)
  xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) list(y = sample(10000, 1))

  expect_null(worker_loop_default(fun, rush = rush))

  expect_equal(rush$fetch_finished_tasks()$y, c(7521, 1616, 551))

  expect_rush_reset(rush, type = "terminate")
})

# callr ------------------------------------------------------------------------

test_that("worker_loop_callr works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_null(worker_loop_callr(fun, rush = rush))
  expect_equal(rush$n_finished_tasks, 1L)

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_callr works with failed task", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) stop("Simple R error")

  expect_null(worker_loop_callr(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)
  expect_equal(rush$fetch_failed_tasks()$message, "Simple R error")

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_callr works with lost task", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) get("attach")(structure(list(), class = "UserDefinedDatabase"))

  expect_null(worker_loop_callr(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)
  expect_equal(rush$fetch_failed_tasks()$message, "External R session has crashed or was killed")

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_callr works with timeout", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, timeouts = 1, terminate_workers = TRUE)
  fun = function(x1, x2, ...) Sys.sleep(10)

  expect_null(worker_loop_callr(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)
  expect_equal(rush$fetch_failed_tasks()$message, "Task timed out after 1 seconds")

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_callr sets seed correctly", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE, seed = 123456)
  xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) list(y = sample(10000, 1))

  expect_null(worker_loop_callr(fun, rush = rush))

  expect_equal(rush$fetch_finished_tasks()$y, c(7521, 1616, 551))

  expect_rush_reset(rush, type = "terminate")
})
