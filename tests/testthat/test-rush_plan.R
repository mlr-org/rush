test_that("rush_plan family works", {
  skip_on_cran()

  expect_false(rush_available())
  config = redis_config()
  rush_plan(n_workers = 2, config)
  expect_identical(config, rush_env$config)
  expect_identical(rush_config()$config, config)
  expect_equal(rush_env$n_workers, 2)
  expect_equal(rush_config()$n_workers, 2)
  expect_true(rush_available())
})

test_that("rush_plan throws and error if redis is not available", {
  config = redis_config(url = "redis://localhost:1234")
  expect_error(rush_plan(n_workers = 2, config), "Can't connect to Redis")
})

test_that("start workers", {
  skip_on_cran()

  config = start_flush_redis()
  rush_plan(n_workers = 2, config)

  expect_equal(rush_env$n_workers, 2)

  rush = rsh("test-rush")
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_local_workers(fun = fun)

  expect_equal(rush$n_running_workers, 2)

  expect_rush_reset(rush)
})

test_that("set threshold", {
  skip_on_cran()

  lg_rush = lgr::get_logger("rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush))
  lg_rush$set_threshold("debug")

  config = start_flush_redis()
  rush_plan(n_workers = 2, config, lgr_thresholds = c(rush = "debug"))

  expect_equal(rush_env$n_workers, 2)
  expect_equal(rush_env$lgr_thresholds, c(rush = "debug"))

  rush = rsh("test-rush")
  fun = function(x1, x2, ...) list(y = x1 + x2)
  expect_output(rush$start_local_workers(fun = fun), "Pushing.*")

  expect_rush_reset(rush)
})

test_that("set start worker timeout", {
  skip_on_cran()

  config = start_flush_redis()
  rush_plan(n_workers = 2, config, start_worker_timeout = -Inf)

  expect_equal(rush_env$start_worker_timeout, -Inf)

  rush = rsh("test-rush")
  fun = function(x1, x2, ...) list(y = x1 + x2)
  expect_error(rush$start_local_workers(fun = fun), "Timeout waiting")

  expect_rush_reset(rush)
})
