test_that("worker_loop_default works", {
  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_null(worker_loop_default(fun, rush = rush))
  expect_equal(rush$n_finished_tasks, 1L)

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_default works with failed task", {
  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) stop("failed")

  expect_null(worker_loop_default(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)

  expect_rush_reset(rush, type = "terminate")
})

test_that("worker_loop_default works with terminate ", {
  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) stop("failed")

  expect_null(worker_loop_default(fun, rush = rush))
  expect_equal(rush$n_failed_tasks, 1L)

  expect_rush_reset(rush, type = "terminate")
})

test_that("seed is set correctly", {

  on.exit({
    .lec.exit()
  })

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local", seed = 123456)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss, terminate_workers = TRUE)
  fun = function(x1, x2, ...) list(y = sample(10000, 1))

  expect_null(worker_loop_default(fun, rush = rush))

  expect_equal(rush$fetch_finished_tasks()$y, 4492)

  expect_rush_reset(rush, type = "terminate")
})

